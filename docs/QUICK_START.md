# 快速开始指南

本指南帮助您快速配置并运行qcarios代驾App项目。

## ✅ 前置要求

### 开发环境

- macOS 13.0+
- Xcode 15.0+
- CocoaPods 1.12+
- 注册以下服务账号：
  - [Supabase](https://supabase.com)（后端服务）
  - [高德开放平台](https://lbs.amap.com/)（地图服务）

### 技能要求

- Swift 5.9+
- SwiftUI基础
- 基本的SQL知识

---

## 🚀 5分钟快速启动

### Step 1: 克隆项目

```bash
cd /Users/ai/Desktop/qcarios
```

### Step 2: 安装依赖

```bash
# 安装CocoaPods依赖
pod install

# 如果没有安装CocoaPods
# sudo gem install cocoapods
```

### Step 3: 配置Supabase

#### 3.1 创建Supabase项目

1. 访问 [supabase.com](https://supabase.com)
2. 创建新项目
3. 记录以下信息：
   - Project URL: `https://xxxxx.supabase.co`
   - Anon Key: `eyJhbGc...`

#### 3.2 初始化数据库

1. 在Supabase Dashboard中，打开 SQL Editor
2. 执行 `supabase/migrations/00001_initial_schema.sql`
3. 执行 `supabase/migrations/00002_row_level_security.sql`

详细步骤见：[SUPABASE_SETUP.md](./SUPABASE_SETUP.md)

#### 3.3 配置密钥

方式A：修改Info.plist（推荐）

1. 打开 `qcarios.xcworkspace`
2. 选择 qcarios target → Info
3. 添加：
   - Key: `SUPABASE_URL`, Value: `https://xxxxx.supabase.co`
   - Key: `SUPABASE_ANON_KEY`, Value: `your-anon-key`

方式B：使用.env文件

```bash
cp .env.example .env
# 编辑.env文件，填入你的配置
```

### Step 4: 配置高德地图

#### 4.1 申请高德Key

1. 访问 [高德开放平台](https://lbs.amap.com/)
2. 注册并创建应用
3. 添加iOS平台密钥
4. 记录 `iOS Key`

#### 4.2 配置到项目

在Info.plist中添加：
- Key: `AMAP_IOS_KEY`, Value: `your-amap-ios-key`

### Step 5: 运行项目

```bash
# 打开工作空间（注意是.xcworkspace）
open qcarios.xcworkspace

# 或在Xcode中：
# 1. 选择模拟器（iPhone 15 Pro推荐）
# 2. 点击Run（⌘R）
```

---

## 📁 项目结构

```
qcarios/
├── qcarios/
│   ├── App/                    # 应用入口
│   ├── Core/                   # 核心功能
│   │   ├── Database/          # Supabase配置
│   │   │   ├── SupabaseClient.swift
│   │   │   ├── SupabaseConfig.swift
│   │   │   └── Repositories/  # 数据访问层
│   │   ├── Network/           # 网络层
│   │   └── Utils/             # 工具类
│   ├── Features/              # 功能模块
│   │   ├── Auth/              # 认证
│   │   ├── Passenger/         # 乘客端
│   │   └── Driver/            # 司机端
│   ├── Shared/                # 共享资源
│   │   ├── Components/        # UI组件
│   │   ├── Models/            # 数据模型
│   │   │   ├── User.swift
│   │   │   ├── Order.swift
│   │   │   └── Driver.swift
│   │   └── Services/          # 共享服务
│   └── Resources/             # 资源文件
├── supabase/
│   └── migrations/            # 数据库迁移脚本
├── docs/                      # 文档
├── Podfile                    # CocoaPods配置
└── .env.example              # 环境变量示例
```

---

## 🧪 验证安装

### 测试1: Supabase连接

在任意View中添加：

```swift
import SwiftUI

struct TestView: View {
    @State private var connectionStatus = "未测试"

    var body: some View {
        VStack(spacing: 20) {
            Text("Supabase连接状态")
                .font(.headline)

            Text(connectionStatus)
                .foregroundColor(connectionStatus == "✅ 连接成功" ? .green : .red)

            Button("测试连接") {
                testSupabase()
            }
        }
        .padding()
    }

    func testSupabase() {
        Task {
            do {
                let client = SupabaseClient.shared.client
                let response = try await client.database
                    .from("pricing_rules")
                    .select()
                    .limit(1)
                    .execute()

                await MainActor.run {
                    connectionStatus = "✅ 连接成功"
                }
            } catch {
                await MainActor.run {
                    connectionStatus = "❌ 连接失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
```

### 测试2: 数据表验证

在Supabase Dashboard中检查：

1. Database → Tables
2. 确认有13个表：
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

3. 检查pricing_rules表中有初始数据（BJ、SH等城市）

---

## 🎯 下一步开发

现在您已完成基础配置，可以开始开发核心功能：

### 阶段一：认证模块（1周）

```
[ ] 手机号登录页面
[ ] 验证码验证
[ ] 角色选择（乘客/司机）
[ ] Supabase Auth集成
```

### 阶段二：乘客端基础（2周）

```
[ ] 地图主页（显示当前位置）
[ ] 起终点选择
[ ] 创建订单
[ ] 订单列表
```

### 阶段三：司机端基础（2周）

```
[ ] 订单列表
[ ] 接单功能
[ ] 位置上报
[ ] 订单状态更新
```

### 阶段四：实时功能（1周）

```
[ ] Realtime订阅订单状态
[ ] 实时位置显示
[ ] 推送通知
```

---

## 📚 参考文档

项目文档：

- [开发路线图](../README.md) - 完整开发计划
- [数据库架构](./DATABASE_SCHEMA.md) - 数据表详细说明
- [Supabase配置](./SUPABASE_SETUP.md) - 详细配置指南

外部资源：

- [Supabase文档](https://supabase.com/docs)
- [高德地图iOS SDK](https://lbs.amap.com/api/ios-sdk/summary)
- [SwiftUI官方教程](https://developer.apple.com/tutorials/swiftui)

---

## 🐛 常见问题

### Q1: Pod install失败

**错误**：`Unable to find a specification for 'Supabase'`

**解决**：
```bash
pod repo update
pod install
```

### Q2: Xcode编译错误

**错误**：`No such module 'Supabase'`

**解决**：
1. 确保打开的是 `.xcworkspace` 而不是 `.xcodeproj`
2. Clean Build Folder (⇧⌘K)
3. 重新build

### Q3: Supabase配置未找到

**错误**：`Configuration value for SUPABASE_URL not found`

**解决**：
1. 检查Info.plist中是否添加了配置
2. 确认密钥没有多余空格
3. Clean并重新运行

### Q4: 高德地图不显示

**解决**：
1. 检查AMAP_IOS_KEY是否正确
2. 确认Bundle ID与高德平台配置一致
3. 添加位置权限到Info.plist

---

## 💡 开发建议

### 代码规范

1. 使用SwiftLint（可选）
2. 遵循Swift API设计指南
3. 写清晰的注释

### Git工作流

```bash
# 功能开发
git checkout -b feature/user-authentication
# 开发完成后
git add .
git commit -m "feat: 实现手机号登录功能"
git push origin feature/user-authentication
```

### 调试技巧

1. 使用Xcode的Instruments分析性能
2. 打开Supabase Dashboard的日志查看数据库查询
3. 使用Charles抓包调试网络请求

---

## 🆘 获取帮助

遇到问题？

1. 查看项目文档（docs/目录）
2. 搜索GitHub Issues
3. 查阅Supabase官方文档
4. 联系团队成员

---

## ✨ 开始编码！

现在所有配置已完成，开始构建您的代驾App吧！🚗

祝开发顺利！ 🎉
