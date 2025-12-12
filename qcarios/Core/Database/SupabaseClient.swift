//
//  SupabaseClient.swift
//  qcarios
//
//  Supabase客户端配置和初始化
//

import Foundation
import Supabase

/// Supabase客户端单例
final class SupabaseClient {

    // MARK: - Singleton
    static let shared = SupabaseClient()

    // MARK: - Properties
    let client: SupabaseClient

    // MARK: - Initialization
    private init() {
        // 从配置文件读取Supabase配置
        guard let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              let url = URL(string: supabaseURL) else {
            fatalError("Supabase configuration not found in Info.plist")
        }

        // 初始化Supabase客户端
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(
                    schema: "public"
                ),
                auth: SupabaseClientOptions.AuthOptions(
                    autoRefreshToken: true,
                    persistSession: true,
                    detectSessionInUrl: false
                ),
                global: SupabaseClientOptions.GlobalOptions(
                    headers: [
                        "X-Client-Info": "qcarios-ios"
                    ]
                )
            )
        )

        #if DEBUG
        print("✅ Supabase Client initialized: \(supabaseURL)")
        #endif
    }

    // MARK: - Convenience Accessors

    /// 数据库访问
    var database: PostgrestClient {
        client.database
    }

    /// 认证服务
    var auth: AuthClient {
        client.auth
    }

    /// 实时订阅
    var realtime: RealtimeClient {
        client.realtime
    }

    /// 存储服务
    var storage: StorageClient {
        client.storage
    }

    // MARK: - Helper Methods

    /// 获取当前用户ID
    var currentUserId: UUID? {
        guard let user = try? auth.session.user else {
            return nil
        }
        return user.id
    }

    /// 检查是否已登录
    var isAuthenticated: Bool {
        return currentUserId != nil
    }
}

// MARK: - Environment Configuration
extension SupabaseClient {

    /// 环境配置
    enum Environment {
        case development
        case staging
        case production

        var baseURL: String {
            switch self {
            case .development:
                return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
            case .staging:
                return "https://staging.your-project.supabase.co"
            case .production:
                return "https://your-project.supabase.co"
            }
        }
    }

    static var currentEnvironment: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

// MARK: - Error Handling
extension SupabaseClient {

    enum DatabaseError: LocalizedError {
        case notAuthenticated
        case networkError
        case invalidResponse
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "用户未登录"
            case .networkError:
                return "网络连接失败"
            case .invalidResponse:
                return "服务器响应无效"
            case .unknown(let error):
                return error.localizedDescription
            }
        }
    }
}
