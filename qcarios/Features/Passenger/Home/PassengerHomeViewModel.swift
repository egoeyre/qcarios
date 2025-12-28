//
//  PassengerHomeViewModel.swift
//  qcarios
//
//  乘客端首页ViewModel
//

import Foundation
import CoreLocation
import Combine
import Supabase

@MainActor
final class PassengerHomeViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var pickupLocation: CLLocationCoordinate2D?
    @Published var pickupAddress: String?
    @Published var selectedDestination: POI?
    @Published var annotations: [MapAnnotation] = []
    @Published var routePolyline: [CLLocationCoordinate2D]?
    @Published var currentRoute: RouteInfo?
    @Published var estimatedPrice: Double?
    @Published var isCreatingOrder = false
    @Published var showRouteInfo = false

    // 活跃订单相关
    @Published var activeOrder: Order?
    @Published var showActiveOrderAlert = false
    @Published var showOrderDetail = false
    @Published var alertMessage = ""

    // MARK: - Dependencies

    private let locationService = LocationService.shared
    private let mapService = AMapService.shared
    private let orderRepository = OrderRepository()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupBindings()
        Task {
            await checkActiveOrder()
        }
    }

    // MARK: - Setup

    private func setupBindings() {
        // 监听位置更新
        locationService.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func requestLocationPermission() {
        locationService.requestPermission()
        locationService.startUpdatingLocation()
    }

    func useCurrentLocationAsPickup() {
        guard let location = currentLocation else { return }
        pickupLocation = location
        mapCenter = location
        fetchPickupAddress()
    }

    func calculateRoute() {
        guard let pickup = pickupLocation,
              let destination = selectedDestination else {
            return
        }

        Task {
            do {
                // 计算路线
                let route = try await mapService.calculateRoute(
                    from: pickup,
                    to: destination.location
                )

                self.currentRoute = route
                self.routePolyline = route.polyline
                self.showRouteInfo = true

                // 更新标注
                updateAnnotations()

                // 计算价格
                await calculatePrice(route: route)

            } catch {
                print("❌ 计算路线失败: \(error)")
            }
        }
    }

    func createOrder() {
        guard let pickup = pickupLocation,
              let destination = selectedDestination,
              let userId = AuthService.shared.currentUser?.id else {
            return
        }

        isCreatingOrder = true

        Task {
            do {
                // 先检查是否有活跃订单
                await checkActiveOrder()

                if activeOrder != nil {
                    // 有活跃订单,显示提示并导航到订单详情
                    alertMessage = "您有正在进行的订单，请先完成或取消该订单"
                    showActiveOrderAlert = true
                    isCreatingOrder = false
                    return
                }

                // 创建新订单
                let request = CreateOrderRequest(
                    passengerId: userId,
                    orderType: .immediate,
                    serviceType: .standard,
                    scheduledTime: nil,
                    pickupAddress: pickupAddress,
                    pickupLat: pickup.latitude,
                    pickupLng: pickup.longitude,
                    pickupPoiId: nil,
                    dropoffAddress: destination.address,
                    dropoffLat: destination.location.latitude,
                    dropoffLng: destination.location.longitude,
                    dropoffPoiId: destination.id,
                    waypoints: nil,
                    passengerNote: nil
                )

                let order = try await orderRepository.createOrder(request)

                print("✅ 订单创建成功: \(order.orderNumber)")

                // 设置为活跃订单并导航到详情页
                activeOrder = order
                showOrderDetail = true

            } catch {
                print("❌ 创建订单失败: \(error)")
                alertMessage = "创建订单失败: \(error.localizedDescription)"
                showActiveOrderAlert = true
            }

            isCreatingOrder = false
        }
    }

    /// 检查是否有活跃订单
    func checkActiveOrder() async {
        guard let userId = AuthService.shared.currentUser?.id else {
            return
        }

        do {
            // 查询用户的所有订单
            let orders = try await orderRepository.getOrdersByPassenger(
                passengerId: userId,
                status: nil
            )

            // 找到第一个活跃订单（未完成且未取消）
            activeOrder = orders.first { order in
                order.isActive // pending, accepted, driverArrived, inProgress
            }

            if activeOrder != nil {
                print("📋 找到活跃订单: \(activeOrder!.orderNumber)")
            }

        } catch {
            print("❌ 检查活跃订单失败: \(error)")
        }
    }

    /// 查看活跃订单
    func viewActiveOrder() {
        if activeOrder != nil {
            showOrderDetail = true
        }
    }

    // MARK: - Private Methods

    private func handleLocationUpdate(_ location: CLLocation) {
        currentLocation = location.coordinate

        if pickupLocation == nil {
            pickupLocation = location.coordinate
            mapCenter = location.coordinate
            fetchPickupAddress()
        }
    }

    private func fetchPickupAddress() {
        guard let location = pickupLocation else { return }

        Task {
            do {
                let address = try await mapService.reverseGeocode(location: location)
                self.pickupAddress = address
            } catch {
                print("❌ 获取地址失败: \(error)")
            }
        }
    }

    private func updateAnnotations() {
        var newAnnotations: [MapAnnotation] = []

        // 上车点
        if let pickup = pickupLocation {
            newAnnotations.append(
                MapAnnotation(
                    coordinate: pickup,
                    title: "上车点",
                    subtitle: pickupAddress
                )
            )
        }

        // 目的地
        if let destination = selectedDestination {
            newAnnotations.append(
                MapAnnotation(
                    coordinate: destination.location,
                    title: "目的地",
                    subtitle: destination.address
                )
            )
        }

        annotations = newAnnotations
    }

    private func calculatePrice(route: RouteInfo) async {
        // 使用Supabase RPC函数计算价格
        do {
            let client = SupabaseClientWrapper.shared.client

            // 根据官方文档，params 必须是 Encodable 类型
            let params = CalculateOrderPriceParams(
                p_city_code: "BJ", // TODO: 根据位置获取城市代码
                p_service_type: "standard",
                p_distance_km: route.distanceKm,
                p_duration_min: route.durationMinutes,
                p_order_time: ISO8601DateFormatter().string(from: Date())
            )

            // 根据官方文档，直接使用 client.rpc() 而不是 client.database.rpc()
            let price: Double = try await client
                .rpc(SupabaseConfig.RPC.calculateOrderPrice, params: params)
                .execute()
                .value

            self.estimatedPrice = price

        } catch {
            print("❌ 计算价格失败: \(error)")
            // 使用简单计算作为fallback
            let simplePrice = route.distanceKm * 5 + 20 // 起步价20 + 5元/公里
            self.estimatedPrice = simplePrice
        }
    }
}
