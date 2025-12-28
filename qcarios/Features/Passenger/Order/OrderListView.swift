//
//  OrderListView.swift
//  qcarios
//
//  订单列表页面
//

import SwiftUI
import Combine

struct OrderListView: View {

    @StateObject private var viewModel = OrderListViewModel()
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab切换
                Picker("订单类型", selection: $selectedTab) {
                    Text("进行中").tag(0)
                    Text("已完成").tag(1)
                    Text("已取消").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // 订单列表
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.orders.isEmpty {
                    emptyView
                } else {
                    orderList
                }
            }
            .navigationTitle("我的订单")
            .refreshable {
                await viewModel.loadOrders(status: currentStatus)
            }
            .onAppear {
                Task {
                    await viewModel.loadOrders(status: currentStatus)
                }
            }
            .onChange(of: selectedTab) { _ in
                Task {
                    await viewModel.loadOrders(status: currentStatus)
                }
            }
        }
    }

    private var currentStatus: OrderStatus? {
        switch selectedTab {
        case 0: return nil // 所有进行中的订单
        case 1: return .completed
        case 2: return .cancelled
        default: return nil
        }
    }

    private var orderList: some View {
        List(viewModel.orders) { order in
            NavigationLink(destination: OrderDetailView(order: order)) {
                OrderRowView(order: order)
            }
        }
        .listStyle(PlainListStyle())
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("暂无订单")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Order Row View
struct OrderRowView: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 订单号和状态
            HStack {
                Text("订单号: \(order.orderNumber)")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                Text(order.status.displayText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }

            // 行程信息
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    LocationText(
                        icon: "location.circle.fill",
                        iconColor: .green,
                        text: order.pickupAddress ?? "未知地点"
                    )

                    LocationText(
                        icon: "mappin.circle.fill",
                        iconColor: .red,
                        text: order.dropoffAddress ?? "未知地点"
                    )
                }

                Spacer()

                // 价格
                if let price = order.finalPrice ?? order.estimatedPrice {
                    Text("¥\(String(format: "%.0f", NSDecimalNumber(decimal: price).doubleValue))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }

            // 时间
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.gray)
                    .font(.caption)

                Text(order.createdAt.formatted())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var statusColor: Color {
        switch order.status {
        case .pending: return .orange
        case .accepted, .driverArrived: return .blue
        case .inProgress: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

struct LocationText: View {
    let icon: String
    let iconColor: Color
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.caption)

            Text(text)
                .font(.subheadline)
                .lineLimit(1)
        }
    }
}

// MARK: - ViewModel
@MainActor
final class OrderListViewModel: ObservableObject {

    @Published var orders: [Order] = []
    @Published var isLoading = false

    private let orderRepository = OrderRepository()

    func loadOrders(status: OrderStatus?) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        isLoading = true

        do {
            // 根据用户角色加载订单
            if AuthService.shared.currentUser?.isDriver == true {
                orders = try await orderRepository.getOrdersByDriver(driverId: userId, status: status)
            } else {
                orders = try await orderRepository.getOrdersByPassenger(passengerId: userId, status: status)
            }
        } catch {
            print("❌ 加载订单失败: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Preview
struct OrderListView_Previews: PreviewProvider {
    static var previews: some View {
        OrderListView()
    }
}
