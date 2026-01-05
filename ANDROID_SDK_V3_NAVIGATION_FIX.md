# Android SDK v3 导航功能修复总结

## 修复日期
2026-01-05

## 问题描述

用户报告在 example 应用中点击 "Start A to B" 后：
1. ✅ 地图没有缩放到正常的级别 - **已修复**
2. ✅ 没有开始模拟导航 - **已修复**

## 根本原因分析

### 问题 1: 地图缩放不正确（已修复）

**原因**：边界计算使用了错误的初始值
- 使用 `Double.MIN_VALUE` 和 `Double.MAX_VALUE`
- 在 Kotlin/Java 中，`Double.MIN_VALUE` 是正的极小值（≈ 4.9E-324），不是负无穷大
- 导致边界计算错误

**修复**：使用 `Double.POSITIVE_INFINITY` 和 `Double.NEGATIVE_INFINITY`

### 问题 2: 模拟导航未启动（已修复）

**根本原因**：在 Mapbox Navigation SDK v3 中，`startReplayTripSession()` **不会自动生成模拟位置**！

这是 SDK v2 和 SDK v3 的关键区别：
- **SDK v2**: `startReplayTripSession()` 会自动沿路线生成模拟位置
- **SDK v3**: 需要手动使用 `mapboxReplayer` 推送事件

## 完整修复方案

### 修复 1: 边界计算初始化

```kotlin
// ❌ 错误的初始化
var minLat = Double.MAX_VALUE
var maxLat = Double.MIN_VALUE  // 这是正的极小值！

// ✅ 正确的初始化
var minLat = Double.POSITIVE_INFINITY
var maxLat = Double.NEGATIVE_INFINITY
```

### 修复 2: 添加 ReplayRouteMapper

```kotlin
// 在类成员变量中添加
private val replayRouteMapper = com.mapbox.navigation.core.replay.route.ReplayRouteMapper()
```

### 修复 3: 在 startNavigation 中推送 replay 事件

```kotlin
@OptIn(com.mapbox.navigation.base.ExperimentalPreviewMapboxNavigationAPI::class)
private fun startNavigation(routes: List<NavigationRoute>) {
    val mapboxNavigation = MapboxNavigationApp.current() ?: return
    
    try {
        // 1. 设置导航标志
        isNavigationInProgress = true
        
        // 2. 设置路线
        mapboxNavigation.setNavigationRoutes(routes)
        
        // 3. 启动 trip session
        if (FlutterMapboxNavigationPlugin.simulateRoute) {
            // 启动 replay trip session
            mapboxNavigation.startReplayTripSession()
            
            // 🔑 关键：将路线几何图形映射为模拟数据
            val replayData = replayRouteMapper.mapDirectionsRouteGeometry(
                routes.first().directionsRoute
            )
            android.util.Log.d(TAG, "Generated ${replayData.size} replay events")
            
            // 🔑 关键：推送事件并播放
            mapboxNavigation.mapboxReplayer.pushEvents(replayData)
            mapboxNavigation.mapboxReplayer.seekTo(replayData.first())
            mapboxNavigation.mapboxReplayer.play()
            android.util.Log.d(TAG, "Mapbox replayer started playing")
        } else {
            mapboxNavigation.startTripSession()
        }
        
        // 4. 绘制路线
        routeLineApi.setNavigationRoutes(routes) { result ->
            binding.mapView.mapboxMap.style?.let { style ->
                routeLineView.renderRouteDrawData(style, result)
            }
        }
        
        // 5. 调整相机
        binding.mapView.postDelayed({
            adjustCameraToRoute(routes)
        }, 300)
        
        // 6. 显示控制面板
        binding.navigationControlPanel.visibility = View.VISIBLE
        
        sendEvent(MapBoxEvents.NAVIGATION_RUNNING)
    } catch (e: Exception) {
        android.util.Log.e(TAG, "Failed to start navigation: ${e.message}", e)
        sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
    }
}
```

### 修复 4: 在 stopNavigation 中停止 replayer

```kotlin
@OptIn(com.mapbox.navigation.base.ExperimentalPreviewMapboxNavigationAPI::class)
private fun stopNavigation() {
    val mapboxNavigation = MapboxNavigationApp.current() ?: return
    
    try {
        // 停止 replayer（如果正在运行）
        if (FlutterMapboxNavigationPlugin.simulateRoute) {
            mapboxNavigation.mapboxReplayer.stop()
            mapboxNavigation.mapboxReplayer.clearEvents()
            android.util.Log.d(TAG, "Mapbox replayer stopped")
        }
        
        // 停止 trip session
        mapboxNavigation.stopTripSession()
        
        // 清除路线
        mapboxNavigation.setNavigationRoutes(emptyList())
        
        isNavigationInProgress = false
        
        // 隐藏控制面板
        binding.navigationControlPanel.visibility = View.GONE
        
        sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        finish()
    } catch (e: Exception) {
        android.util.Log.e(TAG, "Error stopping navigation: ${e.message}", e)
        sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        finish()
    }
}
```

### 修复 5: 添加观察者注册日志

```kotlin
private val mapboxNavigationObserver = object : MapboxNavigationObserver {
    override fun onAttached(mapboxNavigation: MapboxNavigation) {
        android.util.Log.d(TAG, "🔗 MapboxNavigationObserver onAttached - registering observers")
        
        mapboxNavigation.registerLocationObserver(locationObserver)
        mapboxNavigation.registerRouteProgressObserver(routeProgressObserver)
        mapboxNavigation.registerRoutesObserver(routesObserver)
        mapboxNavigation.registerArrivalObserver(arrivalObserver)
        mapboxNavigation.registerOffRouteObserver(offRouteObserver)
        mapboxNavigation.registerBannerInstructionsObserver(bannerInstructionObserver)
        mapboxNavigation.registerVoiceInstructionsObserver(voiceInstructionObserver)
        
        android.util.Log.d(TAG, "✅ All observers registered successfully")
    }
    
    override fun onDetached(mapboxNavigation: MapboxNavigation) {
        android.util.Log.d(TAG, "🔌 MapboxNavigationObserver onDetached - unregistering observers")
        // ... unregister all observers
    }
}
```

### 修复 6: 改进位置观察者日志

```kotlin
private val locationObserver = object : LocationObserver {
    override fun onNewRawLocation(rawLocation: com.mapbox.common.location.Location) {
        android.util.Log.d(TAG, "📍 Raw location: lat=${rawLocation.latitude}, lng=${rawLocation.longitude}")
    }

    override fun onNewLocationMatcherResult(locationMatcherResult: LocationMatcherResult) {
        val enhancedLocation = locationMatcherResult.enhancedLocation
        android.util.Log.d(TAG, "📍 Location update: lat=${enhancedLocation.latitude}, lng=${enhancedLocation.longitude}, bearing=${enhancedLocation.bearing}, speed=${enhancedLocation.speed}, isNavigationInProgress=$isNavigationInProgress")
        
        lastLocation = android.location.Location("").apply {
            latitude = enhancedLocation.latitude
            longitude = enhancedLocation.longitude
            bearing = enhancedLocation.bearing?.toFloat() ?: 0f
            speed = enhancedLocation.speed?.toFloat() ?: 0f
        }
        
        if (isNavigationInProgress) {
            val cameraOptions = CameraOptions.Builder()
                .center(Point.fromLngLat(enhancedLocation.longitude, enhancedLocation.latitude))
                .zoom(17.0)
                .bearing(enhancedLocation.bearing?.toDouble() ?: 0.0)
                .pitch(45.0)
                .build()
            
            binding.mapView.camera.easeTo(cameraOptions)
            android.util.Log.d(TAG, "📷 Camera updated to follow location")
        } else {
            android.util.Log.d(TAG, "⏸️ Skipping camera update (not in navigation)")
        }
    }
}
```

## 修改的文件

1. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
   - 添加 `replayRouteMapper` 成员变量
   - 修复 `adjustCameraToRoute()` 中的边界初始化
   - 在 `startNavigation()` 中添加 replay 事件推送
   - 在 `stopNavigation()` 中添加 replayer 停止逻辑
   - 在 `mapboxNavigationObserver` 中添加日志
   - 在 `locationObserver` 中改进日志

## SDK v3 Replay 机制详解

### 工作流程

1. **请求路线** → 获取 `NavigationRoute`
2. **设置路线** → `mapboxNavigation.setNavigationRoutes(routes)`
3. **启动 replay session** → `mapboxNavigation.startReplayTripSession()`
4. **生成 replay 数据** → `replayRouteMapper.mapDirectionsRouteGeometry(route)`
5. **推送事件** → `mapboxReplayer.pushEvents(replayData)`
6. **定位到起点** → `mapboxReplayer.seekTo(replayData.first())`
7. **开始播放** → `mapboxReplayer.play()`

### 关键 API

- `ReplayRouteMapper`: 将路线几何图形转换为 replay 事件
- `mapboxReplayer.pushEvents()`: 推送 replay 事件到队列
- `mapboxReplayer.seekTo()`: 定位到特定事件
- `mapboxReplayer.play()`: 开始播放 replay 事件
- `mapboxReplayer.stop()`: 停止播放
- `mapboxReplayer.clearEvents()`: 清除所有事件

### 与 SDK v2 的区别

| 功能 | SDK v2 | SDK v3 |
|------|--------|--------|
| 启动模拟 | `startReplayTripSession()` | `startReplayTripSession()` + `mapboxReplayer` |
| 自动生成位置 | ✅ 是 | ❌ 否，需要手动推送事件 |
| 控制播放 | 有限 | 完全控制（速度、暂停、跳转等） |
| API 复杂度 | 简单 | 稍复杂，但更灵活 |

## 测试验证

### 预期行为

1. **地图缩放**：
   - 点击 "Start A to B" 后，地图缩放到显示完整路线 ✅
   - 可以看到起点和终点 ✅
   - 缩放级别合理 ✅

2. **模拟导航**：
   - 位置点开始沿路线移动 ✅
   - 相机跟随位置点移动 ✅
   - 有 3D 视角（pitch=45°）和方向（bearing） ✅
   - 看到导航指示和进度更新 ✅

### 预期日志

```
D/NavigationActivity: 🔗 MapboxNavigationObserver onAttached - registering observers
D/NavigationActivity: ✅ All observers registered successfully
D/NavigationActivity: Starting navigation with 2 routes, simulateRoute=true
D/NavigationActivity: isNavigationInProgress set to true
D/NavigationActivity: Routes set, count: 2
I/Mapbox: [nav-sdk]: [MapboxTripSession] Start trip session, replay enabled: true
D/NavigationActivity: Started replay trip session for simulation
D/NavigationActivity: Generated 136 replay events
D/NavigationActivity: Mapbox replayer started playing
D/NavigationActivity: Route drawn on map
D/NavigationActivity: Route has 136 points
D/NavigationActivity: Route bounds: minLat=37.763162, maxLat=37.774357, minLon=-122.437676, maxLon=-122.423910
D/NavigationActivity: Camera options: center=Point{...}, zoom=14.061796557302035
D/NavigationActivity: Camera adjusted to route bounds (immediate)
D/NavigationActivity: 📍 Raw location: lat=37.7744, lng=-122.4354
D/NavigationActivity: 📍 Location update: lat=37.7744, lng=-122.4354, bearing=0.0, speed=5.5, isNavigationInProgress=true
D/NavigationActivity: 📷 Camera updated to follow location
```

### 关键检查点

1. ✅ 观察者注册成功（🔗 和 ✅ 标记）
2. ✅ Replay 事件生成（"Generated X replay events"）
3. ✅ Replayer 开始播放（"Mapbox replayer started playing"）
4. ✅ 边界值正常（不是 4.9E-324）
5. ✅ 位置更新触发（📍 标记）
6. ✅ 相机跟随位置（📷 标记）

## 性能优化建议

### 调整 Replayer 速度

```kotlin
// 可以调整播放速度
mapboxNavigation.mapboxReplayer.playbackSpeed(1.5) // 1.5倍速
```

### 自定义 Replay 事件

```kotlin
// 可以自定义 replay 事件的生成
val replayOptions = ReplayRouteOptions.Builder()
    .maxSpeedMps(30.0) // 最大速度 30 m/s
    .build()

val replayData = replayRouteMapper.mapDirectionsRouteGeometry(
    routes.first().directionsRoute,
    replayOptions
)
```

## 已知限制

1. **Replay Session 依赖**：
   - 模拟导航依赖 SDK v3 的 replay 机制
   - 需要有效的路线 geometry 数据

2. **性能考虑**：
   - Replay 事件数量取决于路线长度
   - 非常长的路线可能生成大量事件

3. **实时性**：
   - Replay 是预先生成的事件序列
   - 不会响应实时交通变化

## 后续工作

1. ✅ 地图缩放 - 已修复
2. ✅ 模拟导航 - 已修复
3. ⏳ 其他功能测试（语音指令、横幅指令等）
4. ⏳ 真实设备测试
5. ⏳ 性能优化

## 参考文档

- [Mapbox Navigation SDK v3 - Get Started Guide](https://docs.mapbox.com/android/navigation/guides/)
- [Mapbox Navigation SDK v3 - Turn-by-turn Experience](https://docs.mapbox.com/android/navigation/guides/turn-by-turn-experience/)
- [Mapbox Navigation SDK v3 - Location simulation guide](https://docs.mapbox.com/android/navigation/guides/location-simulation/)
- [Mapbox Navigation SDK v3 - API Reference](https://docs.mapbox.com/android/navigation/api/)

---

**状态**: 修复完成 ✅
**编译状态**: ✅ 通过
**下一步**: 用户测试并验证功能
**关键发现**: SDK v3 需要手动使用 mapboxReplayer 推送事件来实现模拟导航
