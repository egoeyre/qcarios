# 中国地图坐标系统说明

## 概述

在中国使用地图服务时，需要注意不同的坐标系统问题。GPS 获取的坐标与地图显示的坐标使用不同的坐标系，直接使用会导致位置偏移。

---

## 🌍 三种主要坐标系

### 1. WGS-84 坐标系（地球坐标系）

**定义**：World Geodetic System 1984，国际标准 GPS 坐标系

**特点**：
- ✅ 国际标准，全球通用
- ✅ GPS 设备直接输出
- ✅ Google Earth 使用
- ✅ iOS `CLLocationManager` 返回的坐标

**使用场景**：
- 国际应用
- GPS 原始数据
- 海外地图服务

---

### 2. GCJ-02 坐标系（火星坐标系）

**定义**：国家测绘局标准，中国强制使用的坐标系

**特点**：
- ✅ 中国法律要求
- ✅ 在 WGS-84 基础上加密偏移
- ✅ 高德地图、腾讯地图使用
- ⚠️ 与 WGS-84 有偏移（约 50-500 米）

**使用场景**：
- 高德地图 API
- 腾讯地图 API
- 中国境内地图服务

---

### 3. BD-09 坐标系（百度坐标系）

**定义**：百度在 GCJ-02 基础上二次加密

**特点**：
- ✅ 百度地图专用
- ⚠️ 与 GCJ-02 有偏移
- ⚠️ 与 WGS-84 偏移更大

**使用场景**：
- 百度地图 API

---

## 🔄 坐标转换

### qcarios 项目中的处理

在 qcarios 中，我们使用高德地图，因此需要进行以下转换：

```
GPS (WGS-84) → 高德地图 (GCJ-02)
```

### 实现方式

#### 1. 坐标转换工具类

`CoordinateConverter.swift` 提供了坐标转换方法：

```swift
// WGS-84 转 GCJ-02
let gcjCoordinate = CoordinateConverter.wgs84ToGcj02(wgsCoordinate)

// 或使用扩展方法
let gcjCoordinate = wgsCoordinate.toGcj02
```

#### 2. 自动转换

`LocationService` 在接收到 GPS 坐标后自动转换为 GCJ-02：

```swift
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }

    // 自动转换 WGS-84 → GCJ-02
    let wgsCoordinate = location.coordinate
    let gcjCoordinate = CoordinateConverter.wgs84ToGcj02(wgsCoordinate)

    // 创建转换后的位置对象
    let convertedLocation = CLLocation(coordinate: gcjCoordinate, ...)

    // 发送 GCJ-02 坐标
    locationSubject.send(convertedLocation)
}
```

---

## 📊 偏移量示例

以北京天安门为例：

| 坐标系 | 经度 | 纬度 | 偏移 |
|--------|------|------|------|
| WGS-84 | 116.397428 | 39.909186 | - |
| GCJ-02 | 116.404269 | 39.915168 | ~750 米 |

**说明**：GCJ-02 相对 WGS-84 的偏移量在中国不同地区不同，通常在 50-500 米之间。

---

## 🔍 如何验证坐标系

### 在调试日志中查看

```
📍 位置更新:
   [WGS-84] 经度: 116.397428, 纬度: 39.909186
   [GCJ-02] 经度: 116.404269, 纬度: 39.915168
   偏移: Δ经度: 0.006841, Δ纬度: 0.005982
   精度: 10.0m
```

### 测试方法

1. 在真实设备上测试定位
2. 查看控制台的 WGS-84 和 GCJ-02 坐标
3. 确认偏移量在合理范围内（约 0.001-0.01 度）
4. 在高德地图上验证位置是否准确

---

## ⚠️ 注意事项

### 1. 坐标系一致性

**重要**：在整个应用中保持坐标系一致

```swift
// ✅ 正确：统一使用 GCJ-02
let pickupLocation: CLLocationCoordinate2D  // GCJ-02
let destination: CLLocationCoordinate2D     // GCJ-02
mapView.showRoute(from: pickupLocation, to: destination)  // GCJ-02

// ❌ 错误：混用不同坐标系
let gpsLocation: CLLocationCoordinate2D     // WGS-84
let destination: CLLocationCoordinate2D     // GCJ-02
mapView.showRoute(from: gpsLocation, to: destination)  // 会出现偏移！
```

### 2. 中国境外

在中国境外，GCJ-02 转换会自动返回原坐标（不进行偏移）：

```swift
// 在美国纽约
let nyCoordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
let converted = nyCoordinate.toGcj02
// converted == nyCoordinate (无偏移)
```

### 3. 存储坐标

**建议**：数据库中存储 GCJ-02 坐标

```swift
// ✅ 推荐：存储 GCJ-02
struct Order {
    let pickupLat: Double   // GCJ-02
    let pickupLng: Double   // GCJ-02
}

// ❌ 不推荐：存储 WGS-84（需要每次转换）
```

### 4. API 调用

与第三方服务交互时，注意坐标系：

```swift
// 高德地图 API - 需要 GCJ-02
await mapService.searchNearby(location: gcjCoordinate)

// GPS 跟踪 - 如需原始坐标，转换回 WGS-84
let wgsCoordinate = gcjCoordinate.toWgs84
```

---

## 📚 参考资源

### 算法说明

WGS-84 转 GCJ-02 使用的是国家测绘局的加密算法：
- 基于克拉索夫斯基椭球参数
- 使用复杂的三角函数计算偏移
- 偏移量与经纬度相关

### 相关文档

- [国家测绘局坐标系说明](http://www.geodetic.cn/)
- [高德地图坐标系统](https://lbs.amap.com/api/webservice/guide/api/convert)

---

## 🛠️ 实用工具

### 在线坐标转换

- [坐标拾取器 - 高德地图](https://lbs.amap.com/tools/picker)
- [坐标转换工具](https://tool.lu/coordinate/)

### 验证方法

1. 打开高德地图坐标拾取器
2. 在地图上选择一个位置
3. 对比显示的 GCJ-02 坐标与转换结果

---

## ✅ 总结

### qcarios 中的坐标流程

```
GPS 设备 → WGS-84 坐标
    ↓
LocationService 自动转换
    ↓
GCJ-02 坐标
    ↓
高德地图显示/搜索/导航
```

### 关键要点

1. ✅ iOS `CLLocationManager` 返回 WGS-84
2. ✅ 高德地图需要 GCJ-02
3. ✅ `LocationService` 自动完成转换
4. ✅ 应用内统一使用 GCJ-02
5. ✅ 数据库存储 GCJ-02

---

**文档版本**: 1.0
**创建时间**: 2025-12-28
**作者**: Claude Code & AI Team
