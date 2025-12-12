# 配置检查清单

使用此清单确保所有必要的配置都已正确完成。

## ✅ 环境准备

- [ ] macOS 13.0+ 已安装
- [ ] Xcode 15.0+ 已安装
- [ ] CocoaPods 已安装
  ```bash
  sudo gem install cocoapods
  ```

---

## ✅ 账号注册

- [ ] Supabase账号已注册
  - 访问：https://supabase.com
  - 邮箱：________________
  - 密码：已保存到密码管理器

- [ ] 高德开放平台账号已注册
  - 访问：https://lbs.amap.com/
  - 账号：________________
  - 密码：已保存到密码管理器

- [ ] 微信开放平台账号（支付用，可后期配置）
  - [ ] 已注册
  - [ ] 已创建应用

- [ ] 支付宝开放平台账号（支付用，可后期配置）
  - [ ] 已注册
  - [ ] 已创建应用

---

## ✅ Supabase配置

### 项目创建

- [ ] Supabase项目已创建
  - 项目名称：________________
  - 区域：________________
  - 数据库密码：已保存

### API密钥

- [ ] Project URL已获取
  ```
  https://________________.supabase.co
  ```

- [ ] Anon Key已获取
  ```
  eyJhbGc________________
  ```

- [ ] Service Role Key已获取（仅后端使用）
  ```
  eyJhbGc________________
  ```

### 数据库初始化

- [ ] 执行了 `00001_initial_schema.sql`
  - 方式：SQL Editor / Supabase CLI
  - 状态：Success

- [ ] 执行了 `00002_row_level_security.sql`
  - 方式：SQL Editor / Supabase CLI
  - 状态：Success

### 数据表验证

访问 Database → Tables，确认以下表存在：

- [ ] users
- [ ] passenger_profiles
- [ ] driver_profiles
- [ ] orders
- [ ] location_tracking
- [ ] payments
- [ ] driver_earnings
- [ ] reviews
- [ ] complaints
- [ ] coupons
- [ ] user_coupons
- [ ] notifications
- [ ] pricing_rules

### 初始数据验证

- [ ] pricing_rules表有数据
  - 查询：`SELECT * FROM pricing_rules LIMIT 5;`
  - 应该返回：BJ、SH、GZ、SZ等城市的计价规则

### PostGIS扩展

- [ ] PostGIS已启用
  - 查询：`SELECT PostGIS_Version();`
  - 应该返回：版本信息（如 3.3 USE_GEOS=1...）

### Realtime配置

- [ ] orders表Realtime已启用
  - Database → Replication → orders → 勾选启用

- [ ] location_tracking表Realtime已启用
  - Database → Replication → location_tracking → 勾选启用

### Storage Buckets（可选，后期配置）

- [ ] avatars bucket已创建（Public）
- [ ] id_cards bucket已创建（Private）
- [ ] driver_licenses bucket已创建（Private）
- [ ] review_images bucket已创建（Public）
- [ ] complaint_images bucket已创建（Private）

---

## ✅ 高德地图配置

### 应用创建

- [ ] 高德开放平台应用已创建
  - 应用名称：________________
  - 应用类型：iOS

### iOS Key配置

- [ ] iOS Key已获取
  ```
  ________________
  ```

- [ ] Bundle ID已正确配置
  - 在高德平台配置的Bundle ID：________________
  - 项目实际Bundle ID：________________
  - ⚠️ 两者必须一致！

### SDK功能申请（根据需要）

- [ ] 地图SDK
- [ ] 搜索SDK
- [ ] 导航SDK
- [ ] 定位SDK

---

## ✅ iOS项目配置

### 依赖安装

- [ ] 执行了 `pod install`
  ```bash
  cd /Users/ai/Desktop/qcarios
  pod install
  ```

- [ ] 依赖安装成功
  - Supabase SDK
  - AMap相关SDK

### 环境变量配置

**方式A: Info.plist（推荐）**

- [ ] 打开 qcarios.xcworkspace
- [ ] 选择 qcarios target → Info
- [ ] 添加以下Key：

| Key | Value | 状态 |
|-----|-------|------|
| SUPABASE_URL | https://xxx.supabase.co | [ ] |
| SUPABASE_ANON_KEY | eyJhbGc... | [ ] |
| AMAP_IOS_KEY | your-amap-key | [ ] |

**方式B: .env文件（可选）**

- [ ] 复制了 `.env.example` 为 `.env`
- [ ] 填写了所有必要配置
- [ ] 确认 `.env` 在 `.gitignore` 中

### Bundle Identifier

- [ ] Bundle ID已正确设置
  - 推荐格式：com.yourcompany.qcarios
  - 当前值：________________

### Info.plist权限配置

- [ ] 位置权限描述已添加
  ```xml
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>需要获取您的位置信息以提供代驾服务</string>

  <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
  <string>需要持续获取位置以追踪行程</string>
  ```

- [ ] 相机权限（用于拍摄证件，可后期添加）
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>需要使用相机拍摄证件照片</string>
  ```

- [ ] 相册权限（可后期添加）
  ```xml
  <key>NSPhotoLibraryUsageDescription</key>
  <string>需要访问相册选择图片</string>
  ```

---

## ✅ 代码验证

### Supabase连接测试

- [ ] 创建了测试页面
- [ ] 运行测试代码
- [ ] 连接成功

测试代码：
```swift
let client = SupabaseClient.shared.client
let response = try await client.database
    .from("pricing_rules")
    .select()
    .limit(1)
    .execute()
```

### 配置验证函数

- [ ] 运行配置验证
  ```swift
  let validation = SupabaseConfig.detailedValidation()
  print("Is Valid: \(validation.isValid)")
  print("Missing: \(validation.missingKeys)")
  print("Warnings: \(validation.warnings)")
  ```

- [ ] 结果：
  - isValid: true
  - missingKeys: []
  - warnings: []

---

## ✅ 编译与运行

### 编译检查

- [ ] Clean Build Folder (⇧⌘K)
- [ ] Build项目 (⌘B)
- [ ] 无编译错误
- [ ] 无编译警告（或警告已知且可接受）

### 运行测试

- [ ] 选择模拟器（推荐：iPhone 15 Pro）
- [ ] 运行项目 (⌘R)
- [ ] 应用成功启动
- [ ] 无运行时崩溃

### 日志检查

控制台应该看到：

- [ ] `✅ Supabase Client initialized: https://xxx.supabase.co`
- [ ] `✅ Supabase configuration validated`
- [ ] 无错误日志

---

## ✅ Git配置

### 版本控制

- [ ] Git仓库已初始化
  ```bash
  git init
  ```

- [ ] .gitignore已配置
  - [ ] .env文件被忽略
  - [ ] Pods/目录被忽略
  - [ ] xcuserdata被忽略

- [ ] 首次提交已完成
  ```bash
  git add .
  git commit -m "Initial commit"
  ```

### 远程仓库（可选）

- [ ] GitHub/GitLab仓库已创建
- [ ] 远程仓库已添加
  ```bash
  git remote add origin https://github.com/yourname/qcarios.git
  ```

- [ ] 代码已推送
  ```bash
  git push -u origin main
  ```

---

## ✅ 团队协作（多人开发）

### 文档共享

- [ ] 团队成员能访问项目文档
- [ ] 配置密钥已通过安全方式共享（如1Password）
- [ ] ⚠️ 密钥不能通过IM/邮件明文发送

### 开发环境统一

- [ ] 团队使用相同的Xcode版本
- [ ] 团队使用相同的Swift版本
- [ ] 团队使用相同的依赖版本（Podfile.lock已提交）

---

## ✅ 下一步开发准备

### 开发工具（可选）

- [ ] Charles/Proxyman（抓包工具）
- [ ] Postman（API测试）
- [ ] Sourcetree/Fork（Git GUI）
- [ ] SF Symbols（图标资源）

### 设计资源

- [ ] UI设计稿已准备（Figma/Sketch）
- [ ] App图标已设计
- [ ] 启动页已设计
- [ ] 品牌色彩已确定

### 第三方服务准备（后期）

- [ ] 短信服务商（阿里云/腾讯云）
- [ ] 推送服务（极光/个推）
- [ ] 监控服务（Sentry/Firebase Crashlytics）

---

## 📋 配置完成度

统计一下您的完成情况：

- 必须项（⭐）：______ / ______
- 可选项：______ / ______

### 准备开始开发？

如果所有⭐必须项都已完成，恭喜您可以开始开发了！🎉

下一步：
1. 查看 [开发路线图](../README.md#-开发路线图)
2. 开始实现 **阶段一：认证模块**
3. 参考 [快速开始文档](./QUICK_START.md)

---

## 🐛 遇到问题？

### 常见问题排查

1. **配置不生效**
   - Clean Build Folder
   - 删除DerivedData
   - 重新pod install

2. **Supabase连接失败**
   - 检查网络连接
   - 确认URL和Key正确
   - 查看Supabase项目状态

3. **地图不显示**
   - 确认Key正确
   - 检查Bundle ID匹配
   - 查看控制台错误日志

### 获取帮助

- 📖 查看项目文档
- 🔍 搜索GitHub Issues
- 💬 联系团队成员
- 📧 发送问题到：your.email@example.com

---

**最后更新**：2025-12-12

---

## ✍️ 签名确认

完成所有配置后，请在此签名：

- 配置人：________________
- 完成日期：________________
- 配置完成度：______%
- 备注：________________

---

祝开发顺利！🚀
