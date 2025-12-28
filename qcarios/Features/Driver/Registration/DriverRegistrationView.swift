//
//  DriverRegistrationView.swift
//  qcarios
//
//  司机注册页面
//

import SwiftUI

struct DriverRegistrationView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    // 表单字段
    @State private var realName = ""
    @State private var idCardNumber = ""
    @State private var driverLicenseNumber = ""
    @State private var drivingYears = ""
    @State private var serviceCity = "北京"

    let cities = ["北京", "上海", "广州", "深圳", "成都", "杭州", "武汉", "西安"]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("成为代驾司机")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("填写以下信息，我们将在1-3个工作日内审核")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }

                Section("基本信息") {
                    TextField("真实姓名", text: $realName)
                        .textContentType(.name)

                    TextField("身份证号", text: $idCardNumber)
                        .textContentType(.none)
                        .keyboardType(.numberPad)
                }

                Section("驾驶信息") {
                    TextField("驾驶证号", text: $driverLicenseNumber)
                        .textContentType(.none)

                    HStack {
                        Text("驾龄")
                        Spacer()
                        TextField("年", text: $drivingYears)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    Picker("服务城市", selection: $serviceCity) {
                        ForEach(cities, id: \.self) { city in
                            Text(city).tag(city)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("平台抽成：20%", systemImage: "percent")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Label("接单自由，随时上下线", systemImage: "clock")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Label("收入日结，提现快速", systemImage: "banknote")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("司机权益")
                }

                Section {
                    Button(action: submitRegistration) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isSubmitting ? "提交中..." : "提交申请")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid ? Color.green : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isSubmitting)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("司机注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("提交成功", isPresented: $showSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("您的申请已提交，我们将在1-3个工作日内完成审核，请耐心等待。")
            }
            .alert("提交失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !realName.isEmpty &&
        idCardNumber.count == 18 &&
        !driverLicenseNumber.isEmpty &&
        !drivingYears.isEmpty &&
        Int(drivingYears) != nil
    }

    // MARK: - Methods

    private func submitRegistration() {
        guard let userId = authService.currentUser?.id else { return }
        guard let years = Int(drivingYears) else { return }

        isSubmitting = true

        Task {
            do {
                // 1. 创建司机档案
                try await createDriverProfile(
                    userId: userId,
                    realName: realName,
                    idCardNumber: idCardNumber,
                    driverLicenseNumber: driverLicenseNumber,
                    drivingYears: years,
                    serviceCity: serviceCity
                )

                // 2. 更新用户角色为 both
                _ = try await authService.updateUserRole(.both)

                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSubmitting = false
                }
            }
        }
    }

    private func createDriverProfile(
        userId: UUID,
        realName: String,
        idCardNumber: String,
        driverLicenseNumber: String,
        drivingYears: Int,
        serviceCity: String
    ) async throws {
        let profileData: [String: Any] = [
            "user_id": userId.uuidString,
            "driver_license_number": driverLicenseNumber,
            "driving_years": drivingYears,
            "service_city": serviceCity,
            "online_status": "offline",
            "verification_status": "pending",
            "rating": 5.00,
            "total_orders": 0,
            "total_distance_km": 0
        ]

        let profileJson = try JSONSerialization.data(withJSONObject: profileData)

        let urlString = "\(SupabaseConfig.url)/rest/v1/driver_profiles"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "DriverRegistration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = profileJson

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ 创建司机档案失败: \(errorString)")
            }
            throw NSError(domain: "DriverRegistration", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "创建司机档案失败"])
        }

        // 同时更新用户的真实姓名和身份证
        let userUpdateData: [String: Any] = [
            "real_name": realName,
            "id_card_number": idCardNumber
        ]

        let userJson = try JSONSerialization.data(withJSONObject: userUpdateData)

        let userUrlString = "\(SupabaseConfig.url)/rest/v1/users?id=eq.\(userId.uuidString)"
        guard let userUrl = URL(string: userUrlString) else { return }

        var userRequest = URLRequest(url: userUrl)
        userRequest.httpMethod = "PATCH"
        userRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        userRequest.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        userRequest.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        userRequest.httpBody = userJson

        _ = try? await URLSession.shared.data(for: userRequest)
    }
}

// MARK: - Preview
struct DriverRegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        DriverRegistrationView()
    }
}
