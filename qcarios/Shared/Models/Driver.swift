//
//  Driver.swift
//  qcarios
//
//  司机数据模型
//

import Foundation
import CoreLocation

// MARK: - Driver Online Status
enum DriverOnlineStatus: String, Codable {
    case online
    case offline
    case busy

    var displayText: String {
        switch self {
        case .online: return "在线"
        case .offline: return "离线"
        case .busy: return "忙碌"
        }
    }
}

// MARK: - Driver Verification Status
enum DriverVerificationStatus: String, Codable {
    case pending
    case approved
    case rejected

    var displayText: String {
        switch self {
        case .pending: return "审核中"
        case .approved: return "已通过"
        case .rejected: return "已拒绝"
        }
    }
}

// MARK: - Driver Profile Model
struct DriverProfile: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID

    var driverLicenseNumber: String?
    var driverLicenseURL: String?
    var idCardFrontURL: String?
    var idCardBackURL: String?
    var drivingYears: Int?
    var serviceCity: String?

    var bankCardNumber: String?
    var bankName: String?
    var accountHolderName: String?

    var onlineStatus: DriverOnlineStatus
    var currentLat: Double?
    var currentLng: Double?
    var lastLocationUpdate: Date?

    var verificationStatus: DriverVerificationStatus
    var verifiedAt: Date?
    var verifiedBy: UUID?
    var rejectionReason: String?

    var rating: Decimal
    var totalOrders: Int
    var totalDistanceKm: Decimal

    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case driverLicenseNumber = "driver_license_number"
        case driverLicenseURL = "driver_license_url"
        case idCardFrontURL = "id_card_front_url"
        case idCardBackURL = "id_card_back_url"
        case drivingYears = "driving_years"
        case serviceCity = "service_city"
        case bankCardNumber = "bank_card_number"
        case bankName = "bank_name"
        case accountHolderName = "account_holder_name"
        case onlineStatus = "online_status"
        case currentLat = "current_lat"
        case currentLng = "current_lng"
        case lastLocationUpdate = "last_location_update"
        case verificationStatus = "verification_status"
        case verifiedAt = "verified_at"
        case verifiedBy = "verified_by"
        case rejectionReason = "rejection_reason"
        case rating
        case totalOrders = "total_orders"
        case totalDistanceKm = "total_distance_km"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    var currentLocation: CLLocationCoordinate2D? {
        guard let lat = currentLat, let lng = currentLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var isOnline: Bool {
        return onlineStatus == .online
    }

    var isVerified: Bool {
        return verificationStatus == .approved
    }

    var canAcceptOrders: Bool {
        return isOnline && isVerified
    }

    var ratingText: String {
        return String(format: "%.1f", NSDecimalNumber(decimal: rating).doubleValue)
    }

    var experienceText: String {
        guard let years = drivingYears else { return "未知" }
        return "\(years)年驾龄"
    }
}

// MARK: - Nearby Driver (用于搜索附近司机)
struct NearbyDriver: Identifiable, Codable {
    let driverId: UUID
    let userId: UUID
    let distanceKm: Decimal
    let rating: Decimal
    let totalOrders: Int

    enum CodingKeys: String, CodingKey {
        case driverId = "driver_id"
        case userId = "user_id"
        case distanceKm = "distance_km"
        case rating
        case totalOrders = "total_orders"
    }

    var id: UUID { driverId }

    var distanceText: String {
        let distance = NSDecimalNumber(decimal: distanceKm).doubleValue
        if distance < 1 {
            return String(format: "%.0f米", distance * 1000)
        } else {
            return String(format: "%.1f公里", distance)
        }
    }
}

// MARK: - Driver Location Update
struct DriverLocationUpdate: Codable {
    let driverId: UUID
    let latitude: Double
    let longitude: Double
    let accuracy: Decimal?
    let speed: Decimal?
    let bearing: Decimal?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case driverId = "driver_id"
        case latitude = "lat"
        case longitude = "lng"
        case accuracy
        case speed
        case bearing
        case timestamp
    }

    init(driverId: UUID, location: CLLocation) {
        self.driverId = driverId
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.accuracy = Decimal(location.horizontalAccuracy)
        self.speed = location.speed >= 0 ? Decimal(location.speed * 3.6) : nil // m/s to km/h
        self.bearing = location.course >= 0 ? Decimal(location.course) : nil
        self.timestamp = location.timestamp
    }
}
