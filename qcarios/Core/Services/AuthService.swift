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
final class AuthService: AuthServiceProtocol {

    // MARK: - Properties

    static let shared = AuthService()

    private let client = SupabaseClient.shared.client
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

        do {
            // 使用Supabase Auth发送OTP（一次性密码）
            // 注意：这需要配置Supabase的Phone Auth
            // 目前使用简化版本，实际项目中需要配置短信服务商

            #if DEBUG
            // 开发环境：模拟发送验证码
            print("📱 发送验证码到: \(phone)")
            print("🔢 验证码: 123456 (开发环境固定验证码)")
            #else
            // 生产环境：实际发送短信
            try await client.auth.signInWithOTP(
                phone: phone
            )
            #endif

        } catch {
            throw AuthError.networkError
        }
    }

    /// 验证验证码并登录/注册
    func verifyCode(_ code: String, phone: String) async throws -> User {
        guard isValidPhone(phone) else {
            throw AuthError.invalidPhone
        }

        do {
            #if DEBUG
            // 开发环境：使用固定验证码
            if code != "123456" {
                throw AuthError.verificationFailed
            }

            // 模拟登录，创建测试用户
            let user = try await signInOrRegister(phone: phone)

            #else
            // 生产环境：验证真实OTP
            let session = try await client.auth.verifyOTP(
                phone: phone,
                token: code,
                type: .sms
            )

            guard let authUserId = session.user.id else {
                throw AuthError.verificationFailed
            }

            // 查询或创建用户
            let user = try await signInOrRegister(phone: phone, authUserId: authUserId)
            #endif

            self.currentUser = user
            return user

        } catch let error as AuthError {
            throw error
        } catch {
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
            // 检查是否有活跃的session
            guard let session = try? await client.auth.session else {
                return
            }

            // 加载用户信息
            let user = try await userRepository.getCurrentUser()
            await MainActor.run {
                self.currentUser = user
            }

        } catch {
            print("❌ 加载用户失败: \(error)")
        }
    }

    /// 登录或注册用户
    private func signInOrRegister(phone: String, authUserId: UUID? = nil) async throws -> User {
        // 查询用户是否存在
        if let existingUser = try await userRepository.getUserByPhone(phone: phone) {
            return existingUser
        }

        // 用户不存在，创建新用户
        let userId = authUserId ?? UUID()

        let newUserData: [String: Any] = [
            "id": userId.uuidString,
            "phone": phone,
            "role": UserRole.passenger.rawValue,
            "is_verified": false,
            "status": UserStatus.active.rawValue
        ]

        let response = try await client.database
            .from(SupabaseConfig.Table.users)
            .insert(newUserData)
            .select()
            .single()
            .execute()

        let user: User = try response.decode()

        // 创建乘客profile
        let profileData: [String: Any] = [
            "user_id": userId.uuidString
        ]

        _ = try? await client.database
            .from(SupabaseConfig.Table.passengerProfiles)
            .insert(profileData)
            .execute()

        return user
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
