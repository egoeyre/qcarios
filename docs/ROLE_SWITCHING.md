# 司机乘客角色切换功能

## 功能概述

实现了智能的角色切换系统，根据用户当前角色显示不同的界面：
- **乘客用户**：显示"成为司机"按钮，引导注册成为司机
- **司机用户**（包括 `driver` 和 `both` 角色）：显示乘客/司机模式切换器

## 组件结构

### 1. RoleSwitcher 组件
**位置**: `qcarios/Features/Profile/Components/RoleSwitcher.swift`

**功能**:
- 自动检测用户角色
- 为乘客显示"成为司机"按钮
- 为司机显示模式切换器
- 打开司机注册表单

### 2. DriverRegistrationView
**位置**: `qcarios/Features/Driver/Registration/DriverRegistrationView.swift`

**功能**:
- 收集司机注册信息（姓名、身份证、驾驶证、驾龄等）
- 创建 `driver_profiles` 记录
- 自动升级用户角色为 `both`
- 审核状态设置为 `pending`

### 3. MainTabView 更新
**位置**: `qcarios/Features/Main/MainTabView.swift`

**功能**:
- 监听角色切换通知
- 实时更新首页视图
- 记住用户的模式偏好（通过 UserDefaults）

## 用户角色说明

### Passenger（乘客）
- 只能使用乘客功能
- 看到"成为司机"按钮
- 点击后可以申请成为司机

### Driver（司机）
- 只能使用司机功能
- 看到模式切换器（但只有司机模式可选）
- 可以切换回乘客模式（会升级为 both）

### Both（双重角色）
- 同时拥有乘客和司机权限
- 可以自由切换两种模式
- 切换时不修改数据库，只改变 UI 显示
- 用户选择会被记住

## 数据流

### 成为司机流程
```
1. 乘客点击"成为司机"
   ↓
2. 打开 DriverRegistrationView
   ↓
3. 填写注册信息
   ↓
4. 提交后创建 driver_profiles 记录
   ↓
5. 更新用户角色: passenger → both
   ↓
6. 关闭表单，刷新界面
```

### 模式切换流程（for both 用户）
```
1. 点击"乘客模式"或"司机模式"
   ↓
2. 保存偏好到 UserDefaults
   ↓
3. 发送 NotificationCenter 通知
   ↓
4. MainTabView 接收通知
   ↓
5. 切换首页视图（PassengerHomeView ↔ DriverHomeView）
```

### 角色升级流程（单角色用户切换）
```
1. 乘客点击"司机模式"
   ↓
2. 更新数据库: role = both
   ↓
3. 保存偏好: driver
   ↓
4. 发送通知切换视图
```

## 界面展示

### 乘客用户看到的界面
```
┌─────────────────────────────┐
│ 司机服务                     │
├─────────────────────────────┤
│ 🚗 成为司机                  │
│    加入我们，开始赚钱    →   │
└─────────────────────────────┘
```

### 司机用户看到的界面
```
┌─────────────────────────────┐
│ 模式切换                     │
├─────────────────────────────┤
│ ┌──────────┬───────────┐    │
│ │ 👋 乘客  │ 🚗 司机   │    │
│ │   模式   │   模式    │    │
│ └──────────┴───────────┘    │
└─────────────────────────────┘
```

## 数据库变更

### driver_profiles 表
注册时创建的记录包含：
- `user_id`: 用户ID
- `driver_license_number`: 驾驶证号
- `driving_years`: 驾龄
- `service_city`: 服务城市
- `verification_status`: "pending"（待审核）
- `online_status`: "offline"（离线）
- `rating`: 5.00（初始评分）

### users 表
同时更新用户表：
- `real_name`: 真实姓名
- `id_card_number`: 身份证号
- `role`: passenger → both

## 测试账号

### 测试司机
- 手机号: `13800128003`
- 角色: `driver`
- 状态: approved（已审核）

### 测试乘客
- 手机号: `13900139001`
- 角色: `passenger`
- 可以测试"成为司机"功能

## API 端点

### 创建司机档案
```http
POST /rest/v1/driver_profiles
Content-Type: application/json

{
  "user_id": "uuid",
  "driver_license_number": "B110200001234567",
  "driving_years": 8,
  "service_city": "北京",
  "verification_status": "pending"
}
```

### 更新用户角色
```http
PATCH /rest/v1/users?id=eq.{user_id}
Content-Type: application/json

{
  "role": "both"
}
```

## 注意事项

1. **权限控制**: RLS 策略确保用户只能修改自己的数据
2. **审核流程**: 司机注册后需要审核，`verification_status` 为 `pending`
3. **模式记忆**: 使用 UserDefaults 保存用户偏好，键为 `preferred_mode`
4. **实时切换**: 使用 NotificationCenter 通知，事件名为 `UserModeChanged`
5. **表单验证**:
   - 身份证号必须18位
   - 驾龄必须是数字
   - 所有字段不能为空

## 未来优化

1. **证件上传**: 添加驾驶证、身份证照片上传功能
2. **审核管理**: 后台审核界面
3. **审核通知**: 审核结果推送通知
4. **银行卡绑定**: 添加收款账户设置
5. **协议确认**: 添加司机协议阅读和同意流程
6. **背景调查**: 集成第三方背景调查服务

---

更新时间: 2025-12-28
