//
//  DriverHomeView.swift
//  qcarios
//
//  司机端首页
//

import SwiftUI

struct DriverHomeView: View {

    @StateObject private var viewModel = DriverHomeViewModel()

    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部状态栏
                statusBar

                // 订单列表
                if viewModel.isOnline {
                    orderList
                } else {
                    offlineView
                }
            }
        }
        .onAppear {
            viewModel.loadPendingOrders()
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        VStack(spacing: 16) {
            HStack {
                // 在线状态切换
                Toggle(isOn: $viewModel.isOnline) {
                    HStack {
                        Circle()
                            .fill(viewModel.isOnline ? Color.green : Color.gray)
                            .frame(width: 12, height: 12)

                        Text(viewModel.isOnline ? "在线接单中" : "离线")
                            .font(.headline)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .onChange(of: viewModel.isOnline) { newValue in
                    viewModel.updateOnlineStatus(newValue)
                }

                Spacer()
            }

            // 今日统计
            if viewModel.isOnline {
                HStack(spacing: 20) {
                    StatItem(title: "今日订单", value: "\(viewModel.todayOrders)")
                    StatItem(title: "今日收入", value: "¥\(String(format: "%.0f", viewModel.todayEarnings))")
                    StatItem(title: "在线时长", value: viewModel.onlineTimeText)
                }
            }
        }
        .padding()
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Order List

    private var orderList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("附近订单")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            if viewModel.isLoadingOrders {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.pendingOrders.isEmpty {
                emptyOrdersView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.pendingOrders) { order in
                            DriverOrderCard(order: order) {
                                viewModel.acceptOrder(order)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Offline View

    private var offlineView: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("当前离线")
                .font(.title2)
                .fontWeight(.bold)

            Text("开启在线状态以开始接单")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty Orders View

    private var emptyOrdersView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("暂无附近订单")
                .font(.headline)
                .foregroundColor(.gray)

            Button("刷新") {
                viewModel.loadPendingOrders()
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(.blue)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Driver Order Card
struct DriverOrderCard: View {
    let order: Order
    let onAccept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 距离和价格
            HStack {
                Label("5.2km", systemImage: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                if let price = order.estimatedPrice {
                    Text("¥\(String(format: "%.0f", NSDecimalNumber(decimal: price).doubleValue))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }

            // 行程
            VStack(alignment: .leading, spacing: 8) {
                LocationText(
                    icon: "location.circle.fill",
                    iconColor: .green,
                    text: order.pickupAddress ?? "未知"
                )

                LocationText(
                    icon: "mappin.circle.fill",
                    iconColor: .red,
                    text: order.dropoffAddress ?? "未知"
                )
            }

            // 接单按钮
            Button(action: onAccept) {
                Text("抢单")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.green)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}

// MARK: - ViewModel
@MainActor
final class DriverHomeViewModel: ObservableObject {

    @Published var isOnline = false
    @Published var pendingOrders: [Order] = []
    @Published var isLoadingOrders = false
    @Published var todayOrders = 0
    @Published var todayEarnings: Double = 0
    @Published var onlineTime: TimeInterval = 0

    var onlineTimeText: String {
        let hours = Int(onlineTime / 3600)
        let minutes = Int((onlineTime.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h\(minutes)m"
    }

    private let orderRepository = OrderRepository()
    private let driverRepository = DriverRepository()
    private let locationService = LocationService.shared

    func updateOnlineStatus(_ isOnline: Bool) {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        Task {
            do {
                let status: DriverOnlineStatus = isOnline ? .online : .offline
                _ = try await driverRepository.updateOnlineStatus(userId: userId, status: status)

                if isOnline {
                    locationService.startUpdatingLocation()
                    loadPendingOrders()
                } else {
                    locationService.stopUpdatingLocation()
                }
            } catch {
                print("❌ 更新在线状态失败: \(error)")
            }
        }
    }

    func loadPendingOrders() {
        guard isOnline,
              let location = locationService.currentLocation else {
            return
        }

        isLoadingOrders = true

        Task {
            do {
                let orders = try await orderRepository.getPendingOrders(
                    near: Location(coordinate: location.coordinate),
                    radiusKm: 5
                )

                pendingOrders = orders
            } catch {
                print("❌ 加载订单失败: \(error)")
            }

            isLoadingOrders = false
        }
    }

    func acceptOrder(_ order: Order) {
        guard let driverId = AuthService.shared.currentUser?.id else { return }

        Task {
            do {
                _ = try await orderRepository.acceptOrder(id: order.id, driverId: driverId)

                // 移除已接订单
                pendingOrders.removeAll { $0.id == order.id }

                print("✅ 接单成功")

                // TODO: 导航到订单详情页

            } catch {
                print("❌ 接单失败: \(error)")
            }
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        VStack(alignment: .leading) {
                            Text(AuthService.shared.currentUser?.displayName ?? "用户")
                                .font(.headline)

                            Text(AuthService.shared.currentUser?.phone ?? "")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical)
                }

                Section("账户信息") {
                    NavigationLink("个人资料") {
                        Text("个人资料")
                    }

                    NavigationLink("我的钱包") {
                        Text("我的钱包")
                    }
                }

                Section("设置") {
                    NavigationLink("通知设置") {
                        Text("通知设置")
                    }

                    NavigationLink("隐私设置") {
                        Text("隐私设置")
                    }
                }

                Section {
                    Button("退出登录") {
                        Task {
                            try? await AuthService.shared.signOut()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("我的")
        }
    }
}

// MARK: - Preview
struct DriverHomeView_Previews: PreviewProvider {
    static var previews: some View {
        DriverHomeView()
    }
}
