//
//  RPCParameters.swift
//  qcarios
//
//  RPC 函数参数定义
//  使用 nonisolated 避免 MainActor 隔离问题
//  参考：https://www.donnywals.com/solving-actor-isolated-protocol-conformance-related-errors-in-swift-6-2/
//

import Foundation

// MARK: - Driver RPC Parameters

/// 查找附近司机的RPC参数
/// 使用 nonisolated 使其可以在任何并发上下文中使用
nonisolated struct FindNearbyDriversParams: Encodable, Sendable {
    let p_lat: Double
    let p_lng: Double
    let p_radius_km: Double
    let p_limit: Int
}

// MARK: - Order RPC Parameters

/// 计算订单价格的RPC参数
/// 使用 nonisolated 使其可以在任何并发上下文中使用
nonisolated struct CalculateOrderPriceParams: Encodable, Sendable {
    let p_city_code: String
    let p_service_type: String
    let p_distance_km: Double
    let p_duration_min: Int
    let p_order_time: String
}
