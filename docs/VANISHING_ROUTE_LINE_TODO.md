# Vanishing Route Line 功能待实现

## 功能描述

在导航过程中，已经走过的路线应该变色（通常变灰或变透明），以便用户清楚地看到：
- 已经走过的路径
- 还需要走的路径

## 当前状态

❌ **未实现** - 当前代码中没有启用 Vanishing Route Line 功能

## 实现步骤

### 1. 启用 Vanishing Route Line

在 `initializeRouteLine()` 中配置：

```kotlin
private fun initializeRouteLine() {
    // 自定义路线颜色
    val customColorResources = com.mapbox.navigation.ui.maps.route.line.model.RouteLineColorResources.Builder()
        .routeLineTraveledColor(android.graphics.Color.GRAY) // 已走过的路线变灰
        .routeLineTraveledCasingColor(android.graphics.Color.DKGRAY) // 已走过路线的边框
        .build()
    
    val apiOptions = MapboxRouteLineApiOptions.Builder()
        .vanishingRouteLineEnabled(true) // 🔑 关键：启用消失路线功能
        .colorResources(customColorResources)
        .build()
    
    val viewOptions = MapboxRouteLineViewOptions.Builder(this)
        .build()
    
    routeLineApi = MapboxRouteLineApi(apiOptions)
    routeLineView = MapboxRouteLineView(viewOptions)
}
```

### 2. 注册位置监听器

添加 `OnIndicatorPositionChangedListener` 来更新已走过的路线：

```kotlin
// 在类成员变量中添加
private val onPositionChangedListener = com.mapbox.maps.plugin.locationcomponent.OnIndicatorPositionChangedListener { point ->
    // 更新已走过的路线
    val result = routeLineApi.updateTraveledRouteLine(point)
    
    // 渲染到地图上
    binding.mapView.mapboxMap.style?.let { style ->
        routeLineView.renderRouteLineUpdate(style, result)
    }
}
```

### 3. 在生命周期中注册/注销监听器

在 `startNavigation()` 中注册：

```kotlin
private fun startNavigation(routes: List<NavigationRoute>) {
    // ... 现有代码 ...
    
    // 注册位置监听器以更新已走过的路线
    binding.mapView.location.addOnIndicatorPositionChangedListener(onPositionChangedListener)
    android.util.Log.d(TAG, "Position changed listener registered for vanishing route line")
    
    // ... 现有代码 ...
}
```

在 `stopNavigation()` 中注销：

```kotlin
private fun stopNavigation() {
    // ... 现有代码 ...
    
    // 注销位置监听器
    binding.mapView.location.removeOnIndicatorPositionChangedListener(onPositionChangedListener)
    android.util.Log.d(TAG, "Position changed listener unregistered")
    
    // ... 现有代码 ...
}
```

### 4. 在 RouteProgressObserver 中更新

已经在 `routeProgressObserver` 中有这个调用，确保它正常工作：

```kotlin
private val routeProgressObserver = RouteProgressObserver { routeProgress ->
    // ... 现有代码 ...
    
    // 更新路线（这会同步导航进度）
    routeLineApi.updateWithRouteProgress(routeProgress) { result ->
        binding.mapView.mapboxMap.style?.let { style ->
            routeLineView.renderRouteLineUpdate(style, result)
        }
    }
}
```

## 工作原理

1. **vanishingRouteLineEnabled**: 启用功能
2. **OnIndicatorPositionChangedListener**: 监听位置变化，更新已走过的路线
3. **updateTraveledRouteLine**: 根据当前位置计算已走过的路线
4. **updateWithRouteProgress**: 根据导航进度同步路线状态
5. **routeLineTraveledColor**: 设置已走过路线的颜色

## 视觉效果

- **未走过的路线**: 蓝色（默认）
- **已走过的路线**: 灰色（自定义）
- **路线边框**: 深灰色（自定义）

## 优先级

⏳ **中等优先级** - 这是一个增强功能，不影响基本导航功能

建议先确保基本的模拟导航工作正常，然后再添加这个功能。

## 参考文档

- [Mapbox - Customize the route line](https://docs.mapbox.com/android/navigation/guides/customize-route-line/)
- [MapboxRouteLineApi API](https://docs.mapbox.com/android/navigation/api/mapbox-navigation-ui-maps/)
- [routeLineTraveledColor](https://docs.mapbox.com/android/navigation/api/mapbox-navigation-ui-maps/)

---

**状态**: 待实现
**依赖**: 基本模拟导航功能正常工作
**预计工作量**: 30-60 分钟
