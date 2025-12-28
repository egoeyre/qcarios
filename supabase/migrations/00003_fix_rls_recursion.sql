-- ============================================
-- 修复 RLS 无限递归问题
-- ============================================

-- 临时禁用所有 RLS（仅开发环境）
-- 注意：生产环境需要重新启用并修复策略

ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE passenger_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE driver_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE location_tracking DISABLE ROW LEVEL SECURITY;
ALTER TABLE payments DISABLE ROW LEVEL SECURITY;
ALTER TABLE driver_earnings DISABLE ROW LEVEL SECURITY;
ALTER TABLE reviews DISABLE ROW LEVEL SECURITY;
ALTER TABLE complaints DISABLE ROW LEVEL SECURITY;
ALTER TABLE coupons DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_coupons DISABLE ROW LEVEL SECURITY;
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE pricing_rules DISABLE ROW LEVEL SECURITY;

-- 删除所有现有策略
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Drivers can view passenger info in orders" ON users;
DROP POLICY IF EXISTS "Passengers can view own profile" ON passenger_profiles;
DROP POLICY IF EXISTS "Passengers can update own profile" ON passenger_profiles;
DROP POLICY IF EXISTS "Passengers can insert own profile" ON passenger_profiles;
DROP POLICY IF EXISTS "Drivers can view own profile" ON driver_profiles;
DROP POLICY IF EXISTS "Drivers can update own profile" ON driver_profiles;
DROP POLICY IF EXISTS "Drivers can insert own profile" ON driver_profiles;
DROP POLICY IF EXISTS "Passengers can view assigned driver info" ON driver_profiles;
DROP POLICY IF EXISTS "System can view online drivers" ON driver_profiles;
DROP POLICY IF EXISTS "Passengers can view own orders" ON orders;
DROP POLICY IF EXISTS "Drivers can view assigned orders" ON orders;
DROP POLICY IF EXISTS "Drivers can view pending orders" ON orders;
DROP POLICY IF EXISTS "Passengers can create orders" ON orders;
DROP POLICY IF EXISTS "Passengers can cancel own orders" ON orders;
DROP POLICY IF EXISTS "Drivers can update assigned orders" ON orders;
DROP POLICY IF EXISTS "Drivers can insert own location" ON location_tracking;
DROP POLICY IF EXISTS "Passengers can view driver location in active order" ON location_tracking;
DROP POLICY IF EXISTS "Drivers can view own location history" ON location_tracking;
DROP POLICY IF EXISTS "Users can view own payments" ON payments;
DROP POLICY IF EXISTS "Passengers can create payments" ON payments;
DROP POLICY IF EXISTS "Drivers can view own earnings" ON driver_earnings;
DROP POLICY IF EXISTS "Users can view reviews about themselves" ON reviews;
DROP POLICY IF EXISTS "Users can view own reviews" ON reviews;
DROP POLICY IF EXISTS "Users can create reviews for completed orders" ON reviews;
DROP POLICY IF EXISTS "Public can view non-anonymous reviews" ON reviews;
DROP POLICY IF EXISTS "Users can view own complaints" ON complaints;
DROP POLICY IF EXISTS "Users can view complaints against them" ON complaints;
DROP POLICY IF EXISTS "Users can create complaints" ON complaints;
DROP POLICY IF EXISTS "Public can view active coupons" ON coupons;
DROP POLICY IF EXISTS "Users can view own coupons" ON user_coupons;
DROP POLICY IF EXISTS "Users can update own coupons" ON user_coupons;
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
DROP POLICY IF EXISTS "Public can view active pricing rules" ON pricing_rules;
DROP POLICY IF EXISTS "Admins have full access to users" ON users;
DROP POLICY IF EXISTS "Admins have full access to orders" ON orders;
DROP POLICY IF EXISTS "Admins have full access to driver_profiles" ON driver_profiles;
DROP POLICY IF EXISTS "Admins have full access to complaints" ON complaints;

-- 删除 is_admin 函数
DROP FUNCTION IF EXISTS is_admin();

-- 为开发环境创建简单的策略（允许匿名访问）
-- 这样可以在没有认证的情况下测试应用

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON users FOR ALL USING (true);

ALTER TABLE passenger_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON passenger_profiles FOR ALL USING (true);

ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON driver_profiles FOR ALL USING (true);

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON orders FOR ALL USING (true);

ALTER TABLE location_tracking ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON location_tracking FOR ALL USING (true);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON payments FOR ALL USING (true);

ALTER TABLE driver_earnings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON driver_earnings FOR ALL USING (true);

ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON reviews FOR ALL USING (true);

ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON complaints FOR ALL USING (true);

ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON coupons FOR ALL USING (true);

ALTER TABLE user_coupons ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON user_coupons FOR ALL USING (true);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON notifications FOR ALL USING (true);

ALTER TABLE pricing_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for development" ON pricing_rules FOR ALL USING (true);
