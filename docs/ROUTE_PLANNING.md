# 高德地图路线规划功能

## 功能概述

实现了基于高德地图SDK的智能路线规划功能，在乘客选择目的地后自动计算并显示最优驾车路线。

## 核心功能

### 1. 路线计算
**位置**: `qcarios/Core/Services/MapService.swift:240-314`

**功能**:
- 使用高德地图驾车路线规划API
- 支持多种路线策略（速度优先、费用优先、距离优先、躲避拥堵）
- 返回详细的路线信息（距离、时间、坐标点）

**路线策略**:
```swift
// 32：默认，高德推荐（同高德地图APP默认）- 推荐使用
// 33：躲避拥堵
// 34：高速优先
// 35：不走高速
// 36：避免收费
// 37：躲避拥堵+高速优先
// 38：躲避拥堵+避免收费
// 39：躲避拥堵+不走高速
// 40：躲避拥堵+高速优先+避免收费
request.strategy = 32 // 适合代驾场景
```

### 2. 路线显示
**位置**: `qcarios/Shared/Components/MapView.swift`

**功能**:
- 在地图上绘制详细路线
- 美观的蓝色路线样式
- 圆角连接和端点
- 自动调整地图视野以显示完整路线

**视觉效果**:
- 线条宽度: 8pt
- 颜色: 蓝色 (RGB: 0.2, 0.6, 1.0, alpha: 0.9)
- 样式: 圆角连接和端点

### 3. 标注点
**位置**: `qcarios/Shared/Components/MapView.swift:113-140`

**功能**:
- 绿色大头针表示上车点
- 红色大头针表示目的地
- 支持点击显示详细信息
- 下落动画效果

## 使用流程

### 乘客端使用
```
1. 用户打开乘客首页
   ↓
2. 系统自动定位当前位置作为上车点
   ↓
3. 用户点击"选择目的地"
   ↓
4. 打开LocationPickerView，搜索或选择目的地
   ↓
5. 确认后自动调用 calculateRoute()
   ↓
6. 高德地图API计算最优路线
   ↓
7. 在地图上显示完整路线
   ↓
8. 显示预估距离、时间和费用
   ↓
9. 用户点击"立即呼叫代驾"创建订单
```

## 数据结构

### RouteInfo 模型
```swift
struct RouteInfo {
    let distance: Double           // 距离（米）
    let duration: TimeInterval     // 时间（秒）
    let polyline: [CLLocationCoordinate2D]  // 路线坐标点数组

    var distanceKm: Double        // 距离（公里）
    var durationMinutes: Int      // 时间（分钟）
    var distanceText: String      // 格式化距离文本
    var durationText: String      // 格式化时间文本
}
```

### 示例数据
```swift
RouteInfo(
    distance: 5280.0,           // 5.28公里
    duration: 900.0,            // 15分钟
    polyline: [                 // 包含数百个坐标点的详细路线
        CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
        CLLocationCoordinate2D(latitude: 39.9048, longitude: 116.4082),
        // ... 更多点
    ]
)

// 格式化输出
distanceText: "5.3公里"
durationText: "15分钟"
```

## API 调用

### 高德地图路线规划请求
```swift
let request = AMapDrivingCalRouteSearchRequest()
request.origin = AMapGeoPoint.location(
    withLatitude: CGFloat(from.latitude),
    longitude: CGFloat(from.longitude)
)
request.destination = AMapGeoPoint.location(
    withLatitude: CGFloat(to.latitude),
    longitude: CGFloat(to.longitude)
)
request.strategy = 32 // 高德推荐策略

// 🔑 关键：设置返回字段类型，必须包含polyline才能获取详细路线坐标
request.showFieldType = AMapDrivingRouteShowFieldType(
    rawValue: AMapDrivingRouteShowFieldType.cost.rawValue |
              AMapDrivingRouteShowFieldType.tmcs.rawValue |
              AMapDrivingRouteShowFieldType.navi.rawValue |
              AMapDrivingRouteShowFieldType.cities.rawValue |
              AMapDrivingRouteShowFieldType.polyline.rawValue
)!

// 调用API
searchAPI.aMapDrivingV2RouteSearch(request)
```

### 响应处理
```swift
// 从响应中提取路线信息
let route = routeResult.route
let path = route.paths.first  // 获取第一条路线（推荐路线）

// 解析路线坐标
var polylineCoordinates: [CLLocationCoordinate2D] = []
for step in path.steps {
    if let polyline = step.polyline {
        // polyline 格式: "lng1,lat1;lng2,lat2;..."
        let coordinates = decodePolyline(polyline)
        polylineCoordinates.append(contentsOf: coordinates)
    }
}
```

## 价格计算集成

路线规划完成后，系统会自动调用价格计算：

```swift
// PassengerHomeViewModel.swift:99-100
await calculatePrice(route: route)
```

使用 Supabase RPC 函数计算：
```swift
let price = try await client
    .rpc("calculate_order_price", params: CalculateOrderPriceParams(
        p_city_code: "BJ",
        p_service_type: "standard",
        p_distance_km: route.distanceKm,
        p_duration_min: route.durationMinutes,
        p_order_time: ISO8601DateFormatter().string(from: Date())
    ))
    .execute()
    .value
```

## 地图显示优化

### 自动视野调整
```swift
// MapView.swift:93
mapView.showOverlays(
    [polyline],
    edgePadding: UIEdgeInsets(top: 100, left: 50, bottom: 100, right: 50),
    animated: true
)
```

这确保了：
- 路线完整可见
- 起点和终点都在视野内
- 有合适的边距，UI 不遮挡路线

### 标注优化
```swift
// 上车点 - 绿色
MapAnnotation(
    coordinate: pickup,
    title: "上车点",
    subtitle: pickupAddress
)

// 目的地 - 红色
MapAnnotation(
    coordinate: destination,
    title: "目的地",
    subtitle: destinationAddress
)
```

## 性能优化

### 1. 坐标点精简
高德返回的路线可能包含大量坐标点，对于较长路线可以考虑精简：
```swift
// TODO: 可选优化
func simplifyPolyline(_ coordinates: [CLLocationCoordinate2D], tolerance: Double) -> [CLLocationCoordinate2D] {
    // 使用 Douglas-Peucker 算法精简坐标点
    // 减少渲染负担，提高性能
}
```

### 2. 缓存路线
```swift
// TODO: 可选优化
private var routeCache: [String: RouteInfo] = [:]

func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteInfo {
    let cacheKey = "\(from.latitude),\(from.longitude)-\(to.latitude),\(to.longitude)"
    if let cached = routeCache[cacheKey] {
        return cached
    }
    // ... 计算新路线
}
```

## 错误处理

### 可能的错误
1. **MapError.notConfigured** - 地图服务未初始化
2. **MapError.routeNotFound** - 无法找到路线
3. **网络错误** - API 请求失败

### 降级方案
如果路线规划失败，系统会：
1. 记录错误日志
2. 使用直线距离估算
3. 显示简单的起终点连线
4. 价格计算使用估算值

```swift
// 降级处理示例
if polylineCoordinates.isEmpty {
    polylineCoordinates = [from, to]  // 至少显示起终点连线
}
```

## 调试信息

启用后会在控制台输出详细信息：
```
🗺️ 开始计算路线...
📍 起点: 39.9042, 116.4074
📍 终点: 39.9142, 116.4274
✅ 路线计算成功
📏 距离: 5280米
⏱️ 时间: 900秒
📍 路线点数: 342
```

## 测试建议

### 1. 测试路线
```swift
// 短距离路线（市内）
起点: 天安门 (39.9042, 116.4074)
终点: 鸟巢 (39.9928, 116.3903)
预期: 约15km，25分钟

// 中距离路线
起点: 三里屯 (39.9377, 116.4603)
终点: 首都机场 (40.0799, 116.6031)
预期: 约30km，40分钟
```

### 2. 边界情况
- 非常近的距离（< 500米）
- 跨城路线
- 无效坐标
- 网络断开

## 未来优化

1. **多路线选择**: 显示多条备选路线供用户选择
2. **实时路况**: 集成实时交通信息，动态调整路线
3. **途径点**: 支持添加途径点
4. **路线偏好**: 保存用户的路线偏好（避开高速、避开收费等）
5. **语音导航**: 集成导航SDK提供转向提示
6. **路线分享**: 允许用户分享路线给他人

## 相关文件

- `MapService.swift` - 地图服务封装，路线计算API
- `MapView.swift` - 地图组件，路线渲染
- `PassengerHomeViewModel.swift` - 乘客首页逻辑，路线管理
- `PassengerHomeView.swift` - 乘客首页UI，路线显示
- `LocationPickerView.swift` - 目的地选择器

---

更新时间: 2025-12-28
