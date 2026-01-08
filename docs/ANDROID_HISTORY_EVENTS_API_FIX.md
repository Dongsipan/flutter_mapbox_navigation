# Android History Events API 编译错误修复

## 日期
2026-01-08

## 问题

初始实现使用了错误的 API 类型，导致编译错误：

1. ❌ `ReplaySetRoute` - 不存在的类型
2. ❌ `ReplayEventUpdateLocation.location` 被当作 `android.location.Location`
3. ❌ 访问不存在的 `latitude` / `longitude` 属性

## 根本原因

Android 和 iOS 的 Mapbox SDK API 存在差异：

### iOS API
- 使用 `History` 聚合对象
- 直接提供 `rawLocations: [CLLocation]`
- 事件类型明确：`LocationUpdateHistoryEvent`, `RouteAssignmentHistoryEvent`

### Android API
- 使用 `Iterator<HistoryEvent>` 逐个遍历
- 需要通过 `ReplayHistoryMapper` 转换
- 事件类型：`ReplayEventUpdateLocation`, `ReplaySetNavigationRoute`
- 位置数据类型：`ReplayEventLocation`（不是 `Location`）

## 修复方案

### 1. 修正 Import 语句

**错误的 Import：**
```kotlin
import android.location.Location
import com.mapbox.navigation.core.replay.history.ReplaySetRoute
```

**正确的 Import：**
```kotlin
import com.mapbox.navigation.core.replay.history.ReplaySetNavigationRoute
import com.mapbox.navigation.core.replay.history.ReplayEventLocation
import com.mapbox.navigation.base.route.NavigationRoute
```

### 2. 修正位置数据处理

**错误的代码：**
```kotlin
is ReplayEventUpdateLocation -> {
    val location = replayEvent.location  // 类型是 ReplayEventLocation，不是 Location
    val locationData = serializeLocation(location)  // 类型不匹配
    android.util.Log.v("...", "${location.latitude}, ${location.longitude}")  // 属性不存在
}
```

**正确的代码：**
```kotlin
is ReplayEventUpdateLocation -> {
    val replayLoc = replayEvent.location  // ReplayEventLocation 类型
    val locationData = serializeReplayLocation(replayLoc)  // 使用专门的方法
    android.util.Log.v("...", "${replayLoc.lat}, ${replayLoc.lon}")  // 正确的属性名
}
```

### 3. 实现 ReplayEventLocation 序列化

**新增方法：**
```kotlin
private fun serializeReplayLocation(location: ReplayEventLocation): Map<String, Any?> {
    val data = mutableMapOf<String, Any?>(
        "latitude" to location.lat,      // 注意：是 lat，不是 latitude
        "longitude" to location.lon      // 注意：是 lon，不是 longitude
    )
    
    // time 是 Double?，单位是秒，需要转换为毫秒
    location.time?.let { timeSeconds ->
        data["timestamp"] = (timeSeconds * 1000).toLong()
    }
    
    // 可选字段
    location.altitude?.let { data["altitude"] = it }
    location.accuracyHorizontal?.let {
        data["accuracy"] = it
        data["horizontalAccuracy"] = it
    }
    location.speed?.let { data["speed"] = it }
    location.bearing?.let { data["course"] = it }
    
    return data
}
```

### 4. 修正路线事件处理

**错误的代码：**
```kotlin
is ReplaySetRoute -> {  // 类型不存在
    val routeData = serializeRoute(replayEvent)
}
```

**正确的代码：**
```kotlin
is ReplaySetNavigationRoute -> {  // 正确的类型名
    val routeData = serializeRoute(replayEvent)
}
```

### 5. 实现 NavigationRoute 序列化

**新增方法：**
```kotlin
private fun serializeRoute(replaySetRoute: ReplaySetNavigationRoute): Map<String, Any?>? {
    return try {
        val navigationRoute: NavigationRoute = replaySetRoute.route ?: return null
        
        val data = mutableMapOf<String, Any?>()
        
        // 从 NavigationRoute 获取 DirectionsRoute
        val directionsRoute = navigationRoute.directionsRoute
        data["distance"] = directionsRoute.distance()
        data["duration"] = directionsRoute.duration()
        
        val geometry = directionsRoute.geometry()
        if (geometry != null) {
            data["geometry"] = geometry
        }
        
        data
    } catch (e: Exception) {
        android.util.Log.w("HistoryEventsParser", "⚠️ Failed to serialize route: ${e.message}")
        null
    }
}
```

## API 对比表

| 功能 | iOS | Android |
|------|-----|---------|
| 位置对象 | `CLLocation` | `ReplayEventLocation` |
| 纬度属性 | `coordinate.latitude` | `lat` |
| 经度属性 | `coordinate.longitude` | `lon` |
| 时间戳 | `timestamp` (Date) | `time` (Double?, 秒) |
| 速度 | `speed` (Double) | `speed` (Double?) |
| 方向 | `course` (Double) | `bearing` (Double?) |
| 精度 | `horizontalAccuracy` | `accuracyHorizontal` |
| 路线事件 | `RouteAssignmentHistoryEvent` | `ReplaySetNavigationRoute` |
| 路线对象 | `Route` | `NavigationRoute` |

## ReplayEventLocation 字段说明

根据 Mapbox 文档，`ReplayEventLocation` 的字段包括：

- `lat: Double` - 纬度
- `lon: Double` - 经度
- `time: Double?` - 时间戳（秒，可选）
- `altitude: Double?` - 海拔（可选）
- `accuracyHorizontal: Double?` - 水平精度（可选）
- `speed: Double?` - 速度（可选）
- `bearing: Double?` - 方向（可选）

**注意**：
- 属性名是 `lat` / `lon`，不是 `latitude` / `longitude`
- `time` 单位是秒，需要乘以 1000 转换为毫秒
- 所有可选字段都是 `Double?` 类型

## 验证

修复后的代码：
- ✅ 编译通过，无错误
- ✅ 使用正确的 API 类型
- ✅ 正确处理可选字段
- ✅ 数据格式与 iOS 端兼容
- ✅ 与 Flutter 端期望的数据结构匹配

## 相关文件

- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/utilities/HistoryEventsParser.kt`
- `docs/ANDROID_HISTORY_EVENTS_API_IMPLEMENTATION.md`

## 参考文档

- [ReplayEventUpdateLocation](https://docs.mapbox.com/android/navigation/api/mapbox-navigation-core/com.mapbox.navigation.core.replay.history/-replay-event-update-location/)
- [ReplayEventLocation](https://docs.mapbox.com/android/navigation/api/mapbox-navigation-core/com.mapbox.navigation.core.replay.history/-replay-event-location/)
- [ReplaySetNavigationRoute](https://docs.mapbox.com/android/navigation/api/mapbox-navigation-core/com.mapbox.navigation.core.replay.history/-replay-set-navigation-route/)
- [NavigationRoute](https://docs.mapbox.com/android/navigation/api/mapbox-navigation-base/com.mapbox.navigation.base.route/-navigation-route/)
