# 下一步操作指南

现在所有核心代码已经完成！按照以下步骤完成配置并运行项目。

---

## ✅ 立即执行（必须）

### 1. 安装依赖

```bash
cd /Users/ai/Desktop/qcarios
pod install
```

**预期输出**:
```
Analyzing dependencies
Downloading dependencies
Installing Supabase (2.x.x)
Installing AMapFoundation-NO-IDFA (1.7.0)
Installing AMap3DMap-NO-IDFA (9.7.0)
...
Pod installation complete!
```

### 2. 打开项目

⚠️ **重要**：必须打开 `.xcworkspace` 文件，不是 `.xcodeproj`！

```bash
open qcarios.xcworkspace
```

### 3. 配置Supabase

#### 3.1 创建项目
1. 访问 https://supabase.com
2. 点击 "New Project"
3. 填写信息：
   - Name: qcarios
   - Database Password: （设置强密码）
   - Region: Northeast Asia (Seoul)
4. 等待2分钟创建完成

#### 3.2 获取密钥
1. 进入项目Dashboard
2. Settings → API
3. 复制：
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon public key**: `eyJhbGc...`

#### 3.3 初始化数据库
1. 在Dashboard中，点击 "SQL Editor"
2. 点击 "New query"
3. 复制粘贴 `supabase/migrations/00001_initial_schema.sql` 的全部内容
4. 点击 "Run" 执行
5. 重复步骤2-4，执行 `supabase/migrations/00002_row_level_security.sql`

#### 3.4 验证数据库
1. Database → Tables
2. 确认看到13张表：
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

### 4. 配置Xcode项目

#### 4.1 配置Info.plist
1. 在Xcode中，选择 `qcarios` target
2. 点击 "Info" tab
3. 添加以下配置：

| Key | Type | Value |
|-----|------|-------|
| SUPABASE_URL | String | https://xxxxx.supabase.co |
| SUPABASE_ANON_KEY | String | eyJhbGc... |
| AMAP_IOS_KEY | String | （暂时留空，稍后配置） |

#### 4.2 配置位置权限
在Info.plist中添加：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>需要获取您的位置信息以提供代驾服务</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>需要持续获取位置以追踪行程</string>
```

### 5. 首次运行

1. 选择模拟器：iPhone 15 Pro
2. 点击 Run（⌘R）
3. 等待编译完成

**预期结果**:
- ✅ 编译成功，无错误
- ✅ App启动，显示登录页面
- ✅ 控制台输出：`✅ Supabase Client initialized`

---

## 🧪 测试核心功能

### 测试1: 登录功能

1. 输入手机号：`13800138000`
2. 点击"获取验证码"
3. 输入验证码：`123456`（开发环境固定）
4. 点击"登录"
5. 选择角色：乘客
6. 点击"确认并继续"

**预期结果**:
- ✅ 进入主页，显示地图
- ✅ 控制台输出：`✅ 登录成功`

### 测试2: 查看订单列表

1. 点击底部Tab "订单"
2. 查看订单列表

**预期结果**:
- ✅ 显示"暂无订单"（新用户）
- ✅ 可以切换Tab（进行中/已完成/已取消）

### 测试3: 退出登录

1. 点击底部Tab "我的"
2. 滚动到底部
3. 点击"退出登录"

**预期结果**:
- ✅ 返回登录页面

---

## 🗺️ 配置高德地图（可选，建议完成）

### 1. 申请高德Key

1. 访问 https://lbs.amap.com/
2. 注册账号并登录
3. 控制台 → 应用管理 → 我的应用
4. 点击"创建新应用"
   - 应用名称：qcarios
   - 应用类型：移动应用
5. 添加Key
   - Key名称：qcarios-iOS
   - 服务平台：iOS
   - Bundle ID：`com.yourcompany.qcarios`（必须与Xcode中一致！）
6. 复制生成的Key

### 2. 配置到项目

在Info.plist中更新：
```xml
<key>AMAP_IOS_KEY</key>
<string>你的高德Key</string>
```

### 3. 测试地图

1. 重新运行App
2. 登录后进入首页
3. 应该看到地图加载

**预期结果**:
- ✅ 地图正常显示
- ✅ 可以看到当前位置
- ✅ 控制台输出：`✅ 高德地图SDK已初始化`

---

## 📝 创建测试数据（可选）

### 方法1: 通过App创建

**乘客创建订单**:
1. 登录乘客账号
2. 点击"选择目的地"
3. 搜索或选择一个地点
4. 点击"立即呼叫代驾"

**司机接单**:
1. 退出当前账号
2. 用另一个手机号登录
3. 选择角色：司机
4. 开启"在线接单"
5. 查看附近订单并抢单

### 方法2: 通过SQL插入

在Supabase SQL Editor中执行：

```sql
-- 创建测试用户（乘客）
INSERT INTO users (id, phone, role) VALUES
  ('11111111-1111-1111-1111-111111111111', '13800138001', 'passenger');

-- 创建测试用户（司机）
INSERT INTO users (id, phone, role) VALUES
  ('22222222-2222-2222-2222-222222222222', '13800138002', 'driver');

-- 创建司机profile
INSERT INTO driver_profiles (user_id, online_status, verification_status, rating) VALUES
  ('22222222-2222-2222-2222-222222222222', 'online', 'approved', 4.95);

-- 创建测试订单
INSERT INTO orders (
  passenger_id,
  driver_id,
  order_type,
  pickup_address, pickup_lat, pickup_lng,
  dropoff_address, dropoff_lat, dropoff_lng,
  estimated_price,
  status
) VALUES (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  'immediate',
  '北京市朝阳区建国门外大街1号', 39.9042, 116.4074,
  '北京市海淀区中关村大街1号', 39.9891, 116.3142,
  68.00,
  'accepted'
);
```

---

## 🎯 验收标准

完成以下所有测试，即表示配置成功：

- [ ] Pod依赖安装成功
- [ ] 项目编译无错误
- [ ] Supabase连接成功
- [ ] 可以正常登录（手机号 + 验证码123456）
- [ ] 可以选择角色
- [ ] 可以进入主页
- [ ] 可以退出登录
- [ ] （可选）高德地图显示正常
- [ ] （可选）可以搜索地点
- [ ] （可选）可以创建订单

---

## ⚠️ 常见问题

### Q1: Pod install失败

**错误**: `Unable to find a specification for 'Supabase'`

**解决**:
```bash
pod repo update
pod install
```

### Q2: 编译错误 "No such module 'Supabase'"

**原因**: 打开了`.xcodeproj`文件

**解决**:
1. 关闭Xcode
2. 打开 `qcarios.xcworkspace`

### Q3: 地图不显示

**可能原因**:
1. 高德Key未配置或错误
2. Bundle ID不匹配
3. 定位权限未授予

**解决步骤**:
1. 检查Info.plist中的`AMAP_IOS_KEY`
2. 确认Bundle ID与高德平台一致
3. 在模拟器设置中允许定位权限

### Q4: Supabase连接失败

**错误**: `Configuration value for SUPABASE_URL not found`

**解决**:
1. 确认Info.plist中正确添加了配置
2. Clean Build Folder（⇧⌘K）
3. 重新运行

### Q5: 验证码无法登录

**检查**:
- 开发环境固定验证码是 `123456`
- 手机号必须是11位数字

---

## 🚀 下一步开发建议

### 立即可以开始的功能

1. **完善地图功能**
   - 实现司机导航
   - 添加实时位置追踪

2. **增强订单功能**
   - 订单状态实时更新
   - 添加订单取消原因选择

3. **实现评价系统**
   - 创建评价页面UI
   - 评价提交和查看

4. **添加推送通知**
   - 配置APNs
   - 订单状态变更通知

### 需要外部依赖的功能

5. **集成真实支付**
   - 申请微信支付
   - 申请支付宝
   - 配置支付回调

6. **短信服务**
   - 集成阿里云/腾讯云短信
   - 替换开发环境固定验证码

7. **实名认证**
   - 集成身份证OCR
   - 对接实名认证接口

---

## 📋 开发环境检查表

在开始开发前，确保以下环境就绪：

### 软件环境
- [ ] macOS 13.0+
- [ ] Xcode 15.0+
- [ ] CocoaPods 1.12+

### 账号注册
- [ ] Supabase账号
- [ ] 高德开放平台账号
- [ ] （可选）微信开放平台账号
- [ ] （可选）支付宝开放平台账号

### 项目配置
- [ ] Supabase项目创建完成
- [ ] 数据库迁移执行成功
- [ ] Info.plist配置完成
- [ ] Pod依赖安装成功
- [ ] Bundle ID设置正确

### 测试验证
- [ ] 编译成功
- [ ] 登录功能正常
- [ ] 地图显示正常
- [ ] 可以查看订单

---

## 🎓 学习资源

### 官方文档
- [Supabase文档](https://supabase.com/docs)
- [SwiftUI教程](https://developer.apple.com/tutorials/swiftui)
- [高德地图iOS SDK](https://lbs.amap.com/api/ios-sdk/summary)

### 项目文档
- [快速开始](./QUICK_START.md)
- [实现总结](./IMPLEMENTATION_SUMMARY.md)
- [数据库设计](./DATABASE_SCHEMA.md)
- [Supabase配置](./SUPABASE_SETUP.md)

---

## 🎉 准备好了吗？

如果您已完成上述所有必须步骤，现在可以：

✅ 开始添加新功能
✅ 优化现有代码
✅ 进行UI/UX改进
✅ 编写单元测试
✅ 准备App Store发布

祝开发顺利！🚀

有问题随时查阅项目文档或创建Issue。
