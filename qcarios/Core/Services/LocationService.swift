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
        locationManager.distanceFilter = 10 // 10米更新一次
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

        currentLocation = location
        locationSubject.send(location)
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
