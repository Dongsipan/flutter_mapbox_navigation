# 路线选择功能实现总结

## ✅ 实施完成

### 功能概述
为全屏导航添加了路线选择功能，支持用户在开始导航前查看并选择不同路线。

### 核心参数
- `autoBuildRoute: bool`（默认 `true`）
  - `true`: 直接计算路线并开始导航（默认行为）
  - `false`: 显示路线选择界面，用户选择后再开始导航

---

## 📁 已修改的文件

### Dart 层
1. **`lib/src/models/options.dart`**
   - ✅ 添加 `autoBuildRoute` 字段
   - ✅ 在构造函数中添加参数
   - ✅ 在 `MapBoxOptions.from` 中复制字段
   - ✅ 在 `toMap()` 中序列化字段

2. **`lib/src/flutter_mapbox_navigation.dart`**
   - ✅ 在默认选项中设置 `autoBuildRoute: true`

3. **`example/lib/route_selection_example.dart`** (新文件)
   - ✅ 创建了完整的使用示例

### iOS 层
1. **`ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/NavigationFactory.swift`**
   - ✅ 添加实例变量 `var _autoBuildRoute = true`
   - ✅ 在 `parseFlutterArguments` 中解析参数
   - ✅ 修改 `startNavigationWithWayPoints` 添加条件判断
   - ✅ 实现 `showRouteSelectionView` 方法

2. **`ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/RouteSelectionViewController.swift`** (新文件)
   - ✅ 实现完整的路线选择 UI
   - ✅ 使用正确的 `NavigationMapView` 初始化方式（Mapbox v3 API）
   - ✅ 实现备选路线选择功能（使用 `selecting(alternativeRoute:)`）
   - ✅ 添加底部操作按钮（取消/开始导航）

---

## 🔧 关键技术实现

### 1. NavigationMapView 初始化（Mapbox v3）
```swift
navigationMapView = NavigationMapView(
    location: mapboxNavigationProvider.navigation().locationMatching
        .map(\.mapMatchingResult.enhancedLocation)
        .eraseToAnyPublisher(),
    routeProgress: mapboxNavigationProvider.navigation().routeProgress
        .map(\.?.routeProgress)
        .eraseToAnyPublisher(),
    heading: mapboxNavigationProvider.navigation().heading,
    predictiveCacheManager: mapboxNavigationProvider.predictiveCacheManager
)
```

**关键点：**
- 使用 `mapboxNavigationProvider.navigation()` 方法访问 publishers
- `navigation()` 返回 `MapboxNavigation` 协议实例，包含所需的数据流
- `predictiveCacheManager` 直接从 provider 获取

### 2. 备选路线选择
```swift
func navigationMapView(_ navigationMapView: NavigationMapView, didSelect alternativeRoute: AlternativeRoute) {
    Task { @MainActor in
        if let newNavigationRoutes = await navigationRoutes.selecting(alternativeRoute: alternativeRoute) {
            navigationRoutes = newNavigationRoutes
            navigationMapView.showcase(newNavigationRoutes)
        }
    }
}
```

---

## 📖 使用方法

### 示例 1：直接开始导航（默认）
```dart
await MapBoxNavigation.instance.startNavigation(
  wayPoints: [
    WayPoint(name: '起点', latitude: 39.9042, longitude: 116.4074),
    WayPoint(name: '终点', latitude: 39.9162, longitude: 116.3978),
  ],
  options: MapBoxOptions(
    autoBuildRoute: true, // 可省略，默认就是 true
    alternatives: true,
    simulateRoute: true,
  ),
);
```

### 示例 2：显示路线选择界面
```dart
await MapBoxNavigation.instance.startNavigation(
  wayPoints: [
    WayPoint(name: '起点', latitude: 39.9042, longitude: 116.4074),
    WayPoint(name: '终点', latitude: 39.9162, longitude: 116.3978),
  ],
  options: MapBoxOptions(
    autoBuildRoute: false, // 关键：设置为 false
    alternatives: true, // 确保请求备选路线
    simulateRoute: true,
  ),
);
```

---

## 🎯 功能特性

### 路线选择界面包含：
- ✅ 地图视图显示所有可选路线
- ✅ 主路线和备选路线使用不同颜色区分
- ✅ 用户可点击地图切换路线
- ✅ 底部显示"取消"和"开始导航"按钮
- ✅ 选择路线后实时更新地图显示
- ✅ 点击"开始导航"启动实际导航

### 技术优势：
- ✅ 符合 Mapbox Navigation SDK v3 最佳实践
- ✅ 使用单例管理器避免多个 provider 实例
- ✅ 异步处理路线切换，避免阻塞 UI
- ✅ 完整的错误处理和日志输出

---

## 🚀 测试建议

1. **直接导航模式**
   ```dart
   // 使用 route_selection_example.dart
   // 点击"直接开始导航"按钮
   ```

2. **路线选择模式**
   ```dart
   // 使用 route_selection_example.dart
   // 点击"先选择路线再导航"按钮
   // 在地图上点击不同路线查看切换效果
   // 点击"开始导航"按钮启动导航
   ```

---

## 📝 注意事项

1. **必须启用备选路线**
   - 设置 `alternatives: true` 才能显示多条路线
   - 如果只有一条路线，选择界面仍会显示

2. **iOS 专属功能**
   - 目前仅实现了 iOS 平台
   - Android 平台暂未实现

3. **与嵌入式导航无关**
   - 此功能仅影响全屏导航模式
   - 嵌入式导航有自己的 `buildRoute` 方法

---

## 🔄 版本兼容性

- ✅ Mapbox Navigation SDK for iOS v3.x
- ✅ Flutter Mapbox Navigation Plugin (当前版本)
- ✅ 向后兼容（默认行为不变）

---

## 📚 参考文档

- [NavigationMapView 初始化](https://docs.mapbox.com/ios/navigation/api/3.9.2/navigation/documentation/mapboxnavigationcore/navigationmapview/)
- [AlternativeRoute 处理](https://docs.mapbox.com/ios/navigation/api/3.9.2/navigation/documentation/mapboxnavigationcore/alternativeroute/)
- [NavigationRoutes.selecting](https://docs.mapbox.com/ios/navigation/api/3.9.2/navigation/documentation/mapboxnavigationcore/navigationroutes/selecting(alternativeroute:)/)
- [迁移指南：NavigationMapView](https://docs.mapbox.com/ios/navigation/guides/migration/migrate-ui/#navigationmapview)
- [Predictive caching with NavigationMapView](https://docs.mapbox.com/ios/navigation/guides/advanced/offline/#predictive-caching-with-navigationmapview)
- [MapboxNavigationProvider API](https://docs.mapbox.com/ios/navigation/api/3.9.2/navigation/documentation/mapboxnavigationcore/mapboxnavigationprovider/)

---

## ⚠️ 常见问题与解决方案

### Q: 编译错误 - 找不到 locationMatching/routeProgress 属性
**A:** 确保使用 `mapboxNavigationProvider.navigation()` 方法而不是直接访问 `mapboxNavigationProvider.mapboxNavigation`。`navigation()` 方法返回包含所需 publishers 的 `MapboxNavigation` 协议实例。

### Q: NavigationMapView 初始化失败
**A:** 检查以下几点：
1. 确保 `MapboxNavigationProvider` 已正确初始化
2. 使用 `navigation()` 方法访问 publishers
3. 确认使用的是 Mapbox Navigation SDK v3.x 版本

### Q: 备选路线点击没有响应
**A:** 确保：
1. 已实现 `NavigationMapViewDelegate` 协议
2. 已设置 `navigationMapView.delegate = self`
3. 在请求路线时设置了 `alternatives: true`

