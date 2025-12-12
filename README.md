# qcarios - 代驾服务App

<div align="center">

🚗 一个完整的iOS代驾服务应用

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://www.apple.com/ios)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-green.svg)](https://supabase.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

## 📖 项目简介

qcarios是一个功能完整的代驾服务应用，提供乘客端和司机端的完整业务闭环：

**乘客端**：下单 → 匹配司机 → 实时追踪 → 支付 → 评价

**司机端**：接单 → 导航到上车点 → 行程服务 → 收益结算

**管理后台**：司机审核 → 订单管理 → 财务对账 → 数据分析

---

## ✨ 核心功能

### 🎯 V1 核心功能（MVP）

- ✅ 手机号登录/注册
- ✅ 地图定位与选点
- ✅ 订单创建与管理
- ✅ 司机接单
- ✅ 实时位置追踪
- ✅ 订单状态流转
- ✅ 支付集成
- ✅ 评价系统

### 🚀 V2 增值功能（规划中）

- 📱 预约订单
- 💰 优惠券系统
- 👥 会员体系
- 🎁 推荐奖励
- 📊 司机考核
- 🔔 推送通知
- 💬 即时通讯
- 🆘 紧急求助

---

## 🛠️ 技术栈

### 前端

- **框架**: SwiftUI + Combine
- **最低版本**: iOS 15.0+
- **语言**: Swift 5.9+
- **架构**: MVVM + Clean Architecture

### 后端服务

- **BaaS**: Supabase
- **数据库**: PostgreSQL + PostGIS
- **实时通信**: Supabase Realtime
- **存储**: Supabase Storage
- **认证**: Supabase Auth

### 第三方服务

- **地图**: 高德地图SDK
- **支付**: 微信支付 / 支付宝
- **推送**: APNs / 极光推送

---

## 📂 项目结构

```
qcarios/
├── qcarios/                      # 主项目
│   ├── App/                      # 应用入口
│   │   ├── qcariosApp.swift
│   │   └── AppDelegate.swift
│   ├── Core/                     # 核心功能
│   │   ├── Database/             # 数据库层
│   │   │   ├── SupabaseClient.swift
│   │   │   ├── SupabaseConfig.swift
│   │   │   └── Repositories/     # Repository层
│   │   │       ├── OrderRepository.swift
│   │   │       ├── UserRepository.swift
│   │   │       └── DriverRepository.swift
│   │   ├── Network/              # 网络层
│   │   └── Utils/                # 工具类
│   ├── Features/                 # 功能模块
│   │   ├── Auth/                 # 认证模块
│   │   ├── Passenger/            # 乘客端
│   │   │   ├── Home/
│   │   │   ├── Order/
│   │   │   └── Profile/
│   │   └── Driver/               # 司机端
│   │       ├── Orders/
│   │       ├── Navigation/
│   │       └── Earnings/
│   ├── Shared/                   # 共享资源
│   │   ├── Components/           # UI组件
│   │   ├── Models/               # 数据模型
│   │   │   ├── User.swift
│   │   │   ├── Order.swift
│   │   │   └── Driver.swift
│   │   └── Services/             # 共享服务
│   └── Resources/                # 资源文件
├── supabase/                     # Supabase配置
│   └── migrations/               # 数据库迁移
│       ├── 00001_initial_schema.sql
│       └── 00002_row_level_security.sql
├── docs/                         # 项目文档
│   ├── QUICK_START.md           # 快速开始
│   ├── SUPABASE_SETUP.md        # Supabase配置
│   └── DATABASE_SCHEMA.md       # 数据库设计
├── Podfile                       # CocoaPods依赖
├── .env.example                  # 环境变量示例
└── README.md                     # 项目说明
```

---

## 🚀 快速开始

### 1. 环境准备

```bash
# 确保已安装
- Xcode 15.0+
- CocoaPods 1.12+
```

### 2. 安装依赖

```bash
cd /Users/ai/Desktop/qcarios
pod install
```

### 3. 配置后端服务

详细步骤见：[Supabase配置指南](docs/SUPABASE_SETUP.md)

**快速配置**：

1. 创建Supabase项目
2. 执行数据库迁移脚本
3. 配置API密钥到Info.plist
4. 申请高德地图Key

### 4. 运行项目

```bash
open qcarios.xcworkspace
# 选择模拟器并运行（⌘R）
```

完整指南：[快速开始文档](docs/QUICK_START.md)

---

## 📊 数据库设计

### 核心数据表

| 表名 | 说明 | 记录数估算 |
|------|------|-----------|
| users | 用户基础信息 | 10万+ |
| driver_profiles | 司机详细信息 | 2万+ |
| orders | 订单记录 | 100万+ |
| location_tracking | 位置轨迹 | 1000万+ |
| payments | 支付记录 | 100万+ |
| reviews | 评价记录 | 50万+ |

详细设计：[数据库架构文档](docs/DATABASE_SCHEMA.md)

### ER图

```
Users ─┬─► Passenger Profiles
       └─► Driver Profiles ─┬─► Orders ─┬─► Payments
                            │           ├─► Reviews
                            │           └─► Complaints
                            └─► Location Tracking
```

---

## 🎨 架构设计

### MVVM + Clean Architecture

```
┌─────────────────────────────────────────┐
│              View (SwiftUI)              │
└─────────────────┬───────────────────────┘
                  │ Binding
┌─────────────────▼───────────────────────┐
│    ViewModel (ObservableObject)         │
└─────────────────┬───────────────────────┘
                  │ Use Cases
┌─────────────────▼───────────────────────┐
│         Repository (Protocol)            │
└─────────────────┬───────────────────────┘
                  │ Data Operations
┌─────────────────▼───────────────────────┐
│  DataSource (Supabase/Local Storage)    │
└─────────────────────────────────────────┘
```

### Repository模式示例

```swift
// Protocol定义
protocol OrderRepositoryProtocol {
    func createOrder(_ request: CreateOrderRequest) async throws -> Order
    func getOrder(id: UUID) async throws -> Order
    func updateOrderStatus(id: UUID, status: OrderStatus) async throws -> Order
}

// 实现
final class OrderRepository: OrderRepositoryProtocol {
    private let client = SupabaseClient.shared.client

    func createOrder(_ request: CreateOrderRequest) async throws -> Order {
        // Supabase数据库操作
    }
}
```

---

## 🔐 安全策略

### Row Level Security (RLS)

所有数据表启用RLS，确保：

- ✅ 用户只能访问自己的数据
- ✅ 订单相关方可以查看订单详情
- ✅ 司机位置仅在行程中可见
- ✅ 财务数据严格权限控制

### 数据加密

- ✅ HTTPS传输加密
- ✅ 敏感信息脱敏（手机号、身份证）
- ✅ API密钥环境变量管理

---

## 📈 开发路线图

### ✅ 已完成

- [x] 项目初始化
- [x] Supabase数据库设计
- [x] 数据表创建（13张表）
- [x] RLS安全策略配置
- [x] Swift数据模型定义
- [x] Repository层实现
- [x] 项目文档编写

### 🚧 进行中（阶段一：MVP - 2-3周）

- [ ] 认证模块（手机号登录）
- [ ] 地图功能集成（高德SDK）
- [ ] 乘客端订单创建
- [ ] 司机端订单接收
- [ ] 实时位置上报

### 📅 计划中

**阶段二**：核心功能完善（3-4周）
- [ ] 价格计费系统
- [ ] 支付集成
- [ ] 导航功能
- [ ] 评价系统

**阶段三**：体验优化（2-3周）
- [ ] UI/UX优化
- [ ] 异常处理
- [ ] 推送通知

**阶段四**：高级功能（3-4周）
- [ ] 预约订单
- [ ] 派单算法
- [ ] 安全功能

**阶段五**：运营功能（2-3周）
- [ ] 管理后台
- [ ] 财务对账
- [ ] 数据统计

**阶段六**：V2功能（按需）
- [ ] 优惠券系统
- [ ] 会员体系
- [ ] 推荐奖励

---

## 🧪 测试

### 单元测试（计划）

```bash
# 运行测试
⌘U in Xcode
```

### 集成测试（计划）

- API接口测试
- 数据库操作测试
- 业务流程测试

---

## 📝 开发规范

### 代码规范

- 遵循Swift官方API设计指南
- 使用SwiftLint（可选）
- 清晰的命名和注释

### Git提交规范

```bash
feat: 新功能
fix: 修复bug
docs: 文档更新
style: 代码格式
refactor: 重构
test: 测试相关
chore: 构建/工具变更
```

### 分支策略

```
main (主分支)
  ├── develop (开发分支)
  │   ├── feature/xxx (功能分支)
  │   └── bugfix/xxx (修复分支)
  └── release/vx.x.x (发布分支)
```

---

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'feat: Add AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交Pull Request

---

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 📞 联系方式

- 项目主页：[GitHub](https://github.com/yourusername/qcarios)
- 问题反馈：[Issues](https://github.com/yourusername/qcarios/issues)
- 邮箱：your.email@example.com

---

## 🙏 致谢

- [Supabase](https://supabase.com) - 强大的后端服务
- [高德地图](https://lbs.amap.com/) - 地图与定位服务
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - 现代化UI框架

---

## 📚 相关文档

- [快速开始](docs/QUICK_START.md)
- [Supabase配置](docs/SUPABASE_SETUP.md)
- [数据库设计](docs/DATABASE_SCHEMA.md)
- [开发路线图](docs/ROADMAP.md)（待创建）
- [API文档](docs/API.md)（待创建）

---

<div align="center">

**⭐ 如果这个项目对您有帮助，请给我们一个Star！ ⭐**

Made with ❤️ by qcarios Team

</div>
