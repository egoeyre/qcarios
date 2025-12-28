//
//  UserRepository.swift
//  qcarios
//
//  用户数据访问层
//

import Foundation
import Supabase

protocol UserRepositoryProtocol {
    func getUser(id: UUID) async throws -> User
    func getCurrentUser() async throws -> User
    func updateUser<T: Encodable>(id: UUID, updates: T) async throws -> User
    func getUserByPhone(phone: String) async throws -> User?
}

final class UserRepository: UserRepositoryProtocol {

    // MARK: - Properties
    private let client = SupabaseClientWrapper.shared.client
    private let tableName = SupabaseConfig.Table.users

    // MARK: - Read Operations

    func getUser(id: UUID) async throws -> User {
        let response: User = try await client
            .from(tableName)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        return response
    }

    func getCurrentUser() async throws -> User {
        guard let userId = await SupabaseClientWrapper.shared.getCurrentUserId() else {
            throw SupabaseClientWrapper.DatabaseError.notAuthenticated
        }

        return try await getUser(id: userId)
    }

    func getUserByPhone(phone: String) async throws -> User? {
        do {
            let response: User = try await client
                .from(tableName)
                .select()
                .eq("phone", value: phone)
                .single()
                .execute()
                .value

            return response
        } catch {
            // If no user found, return nil
            return nil
        }
    }

    // MARK: - Update Operations

    func updateUser<T: Encodable>(id: UUID, updates: T) async throws -> User {
        // 使用数组响应以便更好地处理错误
        let response: [User] = try await client
            .from(tableName)
            .update(updates)
            .eq("id", value: id.uuidString)
            .select()
            .execute()
            .value

        guard let user = response.first else {
            throw SupabaseClientWrapper.DatabaseError.invalidResponse
        }

        return user
    }
}

// MARK: - Update Request Models
extension UserRepository {

    /// 用户基本信息更新请求
    struct UserBasicInfoUpdate: Encodable {
        let nickname: String?
        let gender: String?
        let avatarUrl: String?

        enum CodingKeys: String, CodingKey {
            case nickname
            case gender
            case avatarUrl = "avatar_url"
        }
    }

    /// 用户实名信息更新请求
    struct UserVerificationUpdate: Encodable {
        let realName: String
        let idCardNumber: String
        let isVerified: Bool

        enum CodingKeys: String, CodingKey {
            case realName = "real_name"
            case idCardNumber = "id_card_number"
            case isVerified = "is_verified"
        }
    }

    /// 用户状态更新请求
    struct UserStatusUpdate: Encodable {
        let status: String
    }
}
