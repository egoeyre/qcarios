# 数据库架构文档

本文档详细说明qcarios代驾App的数据库设计。

## 📊 ER图概览

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────┐
│    Users    │────────▶│ Passenger Profile│         │   Orders    │
│             │         └──────────────────┘         │             │
│  - id (PK)  │                                      │  - id (PK)  │
│  - phone    │         ┌──────────────────┐         │  - passenger│
│  - role     │────────▶│  Driver Profile  │◀────────│  - driver   │
│  - nickname │         │                  │         │  - status   │
└─────────────┘         │  - current_lat   │         │  - pickup   │
                        │  - current_lng   │         │  - dropoff  │
                        │  - rating        │         └─────────────┘
                        └──────────────────┘               │
                                │                           │
                                │                           ▼
                        ┌──────────────────┐         ┌─────────────┐
                        │Driver Earnings   │         │  Payments   │
                        │                  │         │             │
                        │  - gross_amount  │         │  - amount   │
                        │  - net_income    │         │  - status   │
                        └──────────────────┘         └─────────────┘
```

---

## 📋 数据表详解

### 1. users（用户表）

**描述**：存储所有用户的基础信息，包括乘客和司机。

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | UUID | PK | 用户ID |
| phone | VARCHAR(20) | UNIQUE, NOT NULL | 手机号 |
| role | VARCHAR(10) | NOT NULL | 角色：passenger/driver/both/admin |
| nickname | VARCHAR(50) | | 昵称 |
| avatar_url | TEXT | | 头像URL |
| gender | VARCHAR(10) | | 性别：male/female/other |
| real_name | VARCHAR(50) | | 真实姓名 |
| id_card_number | VARCHAR(18) | | 身份证号 |
| is_verified | BOOLEAN | DEFAULT FALSE | 是否已实名认证 |
| status | VARCHAR(20) | DEFAULT 'active' | 账号状态：active/suspended/banned |
| created_at | TIMESTAMP | DEFAULT NOW() | 创建时间 |
| updated_at | TIMESTAMP | DEFAULT NOW() | 更新时间 |

**索引**：
- `idx_users_phone` ON (phone)
- `idx_users_role` ON (role)
- `idx_users_status` ON (status)

**RLS策略**：
- 用户可以查看和更新自己的信息
- 在有订单关系时，乘客和司机可以查看对方的基本信息

---

### 2. passenger_profiles（乘客扩展信息）

**描述**：乘客专属的扩展信息。

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | UUID | PK | 主键 |
| user_id | UUID | FK → users, UNIQUE | 关联用户ID |
| home_address | JSONB | | 家庭地址 {address, lat, lng, poi_id} |
| company_address | JSONB | | 公司地址 |
| emergency_contact_name | VARCHAR(50) | | 紧急联系人姓名 |
| emergency_contact_phone | VARCHAR(20) | | 紧急联系人电话 |
| created_at | TIMESTAMP | DEFAULT NOW() | 创建时间 |
| updated_at | TIMESTAMP | DEFAULT NOW() | 更新时间 |

---

### 3. driver_profiles（司机扩展信息）

**描述**：司机专属信息，包括认证、位置、评分等。

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | UUID | PK | 主键 |
| user_id | UUID | FK → users, UNIQUE | 关联用户ID |
| driver_license_number | VARCHAR(50) | | 驾驶证号 |
| driver_license_url | TEXT | | 驾驶证照片URL |
| id_card_front_url | TEXT | | 身份证正面URL |
| id_card_back_url | TEXT | | 身份证背面URL |
| driving_years | INTEGER | | 驾龄 |
| service_city | VARCHAR(50) | | 服务城市 |
| bank_card_number | VARCHAR(30) | | 银行卡号 |
| bank_name | VARCHAR(100) | | 银行名称 |
| account_holder_name | VARCHAR(50) | | 持卡人姓名 |
| online_status | VARCHAR(20) | DEFAULT 'offline' | 在线状态：online/offline/busy |
| current_lat | DOUBLE PRECISION | | 当前纬度 |
| current_lng | DOUBLE PRECISION | | 当前经度 |
| last_location_update | TIMESTAMP | | 最后位置更新时间 |
| verification_status | VARCHAR(20) | DEFAULT 'pending' | 认证状态：pending/approved/rejected |
| verified_at | TIMESTAMP | | 认证通过时间 |
| verified_by | UUID | FK → users | 审核人ID |
| rejection_reason | TEXT | | 拒绝原因 |
| rating | DECIMAL(3,2) | DEFAULT 5.00 | 评分（1-5） |
| total_orders | INTEGER | DEFAULT 0 | 总订单数 |
| total_distance_km | DECIMAL(10,2) | DEFAULT 0 | 总里程 |
| created_at | TIMESTAMP | DEFAULT NOW() | 创建时间 |
| updated_at | TIMESTAMP | DEFAULT NOW() | 更新时间 |

**索引**：
- `idx_driver_location` GIST (PostGIS空间索引，用于附近司机查询)
- `idx_driver_online_status` ON (online_status)
- `idx_driver_verification_status` ON (verification_status)

**重要**：`current_lat` 和 `current_lng` 使用PostGIS的空间索引，可高效查询附近司机。

---

### 4. pricing_rules（计价规则）

**描述**：按城市和服务类型定义的计价规则。

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | UUID | PK | 主键 |
| city_code | VARCHAR(10) | NOT NULL | 城市代码（如BJ、SH） |
| service_type | VARCHAR(20) | DEFAULT 'standard' | 服务类型：standard/business/long_distance |
| base_price | DECIMAL(10,2) | NOT NULL | 起步价 |
| base_distance_km | DECIMAL(5,2) | DEFAULT 0 | 起步里程 |
| price_per_km | DECIMAL(10,2) | NOT NULL | 每公里价格 |
| price_per_minute | DECIMAL(10,2) | DEFAULT 0 | 每分钟价格 |
| night_fee_rate | DECIMAL(5,2) | DEFAULT 0 | 夜间加价比例（%） |
| night_start_hour | INTEGER | DEFAULT 22 | 夜间开始时间 |
| night_end_hour | INTEGER | DEFAULT 6 | 夜间结束时间 |
| min_price | DECIMAL(10,2) | DEFAULT 0 | 最低消费 |
| is_active | BOOLEAN | DEFAULT TRUE | 是否生效 |
| effective_from | TIMESTAMP | DEFAULT NOW() | 生效开始时间 |
| effective_to | TIMESTAMP | | 生效结束时间 |
| created_at | TIMESTAMP | DEFAULT NOW() | 创建时间 |
| updated_at | TIMESTAMP | DEFAULT NOW() | 更新时间 |

**初始数据**：
```sql
-- 北京标准服务
city_code: 'BJ', service_type: 'standard'
base_price: 20.00, base_distance_km: 3.00
price_per_km: 5.00, price_per_minute: 0.50
night_fee_rate: 30.00, min_price: 20.00
```

**计价公式**：
```
总价 = 起步价 + 超出里程费 + 时间费 + 夜间费
超出里程费 = MAX(0, (实际里程 - 起步里程)) × 每公里价格
时间费 = 行驶时长(分钟) × 每分钟价格
夜间费 = (起步价 + 超出里程费 + 时间费) × 夜间费率%（如果在夜间时段）
最终价格 = MAX(总价, 最低消费)
```

---

### 5. orders（订单表）

**描述**：核心业务表，记录所有代驾订单。

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | UUID | PK | 订单ID |
| order_number | VARCHAR(32) | UNIQUE | 订单号（自动生成） |
| passenger_id | UUID | FK → users | 乘客ID |
| driver_id | UUID | FK → users | 司机ID（接单后填充） |
| order_type | VARCHAR(20) | DEFAULT 'immediate' | 订单类型：immediate/scheduled |
| service_type | VARCHAR(20) | DEFAULT 'standard' | 服务类型 |
| scheduled_time | TIMESTAMP | | 预约时间 |
| accepted_at | TIMESTAMP | | 接单时间 |
| arrived_at | TIMESTAMP | | 到达上车点时间 |
| started_at | TIMESTAMP | | 开始行程时间 |
| completed_at | TIMESTAMP | | 完成时间 |
| cancelled_at | TIMESTAMP | | 取消时间 |
| pickup_address | VARCHAR(255) | | 上车地址 |
| pickup_lat | DOUBLE PRECISION | NOT NULL | 上车纬度 |
| pickup_lng | DOUBLE PRECISION | NOT NULL | 上车经度 |
| pickup_poi_id | VARCHAR(100) | | 上车POI ID |
| dropoff_address | VARCHAR(255) | | 目的地地址 |
| dropoff_lat | DOUBLE PRECISION | NOT NULL | 目的地纬度 |
| dropoff_lng | DOUBLE PRECISION | NOT NULL | 目的地经度 |
| dropoff_poi_id | VARCHAR(100) | | 目的地POI ID |
| waypoints | JSONB | | 途经点数组 |
| estimated_distance_km | DECIMAL(10,2) | | 预估里程 |
| estimated_duration_min | INTEGER | | 预估时长 |
| estimated_price | DECIMAL(10,2) | | 预估价格 |
| actual_distance_km | DECIMAL(10,2) | | 实际里程 |
| actual_duration_min | INTEGER | | 实际时长 |
| final_price | DECIMAL(10,2) | | 最终价格 |
| discount_amount | DECIMAL(10,2) | DEFAULT 0 | 优惠金额 |
| coupon_id | UUID | FK → coupons | 使用的优惠券ID |
| status | VARCHAR(20) | DEFAULT 'pending' | 状态：pending/accepted/driver_arrived/in_progress/completed/cancelled |
| cancelled_by | UUID | FK → users | 取消人ID |
| cancel_reason | TEXT | | 取消原因 |
| passenger_note | TEXT | | 乘客备注 |
| driver_note | TEXT | | 司机备注 |
| created_at | TIMESTAMP | DEFAULT NOW() | 创建时间 |
| updated_at | TIMESTAMP | DEFAULT NOW() | 更新时间 |

**订单状态流转**：
```
pending → accepted → driver_arrived → in_progress → completed
   ↓
cancelled
```

**索引**：
- `idx_orders_passenger` ON (passenger_id)
- `idx_orders_driver` ON (driver_id)
- `idx_orders_status` ON (status)
- `idx_orders_created_at` ON (created_at DESC)
- `idx_orders_order_number` ON (order_number)
- `idx_orders_pickup_location` GIST (空间索引，用于查找附近订单)

---

### 6. location_tracking（位置轨迹）

**描述**：记录行程中司机的实时位置轨迹。

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | UUID | PK | 主键 |
| order_id | UUID | FK → orders | 订单ID |
| driver_id | UUID | FK → users | 司机ID |
| lat | DOUBLE PRECISION | NOT NULL | 纬度 |
| lng | DOUBLE PRECISION | NOT NULL | 经度 |
| accuracy | DECIMAL(5,2) | | GPS精度（米） |
| speed | DECIMAL(5,2) | | 速度（km/h） |
| bearing | DECIMAL(5,2) | | 方向角（0-360度） |
| timestamp | TIMESTAMP | DEFAULT NOW() | 定位时间 |
| created_at | TIMESTAMP | DEFAULT NOW() | 记录创建时间 |

**使用场景**：
- 乘客实时查看司机位置
- 轨迹回放
- 异常行为检测（如绕路）

**优化建议**：
- 可使用TimescaleDB扩展将此表转为时序表，提高查询性能
- 定期归档历史数据

**索引**：
- `idx_location_order` ON (order_id, timestamp DESC)
- `idx_location_timestamp` ON (timestamp DESC)

---

### 7. payments（支付记录）

**描述**：记录订单支付信息。

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | UUID | PK | 主键 |
| order_id | UUID | FK → orders | 订单ID |
| amount | DECIMAL(10,2) | NOT NULL | 支付金额 |
| payment_method | VARCHAR(20) | NOT NULL | 支付方式：wechat/alipay/balance/apple_pay |
| transaction_id | VARCHAR(100) | | 第三方交易ID |
| status | VARCHAR(20) | DEFAULT 'pending' | 状态：pending/processing/success/failed/refunded |
| paid_at | TIMESTAMP | | 支付成功时间 |
| refunded_at | TIMESTAMP | | 退款时间 |
| refund_amount | DECIMAL(10,2) | | 退款金额 |
| failure_reason | TEXT | | 失败原因 |
| metadata | JSONB | | 支付元数据 |
| created_at | TIMESTAMP | DEFAULT NOW() | 创建时间 |
| updated_at | TIMESTAMP | DEFAULT NOW() | 更新时间 |

---

### 8. driver_earnings（司机收益）

**描述**：记录司机每笔订单的收益明细。

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | UUID | PK | 主键 |
| driver_id | UUID | FK → users | 司机ID |
| order_id | UUID | FK → orders | 订单ID |
| gross_amount | DECIMAL(10,2) | NOT NULL | 订单总额 |
| platform_commission_rate | DECIMAL(5,2) | DEFAULT 20.00 | 平台抽成比例（%） |
| platform_commission | DECIMAL(10,2) | NOT NULL | 平台抽成金额 |
| net_income | DECIMAL(10,2) | NOT NULL | 司机净收入 |
| bonus | DECIMAL(10,2) | DEFAULT 0 | 奖励金额 |
| settled | BOOLEAN | DEFAULT FALSE | 是否已结算 |
| settled_at | TIMESTAMP | | 结算时间 |
| settlement_batch_id | UUID | | 结算批次ID |
| created_at | TIMESTAMP | DEFAULT NOW() | 创建时间 |

**计算公式**：
```
platform_commission = gross_amount × (platform_commission_rate / 100)
net_income = gross_amount - platform_commission + bonus
```

---

### 9. reviews（评价）

**描述**：订单完成后的评价记录。

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | UUID | PK | 主键 |
| order_id | UUID | FK → orders | 订单ID |
| reviewer_id | UUID | FK → users | 评价人ID |
| reviewee_id | UUID | FK → users | 被评价人ID |
| reviewer_role | VARCHAR(10) | NOT NULL | 评价人角色：passenger/driver |
| rating | INTEGER | NOT NULL | 评分（1-5） |
| tags | TEXT[] | | 评价标签数组 |
| comment | TEXT | | 评价内容 |
| images | TEXT[] | | 评价图片URL数组 |
| is_anonymous | BOOLEAN | DEFAULT FALSE | 是否匿名 |
| created_at | TIMESTAMP | DEFAULT NOW() | 创建时间 |

**约束**：
- UNIQUE(order_id, reviewer_id) - 每人对每个订单只能评价一次

**标签示例**：
- 司机评价标签：['礼貌', '专业', '车技好', '准时', '车内整洁']
- 乘客评价标签：['友好', '守时', '礼貌']

---

### 10. complaints（投诉）

**描述**：投诉和问题反馈。

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | UUID | PK | 主键 |
| order_id | UUID | FK → orders | 关联订单ID |
| complainant_id | UUID | FK → users | 投诉人ID |
| respondent_id | UUID | FK → users | 被投诉人ID |
| type | VARCHAR(50) | NOT NULL | 投诉类型 |
| description | TEXT | NOT NULL | 投诉描述 |
| images | TEXT[] | | 证据图片 |
| status | VARCHAR(20) | DEFAULT 'pending' | 状态：pending/processing/resolved/rejected/closed |
| priority | VARCHAR(10) | DEFAULT 'normal' | 优先级：low/normal/high/urgent |
| assigned_to | UUID | FK → users | 分配给（客服ID） |
| resolution | TEXT | | 处理结果 |
| resolved_at | TIMESTAMP | | 解决时间 |
| created_at | TIMESTAMP | DEFAULT NOW() | 创建时间 |
| updated_at | TIMESTAMP | DEFAULT NOW() | 更新时间 |

---

## 🔧 数据库函数

### 1. calculate_distance

计算两个坐标点之间的距离（单位：公里）。

```sql
SELECT calculate_distance(39.9042, 116.4074, 31.2304, 121.4737) AS distance_km;
-- 返回: 1067.50 (北京到上海约1067公里)
```

### 2. find_nearby_drivers

查找附近的在线司机。

```sql
SELECT * FROM find_nearby_drivers(
    p_lat := 39.9042,
    p_lng := 116.4074,
    p_radius_km := 5,
    p_limit := 10
);
```

返回：
- driver_id
- user_id
- distance_km
- rating
- total_orders

### 3. calculate_order_price

计算订单价格。

```sql
SELECT calculate_order_price(
    p_city_code := 'BJ',
    p_service_type := 'standard',
    p_distance_km := 10.5,
    p_duration_min := 30,
    p_order_time := NOW()
) AS estimated_price;
```

---

## 🔒 安全策略（RLS）

所有表都启用了Row Level Security，确保数据访问安全。详见 [00002_row_level_security.sql](../supabase/migrations/00002_row_level_security.sql)。

### 关键策略：

1. **用户数据隔离**：用户只能访问自己的数据
2. **订单可见性**：乘客和司机可以查看共同订单的详情
3. **司机位置**：仅在行程中对乘客可见
4. **财务数据**：严格限制访问权限
5. **管理员权限**：管理员可以访问所有数据

---

## 📈 性能优化建议

### 1. 索引优化

已创建的关键索引：
- 用户手机号、角色、状态
- 司机位置（PostGIS空间索引）
- 订单状态、时间、用户关联
- 轨迹时间序列

### 2. 分区建议（未来扩展）

当数据量增大时，考虑对以下表进行分区：
- `orders` - 按月份分区
- `location_tracking` - 按月份分区（或使用TimescaleDB）
- `driver_earnings` - 按月份分区

### 3. 查询优化

- 使用`select()`明确指定需要的字段，避免`SELECT *`
- 对频繁查询的组合条件创建复合索引
- 使用数据库函数进行复杂计算（如价格计算）

### 4. 缓存策略

建议缓存：
- 计价规则（rarely change）
- 用户基本信息
- 司机评分和统计数据

---

## 🔄 数据迁移

所有数据库变更通过迁移脚本管理：

- `00001_initial_schema.sql` - 初始架构
- `00002_row_level_security.sql` - RLS策略

未来迁移命名规则：
```
XXXXX_description.sql
```
例如：`00003_add_coupon_system.sql`

---

## 📝 备注

1. 所有时间字段使用 `TIMESTAMP WITH TIME ZONE`，确保时区正确
2. 金额字段使用 `DECIMAL(10,2)`，避免浮点精度问题
3. UUID作为主键，利于分布式系统扩展
4. 使用JSONB存储灵活数据（如地址、元数据），支持索引和查询

---

更新日期：2025-12-12
