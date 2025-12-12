-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable PostGIS for geographic data
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================
-- 1. Users Table (基础用户表)
-- ============================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) UNIQUE NOT NULL,
    role VARCHAR(10) NOT NULL CHECK (role IN ('passenger', 'driver', 'both')),
    nickname VARCHAR(50),
    avatar_url TEXT,
    gender VARCHAR(10) CHECK (gender IN ('male', 'female', 'other')),
    real_name VARCHAR(50),
    id_card_number VARCHAR(18),
    is_verified BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'banned')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 用户表索引
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_status ON users(status);

-- ============================================
-- 2. Passenger Profiles (乘客扩展信息)
-- ============================================
CREATE TABLE passenger_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    home_address JSONB, -- {address, lat, lng, poi_id}
    company_address JSONB,
    emergency_contact_name VARCHAR(50),
    emergency_contact_phone VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- ============================================
-- 3. Driver Profiles (司机扩展信息)
-- ============================================
CREATE TABLE driver_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    driver_license_number VARCHAR(50),
    driver_license_url TEXT,
    id_card_front_url TEXT,
    id_card_back_url TEXT,
    driving_years INTEGER,
    service_city VARCHAR(50),
    bank_card_number VARCHAR(30),
    bank_name VARCHAR(100),
    account_holder_name VARCHAR(50),
    online_status VARCHAR(20) DEFAULT 'offline' CHECK (online_status IN ('online', 'offline', 'busy')),
    current_lat DOUBLE PRECISION,
    current_lng DOUBLE PRECISION,
    last_location_update TIMESTAMP WITH TIME ZONE,
    verification_status VARCHAR(20) DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    verified_at TIMESTAMP WITH TIME ZONE,
    verified_by UUID REFERENCES users(id),
    rejection_reason TEXT,
    rating DECIMAL(3,2) DEFAULT 5.00,
    total_orders INTEGER DEFAULT 0,
    total_distance_km DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 司机位置索引（使用PostGIS）
CREATE INDEX idx_driver_location ON driver_profiles USING GIST (
    ST_SetSRID(ST_MakePoint(current_lng, current_lat), 4326)
) WHERE online_status = 'online';

CREATE INDEX idx_driver_online_status ON driver_profiles(online_status);
CREATE INDEX idx_driver_verification_status ON driver_profiles(verification_status);

-- ============================================
-- 4. Pricing Rules (计价规则)
-- ============================================
CREATE TABLE pricing_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    city_code VARCHAR(10) NOT NULL,
    service_type VARCHAR(20) DEFAULT 'standard' CHECK (service_type IN ('standard', 'business', 'long_distance')),
    base_price DECIMAL(10,2) NOT NULL DEFAULT 0, -- 起步价
    base_distance_km DECIMAL(5,2) DEFAULT 0, -- 起步里程
    price_per_km DECIMAL(10,2) NOT NULL DEFAULT 0, -- 每公里价格
    price_per_minute DECIMAL(10,2) DEFAULT 0, -- 每分钟价格
    night_fee_rate DECIMAL(5,2) DEFAULT 0, -- 夜间加价比例
    night_start_hour INTEGER DEFAULT 22, -- 夜间开始时间
    night_end_hour INTEGER DEFAULT 6, -- 夜间结束时间
    min_price DECIMAL(10,2) DEFAULT 0, -- 最低消费
    is_active BOOLEAN DEFAULT TRUE,
    effective_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    effective_to TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_pricing_city_type ON pricing_rules(city_code, service_type, is_active);

-- ============================================
-- 5. Orders (订单表)
-- ============================================
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number VARCHAR(32) UNIQUE NOT NULL, -- 订单号
    passenger_id UUID NOT NULL REFERENCES users(id),
    driver_id UUID REFERENCES users(id),

    -- 订单类型
    order_type VARCHAR(20) DEFAULT 'immediate' CHECK (order_type IN ('immediate', 'scheduled')),
    service_type VARCHAR(20) DEFAULT 'standard',

    -- 时间相关
    scheduled_time TIMESTAMP WITH TIME ZONE, -- 预约时间
    accepted_at TIMESTAMP WITH TIME ZONE, -- 接单时间
    arrived_at TIMESTAMP WITH TIME ZONE, -- 到达上车点时间
    started_at TIMESTAMP WITH TIME ZONE, -- 开始行程时间
    completed_at TIMESTAMP WITH TIME ZONE, -- 完成时间
    cancelled_at TIMESTAMP WITH TIME ZONE, -- 取消时间

    -- 地理位置
    pickup_address VARCHAR(255),
    pickup_lat DOUBLE PRECISION NOT NULL,
    pickup_lng DOUBLE PRECISION NOT NULL,
    pickup_poi_id VARCHAR(100),

    dropoff_address VARCHAR(255),
    dropoff_lat DOUBLE PRECISION NOT NULL,
    dropoff_lng DOUBLE PRECISION NOT NULL,
    dropoff_poi_id VARCHAR(100),

    -- 途经点（可选）
    waypoints JSONB, -- [{address, lat, lng, poi_id}]

    -- 费用相关
    estimated_distance_km DECIMAL(10,2),
    estimated_duration_min INTEGER,
    estimated_price DECIMAL(10,2),

    actual_distance_km DECIMAL(10,2),
    actual_duration_min INTEGER,
    final_price DECIMAL(10,2),

    discount_amount DECIMAL(10,2) DEFAULT 0,
    coupon_id UUID,

    -- 订单状态
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'accepted', 'driver_arrived', 'in_progress', 'completed', 'cancelled')
    ),

    -- 取消相关
    cancelled_by UUID REFERENCES users(id),
    cancel_reason TEXT,

    -- 备注
    passenger_note TEXT,
    driver_note TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 生成订单号的函数
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS VARCHAR(32) AS $$
BEGIN
    RETURN 'DD' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- 订单表索引
CREATE INDEX idx_orders_passenger ON orders(passenger_id);
CREATE INDEX idx_orders_driver ON orders(driver_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_orders_order_number ON orders(order_number);

-- 订单位置索引（用于查找附近订单）
CREATE INDEX idx_orders_pickup_location ON orders USING GIST (
    ST_SetSRID(ST_MakePoint(pickup_lng, pickup_lat), 4326)
) WHERE status = 'pending';

-- ============================================
-- 6. Location Tracking (位置轨迹)
-- ============================================
CREATE TABLE location_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES users(id),
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    accuracy DECIMAL(5,2), -- GPS精度（米）
    speed DECIMAL(5,2), -- 速度（km/h）
    bearing DECIMAL(5,2), -- 方向角
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 轨迹索引
CREATE INDEX idx_location_order ON location_tracking(order_id, timestamp DESC);
CREATE INDEX idx_location_timestamp ON location_tracking(timestamp DESC);

-- 使用TimescaleDB可以优化（可选）
-- SELECT create_hypertable('location_tracking', 'timestamp');

-- ============================================
-- 7. Payments (支付记录)
-- ============================================
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id),
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(20) NOT NULL CHECK (
        payment_method IN ('wechat', 'alipay', 'balance', 'apple_pay')
    ),
    transaction_id VARCHAR(100), -- 第三方交易ID
    status VARCHAR(20) DEFAULT 'pending' CHECK (
        status IN ('pending', 'processing', 'success', 'failed', 'refunded')
    ),
    paid_at TIMESTAMP WITH TIME ZONE,
    refunded_at TIMESTAMP WITH TIME ZONE,
    refund_amount DECIMAL(10,2),
    failure_reason TEXT,
    metadata JSONB, -- 支付元数据
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_transaction_id ON payments(transaction_id);

-- ============================================
-- 8. Driver Earnings (司机收益)
-- ============================================
CREATE TABLE driver_earnings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES users(id),
    order_id UUID NOT NULL REFERENCES orders(id),
    gross_amount DECIMAL(10,2) NOT NULL, -- 订单总额
    platform_commission_rate DECIMAL(5,2) DEFAULT 20.00, -- 平台抽成比例
    platform_commission DECIMAL(10,2) NOT NULL, -- 平台抽成金额
    net_income DECIMAL(10,2) NOT NULL, -- 司机净收入
    bonus DECIMAL(10,2) DEFAULT 0, -- 奖励
    settled BOOLEAN DEFAULT FALSE,
    settled_at TIMESTAMP WITH TIME ZONE,
    settlement_batch_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_earnings_driver ON driver_earnings(driver_id, created_at DESC);
CREATE INDEX idx_earnings_settled ON driver_earnings(settled, driver_id);

-- ============================================
-- 9. Reviews (评价)
-- ============================================
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id),
    reviewer_id UUID NOT NULL REFERENCES users(id),
    reviewee_id UUID NOT NULL REFERENCES users(id),
    reviewer_role VARCHAR(10) NOT NULL CHECK (reviewer_role IN ('passenger', 'driver')),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    tags TEXT[], -- 评价标签
    comment TEXT,
    images TEXT[], -- 评价图片
    is_anonymous BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(order_id, reviewer_id)
);

CREATE INDEX idx_reviews_reviewee ON reviews(reviewee_id, created_at DESC);
CREATE INDEX idx_reviews_order ON reviews(order_id);

-- ============================================
-- 10. Complaints (投诉)
-- ============================================
CREATE TABLE complaints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id),
    complainant_id UUID NOT NULL REFERENCES users(id),
    respondent_id UUID NOT NULL REFERENCES users(id),
    type VARCHAR(50) NOT NULL, -- 投诉类型
    description TEXT NOT NULL,
    images TEXT[],
    status VARCHAR(20) DEFAULT 'pending' CHECK (
        status IN ('pending', 'processing', 'resolved', 'rejected', 'closed')
    ),
    priority VARCHAR(10) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    assigned_to UUID REFERENCES users(id),
    resolution TEXT,
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_complaints_order ON complaints(order_id);
CREATE INDEX idx_complaints_status ON complaints(status);
CREATE INDEX idx_complaints_complainant ON complaints(complainant_id);

-- ============================================
-- 11. Coupons (优惠券 - V2功能)
-- ============================================
CREATE TABLE coupons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) CHECK (type IN ('discount', 'amount', 'first_order')),
    discount_rate DECIMAL(5,2), -- 折扣比例（如10表示10%）
    discount_amount DECIMAL(10,2), -- 固定减免金额
    min_order_amount DECIMAL(10,2), -- 最低使用金额
    max_discount_amount DECIMAL(10,2), -- 最大优惠金额
    total_quantity INTEGER, -- 总发行量
    used_quantity INTEGER DEFAULT 0, -- 已使用数量
    valid_from TIMESTAMP WITH TIME ZONE,
    valid_to TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 12. User Coupons (用户优惠券)
-- ============================================
CREATE TABLE user_coupons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    coupon_id UUID NOT NULL REFERENCES coupons(id),
    status VARCHAR(20) DEFAULT 'unused' CHECK (status IN ('unused', 'used', 'expired')),
    used_at TIMESTAMP WITH TIME ZONE,
    used_order_id UUID REFERENCES orders(id),
    obtained_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_user_coupons_user ON user_coupons(user_id, status);

-- ============================================
-- 13. System Notifications (系统通知)
-- ============================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    type VARCHAR(50) NOT NULL, -- order_update, payment_success, promotion等
    title VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    data JSONB, -- 附加数据
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read, created_at DESC);

-- ============================================
-- Triggers (触发器)
-- ============================================

-- 更新updated_at字段
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_driver_profiles_updated_at BEFORE UPDATE ON driver_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 自动生成订单号
CREATE OR REPLACE FUNCTION set_order_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.order_number IS NULL THEN
        NEW.order_number = generate_order_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_order_number_trigger BEFORE INSERT ON orders
    FOR EACH ROW EXECUTE FUNCTION set_order_number();

-- ============================================
-- Functions (工具函数)
-- ============================================

-- 计算两点之间的距离（使用PostGIS）
CREATE OR REPLACE FUNCTION calculate_distance(
    lat1 DOUBLE PRECISION,
    lng1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lng2 DOUBLE PRECISION
)
RETURNS DECIMAL(10,2) AS $$
BEGIN
    RETURN ST_DistanceSphere(
        ST_MakePoint(lng1, lat1),
        ST_MakePoint(lng2, lat2)
    ) / 1000; -- 返回公里
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 查找附近的在线司机
CREATE OR REPLACE FUNCTION find_nearby_drivers(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_radius_km DECIMAL DEFAULT 5,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    driver_id UUID,
    user_id UUID,
    distance_km DECIMAL(10,2),
    rating DECIMAL(3,2),
    total_orders INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        dp.id,
        dp.user_id,
        calculate_distance(p_lat, p_lng, dp.current_lat, dp.current_lng) as distance_km,
        dp.rating,
        dp.total_orders
    FROM driver_profiles dp
    WHERE dp.online_status = 'online'
        AND dp.verification_status = 'approved'
        AND calculate_distance(p_lat, p_lng, dp.current_lat, dp.current_lng) <= p_radius_km
    ORDER BY distance_km ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 计算订单价格
CREATE OR REPLACE FUNCTION calculate_order_price(
    p_city_code VARCHAR,
    p_service_type VARCHAR,
    p_distance_km DECIMAL,
    p_duration_min INTEGER,
    p_order_time TIMESTAMP WITH TIME ZONE
)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    v_rule pricing_rules%ROWTYPE;
    v_base_price DECIMAL(10,2);
    v_distance_price DECIMAL(10,2);
    v_time_price DECIMAL(10,2);
    v_night_fee DECIMAL(10,2);
    v_total DECIMAL(10,2);
    v_hour INTEGER;
BEGIN
    -- 获取计价规则
    SELECT * INTO v_rule
    FROM pricing_rules
    WHERE city_code = p_city_code
        AND service_type = p_service_type
        AND is_active = TRUE
        AND effective_from <= p_order_time
        AND (effective_to IS NULL OR effective_to >= p_order_time)
    ORDER BY effective_from DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No pricing rule found for city % and service type %', p_city_code, p_service_type;
    END IF;

    -- 基础价格
    v_base_price := v_rule.base_price;

    -- 里程费用
    IF p_distance_km > v_rule.base_distance_km THEN
        v_distance_price := (p_distance_km - v_rule.base_distance_km) * v_rule.price_per_km;
    ELSE
        v_distance_price := 0;
    END IF;

    -- 时间费用
    v_time_price := p_duration_min * v_rule.price_per_minute;

    -- 夜间费用
    v_hour := EXTRACT(HOUR FROM p_order_time);
    IF v_hour >= v_rule.night_start_hour OR v_hour < v_rule.night_end_hour THEN
        v_night_fee := (v_base_price + v_distance_price + v_time_price) * v_rule.night_fee_rate / 100;
    ELSE
        v_night_fee := 0;
    END IF;

    -- 总价
    v_total := v_base_price + v_distance_price + v_time_price + v_night_fee;

    -- 最低消费
    IF v_total < v_rule.min_price THEN
        v_total := v_rule.min_price;
    END IF;

    RETURN ROUND(v_total, 2);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 初始数据
-- ============================================

-- 插入默认计价规则（以北京为例）
INSERT INTO pricing_rules (city_code, service_type, base_price, base_distance_km, price_per_km, price_per_minute, night_fee_rate, min_price) VALUES
('BJ', 'standard', 20.00, 3.00, 5.00, 0.50, 30.00, 20.00),
('BJ', 'business', 50.00, 3.00, 8.00, 1.00, 30.00, 50.00),
('BJ', 'long_distance', 30.00, 5.00, 4.00, 0.30, 20.00, 30.00);

-- 插入其他城市（示例）
INSERT INTO pricing_rules (city_code, service_type, base_price, base_distance_km, price_per_km, price_per_minute, night_fee_rate, min_price) VALUES
('SH', 'standard', 22.00, 3.00, 5.50, 0.50, 30.00, 22.00),
('GZ', 'standard', 18.00, 3.00, 4.50, 0.50, 30.00, 18.00),
('SZ', 'standard', 20.00, 3.00, 5.00, 0.50, 30.00, 20.00);

COMMENT ON TABLE users IS '用户基础表';
COMMENT ON TABLE passenger_profiles IS '乘客扩展信息';
COMMENT ON TABLE driver_profiles IS '司机扩展信息';
COMMENT ON TABLE orders IS '订单表';
COMMENT ON TABLE location_tracking IS '位置轨迹表';
COMMENT ON TABLE payments IS '支付记录表';
COMMENT ON TABLE driver_earnings IS '司机收益表';
COMMENT ON TABLE reviews IS '评价表';
COMMENT ON TABLE complaints IS '投诉表';
