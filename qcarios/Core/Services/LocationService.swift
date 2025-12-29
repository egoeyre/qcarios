//
//  LocationService.swift
//  qcarios
//
//  定位服务
//

import Foundation
import CoreLocation
import Combine

// MARK: - Location Service Protocol
protocol LocationServiceProtocol {
    var currentLocation: CLLocation? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var locationPublisher: AnyPublisher<CLLocation, Never> { get }

    func requestPermission()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

// MARK: - Location Service
final class LocationService: NSObject, LocationServiceProtocol {

    // MARK: - Properties

    static let shared = LocationService()

    private let locationManager = CLLocationManager()
    private let locationSubject = PassthroughSubject<CLLocation, Never>()

    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    // 位置更新优化
    private var lastPublishedLocation: CLLocation?
    private var lastPublishTime: Date?
    private let minimumUpdateInterval: TimeInterval = 3.0 // 最小更新间隔3秒
    private let minimumDistance: CLLocationDistance = 10.0 // 最小移动距离10米

    var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        configureLocationManager()
    }

    // MARK: - Configuration

    private func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone // 让系统提供所有更新，我们自己过滤
        locationManager.activityType = .automotiveNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Public Methods

    func requestPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }

        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // 过滤低精度的位置
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100 else {
            return // 忽略精度差于100米的位置
        }

        // 将 WGS-84 坐标转换为 GCJ-02（高德地图坐标系）
        let wgsCoordinate = location.coordinate
        let gcjCoordinate = CoordinateConverter.wgs84ToGcj02(wgsCoordinate)

        // 创建使用 GCJ-02 坐标的 CLLocation 对象
        let convertedLocation = CLLocation(
            coordinate: gcjCoordinate,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            timestamp: location.timestamp
        )

        // 智能过滤：避免频繁更新
        let shouldPublish = shouldPublishLocation(convertedLocation)

        if shouldPublish {
            #if DEBUG
            print("📍 位置更新: (\(String(format: "%.6f", gcjCoordinate.latitude)), \(String(format: "%.6f", gcjCoordinate.longitude))) 精度:\(Int(location.horizontalAccuracy))m")
            #endif

            currentLocation = convertedLocation
            locationSubject.send(convertedLocation)

            lastPublishedLocation = convertedLocation
            lastPublishTime = Date()
        }
    }

    // MARK: - Helper Methods

    /// 判断是否应该发布位置更新
    private func shouldPublishLocation(_ newLocation: CLLocation) -> Bool {
        // 如果是第一次更新，直接发布
        guard let lastLocation = lastPublishedLocation,
              let lastTime = lastPublishTime else {
            return true
        }

        // 检查时间间隔
        let timeSinceLastUpdate = Date().timeIntervalSince(lastTime)
        if timeSinceLastUpdate < minimumUpdateInterval {
            return false // 更新太频繁，跳过
        }

        // 检查移动距离
        let distance = newLocation.distance(from: lastLocation)
        if distance < minimumDistance {
            return false // 移动距离太小，跳过
        }

        return true
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 定位失败: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied, .restricted:
            print("⚠️ 定位权限被拒绝")
        default:
            break
        }
    }
}
