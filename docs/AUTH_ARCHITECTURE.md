# Supabase 认证架构说明

## 目录
- [概述](#概述)
- [Auth Users vs Database Users](#auth-users-vs-database-users)
- [为什么需要两个表](#为什么需要两个表)
- [关系图](#关系图)
- [最佳实践](#最佳实践)
- [是否应该重命名](#是否应该重命名)

---

## 概述

Supabase 使用 **双层用户架构**：
1. `auth.users` - 认证层（Authentication）
2. `public.users` - 业务层（Application Data）

这是业界标准做法，**不是重复设计**。

---

## Auth Users vs Database Users

### 1. `auth.users` - 认证层

**位置**: `auth` schema（Supabase 系统表）

**作用**:
- 存储登录凭证
- 管理认证会话
- 处理密码重置、邮箱验证等

**字段（示例）**:
```sql
auth.users (
  id UUID PRIMARY KEY,              -- Supabase 生成的 User ID
  email VARCHAR,                    -- 登录邮箱
  phone VARCHAR,                    -- 登录手机号
  encrypted_password VARCHAR,       -- 加密密码
  email_confirmed_at TIMESTAMP,     -- 邮箱确认时间
  phone_confirmed_at TIMESTAMP,     -- 手机号确认时间
  last_sign_in_at TIMESTAMP,        -- 最后登录时间
  raw_app_meta_data JSONB,          -- 应用元数据
  raw_user_meta_data JSONB,         -- 用户元数据
  created_at TIMESTAMP,
  updated_at TIMESTAMP
  -- ... 更多认证相关字段
)
```

**特点**:
- ✅ 由 Supabase 完全管理
- ❌ **不能修改表结构**
- ❌ **不能直接访问**（只能通过 Auth API）
- ✅ 自动处理安全性（密码加密、token 管理）

---

### 2. `public.users` - 业务层

**位置**: `public` schema（我们的应用表）

**作用**:
- 存储业务相关的用户信息
- 存储应用特定的数据
- 可以自由扩展

**字段（qcarios 实现）**:
```sql
public.users (
  id UUID PRIMARY KEY,              -- 关联 auth.users.id
  phone VARCHAR UNIQUE NOT NULL,    -- 手机号（业务使用）
  role VARCHAR NOT NULL,            -- 用户角色: passenger/driver/both/admin
  nickname VARCHAR,                 -- 昵称
  avatar_url VARCHAR,               -- 头像
  gender VARCHAR,                   -- 性别
  real_name VARCHAR,                -- 真实姓名
  id_card_number VARCHAR,           -- 身份证号
  is_verified BOOLEAN,              -- 是否实名认证
  status VARCHAR NOT NULL,          -- 账户状态: active/suspended/banned
  created_at TIMESTAMP,
  updated_at TIMESTAMP
)
```

**特点**:
- ✅ 完全自定义
- ✅ 可以添加任何业务字段
- ✅ 可以直接查询和修改
- ✅ 支持复杂的业务逻辑

---

## 为什么需要两个表？

### 关注点分离（Separation of Concerns）

| 方面 | auth.users | public.users |
|------|-----------|--------------|
| **职责** | 认证和授权 | 业务数据 |
| **管理者** | Supabase 系统 | 应用开发者 |
| **数据类型** | 登录凭证、会话 | 个人资料、业务信息 |
| **修改权限** | 只能通过 Auth API | 完全控制 |
| **安全性** | 系统级加密 | 应用级控制 |
| **查询方式** | `client.auth.*` | `client.from('users')` |

### 具体原因

#### 1. **安全性**
```sql
-- ❌ 不好的做法：把所有信息放在 auth.users
-- 风险：业务数据混在认证数据中，容易泄露敏感信息

-- ✅ 好的做法：分离
auth.users: 只存储登录凭证（由系统保护）
public.users: 存储业务数据（由 RLS 保护）
```

#### 2. **灵活性**
```sql
-- auth.users 的字段是固定的，不能添加业务字段
-- public.users 可以随意扩展

ALTER TABLE public.users ADD COLUMN vip_level INTEGER;  -- ✅ 可以
ALTER TABLE auth.users ADD COLUMN vip_level INTEGER;    -- ❌ 不可以
```

#### 3. **查询效率**
```sql
-- 频繁的业务查询不会影响认证系统
SELECT * FROM public.users WHERE role = 'driver';  -- 快速
-- 认证查询由 Supabase 优化
SELECT * FROM auth.users WHERE email = '...';      -- 由系统处理
```

#### 4. **数据一致性**
```sql
-- auth.users 保证了认证数据的完整性
-- public.users 保证了业务数据的完整性
-- 两者通过 id 关联，职责清晰
```

---

## 关系图

```
┌─────────────────────────────────────────────────────────────┐
│                    Supabase 认证架构                          │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────┐          ┌──────────────────────┐
│   auth.users         │          │   public.users       │
│   (认证层)           │          │   (业务层)           │
├──────────────────────┤          ├──────────────────────┤
│ id (UUID)           │◄─────────┤ id (UUID) [FK]       │
│ email               │          │ phone                │
│ phone               │          │ role                 │
│ encrypted_password  │          │ nickname             │
│ email_confirmed_at  │          │ avatar_url           │
│ phone_confirmed_at  │          │ is_verified          │
│ last_sign_in_at     │          │ status               │
│ ...                 │          │ ...                  │
└──────────────────────┘          └──────────────────────┘
         ▲                                 │
         │                                 │
         │                                 ▼
    [Auth API]                    ┌────────────────┐
         │                        │ 扩展表          │
         │                        ├────────────────┤
         │                        │ driver_profiles│
         │                        │ passenger_..   │
         ▼                        │ ...            │
   ┌─────────┐                   └────────────────┘
   │  客户端  │
   └─────────┘
```

### 数据流

```
用户登录流程:
1. 用户输入手机号 + 验证码
2. Supabase Auth 验证 → 创建 auth.users 记录
3. 获取 auth.users.id
4. 在 public.users 创建业务记录（使用相同的 id）
5. 关联成功 ✅

查询用户信息:
1. 获取当前登录的 auth.uid()
2. 查询 public.users WHERE id = auth.uid()
3. 获取完整的业务信息
```

---

## 最佳实践

### 1. 永远保持 ID 一致

```swift
// ✅ 正确：使用 auth.user.id 作为 public.users.id
let authUserId = session.user.id
let newUser = User(
    id: authUserId,  // 使用相同的 ID
    phone: phone,
    role: .passenger
)
```

### 2. 使用 RLS 保护数据

```sql
-- public.users 的 RLS 策略
CREATE POLICY "Users can view own profile"
ON public.users FOR SELECT
USING (auth.uid() = id);  -- 使用 auth.uid() 关联

CREATE POLICY "Users can update own profile"
ON public.users FOR UPDATE
USING (auth.uid() = id);
```

### 3. 触发器自动同步

```sql
-- 可选：当 auth.users 创建时自动创建 public.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, phone, role, status)
  VALUES (
    new.id,
    new.phone,
    'passenger',
    'active'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

---

## 是否应该重命名？

### ❌ 不建议重命名为 `profiles`

**原因**:

1. **语义不准确**
   - `users` 更准确地表达"用户"的概念
   - `profiles` 通常指"用户资料"，是 `users` 的子集
   - 我们存储的不仅是资料，还有角色、状态等核心用户信息

2. **行业标准**
   - 大多数应用都使用 `auth.users` + `public.users` 模式
   - Firebase、Auth0、Clerk 等都是类似架构
   - 团队成员更容易理解

3. **避免混淆**
   ```
   ❌ 不好的命名:
   auth.users + public.profiles  → 混淆概念

   ✅ 清晰的命名:
   auth.users + public.users     → 认证用户 + 业务用户
   auth.users + public.user_profiles → 如果真的需要区分
   ```

4. **扩展性问题**
   ```sql
   -- 如果改成 profiles，那么：
   public.profiles          -- 基础信息？
   public.passenger_profiles -- 乘客资料
   public.driver_profiles    -- 司机资料

   -- 命名变得混乱，不如：
   public.users              -- 基础用户
   public.passenger_profiles -- 乘客扩展信息
   public.driver_profiles    -- 司机扩展信息
   ```

### ✅ 推荐的架构

保持当前设计：

```
auth.users (认证)
  ├─ public.users (基础用户信息)
  │   ├─ passenger_profiles (乘客扩展信息)
  │   └─ driver_profiles (司机扩展信息)
  └─ ...
```

**优点**:
- ✅ 层次清晰
- ✅ 语义准确
- ✅ 符合行业标准
- ✅ 易于理解和维护

---

## 示例：完整的用户数据

```swift
// 登录后获取完整的用户信息

// 1. Auth 层（由 Supabase 管理）
let authUser = supabase.auth.currentUser
// authUser.id: "550e8400-e29b-41d4-a716-446655440000"
// authUser.phone: "13800138001"
// authUser.email_confirmed_at: "2025-12-27T10:00:00Z"

// 2. 业务层（由我们管理）
let user = try await supabase
    .from("users")
    .select()
    .eq("id", value: authUser.id)
    .single()
    .execute()
    .value as User
// user.id: "550e8400-e29b-41d4-a716-446655440000" (相同)
// user.phone: "13800138001"
// user.role: "passenger"
// user.nickname: "小明"
// user.is_verified: true

// 3. 扩展层（如果用户是司机）
if user.isDriver {
    let driverProfile = try await supabase
        .from("driver_profiles")
        .select()
        .eq("user_id", value: user.id)
        .single()
        .execute()
        .value as DriverProfile
    // driverProfile.driver_license_number: "..."
    // driverProfile.rating: 4.8
}
```

---

## 总结

### 关键要点

1. ✅ **`auth.users` 和 `public.users` 不是重复，是标准架构**
2. ✅ **不建议重命名为 `profiles`**
3. ✅ **保持当前设计是最佳选择**
4. ✅ **通过 ID 关联两个表**
5. ✅ **使用 RLS 保护数据安全**

### 记住

> **认证（Authentication）和用户数据（User Data）是两个不同的关注点，应该分离。**

这不是设计缺陷，而是最佳实践！

---

## 参考资源

- [Supabase Auth 官方文档](https://supabase.com/docs/guides/auth)
- [User Management 最佳实践](https://supabase.com/docs/guides/auth/managing-user-data)
- [PostgreSQL Schema 设计](https://www.postgresql.org/docs/current/ddl-schemas.html)

---

**文档版本**: 1.0
**创建时间**: 2025-12-27
**作者**: Claude Code & AI Team
