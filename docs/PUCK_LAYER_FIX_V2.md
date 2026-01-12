# Location Puck 层级修复 V2

## 问题描述

用户位置 puck（蓝色箭头图标）被路线遮挡，无法正常显示在地图最上层。

## 根本原因

Mapbox Maps SDK 的图层渲染顺序问题：
1. 路线层（route line layers）在初始化时可能被放置在较高的层级
2. Location puck 的层级设置不正确
3. `routeLineBelowLayerId` 设置可能导致路线层在不合适的位置

## 解决方案

### 1. 移除 `routeLineBelowLayerId` 限制

让路线层自动放置在默认位置，而不是强制指定在某个图层下方：

```kotlin
val viewOptions = MapboxRouteLineViewOptions.Builder(this)
    .routeLineColorResources(customColorResources)
    // 移除 .routeLineBelowLayerId("road-label-navigation")
    .build()
```

### 2. 使用 `topImage` 确保 Puck 可见性

在 `LocationPuck2D` 配置中同时设置 `topImage` 和 `bearingImage`：

```kotlin
binding.mapView.location.apply {
    setLocationProvider(navigationLocationProvider)
    this.locationPuck = LocationPuck2D(
        topImage = ImageHolder.from(
            com.mapbox.navigation.ui.maps.R.drawable.mapbox_navigation_puck_icon
        ),
        bearingImage = ImageHolder.from(
            com.mapbox.navigation.ui.maps.R.drawable.mapbox_navigation_puck_icon
        )
    )
    puckBearingEnabled = true
    enabled = true
}
```

**关键点**：
- `topImage`：在 2D 模式下显示的图标（最上层）
- `bearingImage`：带方向的图标（用于导航时显示方向）

### 3. 刷新 Location Puck 层级

在地图样式加载完成后，刷新 location puck 以确保它在最上层：

```kotlin
binding.mapView.mapboxMap.loadStyle(styleUrl) { style ->
    // 先初始化路线层
    routeLineView.initializeLayers(style)
    
    // 刷新 location puck 层级
    binding.mapView.location.apply {
        enabled = false
        enabled = true
    }
    
    // 注册位置监听器
    binding.mapView.location.addOnIndicatorPositionChangedListener(onIndicatorPositionChangedListener)
}
```

## 技术细节

### Mapbox 图层顺序（从下到上）

1. 地图底图层（roads, buildings, etc.）
2. 路线层（route lines）
3. 路线箭头层（route arrows）
4. 标签层（labels）
5. **Location puck 层（最上层）**

### LocationPuck2D 配置选项

- `topImage`：2D 视图中显示的主图标
- `bearingImage`：带方向指示的图标
- `shadowImage`：阴影图标（可选）
- `scaleExpression`：缩放表达式（可选）

## 修改文件

1. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
   - `initializeNavigation()` 方法：添加 `topImage` 配置
   - `initializeMap()` 方法：添加 puck 层级刷新逻辑
   - `initializeRouteLine()` 方法：移除 `routeLineBelowLayerId` 限制

## 测试验证

✅ 编译成功
```
Running Gradle task 'assembleDebug'...                             39.0s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

## 预期效果

- ✅ Location puck 始终显示在地图最上层
- ✅ 路线不会遮挡用户位置图标
- ✅ 导航时可以清晰看到用户位置和方向
- ✅ 路线、箭头、标签等其他元素正常显示

## 参考

- Mapbox Navigation Android SDK v3 官方文档
- LocationPuck2D API 文档
- MapboxRouteLineView 层级管理
