-- ============================================
-- Row Level Security (RLS) 策略配置
-- ============================================

-- ============================================
-- 1. Users Table RLS
-- ============================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 用户可以查看自己的信息
CREATE POLICY "Users can view own profile"
ON users FOR SELECT
USING (auth.uid() = id);

-- 用户可以更新自己的信息
CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
USING (auth.uid() = id);

-- 司机可以查看乘客的基本信息（在有订单的情况下）
CREATE POLICY "Drivers can view passenger info in orders"
ON users FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM orders
        WHERE (driver_id = auth.uid() AND passenger_id = users.id)
           OR (passenger_id = auth.uid() AND driver_id = users.id)
    )
);

-- ============================================
-- 2. Passenger Profiles RLS
-- ============================================
ALTER TABLE passenger_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Passengers can view own profile"
ON passenger_profiles FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Passengers can update own profile"
ON passenger_profiles FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Passengers can insert own profile"
ON passenger_profiles FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 3. Driver Profiles RLS
-- ============================================
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;

-- 司机可以查看和更新自己的信息
CREATE POLICY "Drivers can view own profile"
ON driver_profiles FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Drivers can update own profile"
ON driver_profiles FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Drivers can insert own profile"
ON driver_profiles FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- 乘客可以查看接单司机的信息（限制字段）
CREATE POLICY "Passengers can view assigned driver info"
ON driver_profiles FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM orders
        WHERE passenger_id = auth.uid()
          AND driver_id = driver_profiles.user_id
          AND status IN ('accepted', 'driver_arrived', 'in_progress')
    )
);

-- 系统可以查看在线司机（用于派单）
CREATE POLICY "System can view online drivers"
ON driver_profiles FOR SELECT
USING (online_status = 'online' AND verification_status = 'approved');

-- ============================================
-- 4. Orders RLS
-- ============================================
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- 乘客可以查看自己的订单
CREATE POLICY "Passengers can view own orders"
ON orders FOR SELECT
USING (passenger_id = auth.uid());

-- 司机可以查看分配给自己的订单
CREATE POLICY "Drivers can view assigned orders"
ON orders FOR SELECT
USING (driver_id = auth.uid());

-- 司机可以查看待接单的订单（附近的订单）
CREATE POLICY "Drivers can view pending orders"
ON orders FOR SELECT
USING (
    status = 'pending'
    AND order_type = 'immediate'
    AND EXISTS (
        SELECT 1 FROM driver_profiles
        WHERE user_id = auth.uid()
          AND online_status = 'online'
          AND verification_status = 'approved'
    )
);

-- 乘客可以创建订单
CREATE POLICY "Passengers can create orders"
ON orders FOR INSERT
WITH CHECK (passenger_id = auth.uid());

-- 乘客可以取消自己的订单
CREATE POLICY "Passengers can cancel own orders"
ON orders FOR UPDATE
USING (
    passenger_id = auth.uid()
    AND status IN ('pending', 'accepted')
)
WITH CHECK (
    passenger_id = auth.uid()
    AND status = 'cancelled'
    AND cancelled_by = auth.uid()
);

-- 司机可以接单和更新订单状态
CREATE POLICY "Drivers can update assigned orders"
ON orders FOR UPDATE
USING (
    driver_id = auth.uid()
    OR (
        status = 'pending'
        AND EXISTS (
            SELECT 1 FROM driver_profiles
            WHERE user_id = auth.uid()
              AND online_status = 'online'
              AND verification_status = 'approved'
        )
    )
);

-- ============================================
-- 5. Location Tracking RLS
-- ============================================
ALTER TABLE location_tracking ENABLE ROW LEVEL SECURITY;

-- 司机可以插入自己的位置
CREATE POLICY "Drivers can insert own location"
ON location_tracking FOR INSERT
WITH CHECK (driver_id = auth.uid());

-- 乘客可以查看当前订单司机的位置
CREATE POLICY "Passengers can view driver location in active order"
ON location_tracking FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM orders
        WHERE id = location_tracking.order_id
          AND passenger_id = auth.uid()
          AND status IN ('accepted', 'driver_arrived', 'in_progress')
    )
);

-- 司机可以查看自己的位置记录
CREATE POLICY "Drivers can view own location history"
ON location_tracking FOR SELECT
USING (driver_id = auth.uid());

-- ============================================
-- 6. Payments RLS
-- ============================================
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- 用户可以查看与自己订单相关的支付记录
CREATE POLICY "Users can view own payments"
ON payments FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM orders
        WHERE id = payments.order_id
          AND (passenger_id = auth.uid() OR driver_id = auth.uid())
    )
);

-- 乘客可以创建支付记录
CREATE POLICY "Passengers can create payments"
ON payments FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM orders
        WHERE id = order_id AND passenger_id = auth.uid()
    )
);

-- ============================================
-- 7. Driver Earnings RLS
-- ============================================
ALTER TABLE driver_earnings ENABLE ROW LEVEL SECURITY;

-- 司机可以查看自己的收益
CREATE POLICY "Drivers can view own earnings"
ON driver_earnings FOR SELECT
USING (driver_id = auth.uid());

-- ============================================
-- 8. Reviews RLS
-- ============================================
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- 用户可以查看关于自己的评价
CREATE POLICY "Users can view reviews about themselves"
ON reviews FOR SELECT
USING (reviewee_id = auth.uid());

-- 用户可以查看自己写的评价
CREATE POLICY "Users can view own reviews"
ON reviews FOR SELECT
USING (reviewer_id = auth.uid());

-- 用户可以创建评价（对已完成订单）
CREATE POLICY "Users can create reviews for completed orders"
ON reviews FOR INSERT
WITH CHECK (
    reviewer_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM orders
        WHERE id = order_id
          AND status = 'completed'
          AND (passenger_id = auth.uid() OR driver_id = auth.uid())
    )
);

-- 用户可以查看公开的评价（查看司机评分时）
CREATE POLICY "Public can view non-anonymous reviews"
ON reviews FOR SELECT
USING (is_anonymous = FALSE);

-- ============================================
-- 9. Complaints RLS
-- ============================================
ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;

-- 用户可以查看自己提交的投诉
CREATE POLICY "Users can view own complaints"
ON complaints FOR SELECT
USING (complainant_id = auth.uid());

-- 用户可以查看针对自己的投诉
CREATE POLICY "Users can view complaints against them"
ON complaints FOR SELECT
USING (respondent_id = auth.uid());

-- 用户可以创建投诉
CREATE POLICY "Users can create complaints"
ON complaints FOR INSERT
WITH CHECK (
    complainant_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM orders
        WHERE id = order_id
          AND (passenger_id = auth.uid() OR driver_id = auth.uid())
    )
);

-- ============================================
-- 10. Coupons RLS
-- ============================================
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;

-- 所有人可以查看有效的优惠券
CREATE POLICY "Public can view active coupons"
ON coupons FOR SELECT
USING (is_active = TRUE AND valid_to >= NOW());

-- ============================================
-- 11. User Coupons RLS
-- ============================================
ALTER TABLE user_coupons ENABLE ROW LEVEL SECURITY;

-- 用户可以查看自己的优惠券
CREATE POLICY "Users can view own coupons"
ON user_coupons FOR SELECT
USING (user_id = auth.uid());

-- 用户可以使用自己的优惠券
CREATE POLICY "Users can update own coupons"
ON user_coupons FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- ============================================
-- 12. Notifications RLS
-- ============================================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 用户只能查看自己的通知
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
USING (user_id = auth.uid());

-- 用户可以标记自己的通知为已读
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- ============================================
-- 13. Pricing Rules RLS
-- ============================================
ALTER TABLE pricing_rules ENABLE ROW LEVEL SECURITY;

-- 所有人可以查看有效的计价规则
CREATE POLICY "Public can view active pricing rules"
ON pricing_rules FOR SELECT
USING (is_active = TRUE);

-- ============================================
-- 管理员角色相关（可选，用于后台管理）
-- ============================================

-- 创建管理员检查函数
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid()
          AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 管理员可以查看和修改所有数据（示例）
CREATE POLICY "Admins have full access to users"
ON users FOR ALL
USING (is_admin());

CREATE POLICY "Admins have full access to orders"
ON orders FOR ALL
USING (is_admin());

CREATE POLICY "Admins have full access to driver_profiles"
ON driver_profiles FOR ALL
USING (is_admin());

CREATE POLICY "Admins have full access to complaints"
ON complaints FOR ALL
USING (is_admin());

-- ============================================
-- 服务角色策略（用于Edge Functions等服务端操作）
-- ============================================

-- 注意：使用服务角色密钥时，RLS会被绕过
-- 确保在客户端只使用anon key
