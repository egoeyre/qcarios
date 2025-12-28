//
//  DriverRepository.swift
//  qcarios
//
//  司机数据访问层
//

import Foundation
import Supabase
import CoreLocation

protocol DriverRepositoryProtocol {
    func getDriverProfile(userId: UUID) async throws -> DriverProfile
    func updateDriverProfile<T: Encodable>(id: UUID, updates: T) async throws -> DriverProfile
    func updateOnlineStatus(userId: UUID, status: DriverOnlineStatus) async throws -> DriverProfile
    func updateDriverLocation(userId: UUID, location: CLLocation) async throws -> DriverProfile
    func findNearbyDrivers(location: Location, radiusKm: Decimal, limit: Int) async throws -> [NearbyDriver]
    func trackLocation(orderId: UUID, driverId: UUID, location: CLLocation) async throws
    func getOrderTrack(orderId: UUID) async throws -> [DriverLocationUpdate]
}

final class DriverRepository: DriverRepositoryProtocol {

    // MARK: - Properties
    private let client = SupabaseClientWrapper.shared.client
    private let tableName = SupabaseConfig.Table.driverProfiles
    private let trackingTableName = SupabaseConfig.Table.locationTracking

    // MARK: - Read Operations

    func getDriverProfile(userId: UUID) async throws -> DriverProfile {
        let response: DriverProfile = try await client
            .from(tableName)
            .select()
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()
            .value

        return response
    }

    // MARK: - Update Operations

    func updateDriverProfile<T: Encodable>(id: UUID, updates: T) async throws -> DriverProfile {
        // 使用数组响应以便更好地处理错误
        let response: [DriverProfile] = try await client
            .from(tableName)
            .update(updates)
            .eq("id", value: id.uuidString)
            .select()
            .execute()
            .value

        guard let profile = response.first else {
            throw SupabaseClientWrapper.DatabaseError.invalidResponse
        }

        return profile
    }

    func updateOnlineStatus(userId: UUID, status: DriverOnlineStatus) async throws -> DriverProfile {
        struct OnlineStatusUpdate: Encodable {
            let onlineStatus: String

            enum CodingKeys: String, CodingKey {
                case onlineStatus = "online_status"
            }
        }

        let updates = OnlineStatusUpdate(onlineStatus: status.rawValue)

        let response: [DriverProfile] = try await client
            .from(tableName)
            .update(updates)
            .eq("user_id", value: userId.uuidString)
            .select()
            .execute()
            .value

        guard let profile = response.first else {
            throw SupabaseClientWrapper.DatabaseError.invalidResponse
        }

        return profile
    }

    func updateDriverLocation(userId: UUID, location: CLLocation) async throws -> DriverProfile {
        struct LocationUpdate: Encodable {
            let currentLat: Double
            let currentLng: Double
            let lastLocationUpdate: String

            enum CodingKeys: String, CodingKey {
                case currentLat = "current_lat"
                case currentLng = "current_lng"
                case lastLocationUpdate = "last_location_update"
            }
        }

        let updates = LocationUpdate(
            currentLat: location.coordinate.latitude,
            currentLng: location.coordinate.longitude,
            lastLocationUpdate: ISO8601DateFormatter().string(from: Date())
        )

        let response: [DriverProfile] = try await client
            .from(tableName)
            .update(updates)
            .eq("user_id", value: userId.uuidString)
            .select()
            .execute()
            .value

        guard let profile = response.first else {
            throw SupabaseClientWrapper.DatabaseError.invalidResponse
        }

        return profile
    }

    // MARK: - Search Operations

    func findNearbyDrivers(location: Location, radiusKm: Decimal = 5, limit: Int = 10) async throws -> [NearbyDriver] {
        // 使用数据库函数查找附近司机
        // 根据官方文档，params 必须是 Encodable 类型
        // 创建一个符合 Encodable 的参数对象
        let params = FindNearbyDriversParams(
            p_lat: location.latitude,
            p_lng: location.longitude,
            p_radius_km: NSDecimalNumber(decimal: radiusKm).doubleValue,
            p_limit: limit
        )

        let response: [NearbyDriver] = try await client
            .rpc(SupabaseConfig.RPC.findNearbyDrivers, params: params)
            .execute()
            .value

        return response
    }

    // MARK: - Location Tracking

    func trackLocation(orderId: UUID, driverId: UUID, location: CLLocation) async throws {
        struct LocationTrackingInsert: Encodable {
            let orderId: String
            let driverId: String
            let lat: Double
            let lng: Double
            let accuracy: Double?
            let speed: Double?
            let bearing: Double?
            let timestamp: String

            enum CodingKeys: String, CodingKey {
                case orderId = "order_id"
                case driverId = "driver_id"
                case lat
                case lng
                case accuracy
                case speed
                case bearing
                case timestamp
            }
        }

        let locationUpdate = DriverLocationUpdate(driverId: driverId, location: location)

        let record = LocationTrackingInsert(
            orderId: orderId.uuidString,
            driverId: driverId.uuidString,
            lat: locationUpdate.latitude,
            lng: locationUpdate.longitude,
            accuracy: locationUpdate.accuracy.map { NSDecimalNumber(decimal: $0).doubleValue },
            speed: locationUpdate.speed.map { NSDecimalNumber(decimal: $0).doubleValue },
            bearing: locationUpdate.bearing.map { NSDecimalNumber(decimal: $0).doubleValue },
            timestamp: ISO8601DateFormatter().string(from: locationUpdate.timestamp)
        )

        _ = try await client
            .from(trackingTableName)
            .insert(record)
            .execute()

        // 同时更新司机profile中的位置
        _ = try await updateDriverLocation(userId: driverId, location: location)
    }

    func getOrderTrack(orderId: UUID) async throws -> [DriverLocationUpdate] {
        let response: [DriverLocationUpdate] = try await client
            .from(trackingTableName)
            .select()
            .eq("order_id", value: orderId.uuidString)
            .order("timestamp", ascending: true)
            .execute()
            .value

        return response
    }
}

// MARK: - Location Tracking Model
struct LocationTrackingRecord: Codable {
    let id: UUID
    let orderId: UUID
    let driverId: UUID
    let lat: Double
    let lng: Double
    let accuracy: Decimal?
    let speed: Decimal?
    let bearing: Decimal?
    let timestamp: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case driverId = "driver_id"
        case lat
        case lng
        case accuracy
        case speed
        case bearing
        case timestamp
        case createdAt = "created_at"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
