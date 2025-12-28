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
    func updateUser(id: UUID, updates: [String: Any]) async throws -> User
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

    func updateUser(id: UUID, updates: [String: Any]) async throws -> User {
        let jsonData = try JSONSerialization.data(withJSONObject: updates)

        let response: User = try await client
            .from(tableName)
            .update(jsonData)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return response
    }
}
