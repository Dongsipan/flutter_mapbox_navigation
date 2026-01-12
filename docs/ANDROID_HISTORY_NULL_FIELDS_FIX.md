# Android 历史记录 Null 字段问题修复

## 问题描述

在查看历史记录时，发现某些记录的 `endTime` 和 `distance` 字段为 null：

```
{
  id: 8ec5eb95-a88c-4a00-b1ec-4abeff4b653e,
  historyFilePath: /data/user/0/.../history/2026-01-08T05-49-27Z_24ed1376-2327-4ef9-8ad4-8c80a2a1f3aa.pbf.gz,
  cover: /data/user/0/.../navigation_history/8ec5eb95-a88c-4a00-b1ec-4abeff4b653e_cover.png,
  startTime: 1767851367000,
  endTime: null,           // ❌ 为 null
  distance: null,          // ❌ 为 null
  duration: 136,
  startPointName: Home,
  endPointName: Store,
  navigationMode: simulation
}
```

## 问题原因分析

### 1. 可能的原因

根据代码分析，`endTime` 和 `distance` 为 null 可能有以下几种情况：

#### a) 导航被中断
- 用户在导航过程中强制关闭了应用
- 应用崩溃或被系统杀死
- 用户点击了取消按钮但没有正常结束导航
- 这些情况下 `stopHistoryRecording()` 没有被调用

#### b) 距离追踪失败
- `navigationDistanceTraveled` 始终为 0
- `navigationInitialDistance` 也为 null
- 可能是因为：
  - RouteProgressObserver 没有正确注册
  - 路线数据获取失败
  - 模拟导航时距离追踪有问题

#### c) 异步回调问题
- `stopRecording()` 的回调没有正确执行
- 数据在异步回调前被重置

### 2. 当前代码逻辑

在 `NavigationActivity.kt` 和 `TurnByTurn.kt` 中：

```kotlin
// 开始导航时
navigationStartTime = System.currentTimeMillis()
navigationInitialDistance = routes.firstOrNull()?.directionsRoute?.distance()?.toFloat()
navigationDistanceTraveled = 0f

// 导航过程中追踪距离
private val routeProgressObserver = RouteProgressObserver { routeProgress ->
    if (isRecordingHistory) {
        navigationDistanceTraveled = routeProgress.distanceTraveled
    }
}

// 停止导航时
stopRecording { historyFilePath ->
    val totalDistance: Double? = if (capturedDistanceTraveled > 0) {
        capturedDistanceTraveled.toDouble()
    } else {
        capturedInitialDistance?.toDouble()
    }
    
    val historyData = mapOf(
        "endTime" to navigationEndTime,
        "distance" to totalDistance,  // 如果两个都是 0/null，这里就是 null
        ...
    )
}
```

## 修复方案

### 1. 增强日志追踪

已添加详细的日志输出来追踪问题：

```kotlin
android.util.Log.d(TAG, "📊 Navigation Summary:")
android.util.Log.d(TAG, "  - Start Time: $capturedStartTime")
android.util.Log.d(TAG, "  - End Time: $navigationEndTime")
android.util.Log.d(TAG, "  - Duration: ${duration}s")
android.util.Log.d(TAG, "  - Initial Distance: ${capturedInitialDistance}m")
android.util.Log.d(TAG, "  - Distance Traveled: ${capturedDistanceTraveled}m")
android.util.Log.d(TAG, "  - Total Distance: ${totalDistance}m")
```

### 2. 添加 HistoryManager 更新方法

在 `HistoryManager.kt` 中添加了 `updateHistoryRecord()` 方法，用于更新现有记录：

```kotlin
fun updateHistoryRecord(historyId: String, updates: Map<String, Any?>): Boolean {
    // 可以用于后续补充 endTime 和 distance
}
```

### 3. 建议的改进

#### a) 在导航开始时保存初始记录

```kotlin
private fun startHistoryRecording() {
    // 生成历史记录 ID
    currentHistoryId = UUID.randomUUID().toString()
    
    // 保存初始记录（endTime 和 distance 为 null）
    val initialHistoryData = mapOf(
        "id" to currentHistoryId,
        "filePath" to "", // 暂时为空
        "startTime" to navigationStartTime,
        "endTime" to null,
        "distance" to null,
        "duration" to null,
        "startPointName" to startPointName,
        "endPointName" to endPointName,
        "navigationMode" to navigationMode
    )
    
    historyManager.saveHistoryRecord(initialHistoryData)
    
    // 开始录制
    mapboxNavigation.historyRecorder.startRecording()
}
```

#### b) 在导航结束时更新记录

```kotlin
private fun stopHistoryRecording() {
    mapboxNavigation.historyRecorder.stopRecording { historyFilePath ->
        // 更新现有记录
        val updates = mapOf(
            "filePath" to historyFilePath,
            "endTime" to navigationEndTime,
            "distance" to totalDistance,
            "duration" to duration
        )
        
        historyManager.updateHistoryRecord(currentHistoryId, updates)
    }
}
```

#### c) 添加异常处理和清理

```kotlin
override fun onDestroy() {
    super.onDestroy()
    
    // 如果导航被中断，确保历史记录被正确保存
    if (isRecordingHistory && currentHistoryId != null) {
        // 保存不完整的记录（标记为中断）
        val updates = mapOf(
            "endTime" to System.currentTimeMillis(),
            "distance" to navigationDistanceTraveled.toDouble(),
            "duration" to ((System.currentTimeMillis() - navigationStartTime) / 1000).toInt(),
            "navigationMode" to "interrupted"
        )
        
        historyManager.updateHistoryRecord(currentHistoryId!!, updates)
    }
}
```

## 调试步骤

### 1. 查看日志

运行导航并查看日志输出：

```bash
adb logcat | grep -E "NavigationActivity|HistoryManager"
```

关注以下日志：
- `📊 Navigation Summary:` - 查看所有字段的值
- `💾 Saving history data:` - 查看保存的数据
- `📹 History recording stopped` - 确认录制正常停止

### 2. 检查距离追踪

在 `routeProgressObserver` 中添加日志：

```kotlin
private val routeProgressObserver = RouteProgressObserver { routeProgress ->
    if (isRecordingHistory) {
        navigationDistanceTraveled = routeProgress.distanceTraveled
        android.util.Log.d(TAG, "📏 Distance traveled: ${navigationDistanceTraveled}m")
    }
}
```

### 3. 验证初始距离

在开始导航时检查：

```kotlin
navigationInitialDistance = routes.firstOrNull()?.directionsRoute?.distance()?.toFloat()
android.util.Log.d(TAG, "📏 Initial route distance: ${navigationInitialDistance}m")
```

## 预期结果

修复后，所有历史记录应该包含完整的数据：

```
{
  id: xxx,
  historyFilePath: xxx,
  cover: xxx,
  startTime: 1767851367000,
  endTime: 1767851503000,     // ✅ 有值
  distance: 1234.5,           // ✅ 有值
  duration: 136,
  startPointName: Home,
  endPointName: Store,
  navigationMode: simulation
}
```

## 下一步

1. 运行导航测试，查看新的日志输出
2. 确认 `navigationDistanceTraveled` 是否正确更新
3. 如果距离仍然为 0，检查 `routeProgressObserver` 是否正确注册
4. 考虑实现"保存初始记录 + 更新记录"的方案，确保即使导航中断也能保存部分数据
