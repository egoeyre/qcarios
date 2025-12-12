//
//  PassengerHomeView.swift
//  qcarios
//
//  乘客端首页
//

import SwiftUI
import CoreLocation

struct PassengerHomeView: View {

    @StateObject private var viewModel = PassengerHomeViewModel()
    @State private var showLocationPicker = false

    var body: some View {
        ZStack {
            // 地图
            MapView(
                centerCoordinate: $viewModel.mapCenter,
                userLocation: $viewModel.currentLocation,
                annotations: viewModel.annotations,
                polyline: viewModel.routePolyline,
                showsUserLocation: true
            )
            .ignoresSafeArea()

            // UI覆盖层
            VStack {
                // 顶部搜索栏
                searchBar

                Spacer()

                // 底部卡片
                if viewModel.showRouteInfo {
                    routeInfoCard
                } else {
                    quickActionCard
                }
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(
                selectedLocation: $viewModel.selectedDestination,
                onConfirm: {
                    showLocationPicker = false
                    viewModel.calculateRoute()
                }
            )
        }
        .onAppear {
            viewModel.requestLocationPermission()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        VStack(spacing: 12) {
            // 上车点
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.green)

                Text(viewModel.pickupAddress ?? "定位中...")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    viewModel.useCurrentLocationAsPickup()
                }) {
                    Image(systemName: "scope")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)

            // 目的地
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)

                if let destination = viewModel.selectedDestination {
                    Text(destination.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                } else {
                    Text("选择目的地")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .onTapGesture {
                showLocationPicker = true
            }
        }
        .padding()
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }

    // MARK: - Quick Action Card

    private var quickActionCard: some View {
        VStack(spacing: 20) {
            Text("选择目的地开始行程")
                .font(.headline)
                .foregroundColor(.gray)

            HStack(spacing: 20) {
                QuickLocationButton(
                    icon: "house.fill",
                    title: "回家",
                    action: {
                        // TODO: 使用保存的家庭地址
                    }
                )

                QuickLocationButton(
                    icon: "building.2.fill",
                    title: "去公司",
                    action: {
                        // TODO: 使用保存的公司地址
                    }
                )

                QuickLocationButton(
                    icon: "star.fill",
                    title: "收藏",
                    action: {
                        // TODO: 显示收藏地址列表
                    }
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .padding()
    }

    // MARK: - Route Info Card

    private var routeInfoCard: some View {
        VStack(spacing: 16) {
            // 路线信息
            if let route = viewModel.currentRoute {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("预估距离")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(route.distanceText)
                            .font(.headline)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("预估时间")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(route.durationText)
                            .font(.headline)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("预估费用")
                            .font(.caption)
                            .foregroundColor(.gray)
                        if let price = viewModel.estimatedPrice {
                            Text("¥\(String(format: "%.0f", price))")
                                .font(.headline)
                                .foregroundColor(.green)
                        } else {
                            Text("计算中...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }

            // 呼叫按钮
            Button(action: {
                viewModel.createOrder()
            }) {
                HStack {
                    if viewModel.isCreatingOrder {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(viewModel.isCreatingOrder ? "创建中..." : "立即呼叫代驾")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.green)
                .cornerRadius(12)
            }
            .disabled(viewModel.isCreatingOrder)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .padding()
    }
}

// MARK: - Quick Location Button
struct QuickLocationButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview
struct PassengerHomeView_Previews: PreviewProvider {
    static var previews: some View {
        PassengerHomeView()
    }
}
