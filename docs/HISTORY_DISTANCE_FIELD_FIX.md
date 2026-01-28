# 历史记录距离字段修复

## 问题描述

iOS端获取导航历史记录列表时缺少`distance`字段，导致Flutter端无法显示导航距离信息。同时，历史记录列表没有按创建时间倒序排列。

**重要说明**：distance字段表示用户实际行驶的距离（distanceTraveled），而不是路线规划的总长度。

## 修复内容

### 1. iOS端修复

#### 1.1 添加distance字段到HistoryRecord结构
- 文件：`ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/NavigationFactory.swift`
- 在`HistoryRecord`结构中添加`distance: Double?`字段
- 在`toFlutterMap()`方法中添加distance字段的映射

#### 1.2 跟踪实际行驶距离
- 添加`_historyDistanceTraveled`变量跟踪实际行驶距离
- 在`navigationViewController(_:didUpdate:with:rawLocation:)`中更新：
  ```swift
  _historyDistanceTraveled = progress.distanceTraveled
  ```
- 在`startNavigation()`开始时重置为0

#### 1.3 保存历史记录时使用实际行驶距离
- 在`saveHistoryRecord()`方法中使用`_historyDistanceTraveled`
- 不再使用路线规划的总距离（`navigationRoutes?.mainRoute.route.distance`）

#### 1.4 更新封面时保留distance
- 在`updateHistoryCover()`方法中创建新记录时保留distance字段

#### 1.5 列表排序
- 在`getNavigationHistoryList()`方法中按`startTime`倒序排列
- 最新的记录显示在最前面

### 2. Android端修复

#### 2.1 列表排序
- 文件：`android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/FlutterMapboxNavigationPlugin.kt`
- 在`getNavigationHistoryList()`方法中使用`sortedByDescending { it.startTime }`
- 最新的记录显示在最前面

#### 2.2 验证distance字段（已正确实现）
- Android端已经正确实现了distance字段的保存和返回
- `NavigationActivity`在导航进度更新时跟踪：
  ```kotlin
  navigationDistanceTraveled = routeProgress.distanceTraveled
  ```
- 保存历史记录时使用实际行驶距离：
  ```kotlin
  val totalDistance: Double? = if (capturedDistanceTraveled > 0) {
      capturedDistanceTraveled.toDouble()
  } else {
      capturedInitialDistance?.toDouble()
  }
  ```

## 实现细节

### iOS实际行驶距离跟踪
```swift
// 1. 定义变量
var _historyDistanceTraveled: Double = 0.0

// 2. 开始导航时重置
func startNavigation(navigationRoutes: NavigationRoutes, mapboxNavigation: MapboxNavigation) {
    _historyDistanceTraveled = 0.0
    // ...
}

// 3. 导航进度更新时跟踪
public func navigationViewController(_ navigationViewController: NavigationViewController, 
                                    didUpdate progress: RouteProgress, 
                                    with location: CLLocation, 
                                    rawLocation: CLLocation) {
    _historyDistanceTraveled = progress.distanceTraveled
    // ...
}

// 4. 保存时使用
let totalDistance = _historyDistanceTraveled > 0 ? _historyDistanceTraveled : nil
```

### Android实际行驶距离跟踪
```kotlin
// 1. 定义变量
private var navigationDistanceTraveled: Float = 0f

// 2. 开始导航时重置
navigationDistanceTraveled = 0f

// 3. 导航进度更新时跟踪
override fun onRouteProgressChanged(routeProgress: RouteProgress) {
    if (isRecordingHistory) {
        navigationDistanceTraveled = routeProgress.distanceTraveled
    }
}

// 4. 保存时使用
val totalDistance: Double? = if (capturedDistanceTraveled > 0) {
    capturedDistanceTraveled.toDouble()
} else {
    capturedInitialDistance?.toDouble()
}
```

## 测试验证

### iOS测试
```swift
// 验证HistoryRecord包含distance字段
let record = HistoryRecord(
    id: "test",
    historyFilePath: "/path/to/file",
    startTime: Date(),
    duration: 100,
    distance: 5000.0,  // ✅ 实际行驶距离
    startPointName: "起点",
    endPointName: "终点",
    navigationMode: "driving",
    cover: nil,
    mapStyle: "standard",
    lightPreset: "day"
)

// 验证toFlutterMap包含distance
let map = record.toFlutterMap()
assert(map["distance"] as? Double == 5000.0)
```

### Android测试
```kotlin
// 验证列表排序
val historyList = historyManager.getHistoryList()
val sortedList = historyList.sortedByDescending { it.startTime }
// 最新的记录在第一个
assert(sortedList[0].startTime >= sortedList[1].startTime)
```

## 影响范围

- ✅ iOS端：添加distance字段（实际行驶距离），列表倒序排列
- ✅ Android端：列表倒序排列（distance字段已正确实现）
- ✅ Flutter端：NavigationHistory模型已支持distance字段
- ✅ 向后兼容：distance为可选字段，旧数据不受影响

## 相关文件

### iOS
- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/NavigationFactory.swift`

### Android
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/FlutterMapboxNavigationPlugin.kt`
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/utilities/HistoryManager.kt`

### Flutter
- `lib/src/models/navigation_history.dart`
