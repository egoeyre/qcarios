//
//  LoginView.swift
//  qcarios
//
//  登录页面
//

import SwiftUI

struct LoginView: View {

    @StateObject private var viewModel = LoginViewModel()
    @State private var showRoleSelection = false

    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()

                    // Logo和标题
                    VStack(spacing: 16) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)

                        Text("qcarios")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)

                        Text("专业代驾服务")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    // 登录表单
                    VStack(spacing: 20) {
                        // 手机号输入
                        PhoneInputField(
                            phone: $viewModel.phoneNumber,
                            isValid: viewModel.isPhoneValid
                        )

                        // 验证码输入（发送验证码后显示）
                        if viewModel.isCodeSent {
                            VerificationCodeField(
                                code: $viewModel.verificationCode
                            )
                        }

                        // 发送验证码按钮
                        Button(action: {
                            Task {
                                await viewModel.sendVerificationCode()
                            }
                        }) {
                            Text(viewModel.sendCodeButtonText)
                                .font(.headline)
                                .foregroundColor(viewModel.canSendCode ? .white : .white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    viewModel.canSendCode ?
                                    Color.blue : Color.gray.opacity(0.3)
                                )
                                .cornerRadius(12)
                        }
                        .disabled(!viewModel.canSendCode)

                        // 登录按钮
                        if viewModel.isCodeSent {
                            Button(action: {
                                Task {
                                    let success = await viewModel.verifyAndLogin()
                                    if success {
                                        showRoleSelection = true
                                    }
                                }
                            }) {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    }
                                    Text(viewModel.isLoading ? "验证中..." : "登录")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    viewModel.canVerify ?
                                    Color.green : Color.gray.opacity(0.3)
                                )
                                .cornerRadius(12)
                            }
                            .disabled(!viewModel.canVerify)
                        }

                        // 错误提示
                        if let errorMessage = viewModel.errorMessage {
                            HStack {
                                Image(systemName: errorMessage.contains("已发送") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                Text(errorMessage)
                                    .font(.caption)
                            }
                            .foregroundColor(errorMessage.contains("已发送") ? .green : .red)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(8)
                            .onTapGesture {
                                viewModel.clearError()
                            }
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    // 用户协议
                    VStack(spacing: 8) {
                        Text("登录即表示同意")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        HStack(spacing: 4) {
                            Button("《用户协议》") {}
                                .font(.caption)
                                .foregroundColor(.white)

                            Text("和")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))

                            Button("《隐私政策》") {}
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showRoleSelection) {
                RoleSelectionView()
            }
        }
    }
}

// MARK: - Phone Input Field
struct PhoneInputField: View {
    @Binding var phone: String
    let isValid: Bool

    var body: some View {
        HStack {
            Image(systemName: "phone.fill")
                .foregroundColor(.white.opacity(0.7))

            Text("+86")
                .foregroundColor(.white)

            TextField("请输入手机号", text: $phone)
                .keyboardType(.numberPad)
                .foregroundColor(.white)
                .onChange(of: phone) { newValue in
                    // 限制只能输入11位数字
                    if newValue.count > 11 {
                        phone = String(newValue.prefix(11))
                    }
                }

            if !phone.isEmpty {
                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isValid ? .green : .red)
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Verification Code Field
struct VerificationCodeField: View {
    @Binding var code: String

    var body: some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundColor(.white.opacity(0.7))

            TextField("请输入验证码", text: $code)
                .keyboardType(.numberPad)
                .foregroundColor(.white)
                .onChange(of: code) { newValue in
                    // 限制只能输入6位数字
                    if newValue.count > 6 {
                        code = String(newValue.prefix(6))
                    }
                }

            if code.count == 6 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Preview
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
