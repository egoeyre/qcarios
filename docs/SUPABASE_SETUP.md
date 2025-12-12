# Supabase配置指南

本文档介绍如何配置和使用Supabase作为qcarios代驾App的后端服务。

## 📋 目录

- [创建Supabase项目](#创建supabase项目)
- [数据库初始化](#数据库初始化)
- [iOS项目配置](#ios项目配置)
- [测试连接](#测试连接)
- [常见问题](#常见问题)

---

## 🚀 创建Supabase项目

### 1. 注册Supabase账号

访问 [supabase.com](https://supabase.com) 并注册账号。

### 2. 创建新项目

1. 点击 "New Project"
2. 填写项目信息：
   - **Name**: qcarios (或任意名称)
   - **Database Password**: 设置一个强密码（请妥善保管）
   - **Region**: 选择离你最近的区域（如：Northeast Asia (Seoul)）
   - **Pricing Plan**: 选择 Free 或 Pro（根据需求）
3. 点击 "Create new project"
4. 等待项目初始化（约2分钟）

### 3. 获取API密钥

项目创建完成后：

1. 进入项目 Dashboard
2. 点击左侧菜单 "Settings" → "API"
3. 复制以下信息：
   - **Project URL**: `https://xxxxxxxxxxxxx.supabase.co`
   - **anon public key**: `eyJhbGc...` (用于客户端)
   - **service_role key**: `eyJhbGc...` (仅用于服务端，不要泄露)

---

## 🗄️ 数据库初始化

### 方式一：使用SQL编辑器（推荐）

1. 在Supabase Dashboard中，点击左侧菜单 "SQL Editor"
2. 点击 "New query"
3. 复制 `supabase/migrations/00001_initial_schema.sql` 文件的全部内容
4. 粘贴到SQL编辑器中
5. 点击 "Run" 执行
6. 等待执行完成（应该显示 "Success"）

7. 重复步骤2-5，执行 `supabase/migrations/00002_row_level_security.sql`

### 方式二：使用Supabase CLI

如果你已经安装了Supabase CLI：

```bash
# 登录
supabase login

# 链接到你的项目
supabase link --project-ref your-project-id

# 运行迁移
supabase db push
```

### 验证数据库

执行完成后，检查：

1. 点击左侧菜单 "Database" → "Tables"
2. 确认以下表已创建：
   - ✅ users
   - ✅ passenger_profiles
   - ✅ driver_profiles
   - ✅ orders
   - ✅ location_tracking
   - ✅ payments
   - ✅ driver_earnings
   - ✅ reviews
   - ✅ complaints
   - ✅ coupons
   - ✅ user_coupons
   - ✅ notifications
   - ✅ pricing_rules

3. 检查 `pricing_rules` 表中是否有初始数据：
   - 点击表名，查看是否有北京、上海等城市的计价规则

---

## 📱 iOS项目配置

### 1. 安装Supabase SDK

项目已经配置了 `Podfile`，执行：

```bash
cd /Users/ai/Desktop/qcarios
pod install
```

### 2. 配置API密钥

#### 方法A：使用Info.plist（推荐用于开发）

1. 打开 `qcarios.xcworkspace`
2. 选择 `qcarios` target
3. 选择 "Info" tab
4. 添加以下键值对：

| Key | Type | Value |
|-----|------|-------|
| SUPABASE_URL | String | https://xxxxx.supabase.co |
| SUPABASE_ANON_KEY | String | eyJhbGc... |

#### 方法B：使用环境变量（推荐用于生产）

1. 复制 `.env.example` 为 `.env`：
   ```bash
   cp .env.example .env
   ```

2. 编辑 `.env` 文件，填入你的配置：
   ```
   SUPABASE_URL=https://xxxxxxxxxxxxx.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJI...
   ```

3. 在Xcode中配置环境变量：
   - Product → Scheme → Edit Scheme...
   - Run → Arguments → Environment Variables
   - 添加 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY`

⚠️ **重要**：不要将 `.env` 文件提交到Git！已经在 `.gitignore` 中排除。

### 3. 验证配置

在 `AppDelegate` 或 `App` 入口处添加验证代码：

```swift
import SwiftUI

@main
struct qcariosApp: App {
    init() {
        // 验证Supabase配置
        let validation = SupabaseConfig.detailedValidation()
        if !validation.isValid {
            print("❌ Supabase配置不完整:")
            print("缺失: \(validation.missingKeys)")
        }

        if !validation.warnings.isEmpty {
            print("⚠️ 警告: \(validation.warnings)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

## 🧪 测试连接

### 测试1：基本连接

在任意ViewController或SwiftUI View中：

```swift
import SwiftUI

struct TestSupabaseView: View {
    @State private var isConnected = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            if isConnected {
                Text("✅ Supabase连接成功")
                    .foregroundColor(.green)
            } else if let error = errorMessage {
                Text("❌ 连接失败: \(error)")
                    .foregroundColor(.red)
            }

            Button("测试连接") {
                testConnection()
            }
        }
        .padding()
    }

    func testConnection() {
        Task {
            do {
                // 测试查询pricing_rules表
                let client = SupabaseClient.shared.client
                let response = try await client.database
                    .from("pricing_rules")
                    .select()
                    .limit(1)
                    .execute()

                await MainActor.run {
                    isConnected = true
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    isConnected = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
```

### 测试2：用户注册

```swift
func testUserRegistration() async {
    do {
        let client = SupabaseClient.shared.client

        // 测试手机号注册
        let phone = "+86138000138\(Int.random(in: 10000...99999))"

        // 这里需要先实现认证逻辑
        // Supabase Auth支持多种方式，包括手机号

        print("✅ 测试通过")
    } catch {
        print("❌ 测试失败: \(error)")
    }
}
```

---

## 🔒 安全配置

### Row Level Security (RLS)

项目已经配置了完整的RLS策略，确保：

- ✅ 用户只能查看自己的数据
- ✅ 乘客和司机可以查看订单相关的对方信息
- ✅ 司机可以查看待接单订单
- ✅ 敏感数据受保护

### 验证RLS

在Supabase Dashboard中：

1. 点击 "Database" → "Tables"
2. 选择任意表（如 `users`）
3. 点击右上角的盾牌图标 🛡️
4. 确认 "Enable RLS" 已开启
5. 查看配置的策略列表

---

## 🌍 配置PostGIS（地理位置功能）

PostGIS扩展已在迁移脚本中自动启用。验证方法：

```sql
-- 在SQL Editor中运行
SELECT PostGIS_Version();
```

应该返回版本信息，如：`3.3 USE_GEOS=1 USE_PROJ=1...`

---

## 📊 配置Realtime（实时订阅）

### 启用Realtime

1. 在Supabase Dashboard中，点击 "Database" → "Replication"
2. 找到 `orders` 和 `location_tracking` 表
3. 勾选启用 Realtime

### 测试Realtime

```swift
func testRealtimeSubscription() {
    let client = SupabaseClient.shared.client

    let channel = client.realtime.channel("test-channel")

    channel
        .on("postgres_changes", filter: ChannelFilter(
            event: "INSERT",
            schema: "public",
            table: "orders"
        )) { message in
            print("📨 收到新订单: \(message)")
        }
        .subscribe()
}
```

---

## 🗂️ 配置Storage（文件存储）

### 创建Storage Buckets

1. 点击左侧菜单 "Storage"
2. 创建以下Buckets：

| Bucket名称 | 公开 | 说明 |
|-----------|------|------|
| avatars | ✅ Public | 用户头像 |
| id_cards | ❌ Private | 身份证照片 |
| driver_licenses | ❌ Private | 驾驶证照片 |
| review_images | ✅ Public | 评价图片 |
| complaint_images | ❌ Private | 投诉图片 |

### 配置Storage策略

示例（avatars bucket）：

```sql
-- 允许认证用户上传自己的头像
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 允许所有人读取头像
CREATE POLICY "Public can view avatars"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');
```

---

## 🔍 常见问题

### Q1: 连接超时

**问题**：请求一直挂起，无法连接到Supabase

**解决**：
1. 检查网络连接
2. 确认Supabase项目状态（是否暂停）
3. 检查URL是否正确（不要有多余空格）

### Q2: API Key无效

**问题**：401 Unauthorized 错误

**解决**：
1. 确认使用的是 `anon key`，不是 `service_role key`
2. 检查密钥是否完整（没有被截断）
3. 重新复制密钥（可能复制时有换行符）

### Q3: RLS阻止查询

**问题**：查询返回空结果，但数据确实存在

**解决**：
1. 确认用户已登录（`auth.uid()` 不为空）
2. 检查RLS策略是否正确
3. 暂时禁用RLS测试（仅开发环境）

### Q4: Realtime不工作

**问题**：订阅后没有收到更新

**解决**：
1. 确认表已启用 Replication
2. 检查订阅的filter是否正确
3. 查看Supabase Dashboard中的日志

### Q5: PostGIS函数错误

**问题**：调用 `find_nearby_drivers` 等函数失败

**解决**：
1. 确认PostGIS扩展已安装
2. 检查函数是否已创建（在SQL Editor中运行迁移脚本）
3. 查看错误日志确定具体问题

---

## 📚 参考资源

- [Supabase官方文档](https://supabase.com/docs)
- [Supabase Swift SDK](https://github.com/supabase-community/supabase-swift)
- [PostGIS文档](https://postgis.net/documentation/)
- [Row Level Security指南](https://supabase.com/docs/guides/auth/row-level-security)

---

## 🎯 下一步

配置完成后，您可以：

1. ✅ 开始实现认证功能（手机号登录）
2. ✅ 集成高德地图SDK
3. ✅ 开发乘客端首页
4. ✅ 实现订单创建流程

有问题请查看项目文档或提issue。
