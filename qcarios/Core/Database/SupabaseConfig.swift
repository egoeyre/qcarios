//
//  SupabaseConfig.swift
//  qcarios
//
//  Supabase配置管理
//

import Foundation

/// Supabase配置
struct SupabaseConfig {

    // MARK: - Properties

    /// Supabase项目URL
    static var url: String {
        return getConfigValue(for: "SUPABASE_URL")
    }

    /// Supabase匿名密钥（客户端使用）
    static var anonKey: String {
        return getConfigValue(for: "SUPABASE_ANON_KEY")
    }

    // MARK: - Table Names

    enum Table {
        static let users = "users"
        static let passengerProfiles = "passenger_profiles"
        static let driverProfiles = "driver_profiles"
        static let orders = "orders"
        static let locationTracking = "location_tracking"
        static let payments = "payments"
        static let driverEarnings = "driver_earnings"
        static let reviews = "reviews"
        static let complaints = "complaints"
        static let coupons = "coupons"
        static let userCoupons = "user_coupons"
        static let notifications = "notifications"
        static let pricingRules = "pricing_rules"
    }

    // MARK: - Realtime Channels

    enum RealtimeChannel {
        static let orders = "orders"
        static let driverLocation = "driver_location"
        static let notifications = "notifications"
    }

    // MARK: - Storage Buckets

    enum StorageBucket {
        static let avatars = "avatars"
        static let idCards = "id_cards"
        static let driverLicenses = "driver_licenses"
        static let reviewImages = "review_images"
        static let complaintImages = "complaint_images"
    }

    // MARK: - Helper Methods

    /// 从Info.plist或环境变量获取配置值
    private static func getConfigValue(for key: String) -> String {
        // 优先从Info.plist读取
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !value.isEmpty {
            return value
        }

        // 其次从环境变量读取（用于本地开发）
        if let value = ProcessInfo.processInfo.environment[key],
           !value.isEmpty {
            return value
        }

        // 开发环境返回默认值
        #if DEBUG
        print("⚠️ Warning: \(key) not found in configuration")
        return ""
        #else
        fatalError("Configuration value for \(key) not found")
        #endif
    }

    /// 验证配置是否完整
    static func validateConfiguration() -> Bool {
        let isValid = !url.isEmpty && !anonKey.isEmpty

        #if DEBUG
        if isValid {
            print("✅ Supabase configuration validated")
        } else {
            print("❌ Supabase configuration incomplete")
        }
        #endif

        return isValid
    }
}

// MARK: - Remote Functions (RPC)
extension SupabaseConfig {
    enum RPC {
        static let findNearbyDrivers = "find_nearby_drivers"
        static let calculateOrderPrice = "calculate_order_price"
        static let calculateDistance = "calculate_distance"
    }
}

// MARK: - Configuration Validation
extension SupabaseConfig {

    /// 配置检查结果
    struct ValidationResult {
        let isValid: Bool
        let missingKeys: [String]
        let warnings: [String]
    }

    /// 详细的配置验证
    static func detailedValidation() -> ValidationResult {
        var missingKeys: [String] = []
        var warnings: [String] = []

        if url.isEmpty {
            missingKeys.append("SUPABASE_URL")
        }

        if anonKey.isEmpty {
            missingKeys.append("SUPABASE_ANON_KEY")
        }

        // 检查URL格式
        if !url.isEmpty, URL(string: url) == nil {
            warnings.append("SUPABASE_URL格式无效")
        }

        // 检查密钥长度
        if !anonKey.isEmpty, anonKey.count < 20 {
            warnings.append("SUPABASE_ANON_KEY看起来太短")
        }

        return ValidationResult(
            isValid: missingKeys.isEmpty,
            missingKeys: missingKeys,
            warnings: warnings
        )
    }
}
