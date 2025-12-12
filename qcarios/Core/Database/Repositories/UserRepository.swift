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
    private let client = SupabaseClient.shared.client
    private let tableName = SupabaseConfig.Table.users

    // MARK: - Read Operations

    func getUser(id: UUID) async throws -> User {
        let response = try await client.database
            .from(tableName)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()

        return try response.decode()
    }

    func getCurrentUser() async throws -> User {
        guard let userId = SupabaseClient.shared.currentUserId else {
            throw SupabaseClient.DatabaseError.notAuthenticated
        }

        return try await getUser(id: userId)
    }

    func getUserByPhone(phone: String) async throws -> User? {
        let response = try await client.database
            .from(tableName)
            .select()
            .eq("phone", value: phone)
            .maybeSingle()
            .execute()

        return try? response.decode()
    }

    // MARK: - Update Operations

    func updateUser(id: UUID, updates: [String: Any]) async throws -> User {
        let response = try await client.database
            .from(tableName)
            .update(updates)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()

        return try response.decode()
    }
}
