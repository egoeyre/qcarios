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
        guard let searchAPI = searchAPI else {
            print("❌ [MapService] searchAPI 未初始化")
            throw MapError.notConfigured
        }

        // 创建路线规划请求
        let request = AMapDrivingCalRouteSearchRequest()

        // 设置起点
        request.origin = AMapGeoPoint.location(
            withLatitude: CGFloat(from.latitude),
            longitude: CGFloat(from.longitude)
        )

        // 设置终点
        request.destination = AMapGeoPoint.location(
            withLatitude: CGFloat(to.latitude),
            longitude: CGFloat(to.longitude)
        )

        // 驾车导航策略（高德地图新版SDK）
        // 32：默认，高德推荐（同高德地图APP默认）
        // 33：躲避拥堵
        // 34：高速优先
        // 35：不走高速
        // 36：避免收费
        // 37：躲避拥堵+高速优先
        // 38：躲避拥堵+避免收费
        // 39：躲避拥堵+不走高速
        // 40：躲避拥堵+高速优先+避免收费
        request.strategy = 32 // 使用高德推荐策略，适合代驾场景

        // 🔑 关键：设置返回字段，必须包含polyline才能获取详细路线坐标
        // 设置showFieldType来请求polyline数据
        request.showFieldType = AMapDrivingRouteShowFieldType(
            rawValue: AMapDrivingRouteShowFieldType.cost.rawValue |
                      AMapDrivingRouteShowFieldType.tmcs.rawValue |
                      AMapDrivingRouteShowFieldType.navi.rawValue |
                      AMapDrivingRouteShowFieldType.cities.rawValue |
                      AMapDrivingRouteShowFieldType.polyline.rawValue
        )!

        return try await withCheckedThrowingContinuation { continuation in
            self.searchContinuation = continuation
            searchAPI.aMapDrivingV2RouteSearch(request)
        }
        .flatMap { result -> RouteInfo in
            guard let routeResult = result as? AMapRouteSearchResponse else {
                print("❌ [MapService] 响应类型错误")
                throw MapError.routeNotFound
            }

            guard let route = routeResult.route else {
                print("❌ [MapService] route 为 nil")
                throw MapError.routeNotFound
            }

            guard let path = route.paths.first else {
                print("❌ [MapService] paths 为空")
                throw MapError.routeNotFound
            }

            // 解析路线坐标点
            var polylineCoordinates: [CLLocationCoordinate2D] = []

            // 方法1: 尝试从 path.polyline 获取（整体路线）
            if let pathPolyline = path.polyline {
                polylineCoordinates = self.decodePolyline(pathPolyline)
            }
            // 方法2: 如果 path.polyline 为空，尝试从各个 step 拼接
            else {
                for step in path.steps {
                    if let polyline = step.polyline {
                        polylineCoordinates.append(contentsOf: self.decodePolyline(polyline))
                    }
                }
            }

            // 如果没有详细路线点，至少返回起终点连线
            if polylineCoordinates.isEmpty {
                print("⚠️ [MapService] 无详细路线，使用起终点连线")
                polylineCoordinates = [from, to]
            }

            return RouteInfo(
                distance: Double(path.distance),
                duration: TimeInterval(path.duration),
                polyline: polylineCoordinates
            )
        }
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
