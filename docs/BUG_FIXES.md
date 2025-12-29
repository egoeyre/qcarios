# 问题修复记录

## 2025-12-28: 高德地图路线规划API类名和方法名错误

### 问题描述
```
错误1: /Users/ai/Desktop/qcarios/qcarios/Core/Services/MapService.swift:250:23
Cannot find 'AMapDrivingRouteSearchRequest' in scope

错误2: /Users/ai/Desktop/qcarios/qcarios/Core/Services/MapService.swift:278:23
Value of type 'AMapSearchAPI' has no member 'aMapDrivingRouteSearch'
```

### 原因分析
1. 使用了错误的类名：`AMapDrivingRouteSearchRequest` 不存在
2. 使用了错误的方法名：`aMapDrivingRouteSearch` 不存在

### 解决方案

#### 修改前
```swift
let request = AMapDrivingRouteSearchRequest()  // ❌ 错误的类名
request.strategy = 0
request.requireExtension = true
searchAPI.aMapDrivingRouteSearch(request)      // ❌ 错误的方法名
```

#### 修改后
```swift
let request = AMapDrivingCalRouteSearchRequest()  // ✅ 正确的类名
request.strategy = 32 // 高德推荐策略
searchAPI.aMapDrivingV2RouteSearch(request)       // ✅ 正确的方法名
```

### 变更内容

1. **类名更正**:
   - ❌ `AMapDrivingRouteSearchRequest` (不存在)
   - ✅ `AMapDrivingCalRouteSearchRequest` (正确)

2. **方法名更正**:
   - ❌ `aMapDrivingRouteSearch(_:)` (不存在)
   - ✅ `aMapDrivingV2RouteSearch(_:)` (正确，首字母小写)

3. **策略值更新**:
   旧版策略值（0-3）已废弃，新版使用 32-40 范围：
   - `32`: 默认，高德推荐（同高德地图APP默认）
   - `33`: 躲避拥堵
   - `34`: 高速优先
   - `35`: 不走高速
   - `36`: 避免收费
   - `37`: 躲避拥堵+高速优先
   - `38`: 躲避拥堵+避免收费
   - `39`: 躲避拥堵+不走高速
   - `40`: 躲避拥堵+高速优先+避免收费

3. **移除废弃属性**:
   - 移除了 `requireExtension` 属性（新版SDK不再需要）

### 影响范围
- ✅ `MapService.swift:250` - 路线规划请求类名
- ✅ `MapService.swift:278` - 路线规划API调用方法名
- ✅ `ROUTE_PLANNING.md` - 文档更新
- ✅ `BUG_FIXES.md` - 问题记录

### 验证方法
1. 编译项目，确认无编译错误
2. 运行应用，选择目的地
3. 验证路线规划功能正常工作
4. 检查控制台日志，确认返回详细路线

### 参考文档
- 高德地图SDK头文件: `AMapSearchKit.framework/Headers/AMapSearchObj.h`
- 相关类定义: `AMapDrivingCalRouteSearchRequest`
- 继承关系: `AMapDrivingCalRouteSearchRequest` → `AMapRouteSearchBaseRequest` → `AMapSearchObject`

---

## 2025-12-28: MAPolylineRenderer 边框属性不存在

### 问题描述
```
/Users/ai/Desktop/qcarios/qcarios/Shared/Components/MapView.swift:154:27
Value of type 'MAPolylineRenderer' has no member 'borderColor'
```

### 原因分析
高德地图SDK的 `MAPolylineRenderer` 类不支持 `borderColor` 和 `borderWidth` 属性。这些是iOS原生MapKit的属性，高德地图没有提供。

### 解决方案

#### 修改前
```swift
renderer!.lineWidth = 8
renderer!.strokeColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.9)
renderer!.lineJoinType = kMALineJoinRound
renderer!.lineCapType = kMALineCapRound
renderer!.borderColor = UIColor.white.withAlphaComponent(0.5)  // ❌ 不支持
renderer!.borderWidth = 2  // ❌ 不支持
```

#### 修改后
```swift
renderer!.lineWidth = 8
renderer!.strokeColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.9)
renderer!.lineJoinType = kMALineJoinRound
renderer!.lineCapType = kMALineCapRound
// 移除了 borderColor 和 borderWidth
```

### 影响范围
- ✅ `MapView.swift:154-155` - 移除不支持的属性
- ✅ `ROUTE_PLANNING.md` - 文档更新，移除边框相关描述

### 备注
虽然无法添加边框，但路线依然清晰可见，因为：
- 使用了较粗的线宽（8pt）
- 蓝色与地图背景对比度好
- 圆角连接使路线更加平滑

---

## 2025-12-28: 路线规划调试 - 只显示两点问题

### 问题描述
用户反馈：路线规划功能只显示起点和终点两个标注点，没有显示完整的路线路径。

### 调试方法

为了诊断这个问题，我们在关键位置添加了详细的日志输出：

#### 1. MapService.calculateRoute() - 路线计算服务
**位置**: `MapService.swift:240-347`

添加的日志:
- API请求前的参数验证
- API响应的类型检查
- 路线数据的详细解析
- 每个路段的polyline字符串长度和解析结果
- 最终返回的坐标点总数

```swift
print("🗺️ [MapService] 开始计算路线...")
print("📍 起点: \(from.latitude), \(from.longitude)")
print("📍 终点: \(to.latitude), \(to.longitude)")
print("📤 [MapService] 发送路线规划请求...")
print("📥 [MapService] 收到API响应")
print("✅ [MapService] 响应类型正确: AMapRouteSearchResponse")
print("✅ [MapService] route 存在，路径数: \(route.paths.count)")
print("🛣️ 路段数: \(path.steps.count)")
print("   路段\(index+1): polyline 长度 = \(polyline.count) 字符")
print("   路段\(index+1): 解析出 \(coordinates.count) 个坐标点")
print("📍 [MapService] 总路线点数: \(polylineCoordinates.count)")
```

#### 2. PassengerHomeViewModel.calculateRoute() - 视图模型
**位置**: `PassengerHomeViewModel.swift:78-125`

添加的日志:
- 参数验证（起点和终点是否存在）
- 路线计算完成后的数据检查
- routePolyline属性设置确认

```swift
print("🚀 [ViewModel] 开始计算路线")
print("   起点: \(pickup.latitude), \(pickup.longitude)")
print("   终点: \(destination.location.latitude), \(destination.location.longitude)")
print("✅ [ViewModel] 路线计算完成")
print("   距离: \(route.distance)米 (\(route.distanceKm)公里)")
print("   坐标点数: \(route.polyline.count)")
print("✅ [ViewModel] routePolyline 已设置: \(self.routePolyline?.count ?? 0) 个点")
```

#### 3. MapView.updatePolyline() - 地图视图更新
**位置**: `MapView.swift:82-109`

添加的日志:
- polyline数据接收确认
- 坐标点数量和首尾坐标
- MAPolyline对象创建和添加

```swift
print("🗺️ [MapView] 收到路线数据: \(coords.count) 个坐标点")
print("   第一个点: \(coords[0].latitude), \(coords[0].longitude)")
print("   最后一个点: \(coords[coords.count-1].latitude), \(coords[coords.count-1].longitude)")
print("✅ [MapView] 路线已添加到地图")
print("✅ [MapView] 地图视野已调整")
```

#### 4. MapView.rendererFor - 渲染器创建
**位置**: `MapView.swift:157-178`

添加的日志:
- 确认渲染器方法被调用
- overlay类型检查
- 渲染器配置确认

```swift
print("🎨 [MapView] rendererFor overlay 被调用")
print("✅ [MapView] overlay 是 MAPolyline，创建渲染器")
print("✅ [MapView] 渲染器配置完成: lineWidth=8, 蓝色")
```

### 使用方法

1. 在Xcode中运行应用
2. 打开控制台（View > Debug Area > Activate Console）
3. 选择目的地触发路线规划
4. 观察控制台输出，按顺序查看:
   - `[ViewModel]` 开始计算
   - `[MapService]` API调用和响应
   - `[MapService]` polyline解析过程
   - `[ViewModel]` 数据接收
   - `[MapView]` 视图更新
   - `[MapView]` 渲染器创建

### 可能的问题点

根据日志输出，可以诊断:

1. **API未返回polyline数据**
   - 如果看到 "polyline 为 nil" → API响应中缺少polyline字段
   - 检查高德地图SDK版本和API配置

2. **polyline解析失败**
   - 如果看到 "解析出 0 个坐标点" → decodePolyline函数有问题
   - 检查polyline字符串格式是否符合预期（"lng1,lat1;lng2,lat2;..."）

3. **数据未传递到View**
   - 如果 `[ViewModel]` 显示有数据，但 `[MapView]` 显示nil → 数据绑定问题
   - 检查 @Published 和 @Binding 是否正确

4. **渲染器未被调用**
   - 如果没有看到 "rendererFor overlay 被调用" → MAMapView代理问题
   - 检查delegate设置

### 下一步

完成调试后，根据日志输出确定问题所在，然后:
- 移除或注释掉调试日志（保留关键错误日志）
- 修复发现的问题
- 在ROUTE_PLANNING.md中更新解决方案

---

## 2025-12-29: 位置更新太频繁优化

### 问题描述
用户反馈：位置更新日志刷屏，控制台被大量位置更新信息占满，影响调试。

### 原因分析
1. **没有更新频率限制**: LocationService每次收到系统位置更新就立即发布，没有做任何过滤
2. **日志过于详细**: DEBUG模式下每次更新都打印5行详细信息（WGS-84坐标、GCJ-02坐标、偏移量、精度、时间）
3. **低精度位置未过滤**: 即使定位精度很差（>100米）也会更新

### 解决方案

#### 修改前
```swift
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }

    // 直接转换并发布，无任何过滤
    let convertedLocation = ...

    // 详细日志，每次都打印
    print("📍 位置更新:")
    print("   [WGS-84] 经度: ..., 纬度: ...")
    print("   [GCJ-02] 经度: ..., 纬度: ...")
    print("   偏移: ...")
    print("   精度: ...")
    print("   时间: ...")

    currentLocation = convertedLocation
    locationSubject.send(convertedLocation) // 每次都发布
}
```

#### 修改后
```swift
// 添加过滤参数
private var lastPublishedLocation: CLLocation?
private var lastPublishTime: Date?
private let minimumUpdateInterval: TimeInterval = 3.0 // 最小更新间隔3秒
private let minimumDistance: CLLocationDistance = 10.0 // 最小移动距离10米

func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }

    // 1. 过滤低精度位置
    guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100 else {
        return // 忽略精度差于100米的位置
    }

    let convertedLocation = ...

    // 2. 智能过滤：检查时间间隔和移动距离
    let shouldPublish = shouldPublishLocation(convertedLocation)

    if shouldPublish {
        // 3. 简化日志，单行显示关键信息
        print("📍 位置更新: (39.904200, 116.407396) 精度:15m")

        currentLocation = convertedLocation
        locationSubject.send(convertedLocation)

        lastPublishedLocation = convertedLocation
        lastPublishTime = Date()
    }
}

private func shouldPublishLocation(_ newLocation: CLLocation) -> Bool {
    guard let lastLocation = lastPublishedLocation,
          let lastTime = lastPublishTime else {
        return true // 首次更新
    }

    // 时间间隔检查
    let timeSinceLastUpdate = Date().timeIntervalSince(lastTime)
    if timeSinceLastUpdate < minimumUpdateInterval {
        return false // 更新太频繁
    }

    // 移动距离检查
    let distance = newLocation.distance(from: lastLocation)
    if distance < minimumDistance {
        return false // 移动距离太小
    }

    return true
}
```

### 变更内容

1. **精度过滤**:
   - 只接受精度≤100米的位置
   - 忽略低质量的定位数据

2. **时间间隔限制**:
   - 最小更新间隔：3秒
   - 防止短时间内频繁更新

3. **距离过滤**:
   - 最小移动距离：10米
   - 避免微小移动触发更新

4. **日志优化**:
   - 从5行详细信息简化为1行关键信息
   - 只显示GCJ-02坐标和精度
   - 格式：`📍 位置更新: (纬度, 经度) 精度:Xm`

### 优化效果

**优化前**（控制台每秒可能有多条更新）:
```
📍 位置更新:
   [WGS-84] 经度: 116.407396, 纬度: 39.904200
   [GCJ-02] 经度: 116.413611, 纬度: 39.902304
   偏移: Δ经度: 0.006215, Δ纬度: -0.001896
   精度: 15.0m
   时间: 2025-12-29 10:23:45 +0000
📍 位置更新:
   [WGS-84] 经度: 116.407398, 纬度: 39.904202
   ...
```

**优化后**（最快3秒更新一次，且必须移动≥10米）:
```
📍 位置更新: (39.904200, 116.407396) 精度:15m
... (3秒后，移动10米以上)
📍 位置更新: (39.904350, 116.407520) 精度:12m
```

### 影响范围
- ✅ `LocationService.swift:36-40` - 添加过滤参数
- ✅ `LocationService.swift:59` - 调整distanceFilter配置
- ✅ `LocationService.swift:96-156` - 位置更新逻辑优化
- ✅ `BUG_FIXES.md` - 问题记录

### 配置参数说明

可以根据需要调整以下参数：

```swift
// 最小更新间隔（秒）
private let minimumUpdateInterval: TimeInterval = 3.0

// 最小移动距离（米）
private let minimumDistance: CLLocationDistance = 10.0

// 最大允许精度（米）
location.horizontalAccuracy <= 100
```

**使用场景建议**:
- **代驾行驶中**: 间隔3秒，距离10米（当前设置）
- **步行**: 间隔5秒，距离5米
- **静止等待**: 间隔10秒，距离20米

---

---

## 2025-12-29: 路线规划只显示两点 - showFieldType缺失

### 问题描述
路线规划功能只显示起点和终点两个标注点，没有显示完整的路线路径。

### 问题根源
**高德地图API默认不返回polyline数据**！必须在请求中显式设置 `showFieldType` 来包含polyline字段，否则API响应中不会包含详细的路线坐标点。

### 发现过程
1. 用户提供CSDN文章：https://blog.csdn.net/butterfly_new/article/details/135624928
2. 文章关键信息："需要在请求中设置显示字段类型，包括cost、tmcs、navi、cities和**polyline**等"
3. 检查代码发现：我们的请求中缺少 `showFieldType` 设置

### 解决方案

#### 修改前
```swift
let request = AMapDrivingCalRouteSearchRequest()
request.origin = AMapGeoPoint.location(...)
request.destination = AMapGeoPoint.location(...)
request.strategy = 32

// ❌ 缺少showFieldType设置，导致API不返回polyline
searchAPI.aMapDrivingV2RouteSearch(request)
```

#### 修改后
```swift
let request = AMapDrivingCalRouteSearchRequest()
request.origin = AMapGeoPoint.location(...)
request.destination = AMapGeoPoint.location(...)
request.strategy = 32

// ✅ 关键：必须设置返回字段类型，包括polyline
request.showFieldType = AMapDrivingRouteShowFieldType(
    rawValue: AMapDrivingRouteShowFieldType.cost.rawValue |
              AMapDrivingRouteShowFieldType.tmcs.rawValue |
              AMapDrivingRouteShowFieldType.navi.rawValue |
              AMapDrivingRouteShowFieldType.cities.rawValue |
              AMapDrivingRouteShowFieldType.polyline.rawValue
)!

searchAPI.aMapDrivingV2RouteSearch(request)
```

### 技术说明

**showFieldType属性的作用**:
使用位运算组合多个字段类型来请求返回的数据：
- `AMapDrivingRouteShowFieldType.polyline`: 详细路线坐标串
- `AMapDrivingRouteShowFieldType.cost`: 费用信息（如过路费）
- `AMapDrivingRouteShowFieldType.tmcs`: 交通路况信息
- `AMapDrivingRouteShowFieldType.navi`: 导航信息
- `AMapDrivingRouteShowFieldType.cities`: 途径城市

**为什么之前看到2个点**:
```swift
// MapService.swift 降级逻辑
if polylineCoordinates.isEmpty {
    print("⚠️ [MapService] 无详细路线，使用起终点连线")
    polylineCoordinates = [from, to]  // 只有起点和终点
}
```

由于API没有返回polyline，`polylineCoordinates`为空，触发降级逻辑，只返回起终点连线。

### 影响范围
- ✅ `MapService.swift:279-285` - 添加 `request.showFieldType` 设置
- ✅ `BUG_FIXES.md` - 问题记录和解决方案
- ✅ `ROUTE_PLANNING.md` - 更新API调用示例

### 验证方法

运行应用后，控制台应该显示：

```
🗺️ [MapService] 开始计算路线...
📤 [MapService] 发送路线规划请求...
📥 [MapService] 收到API响应
✅ [MapService] 路线计算成功
📍 [MapService] 使用 path.polyline (整体路线)
   polyline 长度: 1243 字符  ← 不再为空！
   解析出 342 个坐标点        ← 不再是0！
📍 [MapService] 总路线点数: 342

✅ [ViewModel] 路线计算完成
   坐标点数: 342              ← 不再是2！

🗺️ [MapView] 收到路线数据: 342 个坐标点
✅ [MapView] 路线已添加到地图
```

地图上应该显示完整的蓝色驾车路线，而不是只有起终点连线。

### 参考资料
- CSDN文章: https://blog.csdn.net/butterfly_new/article/details/135624928
- 高德地图iOS SDK文档: AMapDrivingCalRouteSearchRequest类说明

---

## Bug #6: 路径规划成功后地图持续刷新

### 问题描述
**日期**: 2025-12-29
**报告者**: 用户反馈

路径规划成功后，地图应该显示为静态页面，但实际上持续触发重绘，导致不必要的性能开销。

### 症状
- 路线已经绘制成功，但 `updatePolyline()` 继续被调用
- 每次调用都移除再添加相同的路线
- 造成不必要的CPU和GPU消耗

### 根本原因
`MapView` 的 `updateUIView()` 方法会在 SwiftUI 状态变化时频繁调用，即使路线数据没有实际改变，`updatePolyline()` 也会执行完整的移除+添加逻辑。

缺少对路线状态的跟踪和比较机制。

### 解决方案

#### 1. 在 Coordinator 中添加状态跟踪
**文件**: `qcarios/Shared/Components/MapView.swift:111`

```swift
class Coordinator: NSObject, MAMapViewDelegate {
    var parent: MapView
    var currentPolylineCount: Int = 0  // 跟踪当前路线点数

    init(_ parent: MapView) {
        self.parent = parent
    }
```

#### 2. 在 updatePolyline 中实现智能比较
**文件**: `qcarios/Shared/Components/MapView.swift:92-112`

```swift
private func updatePolyline(mapView: MAMapView, context: Context) {
    let newCount = polyline?.count ?? 0

    // 只有当路线实际发生变化时才更新（避免不必要的重绘）
    if newCount != context.coordinator.currentPolylineCount {
        // 移除旧路线
        if let overlays = mapView.overlays {
            mapView.removeOverlads(overlays)
        }

        // 添加新路线
        if let coords = polyline, !coords.isEmpty {
            var coordinates = coords
            let polyline = MAPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
            mapView.add(polyline)
            mapView.showOverlays([polyline], edgePadding: UIEdgeInsets(top: 100, left: 50, bottom: 100, right: 50), animated: true)
        }

        context.coordinator.currentPolylineCount = newCount
    }
}
```

### 优化效果
- ✅ 路线绘制成功后，地图变为静态显示
- ✅ 消除不必要的overlay移除/添加操作
- ✅ 显著降低CPU和GPU使用率
- ✅ 保持与标注更新相同的优化模式

### 技术要点
1. **状态跟踪**: 使用 `currentPolylineCount` 跟踪已绘制的路线
2. **智能比较**: 比较新旧路线点数，只在真正改变时更新
3. **性能优化**: 避免重复的图形渲染操作
4. **一致性**: 与 `updateAnnotations()` 采用相同的优化模式

### 测试验证
测试场景：
1. 选择目的地并计算路线
2. 观察路线绘制后控制台输出
3. 确认没有重复的overlay操作
4. 验证地图保持静态显示

---

## Bug #7: 地图中心点更新太频繁

### 问题描述
**日期**: 2025-12-29
**报告者**: 用户反馈 "位置居中太频繁"

地图视角不断跟随位置更新而移动，即使是微小的位置变化也会触发地图中心点动画移动，导致用户体验不佳。

### 症状
- 地图中心点频繁移动，视角不稳定
- 即使用户手动拖动地图，也会被强制拉回中心点
- 路线规划后无法静态查看路线全貌

### 根本原因
`MapView.updateUIView()` 中的中心点更新逻辑过于敏感：
```swift
// 问题代码：任何微小差异都会触发更新
if mapView.centerCoordinate.latitude != centerCoordinate.latitude ||
   mapView.centerCoordinate.longitude != centerCoordinate.longitude {
    mapView.setCenter(centerCoordinate, animated: true)
}
```

由于浮点数精度问题和频繁的位置更新，即使是 0.000001 度的差异也会触发地图移动。

### 解决方案

#### 1. 在 Coordinator 中添加中心点跟踪
**文件**: `qcarios/Shared/Components/MapView.swift:119`

```swift
class Coordinator: NSObject, MAMapViewDelegate {
    var parent: MapView
    var currentPolylineCount: Int = 0
    var lastCenterCoordinate: CLLocationCoordinate2D?  // 跟踪上次中心点

    init(_ parent: MapView) {
        self.parent = parent
    }
```

#### 2. 添加智能判断方法
**文件**: `qcarios/Shared/Components/MapView.swift:65-81`

```swift
/// 判断是否需要更新地图中心点
private func shouldUpdateCenter(newCenter: CLLocationCoordinate2D, context: Context) -> Bool {
    // 如果是首次设置，直接更新
    guard let lastCenter = context.coordinator.lastCenterCoordinate else {
        return true
    }

    // 计算两个坐标之间的距离（使用简单的度数差值）
    let latDiff = abs(newCenter.latitude - lastCenter.latitude)
    let lngDiff = abs(newCenter.longitude - lastCenter.longitude)

    // 只有当移动距离超过阈值时才更新（约50米）
    // 经度1度约111km，纬度1度约111km，0.0005度约55米
    let threshold = 0.0005

    return latDiff > threshold || lngDiff > threshold
}
```

#### 3. 更新 updateUIView 逻辑
**文件**: `qcarios/Shared/Components/MapView.swift:45-57`

```swift
func updateUIView(_ mapView: MAMapView, context: Context) {
    // 更新中心点（智能判断，避免频繁移动）
    if shouldUpdateCenter(newCenter: centerCoordinate, context: context) {
        mapView.setCenter(centerCoordinate, animated: true)
        context.coordinator.lastCenterCoordinate = centerCoordinate
    }

    // 更新标注
    updateAnnotations(mapView: mapView, context: context)

    // 更新路线
    updatePolyline(mapView: mapView, context: context)
}
```

### 优化效果
- ✅ 地图中心点只在真正需要时才移动（移动距离 > 50米）
- ✅ 用户可以手动拖动地图查看周边区域
- ✅ 路线规划后地图保持静态，方便查看全貌
- ✅ 消除微小位置变化导致的视角抖动

### 阈值说明

**当前设置**: `0.0005度` ≈ **55米**

可根据使用场景调整：
```swift
// 更敏感（约20米）
let threshold = 0.0002

// 当前设置（约55米）- 推荐
let threshold = 0.0005

// 更宽松（约110米）
let threshold = 0.001
```

**建议**:
- **代驾行驶中**: 0.0005度（55米）- 平衡视角稳定性和跟踪准确性
- **步行导航**: 0.0002度（20米）- 更频繁更新
- **静态查看**: 0.001度（110米）- 基本不移动

### 配合其他优化

此优化与位置更新频率优化相辅相成：
1. **LocationService**: 控制位置数据发布频率（3秒/10米）
2. **MapView 中心点**: 控制地图视角移动频率（55米阈值）

双重过滤确保了稳定的用户体验。

### 测试验证
1. 运行应用，观察地图中心点行为
2. 手动拖动地图，确认不会立即被拉回
3. 进行路线规划，确认可以静态查看完整路线
4. 在车辆行驶时，确认视角跟随合理

---

## 其他已知问题

### 待办事项
- [x] 根据日志输出诊断路线显示问题 - **已解决：添加showFieldType**
- [x] 清理调试日志（保留关键日志） - **已完成**
- [x] 优化位置更新频率 - **已完成：三重过滤机制**
- [x] 修复标注动画重复问题 - **已完成：智能比较**
- [x] 防止路线绘制后持续刷新 - **已完成：状态跟踪**
- [x] 优化地图中心点更新频率 - **已完成：距离阈值**
- [ ] 测试不同策略的路线规划结果
- [ ] 添加路线规划失败的友好提示
- [ ] 实现路线规划缓存机制
- [ ] 优化长路线的坐标点数量（Douglas-Peucker算法）

---

更新时间: 2025-12-29
