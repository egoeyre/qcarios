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
        if let status = status {
            let response: [Order] = try await client
                .from(tableName)
                .select()
                .eq("passenger_id", value: passengerId.uuidString)
                .eq("status", value: status.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
            return response
        } else {
            let response: [Order] = try await client
                .from(tableName)
                .select()
                .eq("passenger_id", value: passengerId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            return response
        }
    }

    func getOrdersByDriver(driverId: UUID, status: OrderStatus? = nil) async throws -> [Order] {
        if let status = status {
            let response: [Order] = try await client
                .from(tableName)
                .select()
                .eq("driver_id", value: driverId.uuidString)
                .eq("status", value: status.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
            return response
        } else {
            let response: [Order] = try await client
                .from(tableName)
                .select()
                .eq("driver_id", value: driverId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            return response
        }
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
        var updates: [String: Any] = ["status": status.rawValue]

        // 根据状态自动设置时间戳
        switch status {
        case .accepted:
            updates["accepted_at"] = ISO8601DateFormatter().string(from: Date())
        case .driverArrived:
            updates["arrived_at"] = ISO8601DateFormatter().string(from: Date())
        case .inProgress:
            updates["started_at"] = ISO8601DateFormatter().string(from: Date())
        case .completed:
            updates["completed_at"] = ISO8601DateFormatter().string(from: Date())
        case .cancelled:
            updates["cancelled_at"] = ISO8601DateFormatter().string(from: Date())
        default:
            break
        }

        let jsonData = try JSONSerialization.data(withJSONObject: updates)

        let response: Order = try await client
            .from(tableName)
            .update(jsonData)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    func acceptOrder(id: UUID, driverId: UUID) async throws -> Order {
        let updates: [String: Any] = [
            "driver_id": driverId.uuidString,
            "status": OrderStatus.accepted.rawValue,
            "accepted_at": ISO8601DateFormatter().string(from: Date())
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: updates)

        let response: Order = try await client
            .from(tableName)
            .update(jsonData)
            .eq("id", value: id.uuidString)
            .eq("status", value: OrderStatus.pending.rawValue) // 只能接待接单状态的订单
            .select()
            .single()
            .execute()
            .value

        return response
    }

    func cancelOrder(id: UUID, cancelledBy: UUID, reason: String? = nil) async throws -> Order {
        var updates: [String: Any] = [
            "status": OrderStatus.cancelled.rawValue,
            "cancelled_by": cancelledBy.uuidString,
            "cancelled_at": ISO8601DateFormatter().string(from: Date())
        ]

        if let reason = reason {
            updates["cancel_reason"] = reason
        }

        let jsonData = try JSONSerialization.data(withJSONObject: updates)

        let response: Order = try await client
            .from(tableName)
            .update(jsonData)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    func updateOrderPrice(id: UUID, finalPrice: Decimal, actualDistance: Decimal, actualDuration: Int) async throws -> Order {
        let updates: [String: Any] = [
            "final_price": NSDecimalNumber(decimal: finalPrice).doubleValue,
            "actual_distance_km": NSDecimalNumber(decimal: actualDistance).doubleValue,
            "actual_duration_min": actualDuration
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: updates)

        let response: Order = try await client
            .from(tableName)
            .update(jsonData)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return response
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
                    let data = try JSONSerialization.data(withJSONObject: message.payload)
                    let order = try JSONDecoder().decode(Order.self, from: data)
                    subject.send(order)
                } catch {
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
