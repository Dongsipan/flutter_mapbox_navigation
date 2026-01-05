# Vanishing Route Line 功能实现

## 功能描述

"消失路线"（Vanishing Route Line）功能可以让已经走过的路线变色（通常变灰或变透明），从而清晰地显示用户的导航进度。

## 实现日期
2026-01-05

## 实现内容

### 1. 配置 Route Line API

在 `initializeRouteLine()` 中启用 vanishing route line 功能：

```kotlin
private fun initializeRouteLine() {
    // 配置自定义颜色（官方规范：透明）
    val customColorResources = RouteLineColorResources.Builder()
        .routeLineTraveledColor(android.graphics.Color.TRANSPARENT) // 走过的路线变透明
        .routeLineTraveledCasingColor(android.graphics.Color.TRANSPARENT) // 走过路线的边框也透明
        .build()
    
    // 配置 API 选项
    val apiOptions = MapboxRouteLineApiOptions.Builder()
        .vanishingRouteLineEnabled(true) // 启用消失路线功能
        .styleInactiveRouteLegsIndependently(true) // 独立样式化非活动路段
        .build()
    
    // 配置视图选项
    val viewOptions = MapboxRouteLineViewOptions.Builder(this)
        .routeLineColorResources(customColorResources) // 应用自定义颜色
        .build()
    
    routeLineApi = MapboxRouteLineApi(apiOptions)
    routeLineView = MapboxRouteLineView(viewOptions)
}
```

### 2. 注册位置指示器监听器

添加 `OnIndicatorPositionChangedListener` 来更新走过的路线：

```kotlin
// 位置指示器监听器
private val onIndicatorPositionChangedListener = OnIndicatorPositionChangedListener { point ->
    // 根据当前位置更新走过的路线
    val result = routeLineApi.updateTraveledRouteLine(point)
    binding.mapView.mapboxMap.style?.let { style ->
        routeLineView.renderRouteLineUpdate(style, result)
    }
}
```

### 3. 在地图初始化时注册监听器

在 `initializeMap()` 中注册监听器：

```kotlin
binding.mapView.mapboxMap.loadStyle(styleUrl) {
    // Enable location component
    binding.mapView.location.updateSettings {
        enabled = true
        pulsingEnabled = true
    }
    
    // 注册位置变化监听器（用于消失路线功能）
    binding.mapView.location.addOnIndicatorPositionChangedListener(onIndicatorPositionChangedListener)
    
    android.util.Log.d(TAG, "Map style loaded successfully: $styleUrl")
}
```

### 4. 在销毁时移除监听器

在 `onDestroy()` 中移除监听器：

```kotlin
override fun onDestroy() {
    super.onDestroy()
    
    try {
        // ... 其他清理代码
        
        // 移除位置变化监听器
        binding.mapView.location.removeOnIndicatorPositionChangedListener(onIndicatorPositionChangedListener)
        
        // ... 其他清理代码
    } catch (e: Exception) {
        android.util.Log.e(TAG, "Error in onDestroy: ${e.message}", e)
    }
}
```

### 5. 在 RouteProgressObserver 中更新

`routeProgressObserver` 已经在调用 `updateWithRouteProgress`，这确保了路径点与导航进度的同步：

```kotlin
private val routeProgressObserver = RouteProgressObserver { routeProgress ->
    // Update UI
    updateNavigationUI(routeProgress)
    
    // Send progress event to Flutter
    val progressEvent = MapBoxRouteProgressEvent(routeProgress)
    FlutterMapboxNavigationPlugin.distanceRemaining = routeProgress.distanceRemaining
    FlutterMapboxNavigationPlugin.durationRemaining = routeProgress.durationRemaining
    sendEvent(progressEvent)
    
    // 更新路线（包括消失路线效果）
    routeLineApi.updateWithRouteProgress(routeProgress) { result ->
        binding.mapView.mapboxMap.style?.let { style ->
            routeLineView.renderRouteLineUpdate(style, result)
        }
    }
}
```

## 工作原理

### 三个关键组件

1. **配置启用**：
   - `vanishingRouteLineEnabled(true)` - 启用功能
   - `routeLineTraveledColor(Color.GRAY)` - 设置走过路线的颜色

2. **位置输入**：
   - `OnIndicatorPositionChangedListener` - 监听位置指示器变化
   - `updateTraveledRouteLine(point)` - 根据位置更新走过的路线

3. **进度输入**：
   - `RouteProgressObserver` - 监听导航进度
   - `updateWithRouteProgress(routeProgress)` - 根据进度更新路线

### 数据流

```
位置更新 → OnIndicatorPositionChangedListener
         ↓
    updateTraveledRouteLine(point)
         ↓
    renderRouteLineUpdate()
         ↓
    地图上的路线变色

导航进度 → RouteProgressObserver
         ↓
    updateWithRouteProgress(routeProgress)
         ↓
    renderRouteLineUpdate()
         ↓
    路线样式更新
```

## 视觉效果

- **未走过的路线**：蓝色（默认）
- **走过的路线**：透明（官方规范）
- **走过路线的边框**：透明

这样可以清晰地看到用户已经走过的路径，同时保持地图的简洁性。

## 自定义选项

### 修改颜色（如果需要自定义）

默认配置使用透明色（官方规范）。如果需要自定义为其他颜色：

```kotlin
val customColorResources = RouteLineColorResources.Builder()
    .routeLineTraveledColor(Color.parseColor("#808080")) // 自定义灰色
    .routeLineTraveledCasingColor(Color.parseColor("#404040")) // 自定义深灰色
    .routeDefaultColor(Color.parseColor("#3887BE")) // 未走过的路线颜色
    .routeCasingColor(Color.parseColor("#2C5F8D")) // 未走过路线的边框
    .build()
```

### 使用透明色（官方推荐）

当前实现使用透明色，这是 Mapbox 官方推荐的方式：

```kotlin
val customColorResources = RouteLineColorResources.Builder()
    .routeLineTraveledColor(Color.TRANSPARENT) // 完全透明（官方规范）
    .routeLineTraveledCasingColor(Color.TRANSPARENT) // 边框也透明
    .build()
```

### 修改不透明度

如果想要半透明效果：

```kotlin
val customColorResources = RouteLineColorResources.Builder()
    .routeLineTraveledColor(Color.argb(128, 128, 128, 128)) // 50% 透明的灰色
    .build()
```

## 修改的文件

1. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
   - `initializeRouteLine()` - 添加 vanishing route line 配置
   - `initializeMap()` - 注册位置指示器监听器
   - 添加 `onIndicatorPositionChangedListener` 监听器
   - `onDestroy()` - 移除监听器

## 测试验证

### 预期行为

1. **导航开始前**：
   - 整条路线显示为蓝色

2. **导航进行中**：
   - 已经走过的路线逐渐变为透明（消失）
   - 未走过的路线保持蓝色
   - 位置指示器（puck）后面的路线是透明的

3. **导航结束**：
   - 整条路线都变为透明

### 测试步骤

1. 启动应用并开始导航
2. 观察路线颜色变化
3. 确认走过的部分变为灰色
4. 确认未走过的部分保持蓝色

## 技术说明

### 为什么需要两个监听器？

1. **OnIndicatorPositionChangedListener**：
   - 监听位置指示器（puck）的位置变化
   - 提供精确的地图坐标
   - 用于实时更新走过的路线

2. **RouteProgressObserver**：
   - 监听导航进度
   - 提供路线上的进度信息
   - 用于同步路线样式和导航状态

两者配合使用可以确保：
- 路线颜色变化平滑
- 与导航进度同步
- 处理重新路由等特殊情况

### 性能考虑

- `updateTraveledRouteLine()` 是轻量级操作
- 只更新必要的路线段
- 不会影响导航性能

## 参考资料

- [Mapbox Navigation SDK v3 - Customize the route line](https://docs.mapbox.com/android/navigation/guides/customize-route-line/)
- [MapboxRouteLineApi API Reference](https://docs.mapbox.com/android/navigation/api/mapbox-navigation-ui-maps/)
- [RouteLineColorResources](https://docs.mapbox.com/android/navigation/api/mapbox-navigation-ui-maps/com.mapbox.navigation.ui.maps.route.line.model/-route-line-color-resources/)

---

**状态**: 实现完成 ✅
**编译状态**: ✅ 通过
**测试状态**: 待测试
**功能**: 走过的路线会变为透明（官方规范），清晰显示导航进度
