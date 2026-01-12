# Android History Events API 实现

## 概述

本文档记录了 Android 端 `getNavigationHistoryEvents` API 的实现，该 API 用于解析导航历史文件并提取详细的事件数据。

## 实现日期

2026-01-08

## 问题描述

用户在历史回放页面点击"查看事件"按钮时报错：

```
Error getting navigation history events: MissingPluginException(No implementation found for method getNavigationHistoryEvents on channel flutter_mapbox_navigation)
```

这是因为 Android 端缺少 `getNavigationHistoryEvents` 方法的实现，而 iOS 端已经实现了该功能。

## Android vs iOS API 差异

### iOS 端

iOS 使用 `HistoryReader.parse()` 返回一个 `History` 聚合对象，包含：
- `events: [HistoryEvent]` - 所有事件的数组
- `rawLocations: [CLLocation]` - 原始位置数据数组
- `initialRoute: NavigationRoutes?` - 初始路线（可选）

事件类型包括：
- `LocationUpdateHistoryEvent` - 位置更新
- `RouteAssignmentHistoryEvent` - 路线分配
- `UserPushedHistoryEvent` - 用户自定义事件

### Android 端

Android 使用 `MapboxHistoryReader` 返回 `Iterator<HistoryEvent>`，需要逐个遍历。

为了提取可用数据，我们使用 `ReplayHistoryMapper` 将 `HistoryEvent` 转换为 `ReplayEventBase`：
- `ReplayEventUpdateLocation` - 包含 `Location` 对象
- `ReplaySetRoute` - 包含 `DirectionsRoute` 对象

**关键差异**：
- iOS 有聚合的 `History` 对象，Android 需要手动遍历和聚合
- iOS 直接提供 `rawLocations` 数组，Android 需要从事件中提取
- iOS 有明确的事件类型，Android 通过 `ReplayEventBase` 的子类判断

## 解决方案

### 1. 在 FlutterMapboxNavigationPlugin 中添加方法处理

在 `FlutterMapboxNavigationPlugin.kt` 的 `onMethodCall` 方法中添加了对 `getNavigationHistoryEvents` 的处理：

```kotlin
"getNavigationHistoryEvents" -> {
    getNavigationHistoryEvents(call, result)
}
```

### 2. 实现 getNavigationHistoryEvents 方法

添加了完整的方法实现，包括：

- 参数验证（historyId 不能为空）
- 从数据库查找历史记录
- 验证历史文件是否存在
- 在后台线程解析历史文件
- 在主线程返回结果
- 完善的错误处理和日志记录

```kotlin
private fun getNavigationHistoryEvents(call: MethodCall, result: Result) {
    android.util.Log.d("FlutterMapboxNavigation", "📞 getNavigationHistoryEvents called")
    
    try {
        val historyId = call.argument<String>("historyId")
        
        if (historyId.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "historyId is required", null)
            return
        }
        
        // 查找历史记录
        val historyRecord = historyManager.getHistoryList().find { it.id == historyId }
        if (historyRecord == null) {
            result.error("HISTORY_NOT_FOUND", "History record with id $historyId not found", null)
            return
        }
        
        // 验证文件存在
        val file = java.io.File(historyRecord.historyFilePath)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "History file not found", null)
            return
        }
        
        // 在后台线程解析
        Thread {
            try {
                val parser = HistoryEventsParser()
                val eventsData = parser.parseHistoryFile(historyRecord.historyFilePath, historyId)
                
                currentActivity?.runOnUiThread {
                    result.success(eventsData)
                }
            } catch (e: Exception) {
                currentActivity?.runOnUiThread {
                    result.error("PARSE_ERROR", "Failed to parse history file: ${e.message}", null)
                }
            }
        }.start()
        
    } catch (e: Exception) {
        result.error("UNKNOWN_ERROR", "An unexpected error occurred: ${e.message}", null)
    }
}
```

### 3. 创建 HistoryEventsParser 类

创建了新的 `HistoryEventsParser.kt` 文件，使用 `ReplayHistoryMapper` 来解析历史文件：

**核心实现思路**：

1. 使用 `MapboxHistoryReader` 读取历史文件
2. 使用 `ReplayHistoryMapper` 将 `HistoryEvent` 转换为 `ReplayEventBase`
3. 根据 `ReplayEventBase` 的子类型提取数据：
   - `ReplayEventUpdateLocation` → 提取位置数据
   - `ReplaySetRoute` → 提取路线数据
4. 聚合所有数据并返回

**主要代码**：

```kotlin
// 创建 ReplayHistoryMapper
val replayHistoryMapper = ReplayHistoryMapper.Builder().build()

// 遍历历史事件
while (historyReader.hasNext()) {
    val historyEvent = historyReader.next()
    val replayEvent = replayHistoryMapper.mapToReplayEvent(historyEvent)
    
    when (replayEvent) {
        is ReplayEventUpdateLocation -> {
            // 提取位置数据
            val replayLoc = replayEvent.location
            val locationData = serializeReplayLocation(replayLoc)
            rawLocations.add(locationData)
            events.add(mapOf(
                "eventType" to "location_update",
                "data" to locationData
            ))
        }
        is ReplaySetNavigationRoute -> {
            // 提取路线数据
            val routeData = serializeRoute(replayEvent)
            if (initialRoute == null) {
                initialRoute = routeData
            }
            events.add(mapOf(
                "eventType" to "route_assignment",
                "data" to routeData
            ))
        }
    }
}

// 序列化位置数据
private fun serializeReplayLocation(location: ReplayEventLocation): Map<String, Any?> {
    return mutableMapOf(
        "latitude" to location.lat,
        "longitude" to location.lon,
        "timestamp" to (location.time?.times(1000))?.toLong(),
        "altitude" to location.altitude,
        "speed" to location.speed,
        "course" to location.bearing,
        "accuracy" to location.accuracyHorizontal
    )
}

// 序列化路线数据
private fun serializeRoute(replaySetRoute: ReplaySetNavigationRoute): Map<String, Any?>? {
    val navigationRoute = replaySetRoute.route ?: return null
    val directionsRoute = navigationRoute.directionsRoute
    return mapOf(
        "distance" to directionsRoute.distance(),
        "duration" to directionsRoute.duration(),
        "geometry" to directionsRoute.geometry()
    )
}
```

**返回数据结构**：

```kotlin
mapOf(
    "historyId" to historyId,
    "events" to events,              // 所有事件列表
    "rawLocations" to rawLocations,  // 原始位置数据
    "initialRoute" to initialRoute   // 初始路线信息（可选）
)
```

**位置数据格式**：

```kotlin
mapOf(
    "latitude" to location.lat,              // Double
    "longitude" to location.lon,             // Double
    "timestamp" to (time * 1000).toLong(),   // 毫秒时间戳
    "altitude" to location.altitude,         // Double? (可选)
    "accuracy" to location.accuracyHorizontal, // Double? (可选)
    "horizontalAccuracy" to location.accuracyHorizontal, // Double? (可选)
    "speed" to location.speed,               // Double? (可选)
    "course" to location.bearing             // Double? (可选)
)
```

**路线数据格式**：

```kotlin
mapOf(
    "distance" to directionsRoute.distance(),  // Double
    "duration" to directionsRoute.duration(),  // Double
    "geometry" to directionsRoute.geometry()   // String? (可选)
)
```

## 技术细节

### 使用的 Mapbox API

- `MapboxHistoryReader(filePath)`: 创建历史文件读取器
- `historyReader.hasNext()`: 检查是否还有更多事件
- `historyReader.next()`: 读取下一个历史事件
- `ReplayHistoryMapper`: 将 `HistoryEvent` 转换为 `ReplayEventBase`
- `ReplayEventUpdateLocation`: 包含位置信息的回放事件
  - `location: ReplayEventLocation` - 位置数据对象
  - `ReplayEventLocation.lat` / `lon` - 纬度/经度
  - `ReplayEventLocation.time` - 时间戳（秒，Double?）
  - `ReplayEventLocation.altitude` / `speed` / `bearing` / `accuracyHorizontal` - 可选字段
- `ReplaySetNavigationRoute`: 包含路线信息的回放事件
  - `route: NavigationRoute?` - 导航路线对象
  - `NavigationRoute.directionsRoute` - 获取 DirectionsRoute
  - `DirectionsRoute.distance()` / `duration()` / `geometry()` - 路线详情

### 为什么使用 ReplayHistoryMapper

Android 的 `HistoryEvent` 是一个底层的 protobuf 对象，不直接暴露位置和路线数据。`ReplayHistoryMapper` 是 Mapbox 提供的官方工具，用于将历史事件转换为可用的回放事件，这些回放事件包含了我们需要的数据。

这个方法已经在 `NavigationHistoryManager.kt` 中用于历史回放功能，证明是可靠的。

### 错误处理

实现了完善的错误处理机制：

1. **INVALID_ARGUMENT**: historyId 为空或无效
2. **HISTORY_NOT_FOUND**: 数据库中找不到对应的历史记录
3. **FILE_NOT_FOUND**: 历史文件不存在
4. **PARSE_ERROR**: 解析历史文件失败
5. **UNKNOWN_ERROR**: 其他未预期的错误

### 日志记录

添加了详细的日志记录，便于调试：

- 📞 方法调用
- 🔍 查找历史记录
- 📋 数据库查询结果
- 📁 文件路径
- 📍 位置事件
- 🗺️ 路线事件
- ✅ 成功操作
- ⚠️ 警告信息
- ❌ 错误信息

## 测试建议

1. **正常流程测试**
   - 创建导航历史记录
   - 调用 `getNavigationHistoryEvents` 获取事件数据
   - 验证返回的数据结构和内容
   - 检查位置数据的准确性
   - 验证路线信息是否正确

2. **错误处理测试**
   - 传入无效的 historyId
   - 传入不存在的 historyId
   - 删除历史文件后尝试获取事件

3. **性能测试**
   - 测试大型历史文件的解析性能
   - 验证后台线程不会阻塞 UI
   - 测试包含大量位置点的历史记录

## 与 iOS 端的对比

| 特性 | iOS | Android |
|------|-----|---------|
| 方法处理 | ✅ | ✅ |
| 历史文件解析 | ✅ `History` 对象 | ✅ `ReplayHistoryMapper` |
| 位置数据提取 | ✅ 直接从 `rawLocations` | ✅ 从 `ReplayEventUpdateLocation` |
| 路线信息提取 | ✅ 直接从 `initialRoute` | ✅ 从 `ReplaySetRoute` |
| 事件类型识别 | ✅ 明确的事件类 | ✅ `ReplayEventBase` 子类 |
| 错误处理 | ✅ | ✅ |
| 后台线程处理 | ✅ | ✅ |
| 数据格式 | ✅ | ✅ 兼容 |

**数据兼容性**：Android 和 iOS 返回的数据结构完全兼容，Flutter 端可以使用相同的代码处理两个平台的数据。

## 相关文件

- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/FlutterMapboxNavigationPlugin.kt`
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/utilities/HistoryEventsParser.kt`
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/utilities/NavigationHistoryManager.kt`
- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/HistoryEventsParser.swift`
- `lib/src/models/navigation_history_events.dart`
- `lib/src/models/history_event_data.dart`
- `lib/src/models/location_data.dart`

## 后续改进

1. **性能优化**
   - 考虑添加缓存机制，避免重复解析同一个历史文件
   - 对于大型文件，可以考虑分页加载
   - 使用协程代替 Thread 以获得更好的性能

2. **功能增强**
   - 支持过滤特定类型的事件
   - 支持时间范围查询
   - 添加事件统计信息
   - 支持提取更多事件类型（如果 Mapbox 提供）

3. **错误处理**
   - 添加更详细的错误信息
   - 支持部分解析失败时返回已解析的数据
   - 添加重试机制

## 参考文档

- [Mapbox Navigation SDK for Android](https://docs.mapbox.com/android/navigation/overview/)
- [History Recording API](https://docs.mapbox.com/android/navigation/api/mapbox-navigation-core/com.mapbox.navigation.core.history/)
- [ReplayHistoryMapper](https://docs.mapbox.com/android/navigation/api/mapbox-navigation-core/com.mapbox.navigation.core.replay.history/-replay-history-mapper/)
- [iOS Implementation](ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/HistoryEventsParser.swift)
