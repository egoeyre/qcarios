//
//  LoginViewModel.swift
//  qcarios
//
//  登录页面ViewModel
//

import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var phoneNumber: String = ""
    @Published var verificationCode: String = ""
    @Published var isCodeSent: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var countdown: Int = 0

    // MARK: - Dependencies

    private let authService: AuthServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: Timer?

    // MARK: - Computed Properties

    var isPhoneValid: Bool {
        let phoneRegex = "^1[3-9]\\d{9}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phoneNumber)
    }

    var canSendCode: Bool {
        isPhoneValid && !isLoading && countdown == 0
    }

    var canVerify: Bool {
        isCodeSent && verificationCode.count == 6 && !isLoading
    }

    var sendCodeButtonText: String {
        if isLoading {
            return "发送中..."
        } else if countdown > 0 {
            return "\(countdown)秒后重试"
        } else if isCodeSent {
            return "重新发送"
        } else {
            return "获取验证码"
        }
    }

    // MARK: - Initialization

    init(authService: AuthServiceProtocol = AuthService.shared) {
        self.authService = authService
    }

    // MARK: - Public Methods

    /// 发送验证码
    func sendVerificationCode() async {
        guard canSendCode else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.sendVerificationCode(to: phoneNumber)

            isCodeSent = true
            startCountdown()

            #if DEBUG
            // 开发环境提示
            errorMessage = "验证码已发送（开发环境固定为：123456）"
            #endif

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 验证验证码并登录
    func verifyAndLogin() async -> Bool {
        guard canVerify else { return false }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.verifyCode(verificationCode, phone: phoneNumber)

            // 登录成功
            print("✅ 登录成功: \(user.displayName)")
            return true

        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        isLoading = false
    }

    /// 清除错误消息
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// 开始倒计时
    private func startCountdown() {
        countdown = 60

        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                if self.countdown > 0 {
                    self.countdown -= 1
                } else {
                    self.countdownTimer?.invalidate()
                    self.countdownTimer = nil
                }
            }
        }
    }

    deinit {
        countdownTimer?.invalidate()
    }
}
