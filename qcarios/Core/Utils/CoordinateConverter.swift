//
//  CoordinateConverter.swift
//  qcarios
//
//  坐标转换工具 - WGS-84 转 GCJ-02
//

import Foundation
import CoreLocation

/// 坐标转换工具类
/// 用于在不同坐标系之间进行转换
class CoordinateConverter {

    // MARK: - Constants

    private static let a: Double = 6378245.0  // 克拉索夫斯基椭球参数长半轴
    private static let ee: Double = 0.00669342162296594323  // 克拉索夫斯基椭球参数第一偏心率平方

    // MARK: - Public Methods

    /// WGS-84 转 GCJ-02（火星坐标系）
    /// - Parameter wgsCoordinate: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（高德地图坐标）
    static func wgs84ToGcj02(_ wgsCoordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 判断是否在中国境外
        if isOutOfChina(latitude: wgsCoordinate.latitude, longitude: wgsCoordinate.longitude) {
            return wgsCoordinate
        }

        var dLat = transformLatitude(x: wgsCoordinate.longitude - 105.0,
                                     y: wgsCoordinate.latitude - 35.0)
        var dLng = transformLongitude(x: wgsCoordinate.longitude - 105.0,
                                      y: wgsCoordinate.latitude - 35.0)

        let radLat = wgsCoordinate.latitude / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi)
        dLng = (dLng * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi)

        let mgLat = wgsCoordinate.latitude + dLat
        let mgLng = wgsCoordinate.longitude + dLng

        return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLng)
    }

    /// GCJ-02 转 WGS-84（粗略转换）
    /// - Parameter gcjCoordinate: GCJ-02 坐标
    /// - Returns: WGS-84 坐标
    static func gcj02ToWgs84(_ gcjCoordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 判断是否在中国境外
        if isOutOfChina(latitude: gcjCoordinate.latitude, longitude: gcjCoordinate.longitude) {
            return gcjCoordinate
        }

        var dLat = transformLatitude(x: gcjCoordinate.longitude - 105.0,
                                     y: gcjCoordinate.latitude - 35.0)
        var dLng = transformLongitude(x: gcjCoordinate.longitude - 105.0,
                                      y: gcjCoordinate.latitude - 35.0)

        let radLat = gcjCoordinate.latitude / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi)
        dLng = (dLng * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi)

        let wgsLat = gcjCoordinate.latitude - dLat
        let wgsLng = gcjCoordinate.longitude - dLng

        return CLLocationCoordinate2D(latitude: wgsLat, longitude: wgsLng)
    }

    // MARK: - Private Methods

    /// 判断坐标是否在中国境外
    private static func isOutOfChina(latitude: Double, longitude: Double) -> Bool {
        if longitude < 72.004 || longitude > 137.8347 {
            return true
        }
        if latitude < 0.8293 || latitude > 55.8271 {
            return true
        }
        return false
    }

    /// 纬度转换
    private static func transformLatitude(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y
        ret += 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320.0 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换
    private static func transformLongitude(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y
        ret += 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return ret
    }
}

// MARK: - CLLocationCoordinate2D Extension

extension CLLocationCoordinate2D {

    /// 将 WGS-84 坐标转换为 GCJ-02 坐标
    var toGcj02: CLLocationCoordinate2D {
        return CoordinateConverter.wgs84ToGcj02(self)
    }

    /// 将 GCJ-02 坐标转换为 WGS-84 坐标
    var toWgs84: CLLocationCoordinate2D {
        return CoordinateConverter.gcj02ToWgs84(self)
    }
}
