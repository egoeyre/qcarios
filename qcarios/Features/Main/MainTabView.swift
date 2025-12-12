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

    var body: some View {
        TabView(selection: $selectedTab) {
            // 根据用户角色显示不同的首页
            Group {
                if authService.currentUser?.isDriver == true {
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
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
