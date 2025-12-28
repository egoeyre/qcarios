//
//  MainTabView.swift
//  qcarios
//
//  主Tab导航
//

import SwiftUI

struct MainTabView: View {

    @StateObject private var authService = AuthService.shared
    @State private var selectedTab = 0
    @State private var showDriverView = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // 根据用户角色显示不同的首页
            Group {
                if showDriverView {
                    DriverHomeView()
                } else {
                    PassengerHomeView()
                }
            }
            .tabItem {
                Label("首页", systemImage: "house.fill")
            }
            .tag(0)

            // 订单
            OrderListView()
                .tabItem {
                    Label("订单", systemImage: "list.bullet.rectangle")
                }
                .tag(1)

            // 我的
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .onAppear {
            updateViewMode()
        }
        .onChange(of: authService.currentUser?.role) { _ in
            updateViewMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserModeChanged"))) { notification in
            if let mode = notification.userInfo?["mode"] as? String {
                showDriverView = (mode == "driver")
            }
        }
    }

    // MARK: - Private Methods

    private func updateViewMode() {
        guard let user = authService.currentUser else {
            showDriverView = false
            return
        }

        // 默认根据用户角色决定显示哪个视图
        showDriverView = user.isDriver && user.role != .both

        // 如果用户是 both，需要记住用户的选择
        // 这里可以从 UserDefaults 读取用户上次的选择
        if user.role == .both {
            let savedMode = UserDefaults.standard.string(forKey: "preferred_mode") ?? "passenger"
            showDriverView = (savedMode == "driver")
        }
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
