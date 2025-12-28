//
//  PaymentView.swift
//  qcarios
//
//  支付页面
//

import SwiftUI
import Combine

struct PaymentView: View {

    let order: Order
    @StateObject private var viewModel: PaymentViewModel
    @Environment(\.dismiss) private var dismiss

    init(order: Order) {
        self.order = order
        self._viewModel = StateObject(wrappedValue: PaymentViewModel(order: order))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 支付金额
                paymentAmountSection

                Divider()

                // 支付方式选择
                paymentMethodSection

                Spacer()

                // 支付按钮
                paymentButton
            }
            .navigationTitle("支付")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("支付结果", isPresented: $viewModel.showPaymentResult) {
                Button("确定") {
                    if viewModel.paymentSuccess {
                        dismiss()
                    }
                }
            } message: {
                Text(viewModel.paymentMessage ?? "")
            }
        }
    }

    // MARK: - Payment Amount Section

    private var paymentAmountSection: some View {
        VStack(spacing: 16) {
            Text("订单金额")
                .font(.headline)
                .foregroundColor(.gray)

            if let amount = order.finalPrice ?? order.estimatedPrice {
                Text("¥\(String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue))")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
            }

            // 费用明细
            VStack(spacing: 8) {
                if let distance = order.actualDistanceKm ?? order.estimatedDistanceKm {
                    HStack {
                        Text("行程距离")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(String(format: "%.1f", NSDecimalNumber(decimal: distance).doubleValue))公里")
                    }
                }

                if let duration = order.actualDurationMin ?? order.estimatedDurationMin {
                    HStack {
                        Text("行程时长")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(duration)分钟")
                    }
                }

                if let discount = order.discountAmount, discount > 0 {
                    HStack {
                        Text("优惠金额")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("-¥\(String(format: "%.2f", NSDecimalNumber(decimal: discount).doubleValue))")
                            .foregroundColor(.red)
                    }
                }
            }
            .font(.subheadline)
            .padding(.horizontal)
        }
        .padding(.vertical, 32)
    }

    // MARK: - Payment Method Section

    private var paymentMethodSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("支付方式")
                .font(.headline)
                .padding()

            ForEach(PaymentMethod.allCases, id: \.self) { method in
                PaymentMethodRow(
                    method: method,
                    isSelected: viewModel.selectedMethod == method
                ) {
                    viewModel.selectedMethod = method
                }
            }
        }
    }

    // MARK: - Payment Button

    private var paymentButton: some View {
        Button(action: {
            viewModel.processPayment()
        }) {
            HStack {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }

                Text(viewModel.isProcessing ? "支付中..." : "确认支付")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(viewModel.canPay ? Color.green : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!viewModel.canPay)
        .padding()
    }
}

// MARK: - Payment Method Row
struct PaymentMethodRow: View {
    let method: PaymentMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: methodIcon)
                    .font(.title2)
                    .foregroundColor(methodColor)
                    .frame(width: 40)

                // 名称
                Text(method.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var methodIcon: String {
        switch method {
        case .wechat: return "message.fill"
        case .alipay: return "creditcard.fill"
        case .balance: return "wallet.pass.fill"
        case .applePay: return "applelogo"
        }
    }

    private var methodColor: Color {
        switch method {
        case .wechat: return .green
        case .alipay: return .blue
        case .balance: return .orange
        case .applePay: return .black
        }
    }
}

// MARK: - Payment Method Extension
// extension PaymentMethod: CaseIterable {}

// MARK: - ViewModel
@MainActor
final class PaymentViewModel: ObservableObject {

    @Published var selectedMethod: PaymentMethod = .wechat
    @Published var isProcessing = false
    @Published var showPaymentResult = false
    @Published var paymentSuccess = false
    @Published var paymentMessage: String?

    let order: Order
    private let paymentService = PaymentService.shared

    var canPay: Bool {
        !isProcessing && (order.finalPrice ?? order.estimatedPrice ?? 0) > 0
    }

    init(order: Order) {
        self.order = order
    }

    func processPayment() {
        guard let amount = order.finalPrice ?? order.estimatedPrice else {
            return
        }

        isProcessing = true

        Task {
            do {
                let result = try await paymentService.initiatePayment(
                    orderId: order.id,
                    amount: amount,
                    method: selectedMethod
                )

                paymentSuccess = result.status == .success
                paymentMessage = result.message ?? (paymentSuccess ? "支付成功" : "支付失败")
                showPaymentResult = true

            } catch {
                paymentSuccess = false
                paymentMessage = error.localizedDescription
                showPaymentResult = true
            }

            isProcessing = false
        }
    }
}

// MARK: - Preview
struct PaymentView_Previews: PreviewProvider {
    static var previews: some View {
        PaymentView(order: Order(
            id: UUID(),
            orderNumber: "DD20231212123456",
            passengerId: UUID(),
            orderType: .immediate,
            serviceType: .standard,
            pickupAddress: "北京市朝阳区",
            pickupLat: 39.9042,
            pickupLng: 116.4074,
            pickupPoiId: nil,
            dropoffAddress: "北京市海淀区",
            dropoffLat: 39.9891,
            dropoffLng: 116.3142,
            dropoffPoiId: nil,
            estimatedDistanceKm: 10.5,
            estimatedDurationMin: 30,
            estimatedPrice: 68,
            finalPrice: 68,
            status: .completed,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
