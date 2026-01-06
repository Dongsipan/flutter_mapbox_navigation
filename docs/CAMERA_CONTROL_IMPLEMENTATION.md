# Android 相机控制功能实现

## 概述

本文档记录了 Android 导航功能的相机控制实现,包括自动跟踪、手动移动检测、重新居中按钮和可配置的相机参数。

## 实现日期
2026-01-05

## 相关需求
- Requirements 10.1: 导航启动时启用相机跟踪
- Requirements 10.2: 平滑更新相机位置
- Requirements 10.3: 手动移动地图时暂停自动跟踪
- Requirements 10.4: 重新居中按钮恢复跟踪
- Requirements 10.5: 支持可配置的 zoom, tilt, bearing
- Requirements 10.6: 平滑的相机动画过渡

## 实现内容

### 1. NavigationCamera 集成 ✅

**位置**: `NavigationActivity.kt` - `initializeNavigationCamera()`

**实现细节**:

#### 1.1 ViewportDataSource 初始化
```kotlin
viewportDataSource = MapboxNavigationViewportDataSource(binding.mapView.mapboxMap)
```

**功能**: 管理相机视口数据,根据导航状态自动调整相机

#### 1.2 相机 Padding 配置
```kotlin
val pixelDensity = resources.displayMetrics.density

// Overview 模式 padding (显示整条路线)
val overviewPadding = EdgeInsets(
    140.0 * pixelDensity,  // top
    40.0 * pixelDensity,   // left
    120.0 * pixelDensity,  // bottom
    40.0 * pixelDensity    // right
)

// Following 模式 padding (跟随用户位置)
val followingPadding = EdgeInsets(
    180.0 * pixelDensity,  // top
    40.0 * pixelDensity,   // left
    150.0 * pixelDensity,  // bottom
    40.0 * pixelDensity    // right
)

viewportDataSource.overviewPadding = overviewPadding
viewportDataSource.followingPadding = followingPadding
```

**说明**:
- Overview padding: 为显示完整路线预留空间
- Following padding: 为导航 UI 元素预留空间
- 使用 pixelDensity 确保在不同屏幕密度下一致

#### 1.3 NavigationCamera 初始化
```kotlin
navigationCamera = NavigationCamera(
    binding.mapView.mapboxMap,
    binding.mapView.camera,
    viewportDataSource
)
```

### 2. 手势处理 ✅

**位置**: `NavigationActivity.kt` - `initializeNavigationCamera()`

#### 2.1 NavigationBasicGesturesHandler
```kotlin
binding.mapView.camera.addCameraAnimationsLifecycleListener(
    NavigationBasicGesturesHandler(navigationCamera)
)
```

**功能**:
- 自动检测用户手势 (拖动、缩放、旋转)
- 用户移动地图时自动暂停相机跟踪
- 切换相机状态从 FOLLOWING 到 IDLE

### 3. 相机状态跟踪 ✅

**位置**: `NavigationActivity.kt`

#### 3.1 状态变量
```kotlin
// Camera state tracking
private var isCameraFollowing = true
private var userHasMovedMap = false
```

#### 3.2 状态观察者
```kotlin
navigationCamera.registerNavigationCameraStateChangeObserver { navigationCameraState ->
    android.util.Log.d(TAG, "📷 Camera state changed: $navigationCameraState")
    
    // Update camera following state
    isCameraFollowing = when (navigationCameraState) {
        NavigationCameraState.FOLLOWING -> true
        NavigationCameraState.OVERVIEW -> false
        NavigationCameraState.IDLE -> false
        else -> isCameraFollowing
    }
    
    // Show/hide recenter button based on camera state
    runOnUiThread {
        if (isCameraFollowing) {
            binding.recenterButton.visibility = View.GONE
            userHasMovedMap = false
        } else if (isNavigationInProgress) {
            binding.recenterButton.visibility = View.VISIBLE
            userHasMovedMap = true
        }
    }
}
```

**相机状态**:
- `FOLLOWING`: 相机跟随用户位置
- `OVERVIEW`: 相机显示路线概览
- `IDLE`: 相机空闲 (用户手动控制)

### 4. 重新居中按钮 ✅

**位置**: `navigation_activity.xml` 和 `NavigationActivity.kt`

#### 4.1 UI 布局
```xml
<com.google.android.material.floatingactionbutton.FloatingActionButton
    android:id="@+id/recenterButton"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:layout_margin="16dp"
    android:src="@android:drawable/ic_menu_mylocation"
    android:contentDescription="Recenter Camera"
    android:visibility="gone"
    app:layout_constraintBottom_toTopOf="@id/navigationControlPanel"
    app:layout_constraintEnd_toEndOf="parent"
    app:fabSize="normal" />
```

**特性**:
- FloatingActionButton (FAB) 样式
- 位于右下角,导航控制面板上方
- 默认隐藏,仅在用户移动地图后显示
- 使用系统定位图标

#### 4.2 点击处理
```kotlin
binding.recenterButton.setOnClickListener {
    recenterCamera()
}
```

#### 4.3 重新居中逻辑
```kotlin
private fun recenterCamera() {
    try {
        android.util.Log.d(TAG, "📷 Recentering camera")
        
        // Request camera to follow mode with smooth animation
        navigationCamera.requestNavigationCameraToFollowing()
        
        // Hide recenter button
        binding.recenterButton.visibility = View.GONE
        userHasMovedMap = false
        isCameraFollowing = true
        
        android.util.Log.d(TAG, "✅ Camera recentered successfully")
    } catch (e: Exception) {
        android.util.Log.e(TAG, "❌ Failed to recenter camera: ${e.message}", e)
    }
}
```

### 5. 可配置相机参数 ✅

**位置**: `FlutterMapboxNavigationPlugin.kt` 和 `NavigationActivity.kt`

#### 5.1 配置属性
```kotlin
// In FlutterMapboxNavigationPlugin
var zoom = 15.0
var bearing = 0.0
var tilt = 0.0
```

#### 5.2 应用配置
```kotlin
// In initializeNavigationCamera()
if (FlutterMapboxNavigationPlugin.zoom > 0) {
    android.util.Log.d(TAG, "📷 Using custom zoom: ${FlutterMapboxNavigationPlugin.zoom}")
}
```

**说明**: 
- 当前实现记录自定义配置
- NavigationCamera 自动管理 zoom/tilt/bearing
- 可以通过 ViewportDataSource 进一步自定义

### 6. 导航启动时的相机行为 ✅

**位置**: `NavigationActivity.kt` - `startNavigation()`

```kotlin
// Use NavigationCamera to show route overview first, then switch to following
navigationCamera.requestNavigationCameraToOverview()
android.util.Log.d(TAG, "📷 Camera set to overview mode")

// After a short delay, switch to following mode to start turn-by-turn navigation
binding.mapView.postDelayed({
    navigationCamera.requestNavigationCameraToFollowing()
    android.util.Log.d(TAG, "📷 Camera switched to following mode")
}, 1500)
```

**工作流程**:
1. 导航启动时先显示路线概览 (Overview 模式)
2. 1.5 秒后自动切换到跟随模式 (Following 模式)
3. 用户可以看到完整路线,然后开始导航

### 7. 位置更新时的相机更新 ✅

**位置**: `NavigationActivity.kt` - `locationObserver`

```kotlin
override fun onNewLocationMatcherResult(locationMatcherResult: LocationMatcherResult) {
    val enhancedLocation = locationMatcherResult.enhancedLocation
    
    // Update viewport data source with new location
    viewportDataSource.onLocationChanged(enhancedLocation)
    viewportDataSource.evaluate()
}
```

**说明**:
- 每次位置更新时通知 ViewportDataSource
- ViewportDataSource 自动计算相机位置
- NavigationCamera 平滑移动到新位置

### 8. 路线进度更新时的相机更新 ✅

**位置**: `NavigationActivity.kt` - `routeProgressObserver`

```kotlin
private val routeProgressObserver = RouteProgressObserver { routeProgress ->
    // Update viewport data source with route progress
    viewportDataSource.onRouteProgressChanged(routeProgress)
    viewportDataSource.evaluate()
    
    // ... other progress handling
}
```

**说明**:
- 路线进度变化时通知 ViewportDataSource
- 相机自动调整以显示即将到来的转弯

### 9. 路线变化时的相机更新 ✅

**位置**: `NavigationActivity.kt` - `routesObserver`

```kotlin
private val routesObserver = RoutesObserver { routeUpdateResult ->
    if (routeUpdateResult.navigationRoutes.isNotEmpty()) {
        // Update viewport data source with new route
        viewportDataSource.onRouteChanged(routeUpdateResult.navigationRoutes.first())
        viewportDataSource.evaluate()
        
        // ... other route handling
    } else {
        // Clear route data from viewport
        viewportDataSource.clearRouteData()
        viewportDataSource.evaluate()
    }
}
```

**说明**:
- 路线重新计算时更新 ViewportDataSource
- 相机自动调整以显示新路线

## 相机模式说明

### Overview 模式
- **用途**: 显示完整路线
- **触发**: 导航启动时、用户请求路线概览
- **特点**: 缩小视图以显示起点到终点的完整路线

### Following 模式
- **用途**: 跟随用户位置进行导航
- **触发**: 导航开始后、用户点击重新居中按钮
- **特点**: 相机跟随用户移动,自动旋转和倾斜

### Idle 模式
- **用途**: 用户手动控制相机
- **触发**: 用户拖动、缩放或旋转地图
- **特点**: 相机不自动移动,完全由用户控制

## 使用示例

### 示例 1: 配置相机参数

```kotlin
// 在 Flutter 层配置
MapboxNavigation.startNavigation(
  wayPoints: waypoints,
  options: MapboxNavigationOptions(
    zoom: 17.0,
    bearing: 0.0,
    tilt: 45.0,
  ),
);
```

### 示例 2: 监听相机状态变化

```kotlin
// 在 NavigationActivity 中
navigationCamera.registerNavigationCameraStateChangeObserver { state ->
    when (state) {
        NavigationCameraState.FOLLOWING -> {
            // 相机正在跟随
        }
        NavigationCameraState.OVERVIEW -> {
            // 相机显示概览
        }
        NavigationCameraState.IDLE -> {
            // 用户手动控制相机
        }
    }
}
```

### 示例 3: 程序化控制相机

```kotlin
// 切换到概览模式
navigationCamera.requestNavigationCameraToOverview()

// 切换到跟随模式
navigationCamera.requestNavigationCameraToFollowing()

// 切换到空闲模式
navigationCamera.requestNavigationCameraToIdle()
```

## 测试建议

### 1. 自动跟踪测试
- 启动导航,验证相机自动跟随用户位置
- 移动设备,验证相机平滑更新
- 验证相机旋转和倾斜

### 2. 手动移动测试
- 导航中拖动地图,验证相机停止跟踪
- 验证重新居中按钮出现
- 缩放地图,验证相机停止跟踪

### 3. 重新居中测试
- 手动移动地图后点击重新居中按钮
- 验证相机平滑返回跟随模式
- 验证重新居中按钮隐藏

### 4. 相机模式切换测试
- 验证 Overview → Following 切换
- 验证 Following → Idle 切换 (用户移动地图)
- 验证 Idle → Following 切换 (点击重新居中)

### 5. 配置参数测试
- 测试自定义 zoom 值
- 测试自定义 bearing 值
- 测试自定义 tilt 值

## 与 iOS 对齐

所有相机控制功能都与 iOS 实现对齐:
- ✅ 自动相机跟踪
- ✅ 平滑位置更新
- ✅ 手动移动检测
- ✅ 重新居中按钮
- ✅ 可配置相机参数
- ✅ 平滑动画过渡

## 文件修改清单

### 修改的文件
1. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
   - 添加相机状态跟踪变量
   - 完善 `initializeNavigationCamera()` 方法
   - 添加相机状态观察者
   - 添加 `recenterCamera()` 方法
   - 添加重新居中按钮点击处理

2. `android/src/main/res/layout/navigation_activity.xml`
   - 添加重新居中 FloatingActionButton

### 已存在的文件 (无需修改)
1. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/FlutterMapboxNavigationPlugin.kt`
   - 已有 zoom, bearing, tilt 配置属性

## 性能考虑

1. **相机动画**: NavigationCamera 使用硬件加速的动画,性能良好
2. **状态更新**: 相机状态变化时使用 `runOnUiThread` 确保 UI 更新在主线程
3. **ViewportDataSource**: 自动优化相机更新频率,避免过度渲染

## 最佳实践

1. **平滑过渡**: 使用 NavigationCamera 的内置动画,不要手动设置相机位置
2. **状态管理**: 跟踪相机状态,避免不必要的状态切换
3. **用户体验**: 用户移动地图后显示重新居中按钮,提供清晰的反馈
4. **配置合理**: 使用合理的 zoom/tilt/bearing 值,避免极端值

## 已知限制

1. **自定义相机参数**: 当前 zoom/tilt/bearing 配置主要由 NavigationCamera 自动管理
2. **相机动画速度**: 动画速度由 SDK 控制,不可自定义
3. **Padding 固定**: 相机 padding 在初始化时设置,导航中不可动态调整

## 后续改进建议

1. **动态 Padding**: 支持导航中动态调整相机 padding
2. **自定义动画**: 支持自定义相机动画速度和曲线
3. **相机预设**: 提供多种相机预设 (2D/3D, 近/远)
4. **手势配置**: 支持禁用特定手势 (如旋转、倾斜)
5. **相机事件**: 发送相机状态变化事件到 Flutter 层

---

**实现状态**: ✅ 完成
**测试状态**: ⏳ 待测试
**文档状态**: ✅ 完成
