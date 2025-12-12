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
    func updateDriverProfile(id: UUID, updates: [String: Any]) async throws -> DriverProfile
    func updateOnlineStatus(userId: UUID, status: DriverOnlineStatus) async throws -> DriverProfile
    func updateDriverLocation(userId: UUID, location: CLLocation) async throws -> DriverProfile
    func findNearbyDrivers(location: Location, radiusKm: Decimal, limit: Int) async throws -> [NearbyDriver]
    func trackLocation(orderId: UUID, driverId: UUID, location: CLLocation) async throws
    func getOrderTrack(orderId: UUID) async throws -> [DriverLocationUpdate]
}

final class DriverRepository: DriverRepositoryProtocol {

    // MARK: - Properties
    private let client = SupabaseClient.shared.client
    private let tableName = SupabaseConfig.Table.driverProfiles
    private let trackingTableName = SupabaseConfig.Table.locationTracking

    // MARK: - Read Operations

    func getDriverProfile(userId: UUID) async throws -> DriverProfile {
        let response = try await client.database
            .from(tableName)
            .select()
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()

        return try response.decode()
    }

    // MARK: - Update Operations

    func updateDriverProfile(id: UUID, updates: [String: Any]) async throws -> DriverProfile {
        let response = try await client.database
            .from(tableName)
            .update(updates)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()

        return try response.decode()
    }

    func updateOnlineStatus(userId: UUID, status: DriverOnlineStatus) async throws -> DriverProfile {
        let updates: [String: Any] = [
            "online_status": status.rawValue
        ]

        let response = try await client.database
            .from(tableName)
            .update(updates)
            .eq("user_id", value: userId.uuidString)
            .select()
            .single()
            .execute()

        return try response.decode()
    }

    func updateDriverLocation(userId: UUID, location: CLLocation) async throws -> DriverProfile {
        let updates: [String: Any] = [
            "current_lat": location.coordinate.latitude,
            "current_lng": location.coordinate.longitude,
            "last_location_update": ISO8601DateFormatter().string(from: Date())
        ]

        let response = try await client.database
            .from(tableName)
            .update(updates)
            .eq("user_id", value: userId.uuidString)
            .select()
            .single()
            .execute()

        return try response.decode()
    }

    // MARK: - Search Operations

    func findNearbyDrivers(location: Location, radiusKm: Decimal = 5, limit: Int = 10) async throws -> [NearbyDriver] {
        // 使用数据库函数查找附近司机
        let params: [String: Any] = [
            "p_lat": location.latitude,
            "p_lng": location.longitude,
            "p_radius_km": NSDecimalNumber(decimal: radiusKm).doubleValue,
            "p_limit": limit
        ]

        let response = try await client.database
            .rpc(SupabaseConfig.RPC.findNearbyDrivers, params: params)
            .execute()

        return try response.decode()
    }

    // MARK: - Location Tracking

    func trackLocation(orderId: UUID, driverId: UUID, location: CLLocation) async throws {
        let locationUpdate = DriverLocationUpdate(driverId: driverId, location: location)

        let record: [String: Any] = [
            "order_id": orderId.uuidString,
            "driver_id": driverId.uuidString,
            "lat": locationUpdate.latitude,
            "lng": locationUpdate.longitude,
            "accuracy": locationUpdate.accuracy.map { NSDecimalNumber(decimal: $0).doubleValue },
            "speed": locationUpdate.speed.map { NSDecimalNumber(decimal: $0).doubleValue },
            "bearing": locationUpdate.bearing.map { NSDecimalNumber(decimal: $0).doubleValue },
            "timestamp": ISO8601DateFormatter().string(from: locationUpdate.timestamp)
        ]

        _ = try await client.database
            .from(trackingTableName)
            .insert(record)
            .execute()

        // 同时更新司机profile中的位置
        _ = try await updateDriverLocation(userId: driverId, location: location)
    }

    func getOrderTrack(orderId: UUID) async throws -> [DriverLocationUpdate] {
        let response = try await client.database
            .from(trackingTableName)
            .select()
            .eq("order_id", value: orderId.uuidString)
            .order("timestamp", ascending: true)
            .execute()

        return try response.decode()
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
