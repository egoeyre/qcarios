//
//  LocationPickerView.swift
//  qcarios
//
//  地点选择器
//

import SwiftUI
import CoreLocation
import Combine

struct LocationPickerView: View {

    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLocation: POI?
    let onConfirm: () -> Void

    @StateObject private var viewModel = LocationPickerViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar

                // 搜索结果列表
                if viewModel.isSearching {
                    ProgressView()
                        .padding()
                } else if !viewModel.searchResults.isEmpty {
                    searchResultsList
                } else if viewModel.searchKeyword.isEmpty {
                    nearbyLocationsList
                } else {
                    emptyView
                }
            }
            .navigationTitle("选择目的地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        onConfirm()
                    }
                    .disabled(selectedLocation == nil)
                }
            }
            .onAppear {
                viewModel.loadNearbyLocations()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("搜索地点", text: $viewModel.searchKeyword)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: viewModel.searchKeyword) { newValue in
                    viewModel.search()
                }

            if !viewModel.searchKeyword.isEmpty {
                Button(action: {
                    viewModel.searchKeyword = ""
                    viewModel.searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        List(viewModel.searchResults) { poi in
            LocationRow(poi: poi, isSelected: selectedLocation?.id == poi.id)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedLocation = poi
                }
        }
        .listStyle(PlainListStyle())
    }

    // MARK: - Nearby Locations List

    private var nearbyLocationsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("附近地点")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            List(viewModel.nearbyLocations) { poi in
                LocationRow(poi: poi, isSelected: selectedLocation?.id == poi.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedLocation = poi
                    }
            }
            .listStyle(PlainListStyle())
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("没有找到相关地点")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Location Row
struct LocationRow: View {
    let poi: POI
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(poi.name)
                    .font(.headline)

                Text(poi.address)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)

                if let distanceText = poi.distanceText {
                    Text(distanceText)
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - ViewModel
@MainActor
final class LocationPickerViewModel: ObservableObject {

    @Published var searchKeyword = ""
    @Published var searchResults: [POI] = []
    @Published var nearbyLocations: [POI] = []
    @Published var isSearching = false

    private let mapService = AMapService.shared
    private let locationService = LocationService.shared
    private var searchTask: Task<Void, Never>?

    func search() {
        guard !searchKeyword.isEmpty else {
            searchResults = []
            return
        }

        // 取消之前的搜索任务
        searchTask?.cancel()

        // 延迟搜索（防抖）
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

            guard !Task.isCancelled else { return }

            isSearching = true

            do {
                let results = try await mapService.searchPOI(
                    keyword: searchKeyword,
                    city: "北京", // TODO: 根据当前位置获取城市
                    location: locationService.currentLocation?.coordinate
                )

                searchResults = results
            } catch {
                print("❌ 搜索失败: \(error)")
            }

            isSearching = false
        }
    }

    func loadNearbyLocations() {
        guard let location = locationService.currentLocation?.coordinate else {
            return
        }

        Task {
            do {
                let locations = try await mapService.searchNearby(
                    location: location,
                    radius: 2000
                )

                nearbyLocations = locations
            } catch {
                print("❌ 加载附近地点失败: \(error)")
            }
        }
    }
}

// MARK: - Preview
struct LocationPickerView_Previews: PreviewProvider {
    static var previews: some View {
        LocationPickerView(
            selectedLocation: .constant(nil),
            onConfirm: {}
        )
    }
}
