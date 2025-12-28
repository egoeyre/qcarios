//
//  RoleSwitcher.swift
//  qcarios
//
//  司机乘客角色切换组件
//

import SwiftUI

struct RoleSwitcher: View {

    @StateObject private var authService = AuthService.shared
    @State private var currentMode: UserMode = .passenger
    @State private var isUpdating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDriverRegistration = false

    enum UserMode: String, CaseIterable {
        case passenger = "乘客模式"
        case driver = "司机模式"

        var icon: String {
            switch self {
            case .passenger: return "figure.wave"
            case .driver: return "car.fill"
            }
        }

        var color: Color {
            switch self {
            case .passenger: return .blue
            case .driver: return .green
            }
        }
    }

    var body: some View {
        Group {
            if let user = authService.currentUser {
                if user.isDriver {
                    // 司机用户：显示切换按钮
                    modeSwitcher
                } else {
                    // 乘客用户：显示"成为司机"按钮
                    becomeDriverButton
                }
            }
        }
        .onAppear {
            updateCurrentMode()
        }
        .onChange(of: authService.currentUser?.role) { _ in
            updateCurrentMode()
        }
        .alert("切换失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showDriverRegistration) {
            DriverRegistrationView()
        }
    }

    // MARK: - Mode Switcher (for drivers)

    private var modeSwitcher: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(UserMode.allCases, id: \.self) { mode in
                    Button(action: {
                        switchToMode(mode)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 16, weight: .semibold))

                            Text(mode.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(currentMode == mode ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            ZStack {
                                if currentMode == mode {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(mode.color)
                                        .shadow(color: mode.color.opacity(0.3), radius: 4, y: 2)
                                }
                            }
                        )
                    }
                    .disabled(isUpdating)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .overlay(
            Group {
                if isUpdating {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        )
    }

    // MARK: - Become Driver Button (for passengers)

    private var becomeDriverButton: some View {
        Button(action: {
            showDriverRegistration = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.system(size: 20, weight: .semibold))

                VStack(alignment: .leading, spacing: 4) {
                    Text("成为司机")
                        .font(.system(size: 17, weight: .semibold))

                    Text("加入我们，开始赚钱")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.green, Color.green.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }

    // MARK: - Private Methods

    private func updateCurrentMode() {
        guard let user = authService.currentUser else { return }

        // 如果用户角色是 both，从 UserDefaults 读取保存的偏好
        if user.role == .both {
            let savedMode = UserDefaults.standard.string(forKey: "preferred_mode") ?? "passenger"
            currentMode = savedMode == "driver" ? .driver : .passenger
        } else if user.isDriver {
            currentMode = .driver
        } else {
            currentMode = .passenger
        }
    }

    private func switchToMode(_ mode: UserMode) {
        guard mode != currentMode else { return }
        guard let user = authService.currentUser else { return }

        isUpdating = true

        Task {
            do {
                // 确定目标角色
                let targetRole: UserRole

                if user.role == .both {
                    // 如果用户已经是 both，只需要切换界面模式并保存偏好
                    currentMode = mode
                    savePreferredMode(mode)
                    isUpdating = false

                    // 发送通知让 MainTabView 刷新
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UserModeChanged"),
                        object: nil,
                        userInfo: ["mode": mode == .driver ? "driver" : "passenger"]
                    )
                    return
                }

                // 如果用户当前只有一个角色，需要升级为 both
                if mode == .driver && user.isPassenger {
                    targetRole = .both
                } else if mode == .passenger && user.isDriver {
                    targetRole = .both
                } else if mode == .driver {
                    targetRole = .driver
                } else {
                    targetRole = .passenger
                }

                // 更新用户角色
                _ = try await authService.updateUserRole(targetRole)

                await MainActor.run {
                    currentMode = mode
                    savePreferredMode(mode)
                    isUpdating = false

                    // 发送通知让 MainTabView 刷新
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UserModeChanged"),
                        object: nil,
                        userInfo: ["mode": mode == .driver ? "driver" : "passenger"]
                    )
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isUpdating = false
                }
            }
        }
    }

    private func savePreferredMode(_ mode: UserMode) {
        let modeString = mode == .driver ? "driver" : "passenger"
        UserDefaults.standard.set(modeString, forKey: "preferred_mode")
    }
}

// MARK: - Preview
struct RoleSwitcher_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            RoleSwitcher()
                .padding()

            RoleSwitcher()
                .padding()
                .preferredColorScheme(.dark)
        }
    }
}
