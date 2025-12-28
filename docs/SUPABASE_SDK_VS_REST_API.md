# Supabase Swift SDK vs REST API 对比文档

## 概述

在 qcarios 项目开发过程中，我们遇到了使用 Supabase Swift SDK 时的 JSON 解析问题。本文档详细说明了两种方式的区别、优缺点，以及我们最终选择直接使用 REST API 的原因。

---

## 1. Supabase Swift SDK 方式

### 代码示例

```swift
// 使用 Supabase Swift SDK
let user: User = try await client
    .from(SupabaseConfig.Table.users)
    .insert(newUserJson)
    .select()
    .single()
    .execute()
    .value
```

### 优点

✅ **类型安全**
- SDK 提供强类型支持
- 编译时就能发现类型错误
- IDE 自动补全和类型提示

✅ **API 抽象**
- 隐藏底层 HTTP 请求细节
- 提供链式调用 API，代码简洁优雅
- 自动处理认证 token

✅ **官方支持**
- Supabase 官方维护
- 与 Supabase 服务紧密集成
- 定期更新和 bug 修复

✅ **功能完整**
- 支持实时订阅（Realtime）
- 支持存储（Storage）
- 支持边缘函数（Edge Functions）

### 缺点

❌ **调试困难**
- 错误信息不够详细
- 难以查看原始 HTTP 请求和响应
- JSON 解析错误难以定位

❌ **灵活性受限**
- 必须按照 SDK 的方式使用
- 自定义请求头或参数较困难
- 版本更新可能导致 API 变化

❌ **问题排查困难**
- 我们遇到的问题：
  ```
  Error Domain=NSCocoaErrorDomain Code=3840
  "JSON text did not start with array or object..."
  ```
- 无法看到实际的 HTTP 响应内容
- 不清楚是 SDK 的 bug 还是配置问题

### 使用场景

适合以下情况：
- 生产环境，需要稳定可靠的集成
- 需要使用 Realtime、Storage 等高级功能
- 团队熟悉 SDK，有相关经验
- 项目成熟，不需要频繁调试底层请求

---

## 2. 直接使用 REST API 方式

### 代码示例

```swift
// 直接使用 URLSession 调用 REST API
let urlString = "\(SupabaseConfig.url)/rest/v1/users"
guard let url = URL(string: urlString) else {
    throw AuthError.networkError
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "Authorization")
request.setValue("return=representation", forHTTPHeaderField: "Prefer")
request.httpBody = newUserJson

let (data, response) = try await URLSession.shared.data(for: request)

// 完全控制响应处理
if let httpResponse = response as? HTTPURLResponse {
    print("📡 HTTP状态码: \(httpResponse.statusCode)")

    if let responseString = String(data: data, encoding: .utf8) {
        print("📄 原始响应: \(responseString)")
    }
}

// 自定义解析
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let users: [User] = try decoder.decode([User].self, from: data)
```

### 优点

✅ **完全透明**
- 可以看到完整的 HTTP 请求和响应
- 便于调试和问题排查
- 响应数据完全可见

✅ **灵活控制**
- 自定义请求头
- 自定义错误处理
- 自定义 JSON 解析策略

✅ **调试友好**
- 可以打印原始响应
- 可以看到 HTTP 状态码
- 可以看到具体的错误消息

✅ **无依赖问题**
- 不依赖第三方 SDK 版本
- 不会因为 SDK 更新导致问题
- 使用 iOS 原生 URLSession

### 缺点

❌ **代码冗长**
- 需要手动构建请求
- 需要手动处理响应
- 代码量比 SDK 多

❌ **类型安全性低**
- 需要手动进行类型转换
- 运行时才能发现类型错误
- 需要更多的错误处理代码

❌ **功能受限**
- 不支持 Realtime 订阅（需要 WebSocket）
- 不支持 Storage 文件上传（需要额外实现）
- 需要手动实现 SDK 的高级功能

❌ **维护成本**
- Supabase API 变化需要手动更新
- 需要自己维护 API 文档
- 团队需要了解 Supabase REST API

### 使用场景

适合以下情况：
- 开发调试阶段，需要查看详细的请求响应
- 遇到 SDK 问题，需要绕过 SDK
- 需要特殊的请求配置
- 简单的 CRUD 操作，不需要高级功能

---

## 3. 我们遇到的具体问题

### 问题描述

使用 Supabase Swift SDK 插入用户数据时，总是抛出 JSON 解析错误：

```
❌ 未知错误: Error Domain=NSCocoaErrorDomain Code=3840
"JSON text did not start with array or object and option to allow fragments not set.
around line 1, column 0."
```

### 问题原因分析

1. **SDK 内部解析问题**
   - SDK 在 `.execute()` 时自动解析响应
   - 解析失败时只抛出 JSON 错误，不显示原始响应
   - 无法确定是服务器返回了错误，还是 SDK 解析出错

2. **调试困难**
   - 无法查看 HTTP 状态码
   - 无法查看原始响应内容
   - 无法判断是网络问题、服务器问题还是 SDK 问题

3. **可能的根本原因**
   - Supabase 可能返回了错误响应（4xx 或 5xx）
   - SDK 尝试将错误响应当作成功的 JSON 解析
   - RLS 策略问题导致服务器返回空响应

### 解决方案

切换到直接使用 REST API，这样可以：

1. ✅ 看到完整的 HTTP 响应
2. ✅ 看到具体的错误消息
3. ✅ 根据实际情况调整请求
4. ✅ 快速定位问题所在

---

## 4. 最佳实践建议

### 开发阶段

**推荐使用 REST API**

```swift
// 开发环境配置
#if DEBUG
// 使用 URLSession 直接调用，便于调试
let (data, response) = try await URLSession.shared.data(for: request)
print("📄 原始响应: \(String(data: data, encoding: .utf8) ?? "")")
#endif
```

**原因：**
- 问题排查更快
- 可以看到完整的请求响应
- 便于调整和优化

### 生产环境

**推荐使用 Supabase SDK**

```swift
// 生产环境配置
#if !DEBUG
// 使用 SDK，代码更简洁
let user: User = try await client
    .from("users")
    .insert(data)
    .select()
    .single()
    .execute()
    .value
#endif
```

**原因：**
- 官方支持，稳定可靠
- 代码简洁，易于维护
- 支持高级功能（Realtime, Storage 等）

### 混合方式

创建一个包装层，根据环境自动选择：

```swift
protocol DatabaseClient {
    func insert<T: Codable>(_ table: String, data: T) async throws -> T
    func query<T: Codable>(_ table: String, filters: [String: Any]) async throws -> [T]
}

class SupabaseDatabaseClient: DatabaseClient {
    #if DEBUG
    // 开发环境：使用 URLSession
    func insert<T: Codable>(_ table: String, data: T) async throws -> T {
        // URLSession 实现，带详细日志
    }
    #else
    // 生产环境：使用 SDK
    func insert<T: Codable>(_ table: String, data: T) async throws -> T {
        // SDK 实现
    }
    #endif
}
```

---

## 5. 性能对比

| 指标 | Supabase SDK | REST API (URLSession) |
|------|--------------|----------------------|
| 代码行数 | ⭐⭐⭐⭐⭐ (少) | ⭐⭐⭐ (多) |
| 类型安全 | ⭐⭐⭐⭐⭐ (高) | ⭐⭐⭐ (中) |
| 调试友好 | ⭐⭐ (差) | ⭐⭐⭐⭐⭐ (优) |
| 灵活性 | ⭐⭐⭐ (中) | ⭐⭐⭐⭐⭐ (高) |
| 学习曲线 | ⭐⭐⭐⭐ (简单) | ⭐⭐⭐ (中等) |
| 维护成本 | ⭐⭐⭐⭐⭐ (低) | ⭐⭐⭐ (中) |
| 功能完整性 | ⭐⭐⭐⭐⭐ (全) | ⭐⭐⭐ (基础) |

---

## 6. 结论

### 当前项目选择

在 qcarios 项目中，我们在 **开发环境** 使用直接的 REST API 调用（URLSession），原因是：

1. 遇到了 SDK 的 JSON 解析问题
2. 需要详细的日志来调试
3. 需要快速迭代和问题排查

### 未来规划

等问题排查清楚后，可以考虑：

1. **短期**：继续使用 REST API，确保稳定性
2. **中期**：创建包装层，统一接口
3. **长期**：切换回 Supabase SDK（如果问题已解决）

### 关键要点

> **记住：没有绝对的最佳方案，只有最适合当前场景的方案。**

- 开发调试 → REST API 更好
- 生产稳定 → SDK 更好
- 混合使用 → 最佳实践

---

## 7. 参考资源

- [Supabase REST API 文档](https://supabase.com/docs/guides/api)
- [Supabase Swift SDK](https://github.com/supabase-community/supabase-swift)
- [Apple URLSession 文档](https://developer.apple.com/documentation/foundation/urlsession)

---

**文档版本**: 1.0
**创建时间**: 2025-12-27
**最后更新**: 2025-12-27
**作者**: Claude Code & AI Team
