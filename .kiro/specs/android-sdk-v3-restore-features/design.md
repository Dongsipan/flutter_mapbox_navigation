# Design Document - Android SDK v3 恢复临时禁用的功能

## Overview

本设计文档描述了如何使用 Mapbox Navigation SDK v3 核心 API 重新实现在 MVP 迁移过程中临时禁用的功能。由于 SDK v3 完全移除了 Drop-in UI 组件（NavigationView），我们需要使用核心 API 手动实现这些功能。

设计目标：
- 使用 SDK v3 核心 API 替代已移除的 Drop-in UI
- 保持与 Flutter 层的 API 兼容性
- 确保功能完整性和稳定性
- 遵循 Android 和 Kotlin 最佳实践

## Architecture

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter Layer                          │
│  (MethodChannel + EventChannel)                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              TurnByTurn (Kotlin)                            │
│  - 处理 Flutter 方法调用                                     │
│  - 管理导航生命周期                                          │
│  - 发送事件到 Flutter                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│         MapboxNavigationApp (SDK v3)                        │
│  - MapboxNavigation 实例管理                                │
│  - 生命周期管理                                              │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│ MapView  │  │ Observers│  │ Replayer │
│          │  │          │  │          │
└──────────┘  └──────────┘  └──────────┘
```

### 核心组件

1. **TurnByTurn**: 主要的导航控制类
   - 处理 Flutter 方法调用
   - 管理 MapboxNavigation 实例
   - 注册和管理观察者
   - 发送事件到 Flutter

2. **MapboxNavigationApp**: SDK v3 的导航应用管理器
   - 管理 MapboxNavigation 单例
   - 处理生命周期事件
   - 提供导航功能访问

3. **Observers**: 各种观察者监听导航事件
   - LocationObserver: 位置更新
   - RouteProgressObserver: 导航进度
   - RoutesObserver: 路线更新
   - ArrivalObserver: 到达事件
   - OffRouteObserver: 偏离路线
   - BannerInstructionsObserver: 横幅指令
   - VoiceInstructionsObserver: 语音指令

## Components and Interfaces

### 1. Free Drive 模式实现

**目的**: 启动无目的地的位置跟踪模式

**实现方式**:
```kotlin
private fun startFreeDrive() {
    val mapboxNavigation = MapboxNavigationApp.current() ?: return
    
    // 启动 trip session 但不设置路线
    mapboxNavigation.startTripSession()
    
    // 发送事件到 Flutter
    PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_RUNNING)
}
```

**关键点**:
- 使用 `startTripSession()` 而不是 `startReplayTripSession()`
- 不调用 `setNavigationRoutes()`
- 位置更新通过 LocationObserver 自动处理

### 2. 路线预览和导航启动

**目的**: 在地图上显示路线并启动导航

**实现方式**:
```kotlin
// 在 NavigationActivity 中已实现
private fun startNavigation(routes: List<NavigationRoute>) {
    val mapboxNavigation = MapboxNavigationApp.current() ?: return
    
    // 设置路线
    mapboxNavigation.setNavigationRoutes(routes)
    
    // 根据模拟模式选择 trip session 类型
    if (FlutterMapboxNavigationPlugin.simulateRoute) {
        mapboxNavigation.startReplayTripSession()
    } else {
        mapboxNavigation.startTripSession()
    }
    
    // 发送事件
    PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_RUNNING)
}
```

**路线绘制**:
```kotlin
// 使用 MapboxRouteLineApi 和 MapboxRouteLineView
private lateinit var routeLineApi: MapboxRouteLineApi
private lateinit var routeLineView: MapboxRouteLineView

// 初始化
routeLineApi = MapboxRouteLineApi(MapboxRouteLineApiOptions.Builder().build())
routeLineView = MapboxRouteLineView(MapboxRouteLineViewOptions.Builder(context).build())

// 绘制路线
routeLineApi.setNavigationRoutes(routes) { result ->
    binding.mapView.mapboxMap.style?.let { style ->
        routeLineView.renderRouteDrawData(style, result)
    }
}
```

### 3. 地图点击回调

**目的**: 响应用户点击地图事件

**实现方式**:
```kotlin
private val onMapClick = OnMapClickListener { point ->
    val waypoint = mapOf(
        "latitude" to point.latitude().toString(),
        "longitude" to point.longitude().toString()
    )
    PluginUtilities.sendEvent(
        MapBoxEvents.ON_MAP_TAP, 
        JSONObject(waypoint).toString()
    )
    true
}

// 注册监听器
if (enableOnMapTapCallback) {
    binding.mapView.gestures.addOnMapClickListener(onMapClick)
}

// 注销监听器
override fun onDestroy() {
    binding.mapView.gestures.removeOnMapClickListener(onMapClick)
    super.onDestroy()
}
```

### 4. 长按设置目的地

**目的**: 长按地图快速规划路线

**实现方式**:
```kotlin
private val onMapLongClick = OnMapLongClickListener { point ->
    lastLocation?.let { location ->
        val waypointSet = WaypointSet()
        waypointSet.add(Waypoint(Point.fromLngLat(location.longitude, location.latitude)))
        waypointSet.add(Waypoint(point))
        requestRoutes(waypointSet)
    }
    true
}

// 注册监听器
if (longPressDestinationEnabled) {
    binding.mapView.gestures.addOnMapLongClickListener(onMapLongClick)
}

// 注销监听器
override fun onDestroy() {
    binding.mapView.gestures.removeOnMapLongClickListener(onMapLongClick)
    super.onDestroy()
}
```

### 5. 模拟导航支持

**目的**: 支持模拟导航用于测试

**实现方式**:
```kotlin
// 在 TurnByTurn 中
private fun startNavigation() {
    if (currentRoutes == null) {
        PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        return
    }
    
    val mapboxNavigation = MapboxNavigationApp.current() ?: return
    
    // 设置路线
    mapboxNavigation.setNavigationRoutes(currentRoutes!!)
    
    // 根据 simulateRoute 标志选择模式
    if (simulateRoute) {
        // 模拟导航
        mapboxNavigation.startReplayTripSession()
        
        // 可选：设置回放速度
        mapboxNavigation.mapboxReplayer.playbackSpeed(1.5)
    } else {
        // 真实导航
        mapboxNavigation.startTripSession()
    }
    
    PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_RUNNING)
}
```

### 6. 嵌入式导航视图

**目的**: 在 Flutter 应用中嵌入导航视图

**实现方式**:
```kotlin
class EmbeddedNavigationMapView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    arguments: Any?
) : PlatformView {
    
    private val binding: EmbeddedNavigationViewBinding
    private val navigationLocationProvider = NavigationLocationProvider()
    
    init {
        binding = EmbeddedNavigationViewBinding.inflate(
            LayoutInflater.from(context)
        )
        
        // 初始化 MapView
        binding.mapView.mapboxMap.loadStyle(Style.MAPBOX_STREETS)
        
        // 配置位置组件
        binding.mapView.location.apply {
            setLocationProvider(navigationLocationProvider)
            enabled = true
            pulsingEnabled = true
        }
        
        // 初始化导航
        initNavigation()
    }
    
    private fun initNavigation() {
        MapboxNavigationApp.setup {
            NavigationOptions.Builder(context).build()
        }
        
        // 注册观察者
        MapboxNavigationApp.current()?.registerLocationObserver(locationObserver)
        // ... 其他观察者
    }
    
    override fun getView(): View = binding.root
    
    override fun dispose() {
        // 注销观察者
        MapboxNavigationApp.current()?.unregisterLocationObserver(locationObserver)
        // ... 其他观察者
    }
}
```

### 7. 事件传递机制

**目的**: 确保所有导航事件正确发送到 Flutter

**实现方式**:
```kotlin
// 在 TurnByTurn 中
private fun registerObservers() {
    val navigation = MapboxNavigationApp.current() ?: return
    
    navigation.registerLocationObserver(locationObserver)
    navigation.registerRouteProgressObserver(routeProgressObserver)
    navigation.registerRoutesObserver(routesObserver)
    navigation.registerArrivalObserver(arrivalObserver)
    navigation.registerOffRouteObserver(offRouteObserver)
    navigation.registerBannerInstructionsObserver(bannerInstructionObserver)
    navigation.registerVoiceInstructionsObserver(voiceInstructionObserver)
}

private fun unregisterObservers() {
    val navigation = MapboxNavigationApp.current() ?: return
    
    navigation.unregisterLocationObserver(locationObserver)
    navigation.unregisterRouteProgressObserver(routeProgressObserver)
    navigation.unregisterRoutesObserver(routesObserver)
    navigation.unregisterArrivalObserver(arrivalObserver)
    navigation.unregisterOffRouteObserver(offRouteObserver)
    navigation.unregisterBannerInstructionsObserver(bannerInstructionObserver)
    navigation.unregisterVoiceInstructionsObserver(voiceInstructionObserver)
}
```

## Data Models

### WaypointSet
```kotlin
class WaypointSet {
    private val waypoints = mutableListOf<Waypoint>()
    
    fun add(waypoint: Waypoint) {
        waypoints.add(waypoint)
    }
    
    fun coordinatesList(): List<Point> {
        return waypoints.map { it.point }
    }
    
    fun waypointsIndices(): List<Int> {
        return waypoints.mapIndexedNotNull { index, waypoint ->
            if (!waypoint.isSilent) index else null
        }
    }
    
    fun waypointsNames(): List<String> {
        return waypoints.map { it.name ?: "" }
    }
}
```

### Waypoint
```kotlin
data class Waypoint(
    val point: Point,
    val isSilent: Boolean = false,
    val name: String? = null
)
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*


### Property 1: Free Drive 位置更新持续性
*For any* Free Drive session, the LocationObserver should continuously receive location updates until the session is stopped.
**Validates: Requirements 1.2**

### Property 2: Free Drive 位置显示
*For any* Free Drive session, the NavigationLocationProvider should be updated with each location change, ensuring the user's position is displayed on the map.
**Validates: Requirements 1.3**

### Property 3: Free Drive 事件传递
*For any* location update during Free Drive, a corresponding event should be sent to the Flutter EventSink.
**Validates: Requirements 1.4**

### Property 4: 路线绘制完整性
*For any* valid route, calling routeLineApi.setNavigationRoutes() should result in the route being rendered on the map.
**Validates: Requirements 2.1**

### Property 5: 相机边界包含路线
*For any* route preview, the camera bounds should include all route points with appropriate padding.
**Validates: Requirements 2.2**

### Property 6: 导航模式选择
*For any* navigation start request, the system should call startReplayTripSession() if simulateRoute is true, otherwise startTripSession().
**Validates: Requirements 2.4, 7.1, 7.2**

### Property 7: 嵌入式视图事件响应
*For any* registered gesture listener in embedded view, user interactions should trigger the corresponding callbacks.
**Validates: Requirements 3.3**

### Property 8: 地图点击事件触发
*For any* map click when enableOnMapTapCallback is true, the onMapClick callback should be invoked with the correct coordinates.
**Validates: Requirements 4.1**

### Property 9: 地图点击事件传递
*For any* map click event, the clicked coordinates should be sent to Flutter EventSink in the correct format.
**Validates: Requirements 4.2**

### Property 10: 长按路线构建
*For any* map long press when longPressDestinationEnabled is true, a route should be requested from current location to the long-pressed point.
**Validates: Requirements 5.1, 5.2**

### Property 11: 信息面板更新
*For any* route progress update during navigation, the info panel should display the updated distance and duration values.
**Validates: Requirements 6.2**

### Property 12: 模拟导航位置更新
*For any* simulated navigation session, the LocationObserver should receive location updates from the MapboxReplayer.
**Validates: Requirements 7.4**

## Error Handling

### 1. 空指针处理
```kotlin
// 安全获取 MapboxNavigation 实例
val mapboxNavigation = MapboxNavigationApp.current() ?: run {
    Log.e(TAG, "MapboxNavigation not initialized")
    PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
    return
}
```

### 2. 路线为空处理
```kotlin
private fun startNavigation() {
    if (currentRoutes == null || currentRoutes!!.isEmpty()) {
        Log.w(TAG, "No routes available for navigation")
        PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        return
    }
    // ... 继续导航
}
```

### 3. 位置不可用处理
```kotlin
private val onMapLongClick = OnMapLongClickListener { point ->
    lastLocation?.let { location ->
        // 使用当前位置
        requestRoutes(...)
    } ?: run {
        Log.w(TAG, "Current location not available")
        Toast.makeText(context, "等待定位...", Toast.LENGTH_SHORT).show()
    }
    true
}
```

### 4. 观察者注册失败处理
```kotlin
private fun registerObservers() {
    try {
        val navigation = MapboxNavigationApp.current() ?: throw IllegalStateException("Navigation not initialized")
        navigation.registerLocationObserver(locationObserver)
        // ... 其他观察者
    } catch (e: Exception) {
        Log.e(TAG, "Failed to register observers", e)
        PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
    }
}
```

### 5. 资源清理失败处理
```kotlin
override fun onDestroy() {
    try {
        unregisterObservers()
        binding.mapView.gestures.removeOnMapClickListener(onMapClick)
        binding.mapView.gestures.removeOnMapLongClickListener(onMapLongClick)
    } catch (e: Exception) {
        Log.e(TAG, "Error during cleanup", e)
    }
    super.onDestroy()
}
```

## Testing Strategy

### 单元测试

**目标**: 测试各个组件的独立功能

**测试内容**:
1. TurnByTurn 方法调用测试
   - 测试 startFreeDrive() 调用正确的 SDK 方法
   - 测试 startNavigation() 根据 simulateRoute 选择正确的模式
   - 测试 clearRoute() 正确清理资源

2. 事件发送测试
   - 测试各种导航事件正确发送到 EventSink
   - 测试事件数据格式正确

3. 观察者测试
   - 测试观察者正确注册和注销
   - 测试观察者回调正确处理事件

**示例**:
```kotlin
@Test
fun testStartFreeDrive_callsStartTripSession() {
    // Arrange
    val mockNavigation = mock(MapboxNavigation::class.java)
    whenever(MapboxNavigationApp.current()).thenReturn(mockNavigation)
    
    // Act
    turnByTurn.startFreeDrive()
    
    // Assert
    verify(mockNavigation).startTripSession()
    verify(mockNavigation, never()).setNavigationRoutes(any())
}
```

### 集成测试

**目标**: 测试组件之间的交互

**测试内容**:
1. Flutter 到 Android 的方法调用
   - 测试 MethodChannel 调用触发正确的 Android 方法
   - 测试参数正确传递

2. Android 到 Flutter 的事件传递
   - 测试导航事件正确发送到 Flutter
   - 测试事件数据完整性

3. 完整导航流程
   - 测试从路线构建到导航完成的完整流程
   - 测试 Free Drive 模式的完整流程

**示例**:
```kotlin
@Test
fun testNavigationFlow_fromRouteToArrival() {
    // 1. 构建路线
    turnByTurn.buildRoute(routeOptions)
    verify(eventSink).success(contains("ROUTE_BUILT"))
    
    // 2. 启动导航
    turnByTurn.startNavigation()
    verify(eventSink).success(contains("NAVIGATION_RUNNING"))
    
    // 3. 模拟到达
    arrivalObserver.onFinalDestinationArrival(mockRouteProgress)
    verify(eventSink).success(contains("ON_ARRIVAL"))
}
```

### 手动测试

**目标**: 验证 UI 和用户体验

**测试场景**:
1. Free Drive 模式
   - 启动 Free Drive
   - 验证位置持续更新
   - 验证地图跟随用户移动
   - 停止 Free Drive

2. 导航流程
   - 设置起点和终点
   - 构建路线
   - 预览路线
   - 启动导航
   - 完成导航

3. 地图交互
   - 点击地图
   - 长按地图设置目的地
   - 验证事件传递到 Flutter

4. 模拟导航
   - 启用模拟模式
   - 启动导航
   - 验证模拟位置更新
   - 验证导航进度

### 测试配置

**单元测试框架**: JUnit 4 + Mockito
**集成测试框架**: AndroidX Test + Espresso
**最小测试覆盖率**: 80%

**测试命令**:
```bash
# 运行单元测试
./gradlew test

# 运行集成测试
./gradlew connectedAndroidTest

# 生成测试覆盖率报告
./gradlew jacocoTestReport
```

## Implementation Notes

### 1. 生命周期管理

**关键点**:
- 使用 MapboxNavigationApp 管理导航生命周期
- 在 Activity/Fragment 的 onCreate 中初始化
- 在 onDestroy 中清理资源
- 使用 LifecycleOwner 自动管理

**示例**:
```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    
    MapboxNavigationApp
        .setup { NavigationOptions.Builder(this).build() }
        .attach(this) // this 是 LifecycleOwner
}
```

### 2. 线程安全

**关键点**:
- 所有 UI 更新必须在主线程
- 使用 lifecycleScope 处理异步操作
- 避免在观察者回调中执行耗时操作

**示例**:
```kotlin
private val routeProgressObserver = RouteProgressObserver { routeProgress ->
    lifecycleScope.launch(Dispatchers.Main) {
        updateNavigationUI(routeProgress)
    }
}
```

### 3. 内存管理

**关键点**:
- 及时注销观察者
- 移除地图监听器
- 清理 MapboxNavigation 引用

**示例**:
```kotlin
override fun onDestroy() {
    unregisterObservers()
    binding.mapView.gestures.removeOnMapClickListener(onMapClick)
    binding.mapView.gestures.removeOnMapLongClickListener(onMapLongClick)
    super.onDestroy()
}
```

### 4. 向后兼容性

**关键点**:
- 保持 MethodChannel 方法签名不变
- 保持事件格式不变
- 支持所有现有配置选项

**示例**:
```kotlin
override fun onMethodCall(methodCall: MethodCall, result: MethodChannel.Result) {
    when (methodCall.method) {
        "startFreeDrive" -> {
            // 新实现，但接口不变
            startFreeDrive()
            result.success(true)
        }
        // ... 其他方法
    }
}
```

## Migration Path

### 从临时禁用到完整实现

**步骤 1**: 实现 Free Drive 模式
- 在 TurnByTurn.kt 中实现 startFreeDrive()
- 测试位置更新和事件传递
- 移除临时禁用标记

**步骤 2**: 实现路线预览和导航
- 在 TurnByTurn.kt 中实现 startNavigation()
- 添加路线绘制逻辑
- 测试完整导航流程

**步骤 3**: 实现地图交互
- 添加地图点击监听器
- 添加长按监听器
- 测试事件传递

**步骤 4**: 实现嵌入式视图
- 重写 EmbeddedNavigationMapView
- 使用核心 API 替代 NavigationView
- 测试视图生命周期

**步骤 5**: 完整测试和文档
- 运行所有测试
- 更新文档
- 发布新版本

## Performance Considerations

### 1. 位置更新频率
- 默认使用 SDK 推荐的更新频率
- 避免过于频繁的 UI 更新
- 使用节流机制减少事件发送

### 2. 地图渲染
- 使用 MapboxRouteLineApi 的缓存机制
- 避免频繁重绘路线
- 优化相机动画

### 3. 内存使用
- 及时清理不需要的资源
- 避免内存泄漏
- 监控内存使用情况

### 4. 电池消耗
- 使用合适的位置精度
- 在不需要时停止 trip session
- 优化后台运行

## Security Considerations

### 1. 权限管理
- 正确请求位置权限
- 处理权限拒绝情况
- 遵循 Android 权限最佳实践

### 2. 数据安全
- 不在日志中记录敏感信息
- 安全存储访问令牌
- 遵循数据保护法规

## Accessibility

### 1. 语音指令
- 支持语音播报
- 支持多语言
- 支持音量控制

### 2. UI 可访问性
- 使用合适的字体大小
- 提供足够的对比度
- 支持屏幕阅读器

---

**创建日期**: 2026-01-05
**最后更新**: 2026-01-05
**状态**: 设计完成，待审查
