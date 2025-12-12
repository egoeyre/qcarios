//
//  OrderDetailView.swift
//  qcarios
//
//  订单详情页面
//

import SwiftUI
import CoreLocation

struct OrderDetailView: View {

    let order: Order
    @StateObject private var viewModel: OrderDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(order: Order) {
        self.order = order
        self._viewModel = StateObject(wrappedValue: OrderDetailViewModel(order: order))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 订单状态卡片
                statusCard

                // 行程信息
                routeCard

                // 司机信息（如果已分配司机）
                if viewModel.order.driverId != nil {
                    driverCard
                }

                // 费用明细
                if viewModel.order.status == .completed {
                    priceCard
                }

                // 操作按钮
                actionButtons
            }
            .padding()
        }
        .navigationTitle("订单详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.subscribeToOrderUpdates()
        }
        .onDisappear {
            viewModel.unsubscribe()
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 12) {
            // 状态图标
            Image(systemName: statusIcon)
                .font(.system(size: 50))
                .foregroundColor(statusColor)

            // 状态文字
            Text(viewModel.order.status.displayText)
                .font(.title2)
                .fontWeight(.bold)

            // 订单号
            Text("订单号: \(viewModel.order.orderNumber)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }

    private var statusIcon: String {
        switch viewModel.order.status {
        case .pending: return "clock"
        case .accepted: return "checkmark.circle"
        case .driverArrived: return "car"
        case .inProgress: return "figure.walk"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    private var statusColor: Color {
        switch viewModel.order.status {
        case .pending: return .orange
        case .accepted, .driverArrived: return .blue
        case .inProgress: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }

    // MARK: - Route Card

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("行程信息")
                .font(.headline)

            // 上车点
            RoutePoint(
                icon: "location.circle.fill",
                iconColor: .green,
                title: "上车点",
                address: viewModel.order.pickupAddress ?? "未知"
            )

            Divider()

            // 目的地
            RoutePoint(
                icon: "mappin.circle.fill",
                iconColor: .red,
                title: "目的地",
                address: viewModel.order.dropoffAddress ?? "未知"
            )

            // 距离和时长
            if let distance = viewModel.order.actualDistanceKm ?? viewModel.order.estimatedDistanceKm,
               let duration = viewModel.order.actualDurationMin ?? viewModel.order.estimatedDurationMin {
                Divider()

                HStack {
                    Label("\(String(format: "%.1f", NSDecimalNumber(decimal: distance).doubleValue))公里", systemImage: "arrow.left.arrow.right")
                    Spacer()
                    Label("\(duration)分钟", systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    // MARK: - Driver Card

    private var driverCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("司机信息")
                .font(.headline)

            if let driverProfile = viewModel.driverProfile {
                HStack(spacing: 16) {
                    // 头像
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )

                    // 信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.driverUser?.displayName ?? "司机")
                            .font(.headline)

                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(driverProfile.ratingText)
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            Spacer()

                            Text("\(driverProfile.totalOrders)单")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Text(driverProfile.experienceText)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    // 拨打电话
                    Button(action: {
                        // TODO: 拨打电话
                    }) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                }
            } else {
                ProgressView()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    // MARK: - Price Card

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("费用明细")
                .font(.headline)

            if let finalPrice = viewModel.order.finalPrice {
                HStack {
                    Text("订单金额")
                    Spacer()
                    Text("¥\(String(format: "%.2f", NSDecimalNumber(decimal: finalPrice).doubleValue))")
                        .fontWeight(.bold)
                }

                if let discount = viewModel.order.discountAmount, discount > 0 {
                    HStack {
                        Text("优惠金额")
                        Spacer()
                        Text("-¥\(String(format: "%.2f", NSDecimalNumber(decimal: discount).doubleValue))")
                            .foregroundColor(.red)
                    }
                }

                Divider()

                HStack {
                    Text("实付金额")
                        .font(.headline)
                    Spacer()
                    Text("¥\(String(format: "%.2f", NSDecimalNumber(decimal: finalPrice).doubleValue))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if viewModel.order.canCancel {
                Button(action: {
                    viewModel.cancelOrder()
                }) {
                    Text("取消订单")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(12)
                }
            }

            if viewModel.order.status == .completed && !viewModel.hasReviewed {
                Button(action: {
                    // TODO: 打开评价页面
                }) {
                    Text("评价司机")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Route Point
struct RoutePoint: View {
    let icon: String
    let iconColor: Color
    let title: String
    let address: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(address)
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - ViewModel
@MainActor
final class OrderDetailViewModel: ObservableObject {

    @Published var order: Order
    @Published var driverUser: User?
    @Published var driverProfile: DriverProfile?
    @Published var hasReviewed = false

    private let orderRepository = OrderRepository()
    private let userRepository = UserRepository()
    private let driverRepository = DriverRepository()
    private var subscription: AnyCancellable?

    init(order: Order) {
        self.order = order
        Task {
            await loadDriverInfo()
        }
    }

    func subscribeToOrderUpdates() {
        subscription = orderRepository.subscribeToOrder(id: order.id)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ 订阅失败: \(error)")
                }
            }, receiveValue: { [weak self] updatedOrder in
                self?.order = updatedOrder
                Task {
                    await self?.loadDriverInfo()
                }
            })
    }

    func unsubscribe() {
        subscription?.cancel()
    }

    func cancelOrder() {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        Task {
            do {
                let cancelledOrder = try await orderRepository.cancelOrder(
                    id: order.id,
                    cancelledBy: userId,
                    reason: "乘客取消"
                )
                order = cancelledOrder
            } catch {
                print("❌ 取消订单失败: \(error)")
            }
        }
    }

    private func loadDriverInfo() async {
        guard let driverId = order.driverId else { return }

        do {
            async let user = userRepository.getUser(id: driverId)
            async let profile = driverRepository.getDriverProfile(userId: driverId)

            self.driverUser = try await user
            self.driverProfile = try await profile
        } catch {
            print("❌ 加载司机信息失败: \(error)")
        }
    }
}

// MARK: - Preview
struct OrderDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OrderDetailView(order: Order(
                id: UUID(),
                orderNumber: "DD20231212123456",
                passengerId: UUID(),
                driverId: UUID(),
                orderType: .immediate,
                serviceType: .standard,
                pickupAddress: "北京市朝阳区建国门外大街1号",
                pickupLat: 39.9042,
                pickupLng: 116.4074,
                pickupPoiId: nil,
                dropoffAddress: "北京市海淀区中关村大街1号",
                dropoffLat: 39.9891,
                dropoffLng: 116.3142,
                dropoffPoiId: nil,
                estimatedDistanceKm: 10.5,
                estimatedDurationMin: 30,
                estimatedPrice: 68,
                status: .accepted,
                createdAt: Date(),
                updatedAt: Date()
            ))
        }
    }
}
