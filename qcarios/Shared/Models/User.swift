//
//  User.swift
//  qcarios
//
//  用户数据模型
//

import Foundation

// MARK: - User Role
enum UserRole: String, Codable {
    case passenger
    case driver
    case both
    case admin
}

// MARK: - User Status
enum UserStatus: String, Codable {
    case active
    case suspended
    case banned
}

// MARK: - Gender
enum Gender: String, Codable {
    case male
    case female
    case other
}

// MARK: - User Model
struct User: Identifiable, Codable, Equatable {
    let id: UUID
    var phone: String
    var role: UserRole
    var nickname: String?
    var avatarURL: String?
    var gender: Gender?
    var realName: String?
    var idCardNumber: String?
    var isVerified: Bool
    var status: UserStatus
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case phone
        case role
        case nickname
        case avatarURL = "avatar_url"
        case gender
        case realName = "real_name"
        case idCardNumber = "id_card_number"
        case isVerified = "is_verified"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    var displayName: String {
        return nickname ?? realName ?? phone.masked
    }

    var isDriver: Bool {
        return role == .driver || role == .both
    }

    var isPassenger: Bool {
        return role == .passenger || role == .both
    }
}

// MARK: - String Extension for Phone Masking
private extension String {
    var masked: String {
        guard count == 11 else { return self }
        let start = prefix(3)
        let end = suffix(4)
        return "\(start)****\(end)"
    }
}
