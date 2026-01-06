# 到达终点自动结束导航功能

## 功能描述

当用户到达最终目的地时，系统会自动结束导航并关闭导航界面，返回到 Flutter 应用。

## 实现逻辑

### 1. 到达终点触发流程

```
用户到达终点
    ↓
onFinalDestinationArrival 回调触发
    ↓
显示到达 UI 和 Toast 消息
    ↓
发送到达事件到 Flutter
    ↓
延迟 3 秒
    ↓
自动调用 stopNavigation()
    ↓
关闭 NavigationActivity
    ↓
返回 Flutter 应用
```

### 2. 代码实现

在 `arrivalObserver` 的 `onFinalDestinationArrival` 方法中添加：

```kotlin
// 延迟 3 秒后自动结束导航并关闭 Activity
binding.mapView.postDelayed({
    android.util.Log.d(TAG, "🏁 Auto-finishing navigation after arrival")
    stopNavigation()
}, 3000)
```

### 3. 用户体验流程

1. **到达终点时**：
   - 隐藏导航 UI（转向指示、进度卡片、声音按钮等）
   - 显示 Toast 消息："🏁 You have arrived at your destination!"
   - 相机切换到概览模式，显示整个路线
   - 发送 `ON_ARRIVAL` 事件到 Flutter

2. **3 秒延迟**：
   - 给用户时间查看到达位置
   - 阅读到达消息
   - 确认已到达目的地

3. **自动结束**：
   - 停止导航会话
   - 清理路线和箭头
   - 停止历史记录（如果启用）
   - 关闭 NavigationActivity
   - 返回 Flutter 应用主界面

## 技术细节

### stopNavigation() 方法执行的操作

```kotlin
@OptIn(ExperimentalPreviewMapboxNavigationAPI::class)
private fun stopNavigation() {
    val mapboxNavigation = MapboxNavigationApp.current() ?: return
    
    try {
        // 1. 停止历史记录
        if (isRecordingHistory) {
            stopHistoryRecording()
        }
        
        // 2. 停止模拟器（如果使用）
        if (FlutterMapboxNavigationPlugin.simulateRoute) {
            mapboxNavigation.mapboxReplayer.stop()
            mapboxNavigation.mapboxReplayer.clearEvents()
        }
        
        // 3. 停止导航会话
        mapboxNavigation.stopTripSession()
        
        // 4. 清除路线
        mapboxNavigation.setNavigationRoutes(emptyList())
        
        // 5. 清除地图上的路线箭头
        binding.mapView.mapboxMap.style?.let { style ->
            routeArrowView.render(style, routeArrowApi.clearArrows())
        }
        
        // 6. 更新状态
        isNavigationInProgress = false
        
        // 7. 隐藏 UI
        binding.tripProgressCard?.visibility = View.GONE
        binding.maneuverView?.visibility = View.GONE
        binding.soundButton?.visibility = View.GONE
        binding.routeOverview?.visibility = View.GONE
        
        // 8. 发送取消事件
        sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        
        // 9. 关闭 Activity
        finish()
    } catch (e: Exception) {
        android.util.Log.e(TAG, "Error stopping navigation: ${e.message}", e)
        sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        finish()
    }
}
```

## 配置选项

### 调整延迟时间

如果需要修改自动结束的延迟时间，可以修改 `postDelayed` 的参数：

```kotlin
// 当前：3 秒延迟
binding.mapView.postDelayed({ stopNavigation() }, 3000)

// 修改为 5 秒延迟
binding.mapView.postDelayed({ stopNavigation() }, 5000)

// 修改为 2 秒延迟
binding.mapView.postDelayed({ stopNavigation() }, 2000)
```

### 禁用自动结束（可选）

如果需要禁用自动结束功能，让用户手动点击停止按钮：

```kotlin
// 注释掉自动结束代码
// binding.mapView.postDelayed({
//     android.util.Log.d(TAG, "🏁 Auto-finishing navigation after arrival")
//     stopNavigation()
// }, 3000)
```

## 多途经点场景

对于有多个途经点的路线：

- **到达途经点**：`onWaypointArrival` 触发，显示消息但不结束导航
- **开始下一段**：`onNextRouteLegStart` 触发，继续导航到下一个目的地
- **到达最终目的地**：`onFinalDestinationArrival` 触发，自动结束导航

## 事件通知

到达终点时，Flutter 应用会收到以下事件：

```dart
// ON_ARRIVAL 事件
{
  "isFinalDestination": true,
  "legIndex": 0,
  "distanceRemaining": 0.0,
  "durationRemaining": 0.0
}

// NAVIGATION_CANCELLED 事件（3秒后）
// 表示导航已结束
```

## 修改文件

- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
  - `arrivalObserver.onFinalDestinationArrival()` 方法

## 编译结果

✅ 编译成功
```
Running Gradle task 'assembleDebug'...                             77.9s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

## 测试建议

1. **正常到达测试**：
   - 启动导航到一个近距离目的地
   - 等待到达终点
   - 验证 Toast 消息显示
   - 验证 3 秒后自动关闭

2. **多途经点测试**：
   - 设置多个途经点
   - 验证到达途经点时不会结束导航
   - 验证到达最终目的地时才结束

3. **手动停止测试**：
   - 在到达前点击停止按钮
   - 验证可以正常停止导航

## 用户反馈

如果用户希望：
- **更长的延迟**：增加 `postDelayed` 的时间参数
- **更短的延迟**：减少 `postDelayed` 的时间参数
- **手动结束**：注释掉自动结束代码，保留停止按钮功能
