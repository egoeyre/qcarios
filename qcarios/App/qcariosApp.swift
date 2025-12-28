//
//  qcariosApp.swift
//  qcarios
//
//  App入口
//

import SwiftUI
import AMapFoundationKit
import AMapNaviKit
import Combine

@main
struct qcariosApp: App {

    init() {
        configureServices()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    private func configureServices() {
        // 配置高德地图隐私合规（必须在 MAMapView 实例化之前调用）
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)

        // 验证Supabase配置
        let validation = SupabaseConfig.detailedValidation()
        if !validation.isValid {
            print("❌ Supabase配置不完整:")
            print("缺失: \(validation.missingKeys)")
        }

        if !validation.warnings.isEmpty {
            print("⚠️ 警告: \(validation.warnings)")
        }

        // 配置高德地图
        if let amapKey = Bundle.main.object(forInfoDictionaryKey: "AMAP_IOS_KEY") as? String {
            AMapService.shared.configure(apiKey: amapKey)
        } else {
            print("⚠️ 警告: 高德地图API Key未配置")
        }
    }
}

// MARK: - Root View
struct RootView: View {

    @StateObject private var authService = AuthService.shared

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            // 请求通知权限
            requestNotificationPermission()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}

// MARK: - Preview
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
