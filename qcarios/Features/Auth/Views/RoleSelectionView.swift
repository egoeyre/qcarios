//
//  RoleSelectionView.swift
//  qcarios
//
//  角色选择页面
//

import SwiftUI

struct RoleSelectionView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: UserRole?
    @State private var isLoading = false
    @State private var navigateToMain = false

    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // 标题
                VStack(spacing: 12) {
                    Text("选择您的身份")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("可以稍后在设置中更改")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                // 角色选项
                VStack(spacing: 20) {
                    RoleCard(
                        role: .passenger,
                        isSelected: selectedRole == .passenger,
                        icon: "person.fill",
                        title: "我是乘客",
                        description: "需要代驾服务"
                    ) {
                        selectedRole = .passenger
                    }

                    RoleCard(
                        role: .driver,
                        isSelected: selectedRole == .driver,
                        icon: "car.fill",
                        title: "我是司机",
                        description: "提供代驾服务"
                    ) {
                        selectedRole = .driver
                    }

                    RoleCard(
                        role: .both,
                        isSelected: selectedRole == .both,
                        icon: "person.2.fill",
                        title: "乘客和司机",
                        description: "同时使用两种身份"
                    ) {
                        selectedRole = .both
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // 确认按钮
                Button(action: {
                    confirmRole()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isLoading ? "保存中..." : "确认并继续")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        selectedRole != nil ?
                        Color.green : Color.gray.opacity(0.3)
                    )
                    .cornerRadius(12)
                }
                .disabled(selectedRole == nil || isLoading)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $navigateToMain) {
            MainTabView()
        }
    }

    private func confirmRole() {
        guard let role = selectedRole else { return }

        isLoading = true

        Task {
            do {
                _ = try await AuthService.shared.updateUserRole(role)

                await MainActor.run {
                    isLoading = false
                    navigateToMain = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
                print("❌ 更新角色失败: \(error)")
            }
        }
    }
}

// MARK: - Role Card
struct RoleCard: View {
    let role: UserRole
    let isSelected: Bool
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                // 图标
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(isSelected ? .blue : .white)
                }

                // 文字
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct RoleSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        RoleSelectionView()
    }
}
