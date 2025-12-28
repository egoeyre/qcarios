//
//  AuthService.swift
//  qcarios
//
//  认证服务 - 处理用户登录、注册、登出
//

import Foundation
import Supabase
import Combine

// MARK: - Auth Error
enum AuthError: LocalizedError {
    case invalidPhone
    case verificationFailed
    case userNotFound
    case networkError
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidPhone:
            return "手机号格式不正确"
        case .verificationFailed:
            return "验证码错误或已过期"
        case .userNotFound:
            return "用户不存在"
        case .networkError:
            return "网络连接失败，请检查网络设置"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Auth Service Protocol
protocol AuthServiceProtocol {
    var currentUser: User? { get }
    var isAuthenticated: Bool { get }
    var authStatePublisher: AnyPublisher<User?, Never> { get }

    func sendVerificationCode(to phone: String) async throws
    func verifyCode(_ code: String, phone: String) async throws -> User
    func signOut() async throws
    func updateUserRole(_ role: UserRole) async throws -> User
}

// MARK: - Auth Service Implementation
final class AuthService: ObservableObject, AuthServiceProtocol {

    // MARK: - Properties

    static let shared = AuthService()

    private let client = SupabaseClientWrapper.shared.client
    private let userRepository = UserRepository()

    @Published private(set) var currentUser: User?

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var authStatePublisher: AnyPublisher<User?, Never> {
        $currentUser.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private init() {
        Task {
            await loadCurrentUser()
        }
    }

    // MARK: - Public Methods

    /// 发送验证码到手机号
    func sendVerificationCode(to phone: String) async throws {
        // 验证手机号格式
        guard isValidPhone(phone) else {
            throw AuthError.invalidPhone
        }

        #if DEBUG
        // 开发环境：模拟发送验证码（不实际调用 Auth API）
        print("📱 发送验证码到: \(phone)")
        print("🔢 验证码: 123456 (开发环境固定验证码)")
        // 开发环境不需要实际发送
        #else
        // 生产环境：使用 Supabase Auth 发送真实验证码
        do {
            print("📱 调用 Supabase Auth 发送验证码到: \(phone)")
            try await client.auth.signInWithOTP(phone: phone)
            print("✅ 验证码已发送")
        } catch {
            print("❌ 发送验证码失败: \(error)")
            throw AuthError.networkError
        }
        #endif
    }

    /// 验证验证码并登录/注册
    func verifyCode(_ code: String, phone: String) async throws -> User {
        print("🔐 AuthService.verifyCode 开始")
        print("📱 手机号: \(phone)")
        print("🔢 验证码: \(code)")

        guard isValidPhone(phone) else {
            print("❌ 手机号格式无效")
            throw AuthError.invalidPhone
        }

        do {
            var authUserId: UUID

            #if DEBUG
            // 开发环境：使用固定验证码 + 邮箱模拟手机号认证
            print("🔧 开发环境验证模式")
            if code != "123456" {
                print("❌ 验证码错误: \(code) != 123456")
                throw AuthError.verificationFailed
            }

            print("✅ 验证码正确")

            // 开发环境：使用邮箱注册/登录来模拟手机号认证
            // 因为本地 Supabase 可能没有配置短信服务
            print("🔐 使用邮箱模拟手机号认证...")
            let testEmail = "\(phone)@dev.local"
            let testPassword = "password_\(phone)"

            do {
                // 尝试登录现有账号
                print("🔑 尝试登录: \(testEmail)")
                let session = try await client.auth.signIn(email: testEmail, password: testPassword)
                authUserId = session.user.id
                print("✅ 登录成功，Auth User ID: \(authUserId)")
            } catch {
                // 账号不存在，创建新账号
                print("📝 账号不存在，创建新账号...")
                let session = try await client.auth.signUp(email: testEmail, password: testPassword)
                authUserId = session.user.id
                print("✅ 注册成功，Auth User ID: \(authUserId)")
            }

            #else
            // 生产环境：使用真实的手机号 OTP 验证
            print("📱 验证手机号 OTP...")
            let session = try await client.auth.verifyOTP(
                phone: phone,
                token: code,
                type: .sms
            )
            authUserId = session.user.id
            print("✅ OTP 验证成功，Auth User ID: \(authUserId)")
            #endif

            // 使用 Auth User ID 创建或查询 public.users
            print("🔄 调用 signInOrRegister...")
            let user = try await signInOrRegister(phone: phone, authUserId: authUserId)

            self.currentUser = user
            print("✅ AuthService.verifyCode 完成")
            print("👤 用户: \(user.displayName)")

            return user

        } catch let error as AuthError {
            print("❌ AuthError: \(error)")
            throw error
        } catch {
            print("❌ 未知错误: \(error)")
            throw AuthError.unknown(error)
        }
    }

    /// 登出
    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
    }

    /// 更新用户角色
    func updateUserRole(_ role: UserRole) async throws -> User {
        guard let userId = currentUser?.id else {
            throw AuthError.userNotFound
        }

        let updates: [String: Any] = ["role": role.rawValue]
        let updatedUser = try await userRepository.updateUser(id: userId, updates: updates)
        self.currentUser = updatedUser

        return updatedUser
    }

    // MARK: - Private Methods

    /// 加载当前用户
    private func loadCurrentUser() async {
        do {
            // 检查是否有活跃的session (根据官方文档)
            // session 是一个 throwing 属性
            _ = try await client.auth.session

            // 加载用户信息
            let user = try await userRepository.getCurrentUser()
            await MainActor.run {
                self.currentUser = user
            }

        } catch {
            // 没有活跃的 session 或加载失败
            #if DEBUG
            print("❌ 加载用户失败: \(error)")
            #endif
        }
    }

    /// 登录或注册用户
    private func signInOrRegister(phone: String, authUserId: UUID? = nil) async throws -> User {
        print("🔄 signInOrRegister 开始")
        print("📱 手机号: \(phone)")

        // 查询用户是否存在
        print("🔍 查询用户是否存在...")
        if let existingUser = try await userRepository.getUserByPhone(phone: phone) {
            print("✅ 找到现有用户: \(existingUser.id)")
            return existingUser
        }

        // 用户不存在，创建新用户
        print("➕ 用户不存在，创建新用户...")
        let userId = authUserId ?? UUID()
        print("🆔 新用户ID: \(userId)")

        let newUserData: [String: Any] = [
            "id": userId.uuidString,
            "phone": phone,
            "role": UserRole.passenger.rawValue,
            "is_verified": false,
            "status": UserStatus.active.rawValue
        ]

        let newUserJson = try JSONSerialization.data(withJSONObject: newUserData)
        print("📦 用户数据: \(newUserData)")

        // 使用 URLSession 直接调用 REST API
        print("💾 插入用户到数据库（使用 URLSession）...")

        do {
            // 构建请求
            let urlString = "\(SupabaseConfig.url)/rest/v1/users"
            guard let url = URL(string: urlString) else {
                throw AuthError.networkError
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "Authorization")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = newUserJson

            print("🌐 请求URL: \(urlString)")
            print("🔑 使用API Key: \(SupabaseConfig.anonKey.prefix(20))...")

            // 发送请求
            let (data, response) = try await URLSession.shared.data(for: request)

            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP状态码: \(httpResponse.statusCode)")
                print("📦 响应数据大小: \(data.count) bytes")

                // 打印原始响应
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 原始响应: \(responseString)")
                }

                guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                    throw AuthError.networkError
                }
            }

            // 解析响应
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let users: [User] = try decoder.decode([User].self, from: data)

            guard let user = users.first else {
                throw AuthError.unknown(NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "未返回用户数据"]))
            }

            print("✅ 用户创建成功")
            print("👤 创建的用户: \(user)")

            // 创建乘客profile
            print("📝 创建乘客profile...")
            let profileData: [String: Any] = [
                "user_id": userId.uuidString
            ]

            let profileJson = try JSONSerialization.data(withJSONObject: profileData)

            let profileUrlString = "\(SupabaseConfig.url)/rest/v1/passenger_profiles"
            if let profileUrl = URL(string: profileUrlString) {
                var profileRequest = URLRequest(url: profileUrl)
                profileRequest.httpMethod = "POST"
                profileRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                profileRequest.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
                profileRequest.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "Authorization")
                profileRequest.httpBody = profileJson

                _ = try? await URLSession.shared.data(for: profileRequest)
            }

            print("✅ Profile创建完成")

            return user

        } catch {
            print("❌ 数据库操作失败: \(error)")
            print("❌ 错误类型: \(type(of: error))")
            if let decodingError = error as? DecodingError {
                print("❌ 解码错误详情: \(decodingError)")
            }
            throw error
        }
    }

    /// 验证手机号格式
    private func isValidPhone(_ phone: String) -> Bool {
        // 简单的中国手机号验证（11位数字）
        let phoneRegex = "^1[3-9]\\d{9}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone)
    }
}

// MARK: - Mock Auth Service (用于SwiftUI Preview)
final class MockAuthService: AuthServiceProtocol {
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    var authStatePublisher: AnyPublisher<User?, Never> {
        Just(currentUser).eraseToAnyPublisher()
    }

    func sendVerificationCode(to phone: String) async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }

    func verifyCode(_ code: String, phone: String) async throws -> User {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let user = User(
            id: UUID(),
            phone: phone,
            role: .passenger,
            isVerified: false,
            status: .active,
            createdAt: Date(),
            updatedAt: Date()
        )
        currentUser = user
        return user
    }

    func signOut() async throws {
        currentUser = nil
    }

    func updateUserRole(_ role: UserRole) async throws -> User {
        guard var user = currentUser else {
            throw AuthError.userNotFound
        }
        user.role = role
        currentUser = user
        return user
    }
}
