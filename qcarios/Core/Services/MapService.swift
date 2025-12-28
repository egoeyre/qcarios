//
//  MapService.swift
//  qcarios
//
//  地图服务封装 - 高德地图
//

import Foundation
import CoreLocation
import AMapFoundationKit
import AMapSearchKit
import AMapNaviKit

// MARK: - POI Model
struct POI: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let location: CLLocationCoordinate2D
    let distance: Double?

    var distanceText: String? {
        guard let distance = distance else { return nil }
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }

    static func == (lhs: POI, rhs: POI) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.address == rhs.address &&
               lhs.location.latitude == rhs.location.latitude &&
               lhs.location.longitude == rhs.location.longitude &&
               lhs.distance == rhs.distance
    }
}

// MARK: - Route Model
struct RouteInfo: Equatable {
    let distance: Double // 米
    let duration: TimeInterval // 秒
    let polyline: [CLLocationCoordinate2D]

    var distanceKm: Double {
        distance / 1000
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    var distanceText: String {
        if distanceKm < 1 {
            return String(format: "%.0f米", distance)
        } else {
            return String(format: "%.1f公里", distanceKm)
        }
    }

    var durationText: String {
        if durationMinutes < 60 {
            return "\(durationMinutes)分钟"
        } else {
            let hours = durationMinutes / 60
            let mins = durationMinutes % 60
            return mins > 0 ? "\(hours)小时\(mins)分钟" : "\(hours)小时"
        }
    }

    static func == (lhs: RouteInfo, rhs: RouteInfo) -> Bool {
        guard lhs.distance == rhs.distance,
              lhs.duration == rhs.duration,
              lhs.polyline.count == rhs.polyline.count else {
            return false
        }

        for (lCoord, rCoord) in zip(lhs.polyline, rhs.polyline) {
            if lCoord.latitude != rCoord.latitude || lCoord.longitude != rCoord.longitude {
                return false
            }
        }

        return true
    }
}

// MARK: - Map Service Protocol
protocol MapServiceProtocol {
    func configure(apiKey: String)
    func searchPOI(keyword: String, city: String?, location: CLLocationCoordinate2D?) async throws -> [POI]
    func searchNearby(location: CLLocationCoordinate2D, radius: Int) async throws -> [POI]
    func reverseGeocode(location: CLLocationCoordinate2D) async throws -> String
    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteInfo
}

// MARK: - AMap Service Implementation
final class AMapService: NSObject, MapServiceProtocol {

    // MARK: - Properties

    static let shared = AMapService()

    private var searchAPI: AMapSearchAPI?
    private var searchContinuation: CheckedContinuation<AMapSearchObject?, Error>?

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    func configure(apiKey: String) {
        print("🗺️ 配置高德地图SDK...")
        print("🔑 API Key: \(apiKey.prefix(20))...")

        // 设置 API Key
        AMapServices.shared().apiKey = apiKey
        AMapServices.shared().enableHTTPS = true

        searchAPI = AMapSearchAPI()
        searchAPI?.delegate = self

        #if DEBUG
        if searchAPI != nil {
            print("✅ 高德地图SDK已初始化 (searchAPI 已创建)")
        } else {
            print("❌ 高德地图SDK初始化失败 (searchAPI 为 nil)")
        }
        #endif
    }

    // MARK: - Search Methods

    /// 搜索POI
    func searchPOI(keyword: String, city: String? = nil, location: CLLocationCoordinate2D? = nil) async throws -> [POI] {
        guard let searchAPI = searchAPI else {
            throw MapError.notConfigured
        }

        let request = AMapPOIKeywordsSearchRequest()
        request.keywords = keyword
        request.city = city

        if let location = location {
            request.location = AMapGeoPoint.location(
                withLatitude: CGFloat(location.latitude),
                longitude: CGFloat(location.longitude)
            )
            request.sortrule = 1 // 按距离排序
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.searchContinuation = continuation
            searchAPI.aMapPOIKeywordsSearch(request)
        }
        .flatMap { result -> [POI] in
            guard let poiResult = result as? AMapPOISearchResponse else { return [] }
            return poiResult.pois.compactMap { poi in
                POI(
                    id: poi.uid,
                    name: poi.name ?? "",
                    address: poi.address ?? "",
                    location: CLLocationCoordinate2D(
                        latitude: poi.location.latitude,
                        longitude: poi.location.longitude
                    ),
                    distance: poi.distance > 0 ? Double(poi.distance) : nil
                )
            }
        }
    }

    /// 搜索附近
    func searchNearby(location: CLLocationCoordinate2D, radius: Int = 1000) async throws -> [POI] {
        guard let searchAPI = searchAPI else {
            throw MapError.notConfigured
        }

        let request = AMapPOIAroundSearchRequest()
        request.location = AMapGeoPoint.location(
            withLatitude: CGFloat(location.latitude),
            longitude: CGFloat(location.longitude)
        )
        request.radius = radius
        request.sortrule = 1

        return try await withCheckedThrowingContinuation { continuation in
            self.searchContinuation = continuation
            searchAPI.aMapPOIAroundSearch(request)
        }
        .flatMap { result -> [POI] in
            guard let poiResult = result as? AMapPOISearchResponse else { return [] }
            return poiResult.pois.compactMap { poi in
                POI(
                    id: poi.uid,
                    name: poi.name ?? "",
                    address: poi.address ?? "",
                    location: CLLocationCoordinate2D(
                        latitude: poi.location.latitude,
                        longitude: poi.location.longitude
                    ),
                    distance: poi.distance > 0 ? Double(poi.distance) : nil
                )
            }
        }
    }

    /// 逆地理编码（坐标转地址）
    func reverseGeocode(location: CLLocationCoordinate2D) async throws -> String {
        guard let searchAPI = searchAPI else {
            throw MapError.notConfigured
        }

        let request = AMapReGeocodeSearchRequest()
        request.location = AMapGeoPoint.location(
            withLatitude: CGFloat(location.latitude),
            longitude: CGFloat(location.longitude)
        )

        return try await withCheckedThrowingContinuation { continuation in
            self.searchContinuation = continuation
            searchAPI.aMapReGoecodeSearch(request)
        }
        .flatMap { result -> String in
            guard let geoResult = result as? AMapReGeocodeSearchResponse,
                  let regeocode = geoResult.regeocode else {
                return "未知位置"
            }

            return regeocode.formattedAddress ?? "未知位置"
        }
    }

    /// 计算路线
    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteInfo {
        // 使用高德导航SDK计算路线
        // 注意：这里简化处理，实际项目中需要集成AMapNaviKit
        // 当前返回模拟数据，实际使用时需要替换为真实的路线规划API

        // 计算直线距离作为估算
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let straightDistance = fromLocation.distance(from: toLocation)

        // 估算行驶距离（通常是直线距离的1.3倍）
        let estimatedDistance = straightDistance * 1.3

        // 估算行驶时间（假设平均速度40km/h）
        let estimatedDuration = (estimatedDistance / 1000) / 40 * 3600

        // 创建简单的两点连线
        let polyline = [from, to]

        return RouteInfo(
            distance: estimatedDistance,
            duration: estimatedDuration,
            polyline: polyline
        )

        // TODO: 集成真实的路线规划API
        // guard let searchAPI = searchAPI else {
        //     throw MapError.notConfigured
        // }
        // 使用 AMapNaviKit 进行实际路线规划
    }

    // MARK: - Helper Methods

    /// 解析polyline字符串为坐标数组
    private func decodePolyline(_ polyline: String) -> [CLLocationCoordinate2D] {
        let points = polyline.components(separatedBy: ";")
        return points.compactMap { point in
            let coords = point.components(separatedBy: ",")
            guard coords.count == 2,
                  let lng = Double(coords[0]),
                  let lat = Double(coords[1]) else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }
}

// MARK: - AMapSearchDelegate
extension AMapService: AMapSearchDelegate {

    func onPOISearchDone(_ request: AMapPOISearchBaseRequest!, response: AMapPOISearchResponse!) {
        searchContinuation?.resume(returning: response)
        searchContinuation = nil
    }

    func onRouteSearchDone(_ request: AMapRouteSearchBaseRequest!, response: AMapRouteSearchResponse!) {
        searchContinuation?.resume(returning: response)
        searchContinuation = nil
    }

    func onGeocodeSearchDone(_ request: AMapGeocodeSearchRequest!, response: AMapGeocodeSearchResponse!) {
        searchContinuation?.resume(returning: response)
        searchContinuation = nil
    }

    func onReGeocodeSearchDone(_ request: AMapReGeocodeSearchRequest!, response: AMapReGeocodeSearchResponse!) {
        searchContinuation?.resume(returning: response)
        searchContinuation = nil
    }

    func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        searchContinuation?.resume(throwing: error ?? MapError.searchFailed)
        searchContinuation = nil
    }
}

// MARK: - Map Error
enum MapError: LocalizedError {
    case notConfigured
    case searchFailed
    case routeNotFound
    case locationNotAvailable

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "地图服务未配置"
        case .searchFailed:
            return "搜索失败"
        case .routeNotFound:
            return "未找到路线"
        case .locationNotAvailable:
            return "无法获取位置"
        }
    }
}

// MARK: - Optional Extension for Result
private extension Optional where Wrapped == AMapSearchObject {
    func flatMap<T>(_ transform: (Wrapped) throws -> T) throws -> T {
        guard let value = self else {
            throw MapError.searchFailed
        }
        return try transform(value)
    }
}
