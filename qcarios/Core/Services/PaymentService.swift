//
//  PaymentService.swift
//  qcarios
//
//  支付服务 - 微信/支付宝支付集成
//

import Foundation
import Supabase

// MARK: - Payment Method
enum PaymentMethod: String, Codable, CaseIterable {
    case wechat = "wechat"
    case alipay = "alipay"
    case balance = "balance"
    case applePay = "apple_pay"

    var displayName: String {
        switch self {
        case .wechat: return "微信支付"
        case .alipay: return "支付宝"
        case .balance: return "余额支付"
        case .applePay: return "Apple Pay"
        }
    }

    var icon: String {
        switch self {
        case .wechat: return "wechat"
        case .alipay: return "alipay"
        case .balance: return "wallet.pass"
        case .applePay: return "applelogo"
        }
    }
}

// MARK: - Payment Status
enum PaymentStatus: String, Codable {
    case pending
    case processing
    case success
    case failed
    case refunded

    var displayText: String {
        switch self {
        case .pending: return "待支付"
        case .processing: return "处理中"
        case .success: return "支付成功"
        case .failed: return "支付失败"
        case .refunded: return "已退款"
        }
    }
}

// MARK: - Payment Result
struct PaymentResult {
    let paymentId: UUID
    let status: PaymentStatus
    let transactionId: String?
    let message: String?
}

// MARK: - Payment Error
enum PaymentError: LocalizedError {
    case invalidAmount
    case orderNotFound
    case paymentCancelled
    case paymentFailed(String)
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "支付金额无效"
        case .orderNotFound:
            return "订单不存在"
        case .paymentCancelled:
            return "支付已取消"
        case .paymentFailed(let message):
            return "支付失败: \(message)"
        case .networkError:
            return "网络连接失败"
        }
    }
}

// MARK: - Payment Service Protocol
protocol PaymentServiceProtocol {
    func initiatePayment(orderId: UUID, amount: Decimal, method: PaymentMethod) async throws -> PaymentResult
    func queryPaymentStatus(paymentId: UUID) async throws -> PaymentStatus
    func handlePaymentCallback(data: [String: Any]) async throws
}

// MARK: - Payment Service Implementation
final class PaymentService: PaymentServiceProtocol {

    // MARK: - Properties

    static let shared = PaymentService()

    private let client = SupabaseClientWrapper.shared.client

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 发起支付
    func initiatePayment(orderId: UUID, amount: Decimal, method: PaymentMethod) async throws -> PaymentResult {
        guard amount > 0 else {
            throw PaymentError.invalidAmount
        }

        // 创建支付记录
        struct PaymentInsert: Encodable {
            let orderId: String
            let amount: Double
            let paymentMethod: String
            let status: String

            enum CodingKeys: String, CodingKey {
                case orderId = "order_id"
                case amount
                case paymentMethod = "payment_method"
                case status
            }
        }

        let paymentData = PaymentInsert(
            orderId: orderId.uuidString,
            amount: NSDecimalNumber(decimal: amount).doubleValue,
            paymentMethod: method.rawValue,
            status: PaymentStatus.pending.rawValue
        )

        let payment: Payment = try await client
            .from(SupabaseConfig.Table.payments)
            .insert(paymentData)
            .select()
            .single()
            .execute()
            .value

        guard let id = payment.id else {
            throw PaymentError.networkError
        }

        // 根据支付方式调用不同的支付SDK
        let result: PaymentResult

        switch method {
        case .wechat:
            result = try await processWeChatPayment(paymentId: id, amount: amount)

        case .alipay:
            result = try await processAlipayPayment(paymentId: id, amount: amount)

        case .balance:
            result = try await processBalancePayment(paymentId: id, amount: amount)

        case .applePay:
            result = try await processApplePayment(paymentId: id, amount: amount)
        }

        // 更新支付状态
        try await updatePaymentStatus(
            paymentId: id,
            status: result.status,
            transactionId: result.transactionId
        )

        return result
    }

    /// 查询支付状态
    func queryPaymentStatus(paymentId: UUID) async throws -> PaymentStatus {
        let payment: Payment = try await client
            .from(SupabaseConfig.Table.payments)
            .select("status")
            .eq("id", value: paymentId.uuidString)
            .single()
            .execute()
            .value

        return payment.status
    }

    /// 处理支付回调
    func handlePaymentCallback(data: [String: Any]) async throws {
        // 解析回调数据
        guard let paymentIdString = data["payment_id"] as? String,
              let paymentId = UUID(uuidString: paymentIdString),
              let statusString = data["status"] as? String,
              let status = PaymentStatus(rawValue: statusString) else {
            return
        }

        let transactionId = data["transaction_id"] as? String

        // 更新支付状态
        try await updatePaymentStatus(
            paymentId: paymentId,
            status: status,
            transactionId: transactionId
        )

        // 如果支付成功，更新订单状态
        if status == .success {
            // TODO: 更新订单状态为已支付
        }
    }

    // MARK: - Private Methods

    /// 处理微信支付
    private func processWeChatPayment(paymentId: UUID, amount: Decimal) async throws -> PaymentResult {
        #if DEBUG
        // 开发环境：模拟支付
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        return PaymentResult(
            paymentId: paymentId,
            status: .success,
            transactionId: "WX\(Int.random(in: 100000...999999))",
            message: "支付成功（开发环境模拟）"
        )
        #else
        // 生产环境：调用微信支付SDK
        // TODO: 集成微信支付SDK

        // 示例代码：
        // let req = PayReq()
        // req.partnerId = "your_partner_id"
        // req.prepayId = prepayId
        // req.nonceStr = nonceStr
        // req.timeStamp = timeStamp
        // req.package = "Sign=WXPay"
        // req.sign = sign
        // WXApi.send(req)

        throw PaymentError.paymentFailed("微信支付SDK未集成")
        #endif
    }

    /// 处理支付宝支付
    private func processAlipayPayment(paymentId: UUID, amount: Decimal) async throws -> PaymentResult {
        #if DEBUG
        // 开发环境：模拟支付
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        return PaymentResult(
            paymentId: paymentId,
            status: .success,
            transactionId: "ALI\(Int.random(in: 100000...999999))",
            message: "支付成功（开发环境模拟）"
        )
        #else
        // 生产环境：调用支付宝SDK
        // TODO: 集成支付宝SDK
        throw PaymentError.paymentFailed("支付宝SDK未集成")
        #endif
    }

    /// 处理余额支付
    private func processBalancePayment(paymentId: UUID, amount: Decimal) async throws -> PaymentResult {
        // TODO: 检查余额
        // TODO: 扣除余额

        return PaymentResult(
            paymentId: paymentId,
            status: .success,
            transactionId: paymentId.uuidString,
            message: "余额支付成功"
        )
    }

    /// 处理Apple Pay
    private func processApplePayment(paymentId: UUID, amount: Decimal) async throws -> PaymentResult {
        // TODO: 集成Apple Pay
        throw PaymentError.paymentFailed("Apple Pay未集成")
    }

    /// 更新支付状态
    private func updatePaymentStatus(
        paymentId: UUID,
        status: PaymentStatus,
        transactionId: String?
    ) async throws {
        struct PaymentStatusUpdate: Encodable {
            let status: String
            let transactionId: String?
            let paidAt: String?

            enum CodingKeys: String, CodingKey {
                case status
                case transactionId = "transaction_id"
                case paidAt = "paid_at"
            }
        }

        let updates = PaymentStatusUpdate(
            status: status.rawValue,
            transactionId: transactionId,
            paidAt: status == .success ? ISO8601DateFormatter().string(from: Date()) : nil
        )

        _ = try await client
            .from(SupabaseConfig.Table.payments)
            .update(updates)
            .eq("id", value: paymentId.uuidString)
            .execute()
    }
}

// MARK: - Payment Model
struct Payment: Identifiable, Codable {
    let id: UUID?
    let orderId: UUID
    let amount: Decimal
    let paymentMethod: PaymentMethod
    var status: PaymentStatus
    var transactionId: String?
    var paidAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case amount
        case paymentMethod = "payment_method"
        case status
        case transactionId = "transaction_id"
        case paidAt = "paid_at"
        case createdAt = "created_at"
    }
}
