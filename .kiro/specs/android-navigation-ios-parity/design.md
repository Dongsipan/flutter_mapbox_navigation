# Design Document - Android 导航功能与 iOS 对齐

## Overview

本设计文档描述了如何在 Android 平台实现完整的转弯导航功能，以实现与 iOS 实现的功能对齐。设计基于 Mapbox Navigation SDK v3 的官方示例和最佳实践，重点是提供完整的导航体验，包括模拟导航支持、路线预览、主动引导以及所有导航模式。

### 设计目标

1. **功能对齐** - 实现与 iOS 端相同的导航功能和用户体验
2. **SDK v3 最佳实践** - 遵循 Mapbox 官方文档和示例的实现模式
3. **模拟导航支持** - 提供完整的模拟导航功能用于测试和演示
4. **事件通信** - 确保所有导航事件正确传递到 Flutter 层
5. **生命周期管理** - 正确管理资源和避免内存泄漏

### 参考资料

- [Mapbox Android Navigation SDK v3 Turn-by-Turn Example](https://docs.mapbox.com/android/navigation/examples/turn-by-turn-experience/)
- iOS NavigationFactory 实现
- 现有 Android TurnByTurn 实现

## Architecture

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter Layer                           │
│  (MethodChannel + EventChannel)                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              FlutterMapboxNavigationPlugin                   │
│  - Method call routing                                       │
│  - Event sink management                                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  NavigationActivity                          │
│  - Full-screen navigation UI                                │
│  - MapView + Navigation components                          │
│  - Lifecycle management                                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              MapboxNavigationApp / MapboxNavigation          │
│  - Core navigation engine                                    │
│  - Route calculation                                         │
│  - Trip session management                                   │
│  - Location tracking                                         │
└─────────────────────────────────────────────────────────────┘
```

### 核心组件

1. **NavigationActivity** - 全屏导航 Activity
   - 管理 MapView 和导航 UI 组件
   - 处理用户交互
   - 管理导航生命周期

2. **MapboxNavigationApp** - 导航应用管理器
   - 单例模式管理 MapboxNavigation 实例
   - 处理生命周期事件
   - 管理观察者注册

3. **Navigation Components**
   - MapboxRouteLineApi/View - 路线绘制
   - MapboxRouteArrowApi/View - 转弯箭头
   - MapboxManeuverApi - 转弯指令
   - MapboxTripProgressApi - 行程进度
   - NavigationCamera - 相机控制

4. **Observers** - 事件监听器
   - LocationObserver - 位置更新
   - RouteProgressObserver - 路线进度
   - VoiceInstructionsObserver - 语音指令
   - BannerInstructionsObserver - 横幅指令
   - ArrivalObserver - 到达检测
   - OffRouteObserver - 偏航检测
   - RoutesObserver - 路线变更

## Components and Interfaces

### NavigationActivity

```kotlin
class NavigationActivity : AppCompatActivity() {
    // View binding
    private lateinit var binding: ActivityNavigationBinding
    
    // Navigation components
    private lateinit var mapboxNavigation: MapboxNavigation
    private lateinit var navigationCamera: NavigationCamera
    private lateinit var viewportDataSource: MapboxNavigationViewportDataSource
    
    // Route rendering
    private lateinit var routeLineApi: MapboxRouteLineApi
    private lateinit var routeLineView: MapboxRouteLineView
    private lateinit var routeArrowApi: MapboxRouteArrowApi
    private lateinit var routeArrowView: MapboxRouteArrowView
    
    // UI components
    private lateinit var maneuverApi: MapboxManeuverApi
    private lateinit var tripProgressApi: MapboxTripProgressApi
    
    // Voice instructions
    private lateinit var speechApi: MapboxSpeechApi
    private lateinit var voiceInstructionsPlayer: MapboxVoiceInstructionsPlayer
    
    // Simulation
    private val replayRouteMapper = ReplayRouteMapper()
    private lateinit var replayProgressObserver: ReplayProgressObserver
    
    // Configuration
    private var simulateRoute: Boolean = false
    private var navigationRoutes: List<NavigationRoute>? = null
}
```

### 关键接口

#### 1. 导航初始化

```kotlin
private fun initNavigation() {
    MapboxNavigationApp.setup(
        NavigationOptions.Builder(this)
            .build()
    )
    
    // Initialize location puck
    binding.mapView.location.apply {
        setLocationProvider(navigationLocationProvider)
        locationPuck = LocationPuck2D(
            bearingImage = ImageHolder.from(R.drawable.mapbox_navigation_puck_icon)
        )
        puckBearingEnabled = true
        enabled = true
    }
}
```

#### 2. 路线计算

```kotlin
private fun findRoute(destination: Point) {
    val originLocation = navigationLocationProvider.lastLocation ?: return
    val originPoint = Point.fromLngLat(
        originLocation.longitude, 
        originLocation.latitude
    )
    
    mapboxNavigation.requestRoutes(
        RouteOptions.builder()
            .applyDefaultNavigationOptions()
            .applyLanguageAndVoiceUnitOptions(this)
            .coordinatesList(listOf(originPoint, destination))
            .build(),
        object : NavigationRouterCallback {
            override fun onRoutesReady(
                routes: List<NavigationRoute>,
                routerOrigin: String
            ) {
                setRouteAndStartNavigation(routes)
            }
            
            override fun onFailure(
                reasons: List<RouterFailure>,
                routeOptions: RouteOptions
            ) {
                // Handle failure
            }
            
            override fun onCanceled(
                routeOptions: RouteOptions,
                routerOrigin: String
            ) {
                // Handle cancellation
            }
        }
    )
}
```

#### 3. 启动导航

```kotlin
private fun setRouteAndStartNavigation(routes: List<NavigationRoute>) {
    // Set routes
    mapboxNavigation.setNavigationRoutes(routes)
    
    // Show UI elements
    binding.soundButton.visibility = View.VISIBLE
    binding.routeOverview.visibility = View.VISIBLE
    binding.tripProgressCard.visibility = View.VISIBLE
    
    // Move camera to overview
    navigationCamera.requestNavigationCameraToOverview()
    
    // Start simulation if enabled
    if (simulateRoute) {
        startSimulation(routes.first().directionsRoute)
    }
}
```

#### 4. 模拟导航

```kotlin
private fun startSimulation(route: DirectionsRoute) {
    mapboxNavigation.mapboxReplayer.stop()
    mapboxNavigation.mapboxReplayer.clearEvents()
    
    val replayData = replayRouteMapper.mapDirectionsRouteGeometry(route)
    mapboxNavigation.mapboxReplayer.pushEvents(replayData)
    mapboxNavigation.mapboxReplayer.seekTo(replayData[0])
    mapboxNavigation.mapboxReplayer.play()
}

private fun stopSimulation() {
    mapboxNavigation.mapboxReplayer.stop()
    mapboxNavigation.mapboxReplayer.clearEvents()
}
```

## Data Models

### NavigationConfiguration

```kotlin
data class NavigationConfiguration(
    val simulateRoute: Boolean = false,
    val navigationMode: String = "driving",
    val language: String = "en",
    val voiceUnits: String = "imperial",
    val mapStyleUrlDay: String? = null,
    val mapStyleUrlNight: String? = null,
    val alternatives: Boolean = true,
    val voiceInstructionsEnabled: Boolean = true,
    val bannerInstructionsEnabled: Boolean = true
)
```

### NavigationState

```kotlin
sealed class NavigationState {
    object Idle : NavigationState()
    object RoutePreview : NavigationState()
    object ActiveGuidance : NavigationState()
    object Arrived : NavigationState()
}
```

### NavigationEvent

```kotlin
sealed class NavigationEvent {
    data class RouteBuilt(val routes: List<NavigationRoute>) : NavigationEvent()
    object RouteBuildFailed : NavigationEvent()
    object NavigationRunning : NavigationEvent()
    object NavigationCancelled : NavigationEvent()
    data class ProgressUpdate(val progress: RouteProgress) : NavigationEvent()
    object Arrival : NavigationEvent()
    object OffRoute : NavigationEvent()
    data class VoiceInstruction(val instruction: String) : NavigationEvent()
    data class BannerInstruction(val instruction: String) : NavigationEvent()
}
```


## Correctness Properties

*属性(Property)是一个特征或行为,应该在系统的所有有效执行中保持为真——本质上是关于系统应该做什么的形式化陈述。属性作为人类可读规范和机器可验证正确性保证之间的桥梁。*

基于需求文档中的验收标准,我们定义以下正确性属性。这些属性将通过属性测试(Property-Based Testing)进行验证,确保导航功能在各种输入和场景下都能正确工作。

### Property 1: 导航模式映射正确性

*对于任何*导航模式参数("driving", "walking", "cycling"),系统应使用正确的 Mapbox 路由配置文件(PROFILE_DRIVING_TRAFFIC, PROFILE_WALKING, PROFILE_CYCLING)。

**验证: Requirements 4.1, 4.2, 4.3**

### Property 2: 模拟模式选择正确性

*对于任何* simulateRoute 布尔值,当为 true 时系统应调用 startReplayTripSession(),当为 false 时应调用 startTripSession()。

**验证: Requirements 2.1, 2.2**

### Property 3: 模拟导航事件生成

*对于任何*有效路线,当模拟导航激活时,系统应生成位置更新并触发所有导航事件(进度更新、语音指令、横幅指令)。

**验证: Requirements 2.3, 2.4**

### Property 4: 偏航检测和重新路由

*对于任何*路线,当位置更新偏离路线超过阈值时,系统应检测偏航并自动触发路线重新计算。

**验证: Requirements 3.3, 3.4**

### Property 5: 路线计算和显示

*对于任何*有效的航点列表,系统应成功计算路线并在地图上绘制路线线。

**验证: Requirements 5.1, 5.2**

### Property 6: 替代路线显示

*对于任何*路线计算结果,当 alternatives 为 true 且存在多条路线时,系统应在地图上显示所有路线。

**验证: Requirements 5.3, 15.2**

### Property 7: 语音指令条件启用

*对于任何* voiceInstructionsEnabled 值,系统应正确启用或禁用语音指导(注册/注销观察者或设置音量)。

**验证: Requirements 6.2, 6.3**

### Property 8: 语音指令播放

*对于任何*导航会话,当 voiceInstructionsEnabled 为 true 时,系统应在适当时机播放语音指令。

**验证: Requirements 6.1**

### Property 9: 横幅指令显示

*对于任何*导航会话,当 bannerInstructionsEnabled 为 true 时,系统应显示横幅指令。

**验证: Requirements 7.1, 7.2**

### Property 10: 路线进度持续跟踪

*对于任何*活动导航会话,系统应持续接收路线进度更新并更新距离和时间剩余值。

**验证: Requirements 8.1, 8.3, 8.4**

### Property 11: 进度事件通信

*对于任何*路线进度更新,系统应将进度事件序列化为 JSON 并通过 EventChannel 发送到 Flutter 层。

**验证: Requirements 8.2**

### Property 12: 到达检测

*对于任何*导航会话,当用户到达最终目的地时,系统应触发到达事件。

**验证: Requirements 9.1**

### Property 13: 航点到达检测

*对于任何*多航点路线,当用户到达中间航点时,系统应触发航点到达事件。

**验证: Requirements 9.2**

### Property 14: 相机跟踪初始化

*对于任何*导航启动,系统应启用相机跟踪并将相机设置为跟随模式。

**验证: Requirements 10.1**

### Property 15: 手动地图移动禁用自动跟踪

*对于任何*活动导航,当用户手动移动地图时,系统应暂时禁用相机自动跟踪。

**验证: Requirements 10.3**

### Property 16: 地图样式应用

*对于任何*提供的地图样式 URL(日间或夜间),系统应正确应用该样式到 MapView。

**验证: Requirements 11.1, 11.2**

### Property 17: 导航事件发送

*对于任何*导航状态变化(路线构建、导航开始、取消、偏航、重新路由),系统应发送相应的事件到 Flutter 层。

**验证: Requirements 12.1, 12.2, 12.3, 12.4, 12.5**

### Property 18: 生命周期初始化

*对于任何* NavigationActivity 创建,系统应正确初始化 MapboxNavigation 和所有必需的组件。

**验证: Requirements 13.1**

### Property 19: 生命周期清理

*对于任何* NavigationActivity 销毁,系统应注销所有观察者并清理所有资源。

**验证: Requirements 13.2**

### Property 20: 导航会话停止

*对于任何*导航结束操作,系统应停止 trip session 并清除路线。

**验证: Requirements 13.3**

### Property 21: 错误事件发送

*对于任何*路线计算失败或导航初始化失败,系统应发送包含错误详情的错误事件。

**验证: Requirements 14.1, 14.2**

### Property 22: 替代路线请求

*对于任何*路线计算,当 alternatives 参数为 true 时,RouteOptions 应包含替代路线请求。

**验证: Requirements 15.1**

### Property 23: 消失路线线启用

*对于任何*活动导航,系统应启用消失路线线功能。

**验证: Requirements 16.1**

### Property 24: 消失路线线进度更新

*对于任何*导航进度,系统应更新已行驶部分的路线线显示状态。

**验证: Requirements 16.2**

### Property 25: 多航点路线创建

*对于任何*多个航点,系统应创建包含多个路段的路线。

**验证: Requirements 17.1**

### Property 26: 路段自动推进

*对于任何*多路段路线,当到达航点时,系统应自动推进到下一路段。

**验证: Requirements 17.2**

### Property 27: 自由驾驶模式启动

*对于任何* startFreeDrive() 调用,系统应启动 trip session 而不设置路线。

**验证: Requirements 18.1**

### Property 28: 自由驾驶位置跟踪

*对于任何*自由驾驶会话,系统应跟踪并显示用户位置。

**验证: Requirements 18.2**

### Property 29: 历史记录启动

*对于任何*导航启动,当 enableHistoryRecording 为 true 时,系统应开始记录历史。

**验证: Requirements 19.1**

### Property 30: 历史记录保存

*对于任何*导航结束,当历史记录激活时,系统应停止记录并保存历史文件。

**验证: Requirements 19.2**

## Error Handling

### 错误类型

1. **路线计算错误**
   - 无效的航点
   - 网络连接失败
   - 服务器错误
   - 无可用路线

2. **导航初始化错误**
   - MapboxNavigation 初始化失败
   - 权限被拒绝
   - 资源不可用

3. **位置错误**
   - GPS 信号丢失
   - 位置权限被拒绝
   - 位置服务禁用

4. **生命周期错误**
   - Activity 意外销毁
   - 内存不足
   - 资源泄漏

### 错误处理策略

```kotlin
// 路线计算错误处理
override fun onFailure(
    reasons: List<RouterFailure>,
    routeOptions: RouteOptions
) {
    val errorMessage = reasons.joinToString { it.message }
    Log.e(TAG, "Route calculation failed: $errorMessage")
    
    // 发送错误事件到 Flutter
    PluginUtilities.sendEvent(
        MapBoxEvents.ROUTE_BUILD_FAILED,
        errorMessage
    )
    
    // 显示用户友好的错误消息
    Toast.makeText(
        this,
        "无法计算路线: $errorMessage",
        Toast.LENGTH_LONG
    ).show()
}

// 导航初始化错误处理
private fun initNavigation() {
    try {
        MapboxNavigationApp.setup(
            NavigationOptions.Builder(this).build()
        )
    } catch (e: Exception) {
        Log.e(TAG, "Navigation initialization failed", e)
        PluginUtilities.sendEvent(
            MapBoxEvents.NAVIGATION_CANCELLED,
            "Initialization failed: ${e.message}"
        )
        finish()
    }
}

// 位置错误处理
private val locationObserver = object : LocationObserver {
    override fun onNewRawLocation(rawLocation: Location) {
        // Handle raw location
    }
    
    override fun onNewLocationMatcherResult(
        locationMatcherResult: LocationMatcherResult
    ) {
        if (locationMatcherResult.enhancedLocation == null) {
            Log.w(TAG, "Location matching failed")
            // Continue with raw location if available
        }
    }
}

// 生命周期错误处理
override fun onDestroy() {
    try {
        unregisterObservers()
        stopSimulation()
        mapboxNavigation.onDestroy()
    } catch (e: Exception) {
        Log.e(TAG, "Error during cleanup", e)
    } finally {
        super.onDestroy()
    }
}
```

### 错误恢复

1. **自动重试** - 对于临时网络错误,自动重试路线计算
2. **降级处理** - GPS 信号弱时使用网络定位
3. **用户通知** - 清晰地告知用户错误原因和建议操作
4. **日志记录** - 记录所有错误以便调试

## Testing Strategy

### 测试方法

我们采用双重测试策略:

1. **单元测试** - 验证特定示例、边缘情况和错误条件
2. **属性测试** - 验证跨所有输入的通用属性

两者是互补的,对于全面覆盖都是必需的。

### 单元测试

单元测试专注于:
- 特定示例,演示正确行为
- 组件之间的集成点
- 边缘情况和错误条件

```kotlin
@Test
fun testNavigationModeMapping() {
    // 测试驾驶模式
    val drivingConfig = NavigationConfiguration(navigationMode = "driving")
    assertEquals(
        DirectionsCriteria.PROFILE_DRIVING_TRAFFIC,
        drivingConfig.toRouteProfile()
    )
    
    // 测试步行模式
    val walkingConfig = NavigationConfiguration(navigationMode = "walking")
    assertEquals(
        DirectionsCriteria.PROFILE_WALKING,
        walkingConfig.toRouteProfile()
    )
    
    // 测试骑行模式
    val cyclingConfig = NavigationConfiguration(navigationMode = "cycling")
    assertEquals(
        DirectionsCriteria.PROFILE_CYCLING,
        cyclingConfig.toRouteProfile()
    )
}

@Test
fun testSimulationModeSelection() {
    val activity = NavigationActivity()
    
    // 测试模拟模式
    activity.simulateRoute = true
    activity.startNavigation()
    verify(mapboxNavigation).startReplayTripSession()
    
    // 测试真实模式
    activity.simulateRoute = false
    activity.startNavigation()
    verify(mapboxNavigation).startTripSession()
}
```

### 属性测试

属性测试专注于:
- 跨所有输入的通用属性
- 通过随机化实现全面的输入覆盖

**配置**:
- 每个属性测试最少 100 次迭代
- 每个测试必须引用其设计文档属性
- 标签格式: **Feature: android-navigation-ios-parity, Property {number}: {property_text}**

```kotlin
@Property(tries = 100)
fun `Property 1 - Navigation mode mapping correctness`(
    @ForAll mode: @From("navigationModes") String
) {
    // Feature: android-navigation-ios-parity, Property 1: 导航模式映射正确性
    val config = NavigationConfiguration(navigationMode = mode)
    val profile = config.toRouteProfile()
    
    when (mode) {
        "driving" -> assertEquals(DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, profile)
        "walking" -> assertEquals(DirectionsCriteria.PROFILE_WALKING, profile)
        "cycling" -> assertEquals(DirectionsCriteria.PROFILE_CYCLING, profile)
    }
}

@Provide
fun navigationModes(): Arbitrary<String> {
    return Arbitraries.of("driving", "walking", "cycling")
}

@Property(tries = 100)
fun `Property 2 - Simulation mode selection correctness`(
    @ForAll simulateRoute: Boolean
) {
    // Feature: android-navigation-ios-parity, Property 2: 模拟模式选择正确性
    val activity = NavigationActivity()
    activity.simulateRoute = simulateRoute
    
    activity.startNavigation()
    
    if (simulateRoute) {
        verify(mapboxNavigation).startReplayTripSession()
    } else {
        verify(mapboxNavigation).startTripSession()
    }
}
```

### 测试库

- **JUnit 5** - 单元测试框架
- **jqwik** - 属性测试库(Java/Kotlin)
- **Mockito** - 模拟框架
- **Robolectric** - Android 单元测试
- **Espresso** - UI 测试(如需要)

### 测试覆盖目标

- 代码覆盖率: > 80%
- 属性覆盖率: 100%(所有定义的属性都有测试)
- 边缘情况覆盖: 关键路径的所有边缘情况

## Implementation Notes

### 关键实现要点

1. **遵循官方示例** - 严格遵循 Mapbox 官方 Turn-by-Turn 示例的实现模式
2. **使用 MapboxNavigationApp** - 使用 MapboxNavigationApp 进行生命周期管理
3. **正确的观察者管理** - 在适当的生命周期回调中注册和注销观察者
4. **模拟支持** - 使用 MapboxReplayer 和 ReplayRouteMapper 实现模拟导航
5. **事件通信** - 确保所有事件正确序列化并发送到 Flutter 层

### 与 iOS 对齐

确保以下方面与 iOS 实现对齐:

1. **方法签名** - Flutter 层的方法调用保持一致
2. **事件格式** - 事件 JSON 格式与 iOS 相同
3. **配置选项** - 支持相同的配置参数
4. **行为一致性** - 相同输入产生相同输出和事件序列

### 性能考虑

1. **内存管理** - 及时释放不再使用的资源
2. **电池优化** - 使用 SDK 的优化位置跟踪
3. **UI 流畅性** - 在后台线程执行耗时操作
4. **网络优化** - 缓存路线和地图数据

### 安全性

1. **权限检查** - 在使用前检查位置权限
2. **数据验证** - 验证来自 Flutter 层的所有输入
3. **错误处理** - 捕获并处理所有异常
4. **资源保护** - 防止资源泄漏和内存泄漏

---

**创建日期**: 2026-01-05
**状态**: 待审核
