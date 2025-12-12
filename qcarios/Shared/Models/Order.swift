//
//  Order.swift
//  qcarios
//
//  订单数据模型
//

import Foundation
import CoreLocation

// MARK: - Order Type
enum OrderType: String, Codable {
    case immediate
    case scheduled
}

// MARK: - Service Type
enum ServiceType: String, Codable {
    case standard
    case business
    case longDistance = "long_distance"
}

// MARK: - Order Status
enum OrderStatus: String, Codable {
    case pending
    case accepted
    case driverArrived = "driver_arrived"
    case inProgress = "in_progress"
    case completed
    case cancelled

    var displayText: String {
        switch self {
        case .pending: return "待接单"
        case .accepted: return "已接单"
        case .driverArrived: return "司机已到达"
        case .inProgress: return "行程中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        }
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .accepted, .driverArrived: return "blue"
        case .inProgress: return "green"
        case .completed: return "gray"
        case .cancelled: return "red"
        }
    }
}

// MARK: - Location
struct Location: Codable, Equatable {
    let address: String?
    let latitude: Double
    let longitude: Double
    let poiId: String?

    enum CodingKeys: String, CodingKey {
        case address
        case latitude = "lat"
        case longitude = "lng"
        case poiId = "poi_id"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(address: String? = nil, latitude: Double, longitude: Double, poiId: String? = nil) {
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.poiId = poiId
    }

    init(coordinate: CLLocationCoordinate2D, address: String? = nil, poiId: String? = nil) {
        self.address = address
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.poiId = poiId
    }
}

// MARK: - Order Model
struct Order: Identifiable, Codable, Equatable {
    let id: UUID
    let orderNumber: String
    let passengerId: UUID
    var driverId: UUID?

    // 订单类型
    var orderType: OrderType
    var serviceType: ServiceType

    // 时间
    var scheduledTime: Date?
    var acceptedAt: Date?
    var arrivedAt: Date?
    var startedAt: Date?
    var completedAt: Date?
    var cancelledAt: Date?

    // 位置
    let pickupAddress: String?
    let pickupLat: Double
    let pickupLng: Double
    let pickupPoiId: String?

    let dropoffAddress: String?
    let dropoffLat: Double
    let dropoffLng: Double
    let dropoffPoiId: String?

    var waypoints: [Location]?

    // 费用
    var estimatedDistanceKm: Decimal?
    var estimatedDurationMin: Int?
    var estimatedPrice: Decimal?

    var actualDistanceKm: Decimal?
    var actualDurationMin: Int?
    var finalPrice: Decimal?

    var discountAmount: Decimal?
    var couponId: UUID?

    // 状态
    var status: OrderStatus

    // 取消
    var cancelledBy: UUID?
    var cancelReason: String?

    // 备注
    var passengerNote: String?
    var driverNote: String?

    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orderNumber = "order_number"
        case passengerId = "passenger_id"
        case driverId = "driver_id"
        case orderType = "order_type"
        case serviceType = "service_type"
        case scheduledTime = "scheduled_time"
        case acceptedAt = "accepted_at"
        case arrivedAt = "arrived_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case cancelledAt = "cancelled_at"
        case pickupAddress = "pickup_address"
        case pickupLat = "pickup_lat"
        case pickupLng = "pickup_lng"
        case pickupPoiId = "pickup_poi_id"
        case dropoffAddress = "dropoff_address"
        case dropoffLat = "dropoff_lat"
        case dropoffLng = "dropoff_lng"
        case dropoffPoiId = "dropoff_poi_id"
        case waypoints
        case estimatedDistanceKm = "estimated_distance_km"
        case estimatedDurationMin = "estimated_duration_min"
        case estimatedPrice = "estimated_price"
        case actualDistanceKm = "actual_distance_km"
        case actualDurationMin = "actual_duration_min"
        case finalPrice = "final_price"
        case discountAmount = "discount_amount"
        case couponId = "coupon_id"
        case status
        case cancelledBy = "cancelled_by"
        case cancelReason = "cancel_reason"
        case passengerNote = "passenger_note"
        case driverNote = "driver_note"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    var pickupLocation: Location {
        Location(
            address: pickupAddress,
            latitude: pickupLat,
            longitude: pickupLng,
            poiId: pickupPoiId
        )
    }

    var dropoffLocation: Location {
        Location(
            address: dropoffAddress,
            latitude: dropoffLat,
            longitude: dropoffLng,
            poiId: dropoffPoiId
        )
    }

    var isActive: Bool {
        return [.pending, .accepted, .driverArrived, .inProgress].contains(status)
    }

    var canCancel: Bool {
        return [.pending, .accepted].contains(status)
    }

    var estimatedDuration: String? {
        guard let minutes = estimatedDurationMin else { return nil }
        if minutes < 60 {
            return "\(minutes)分钟"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)小时\(mins)分钟" : "\(hours)小时"
        }
    }

    var actualDuration: String? {
        guard let minutes = actualDurationMin else { return nil }
        if minutes < 60 {
            return "\(minutes)分钟"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)小时\(mins)分钟" : "\(hours)小时"
        }
    }
}

// MARK: - Create Order Request
struct CreateOrderRequest: Codable {
    let passengerId: UUID
    let orderType: OrderType
    let serviceType: ServiceType
    let scheduledTime: Date?

    let pickupAddress: String?
    let pickupLat: Double
    let pickupLng: Double
    let pickupPoiId: String?

    let dropoffAddress: String?
    let dropoffLat: Double
    let dropoffLng: Double
    let dropoffPoiId: String?

    let waypoints: [Location]?
    let passengerNote: String?

    enum CodingKeys: String, CodingKey {
        case passengerId = "passenger_id"
        case orderType = "order_type"
        case serviceType = "service_type"
        case scheduledTime = "scheduled_time"
        case pickupAddress = "pickup_address"
        case pickupLat = "pickup_lat"
        case pickupLng = "pickup_lng"
        case pickupPoiId = "pickup_poi_id"
        case dropoffAddress = "dropoff_address"
        case dropoffLat = "dropoff_lat"
        case dropoffLng = "dropoff_lng"
        case dropoffPoiId = "dropoff_poi_id"
        case waypoints
        case passengerNote = "passenger_note"
    }
}
