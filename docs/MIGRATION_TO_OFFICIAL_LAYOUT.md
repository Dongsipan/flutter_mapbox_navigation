# 迁移到官方布局指南

## 当前状态

- **当前使用**: `navigation_activity.xml` (自定义 UI)
- **已创建**: `navigation_activity_official.xml` (官方 UI 组件)
- **需要**: 更新代码以使用官方组件

## 关键区别

### 当前布局 (navigation_activity.xml)
```xml
<!-- 自定义 UI -->
<TextView android:id="@+id/distanceRemainingText" />
<TextView android:id="@+id/durationRemainingText" />
<TextView android:id="@+id/etaText" />
<LinearLayout android:id="@+id/maneuverPanel" />
<FloatingActionButton android:id="@+id/recenterButton" />
```

### 官方布局 (navigation_activity_official.xml)
```xml
<!-- 官方组件 -->
<MapboxTripProgressView android:id="@+id/tripProgressView" />
<MapboxManeuverView android:id="@+id/maneuverView" />
<MapboxSoundButton android:id="@+id/soundButton" />
<MapboxRouteOverviewButton android:id="@+id/routeOverview" />
<MapboxRecenterButton android:id="@+id/recenter" />
```

## 需要的代码更改

### 1. 简化 updateNavigationUI

**当前代码（自定义 UI）：**
```kotlin
private fun updateNavigationUI(routeProgress: RouteProgress) {
    // 手动格式化和更新多个 TextView
    val distanceText = if (distanceRemaining >= 1000) { ... }
    binding.distanceRemainingText?.text = distanceText
    binding.durationRemainingText?.text = durationText
    binding.etaText?.text = formatETA(durationRemaining)
}
```

**使用官方组件后：**
```kotlin
private fun updateNavigationUI(routeProgress: RouteProgress) {
    // 一行代码完成！
    binding.tripProgressView?.render(
        tripProgressApi.getTripProgress(routeProgress)
    )
}
```

### 2. 简化 updateManeuverUI

**当前代码（自定义 UI）：**
```kotlin
private fun updateManeuverUI(bannerInstructions: BannerInstructions) {
    // 手动提取和设置文本、图标、距离等
    binding.maneuverText?.text = primary.text()
    binding.maneuverDistance?.text = "In $distanceText"
    binding.maneuverIcon?.setImageResource(iconResId)
    // ... 更多手动代码
}
```

**使用官方组件后（在 RouteProgressObserver 中）：**
```kotlin
private val routeProgressObserver = RouteProgressObserver { routeProgress ->
    // 更新 Maneuver View
    val maneuvers = maneuverApi.getManeuvers(routeProgress)
    maneuvers.fold(
        { error -> Log.e(TAG, error.errorMessage) },
        { binding.maneuverView?.renderManeuvers(maneuvers) }
    )
    
    // 更新 Trip Progress View
    binding.tripProgressView?.render(
        tripProgressApi.getTripProgress(routeProgress)
    )
    
    // ... 其他更新
}
```

### 3. 移除不需要的函数

使用官方组件后，以下函数可以**删除或大幅简化**：
- ❌ `updateManeuverUI()` - 不再需要
- ❌ `getManeuverIconResource()` - 不再需要
- ❌ `formatETA()` - 不再需要（官方组件自动格式化）
- ✅ `updateNavigationUI()` - 简化为一行

### 4. 简化 setupUI

**当前代码：**
```kotlin
private fun setupUI() {
    binding.endNavigationButton.setOnClickListener { stopNavigation() }
    binding.recenterButton.setOnClickListener { recenterCamera() }
    binding.navigationControlPanel.visibility = View.GONE
    binding.recenterButton.visibility = View.GONE
}
```

**使用官方组件后：**
```kotlin
private fun setupUI() {
    // 官方按钮自动处理点击事件，只需设置可见性
    binding.stop?.setOnClickListener { stopNavigation() }
    
    // 官方组件初始状态
    binding.tripProgressCard?.visibility = View.INVISIBLE
    binding.maneuverView?.visibility = View.INVISIBLE
    binding.soundButton?.visibility = View.INVISIBLE
    binding.routeOverview?.visibility = View.INVISIBLE
    
    // 自定义组件
    binding.gpsWarningPanel?.visibility = View.GONE
    binding.routeSelectionPanel?.visibility = View.GONE
}
```

### 5. 更新 startNavigation

**显示官方 UI 组件：**
```kotlin
private fun startNavigation(routes: List<NavigationRoute>) {
    // ... 现有代码 ...
    
    // 显示官方 UI 组件
    binding.tripProgressCard?.visibility = View.VISIBLE
    binding.maneuverView?.visibility = View.VISIBLE
    binding.soundButton?.visibility = View.VISIBLE
    binding.routeOverview?.visibility = View.VISIBLE
    
    // 不再需要显示 navigationControlPanel
    // ❌ binding.navigationControlPanel.visibility = View.VISIBLE
}
```

### 6. 移除 BannerInstructionsObserver 中的 updateManeuverUI 调用

**当前代码：**
```kotlin
private val bannerInstructionObserver = BannerInstructionsObserver { bannerInstructions ->
    sendEvent(MapBoxEvents.BANNER_INSTRUCTION, text)
    
    // ❌ 不再需要手动更新 UI
    if (FlutterMapboxNavigationPlugin.bannerInstructionsEnabled) {
        updateManeuverUI(bannerInstructions)
    }
}
```

**使用官方组件后：**
```kotlin
private val bannerInstructionObserver = BannerInstructionsObserver { bannerInstructions ->
    // 只发送事件到 Flutter
    val text = bannerInstructions.primary().text()
    sendEvent(MapBoxEvents.BANNER_INSTRUCTION, text)
    
    // ✅ MapboxManeuverView 会自动更新，不需要手动调用
}
```

## 完整的代码差异

### RouteProgressObserver 的变化

**之前：**
```kotlin
private val routeProgressObserver = RouteProgressObserver { routeProgress ->
    updateNavigationUI(routeProgress)  // 手动更新自定义 UI
    // ... 其他代码
}
```

**之后：**
```kotlin
private val routeProgressObserver = RouteProgressObserver { routeProgress ->
    // 更新官方 UI 组件
    binding.tripProgressView?.render(
        tripProgressApi.getTripProgress(routeProgress)
    )
    
    val maneuvers = maneuverApi.getManeuvers(routeProgress)
    maneuvers.fold(
        { error -> Log.e(TAG, error.errorMessage) },
        { binding.maneuverView?.renderManeuvers(maneuvers) }
    )
    
    // 发送事件到 Flutter
    val progressEvent = MapBoxRouteProgressEvent(routeProgress)
    FlutterMapboxNavigationPlugin.distanceRemaining = routeProgress.distanceRemaining
    FlutterMapboxNavigationPlugin.durationRemaining = routeProgress.durationRemaining
    sendEvent(progressEvent)
    
    // 更新相机和路线
    viewportDataSource.onRouteProgressChanged(routeProgress)
    viewportDataSource.evaluate()
    
    routeLineApi.updateWithRouteProgress(routeProgress) { result ->
        binding.mapView.mapboxMap.style?.let { style ->
            routeLineView.renderRouteLineUpdate(style, result)
        }
    }
    
    val arrowUpdate = routeArrowApi.addUpcomingManeuverArrow(routeProgress)
    binding.mapView.mapboxMap.style?.let { style ->
        routeArrowView.renderManeuverUpdate(style, arrowUpdate)
    }
}
```

## 代码行数对比

| 功能 | 自定义 UI | 官方组件 | 减少 |
|------|----------|---------|------|
| updateNavigationUI | ~30 行 | ~3 行 | -90% |
| updateManeuverUI | ~50 行 | ~5 行 | -90% |
| getManeuverIconResource | ~30 行 | 0 行 | -100% |
| formatETA | ~10 行 | 0 行 | -100% |
| setupUI | ~10 行 | ~8 行 | -20% |
| **总计** | **~130 行** | **~16 行** | **-88%** |

## 迁移步骤

1. ✅ 已创建 `navigation_activity_official.xml`
2. ⏭️ 重命名布局文件：
   - `navigation_activity.xml` → `navigation_activity_custom.xml` (备份)
   - `navigation_activity_official.xml` → `navigation_activity.xml`
3. ⏭️ 更新 NavigationActivity.kt 代码
4. ⏭️ 测试所有功能
5. ⏭️ 删除不需要的函数

## 建议

**推荐立即迁移**，因为：
- ✅ 减少 88% 的 UI 更新代码
- ✅ 自动获得主题、多语言、动画支持
- ✅ 更好的维护性
- ✅ 自动兼容未来的 SDK 更新

---

**下一步**: 是否需要我帮你创建更新后的 NavigationActivity.kt？
