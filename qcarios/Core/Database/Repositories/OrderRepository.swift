//
//  OrderRepository.swift
//  qcarios
//
//  订单数据访问层
//

import Foundation
import Supabase
import Combine
import CoreLocation

protocol OrderRepositoryProtocol {
    func createOrder(_ request: CreateOrderRequest) async throws -> Order
    func getOrder(id: UUID) async throws -> Order
    func getOrdersByPassenger(passengerId: UUID, status: OrderStatus?) async throws -> [Order]
    func getOrdersByDriver(driverId: UUID, status: OrderStatus?) async throws -> [Order]
    func getPendingOrders(near location: Location, radiusKm: Decimal) async throws -> [Order]
    func updateOrderStatus(id: UUID, status: OrderStatus) async throws -> Order
    func acceptOrder(id: UUID, driverId: UUID) async throws -> Order
    func cancelOrder(id: UUID, cancelledBy: UUID, reason: String?) async throws -> Order
    func updateOrderPrice(id: UUID, finalPrice: Decimal, actualDistance: Decimal, actualDuration: Int) async throws -> Order
    func subscribeToOrder(id: UUID) -> AnyPublisher<Order, Error>
}

final class OrderRepository: OrderRepositoryProtocol {

    // MARK: - Properties
    private let client = SupabaseClientWrapper.shared.client
    private let tableName = SupabaseConfig.Table.orders

    // MARK: - Create Order

    func createOrder(_ request: CreateOrderRequest) async throws -> Order {
        let response: Order = try await client
            .from(tableName)
            .insert(request)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    // MARK: - Read Operations

    func getOrder(id: UUID) async throws -> Order {
        let response: Order = try await client
            .from(tableName)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        return response
    }

    func getOrdersByPassenger(passengerId: UUID, status: OrderStatus? = nil) async throws -> [Order] {
        var query = client
            .from(tableName)
            .select()
            .eq("passenger_id", value: passengerId.uuidString)

        if let status = status {
            query = query.eq("status", value: status.rawValue)
        }

        let response: [Order] = try await query
            .order("created_at", ascending: false)
            .execute()
            .value

        return response
    }

    func getOrdersByDriver(driverId: UUID, status: OrderStatus? = nil) async throws -> [Order] {
        var query = client
            .from(tableName)
            .select()
            .eq("driver_id", value: driverId.uuidString)

        if let status = status {
            query = query.eq("status", value: status.rawValue)
        }

        let response: [Order] = try await query
            .order("created_at", ascending: false)
            .execute()
            .value

        return response
    }

    func getPendingOrders(near location: Location, radiusKm: Decimal = 5) async throws -> [Order] {
        // 使用PostGIS查询附近的待接单订单
        let allOrders: [Order] = try await client
            .from(tableName)
            .select()
            .eq("status", value: OrderStatus.pending.rawValue)
            .execute()
            .value

        // 客户端过滤（也可以用RPC函数在数据库端过滤）
        return allOrders.filter { order in
            let distance = calculateDistance(
                from: location.coordinate,
                to: order.pickupLocation.coordinate
            )
            return distance <= radiusKm
        }
    }

    // MARK: - Update Operations

    func updateOrderStatus(id: UUID, status: OrderStatus) async throws -> Order {
        print("🔄 更新订单状态: 订单ID=\(id), 新状态=\(status.rawValue)")

        // 构建更新数据结构体
        struct OrderStatusUpdate: Encodable {
            let status: String
            let acceptedAt: String?
            let arrivedAt: String?
            let startedAt: String?
            let completedAt: String?
            let cancelledAt: String?

            enum CodingKeys: String, CodingKey {
                case status
                case acceptedAt = "accepted_at"
                case arrivedAt = "arrived_at"
                case startedAt = "started_at"
                case completedAt = "completed_at"
                case cancelledAt = "cancelled_at"
            }
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let updates = OrderStatusUpdate(
            status: status.rawValue,
            acceptedAt: status == .accepted ? now : nil,
            arrivedAt: status == .driverArrived ? now : nil,
            startedAt: status == .inProgress ? now : nil,
            completedAt: status == .completed ? now : nil,
            cancelledAt: status == .cancelled ? now : nil
        )

        // 不使用 .single()，而是返回数组，然后取第一个
        let response: [Order] = try await client
            .from(tableName)
            .update(updates)
            .eq("id", value: id.uuidString)
            .select()
            .execute()
            .value

        guard let order = response.first else {
            print("❌ 订单不存在")
            throw NSError(domain: "OrderRepository", code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "订单不存在"])
        }

        print("✅ 订单状态更新成功")
        return order
    }

    func acceptOrder(id: UUID, driverId: UUID) async throws -> Order {
        print("🚗 司机接单: 订单ID=\(id), 司机ID=\(driverId)")

        // 先查询订单当前状态
        do {
            let existingOrder: Order = try await client
                .from(tableName)
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value

            print("📋 订单当前状态:")
            print("   - 状态: \(existingOrder.status.rawValue)")
            print("   - 司机ID: \(existingOrder.driverId?.uuidString ?? "无")")
            print("   - 乘客ID: \(existingOrder.passengerId.uuidString)")
        } catch {
            print("❌ 查询订单失败: \(error)")
        }

        // 使用结构体替代字典
        struct AcceptOrderUpdate: Encodable {
            let driverId: String
            let status: String
            let acceptedAt: String

            enum CodingKeys: String, CodingKey {
                case driverId = "driver_id"
                case status
                case acceptedAt = "accepted_at"
            }
        }

        let updates = AcceptOrderUpdate(
            driverId: driverId.uuidString,
            status: OrderStatus.accepted.rawValue,
            acceptedAt: ISO8601DateFormatter().string(from: Date())
        )

        print("📝 更新数据: driver_id=\(driverId.uuidString), status=accepted")
        print("🔍 查询条件: status == '\(OrderStatus.pending.rawValue)'")

        // 不使用 .single()，而是返回数组，然后取第一个
        let response: [Order] = try await client
            .from(tableName)
            .update(updates)
            .eq("id", value: id.uuidString)
            .eq("status", value: OrderStatus.pending.rawValue) // 只能接待接单状态的订单
            .select()
            .execute()
            .value

        print("📦 更新响应: 返回 \(response.count) 条记录")

        // 如果没有匹配到，再次查询看看订单是否仍然存在
        if response.isEmpty {
            do {
                let checkOrder: Order = try await client
                    .from(tableName)
                    .select()
                    .eq("id", value: id.uuidString)
                    .single()
                    .execute()
                    .value
                print("⚠️ 更新失败后订单状态: \(checkOrder.status.rawValue)")
            } catch {
                print("⚠️ 更新失败后查询订单也失败: \(error)")
            }
        }

        guard let order = response.first else {
            print("❌ 订单不存在或已被接单（不是 pending 状态）")
            throw NSError(domain: "OrderRepository", code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "订单不存在或已被其他司机接单"])
        }

        print("✅ 接单成功")
        return order
    }

    func cancelOrder(id: UUID, cancelledBy: UUID, reason: String? = nil) async throws -> Order {
        print("🔄 取消订单: \(id)")

        // 使用结构体替代字典
        struct CancelOrderUpdate: Encodable {
            let status: String
            let cancelledBy: String
            let cancelledAt: String
            let cancelReason: String?

            enum CodingKeys: String, CodingKey {
                case status
                case cancelledBy = "cancelled_by"
                case cancelledAt = "cancelled_at"
                case cancelReason = "cancel_reason"
            }
        }

        let updates = CancelOrderUpdate(
            status: OrderStatus.cancelled.rawValue,
            cancelledBy: cancelledBy.uuidString,
            cancelledAt: ISO8601DateFormatter().string(from: Date()),
            cancelReason: reason
        )

        // 不使用 .single()，而是返回数组，然后取第一个
        let response: [Order] = try await client
            .from(tableName)
            .update(updates)
            .eq("id", value: id.uuidString)
            .select()
            .execute()
            .value

        guard let order = response.first else {
            print("❌ 订单不存在或已被取消")
            throw NSError(domain: "OrderRepository", code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "订单不存在或已被取消"])
        }

        print("✅ 订单取消成功")
        return order
    }

    func updateOrderPrice(id: UUID, finalPrice: Decimal, actualDistance: Decimal, actualDuration: Int) async throws -> Order {
        print("💰 更新订单价格: 订单ID=\(id), 最终价格=\(finalPrice)")

        // 使用结构体替代字典
        struct PriceUpdate: Encodable {
            let finalPrice: Double
            let actualDistanceKm: Double
            let actualDurationMin: Int

            enum CodingKeys: String, CodingKey {
                case finalPrice = "final_price"
                case actualDistanceKm = "actual_distance_km"
                case actualDurationMin = "actual_duration_min"
            }
        }

        let updates = PriceUpdate(
            finalPrice: NSDecimalNumber(decimal: finalPrice).doubleValue,
            actualDistanceKm: NSDecimalNumber(decimal: actualDistance).doubleValue,
            actualDurationMin: actualDuration
        )

        // 不使用 .single()，而是返回数组，然后取第一个
        let response: [Order] = try await client
            .from(tableName)
            .update(updates)
            .eq("id", value: id.uuidString)
            .select()
            .execute()
            .value

        guard let order = response.first else {
            print("❌ 订单不存在")
            throw NSError(domain: "OrderRepository", code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "订单不存在"])
        }

        print("✅ 订单价格更新成功")
        return order
    }

    // MARK: - Realtime Subscription

    func subscribeToOrder(id: UUID) -> AnyPublisher<Order, Error> {
        let subject = PassthroughSubject<Order, Error>()

        let channel = client.realtime.channel("order:\(id.uuidString)")

        channel
            .on("postgres_changes", filter: ChannelFilter(
                event: "UPDATE",
                schema: "public",
                table: tableName,
                filter: "id=eq.\(id.uuidString)"
            )) { message in
                do {
                    // 从 payload 的 new 字段获取更新后的数据
                    guard let payload = message.payload as? [String: Any],
                          let newData = payload["new"] else {
                        throw NSError(domain: "OrderRepository", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Invalid realtime payload"])
                    }

                    let data = try JSONSerialization.data(withJSONObject: newData)
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let order = try decoder.decode(Order.self, from: data)
                    subject.send(order)
                } catch {
                    print("❌ 实时订阅解析错误: \(error)")
                    subject.send(completion: .failure(error))
                }
            }
            .subscribe()

        return subject.eraseToAnyPublisher()
    }

    // MARK: - Helper Methods

    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Decimal {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let distanceInMeters = fromLocation.distance(from: toLocation)
        return Decimal(distanceInMeters / 1000) // 转换为公里
    }
}

// MARK: - Order Extensions
extension Order {
    /// 检查订单是否可以被司机接单
    func canBeAcceptedBy(driver: DriverProfile) -> Bool {
        return status == .pending &&
               driver.canAcceptOrders &&
               driverId == nil
    }

    /// 检查订单是否可以被取消
    func canBeCancelledBy(userId: UUID) -> Bool {
        return (passengerId == userId || driverId == userId) &&
               [.pending, .accepted].contains(status)
    }
}
