//
//  SupabaseClient.swift
//  qcarios
//
//  Supabase客户端配置和初始化
//

import Foundation
import Supabase

/// Supabase客户端单例包装器
final class SupabaseClientWrapper {

    // MARK: - Singleton
    static let shared = SupabaseClientWrapper()

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

        // 初始化Supabase客户端 (根据官方文档)
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                db: .init(schema: "public"),
                auth: .init(
                    flowType: .pkce  // 使用PKCE流程提高安全性
                ),
                global: .init(
                    headers: ["x-client-info": "qcarios-ios"]
                )
            )
        )

        #if DEBUG
        print("✅ Supabase Client initialized: \(supabaseURL)")
        #endif
    }

    // MARK: - Convenience Accessors

    /// 数据库访问
//    var database: PostgrestClient {
//        client.database
//    }

    /// 认证服务
    var auth: AuthClient {
        client.auth
    }

    /// 实时订阅
    var realtime: RealtimeClient {
        client.realtime
    }

    /// 存储服务 (需要时可以通过 client.storage 访问)
    // var storage: StorageClient {
    //     client.storage
    // }

    // MARK: - Helper Methods

    /// 获取当前用户ID (异步方法，因为 session 是异步属性)
    func getCurrentUserId() async -> UUID? {
        return try? await auth.session.user.id
    }

    /// 检查是否已登录 (异步方法，因为 session 是异步属性)
    func checkAuthentication() async -> Bool {
        return (try? await auth.session) != nil
    }
}

// MARK: - Environment Configuration
extension SupabaseClientWrapper {

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
extension SupabaseClientWrapper {

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
