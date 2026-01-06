# Puck 层级和到达 UI 修复

## 问题描述

1. **Puck 被路线遮挡** - 用户位置指示器（puck）的层级比路线低，被路线遮挡
2. **到达终点后没有显示 UI** - 到达终点后没有任何视觉反馈

## 修复内容

### 1. 修复 Puck 层级问题

#### 问题原因
路线层（route line layer）默认在地图的顶层，会遮挡住 location puck。

#### 解决方案
根据官方示例，需要：
1. 在 `loadStyle` 回调中初始化路线层级
2. 设置 `routeLineBelowLayerId` 参数，将路线放在指定层下方

**代码更改**：

```kotlin
// 1. 在 loadStyle 回调中初始化路线层级
binding.mapView.mapboxMap.loadStyle(styleUrl) {
    // 初始化路线层级 (官方示例模式)
    // 确保路线层在 location puck 下方
    routeLineView.initializeLayers(it)
    
    // ... 其他代码
}

// 2. 设置路线层级
private fun initializeRouteLine() {
    // 设置路线层级，确保路线在 location puck 下方 (官方示例模式)
    val viewOptions = MapboxRouteLineViewOptions.Builder(this)
        .routeLineColorResources(customColorResources)
        .routeLineBelowLayerId("road-label-navigation") // 路线在标签层下方
        .build()
    
    routeLineView = MapboxRouteLineView(viewOptions)
}
```

#### 层级顺序（从上到下）
1. Location Puck（用户位置指示器）- 最上层
2. Road Labels（道路标签）
3. Route Line（路线）- 在标签下方
4. Map Base Layers（地图基础层）

### 2. 添加到达 UI

#### 问题原因
`arrivalObserver` 只发送事件到 Flutter，没有在原生端显示任何 UI 反馈。

#### 解决方案
在 `onFinalDestinationArrival` 中添加 UI 更新：

```kotlin
private val arrivalObserver = object : ArrivalObserver {
    override fun onFinalDestinationArrival(routeProgress: RouteProgress) {
        android.util.Log.d(TAG, "🏁 Final destination arrival")
        isNavigationInProgress = false
        
        // 显示到达 UI (官方示例模式)
        runOnUiThread {
            // 隐藏导航 UI
            binding.maneuverView?.visibility = View.INVISIBLE
            binding.tripProgressCard?.visibility = View.INVISIBLE
            binding.soundButton?.visibility = View.INVISIBLE
            binding.routeOverview?.visibility = View.INVISIBLE
            
            // 显示到达消息
            android.widget.Toast.makeText(
                this@NavigationActivity,
                "🏁 You have arrived at your destination!",
                android.widget.Toast.LENGTH_LONG
            ).show()
            
            // 切换相机到概览模式
            navigationCamera.requestNavigationCameraToOverview()
        }
        
        // 发送事件到 Flutter
        sendEvent(MapBoxEvents.ON_ARRIVAL)
        // ...
    }
    
    override fun onWaypointArrival(routeProgress: RouteProgress) {
        // 显示途经点到达的消息
        runOnUiThread {
            android.widget.Toast.makeText(
                this@NavigationActivity,
                "📍 Waypoint reached!",
                android.widget.Toast.LENGTH_SHORT
            ).show()
        }
        // ...
    }
    
    override fun onNextRouteLegStart(routeLegProgress: RouteLegProgress) {
        // 显示下一段路程开始的消息
        runOnUiThread {
            android.widget.Toast.makeText(
                this@NavigationActivity,
                "🚩 Starting next leg of the route",
                android.widget.Toast.LENGTH_SHORT
            ).show()
        }
        // ...
    }
}
```

### 3. 到达时的 UI 变化

| 事件 | UI 变化 |
|------|---------|
| 最终目的地到达 | - 隐藏所有导航 UI<br>- 显示到达 Toast 消息<br>- 切换相机到概览模式<br>- 发送事件到 Flutter |
| 途经点到达 | - 显示途经点到达 Toast<br>- 继续导航到下一个点<br>- 发送事件到 Flutter |
| 下一段路程开始 | - 显示下一段开始 Toast<br>- 继续导航<br>- 发送事件到 Flutter |

## 测试建议

### 测试 Puck 层级
1. 启动导航
2. 观察用户位置 puck 是否在路线上方
3. 移动时 puck 应该始终可见，不被路线遮挡

### 测试到达 UI
1. 启动导航到一个近距离目的地
2. 到达目的地时应该：
   - 显示 "You have arrived at your destination!" Toast
   - 隐藏所有导航 UI（maneuver view, trip progress, buttons）
   - 相机切换到概览模式
   - Flutter 端收到 ON_ARRIVAL 事件

3. 测试多途经点：
   - 设置多个途经点
   - 到达第一个途经点时显示 "Waypoint reached!" Toast
   - 继续导航到下一个途经点
   - 到达最终目的地时显示最终到达 UI

## 编译状态

✅ **无编译错误**

## 参考

- [官方 Turn-by-Turn 示例](https://docs.mapbox.com/android/navigation/examples/turn-by-turn-experience/)
- [Route Line API 文档](https://docs.mapbox.com/android/navigation/api/ui-maps/)
- [Arrival Observer 文档](https://docs.mapbox.com/android/navigation/api/core/)

## 改进建议

如果需要更丰富的到达 UI，可以考虑：

1. **自定义到达对话框**
   ```kotlin
   // 显示自定义对话框而不是 Toast
   AlertDialog.Builder(this@NavigationActivity)
       .setTitle("🏁 Arrived!")
       .setMessage("You have reached your destination")
       .setPositiveButton("OK") { dialog, _ -> 
           dialog.dismiss()
           // 可选：自动结束导航
           stopNavigation()
       }
       .show()
   ```

2. **到达动画**
   - 添加相机动画效果
   - 显示目的地标记动画
   - 播放到达音效

3. **到达统计**
   - 显示总行驶距离
   - 显示总行驶时间
   - 显示平均速度
