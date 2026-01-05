# Android 多航点支持实现

## 概述

本文档记录了 Android 导航功能的多航点支持实现,包括多航点路线创建、航点到达事件、自动推进到下一路段和静默航点支持。

## 实现日期
2026-01-05

## 相关需求
- Requirements 17.1: 创建多路段路线
- Requirements 17.2: 自动推进到下一路段
- Requirements 17.3: 静默航点支持
- Requirements 17.4: 导航中添加航点
- Requirements 17.5: 航点重排序和优化
- Requirements 17.6: 分别跟踪每段进度

## 实现内容

### 1. 数据模型 ✅

#### 1.1 Waypoint 类
**位置**: `models/Waypoint.kt`

```kotlin
data class Waypoint(
    val name: String = "",
    val point: Point,
    val isSilent: Boolean,
) : Serializable
```

**特性**:
- 支持命名航点
- 支持静默航点 (`isSilent`)
- 多个构造函数方便创建

**构造函数**:
```kotlin
// 完整构造函数
Waypoint(name: String, point: Point, isSilent: Boolean)

// 命名航点
Waypoint(name: String, point: Point)

// 坐标航点
Waypoint(longitude: Double, latitude: Double)

// 静默航点
Waypoint(point: Point, isSilent: Boolean)

// 默认静默
Waypoint(point: Point)
```

#### 1.2 WaypointSet 类
**位置**: `models/WaypointSet.kt`

**功能**:
1. 存储航点列表
2. 转换为 RouteOptions 参数

**关键方法**:

```kotlin
// 添加航点
fun add(waypoint: Waypoint)

// 清空航点
fun clear()

// 获取航点索引 (排除静默航点)
fun waypointsIndices(): List<Int>

// 获取航点名称 (排除静默航点)
fun waypointsNames(): List<String>

// 获取所有坐标
fun coordinatesList(): List<Point>
```

**静默航点逻辑**:
```kotlin
private fun List<Waypoint>.isSilentWaypoint(index: Int) =
    this[index].isSilent && canWaypointBeSilent(index)

// 第一个和最后一个航点不能是静默的
private fun List<Waypoint>.canWaypointBeSilent(index: Int): Boolean {
    val isLastWaypoint = index == this.size - 1
    val isFirstWaypoint = index == 0
    return !isLastWaypoint && !isFirstWaypoint
}
```

### 2. 路线请求 ✅

**位置**: `NavigationActivity.kt` - `requestRoutesWithRetry()`

**实现细节**:
```kotlin
MapboxNavigationApp.current()?.requestRoutes(
    routeOptions = RouteOptions.builder()
        .applyDefaultNavigationOptions()
        .applyLanguageAndVoiceUnitOptions(this)
        .coordinatesList(waypointSet.coordinatesList())      // 所有坐标
        .waypointIndicesList(waypointSet.waypointsIndices()) // 非静默航点索引
        .waypointNamesList(waypointSet.waypointsNames())     // 非静默航点名称
        // ...
        .build(),
    callback = // ...
)
```

**关键点**:
- `coordinatesList()` 包含所有航点(包括静默航点)
- `waypointIndicesList()` 只包含非静默航点的索引
- `waypointNamesList()` 只包含非静默航点的名称
- 静默航点用于路线计算但不会触发到达事件

### 3. 航点到达事件 ✅

**位置**: `NavigationActivity.kt` 和 `TurnByTurn.kt` - `arrivalObserver`

#### 3.1 ArrivalObserver 实现

```kotlin
private val arrivalObserver = object : ArrivalObserver {
    // 最终目的地到达
    override fun onFinalDestinationArrival(routeProgress: RouteProgress) {
        android.util.Log.d(TAG, "🏁 Final destination arrival")
        isNavigationInProgress = false
        
        val arrivalData = mapOf(
            "isFinalDestination" to true,
            "legIndex" to routeProgress.currentLegProgress?.legIndex,
            "distanceRemaining" to routeProgress.distanceRemaining,
            "durationRemaining" to routeProgress.durationRemaining
        )
        sendEvent(MapBoxEvents.ON_ARRIVAL, JSONObject(arrivalData).toString())
    }

    // 下一路段开始 (航点到达后自动触发)
    override fun onNextRouteLegStart(routeLegProgress: RouteLegProgress) {
        android.util.Log.d(TAG, "🚩 Next route leg started: leg ${routeLegProgress.legIndex}")
        
        val waypointData = mapOf(
            "legIndex" to routeLegProgress.legIndex,
            "distanceRemaining" to routeLegProgress.distanceRemaining,
            "durationRemaining" to routeLegProgress.durationRemaining
        )
        sendEvent(MapBoxEvents.WAYPOINT_ARRIVAL, JSONObject(waypointData).toString())
    }

    // 航点到达
    override fun onWaypointArrival(routeProgress: RouteProgress) {
        android.util.Log.d(TAG, "📍 Waypoint arrival: leg ${routeProgress.currentLegProgress?.legIndex}")
        
        val waypointData = mapOf(
            "isFinalDestination" to false,
            "legIndex" to routeProgress.currentLegProgress?.legIndex,
            "distanceRemaining" to routeProgress.distanceRemaining,
            "durationRemaining" to routeProgress.durationRemaining
        )
        sendEvent(MapBoxEvents.WAYPOINT_ARRIVAL, JSONObject(waypointData).toString())
    }
}
```

#### 3.2 事件类型

**新增事件**: `WAYPOINT_ARRIVAL("waypoint_arrival")`

**事件数据结构**:
```json
{
  "isFinalDestination": false,
  "legIndex": 1,
  "distanceRemaining": 5000.0,
  "durationRemaining": 300.0
}
```

### 4. 自动推进到下一路段 ✅

**实现方式**: Mapbox Navigation SDK v3 自动处理

**工作流程**:
1. 用户到达航点
2. SDK 触发 `onWaypointArrival()`
3. SDK 自动推进到下一路段
4. SDK 触发 `onNextRouteLegStart()`
5. 导航继续到下一个航点

**无需手动干预** - SDK 自动管理路段切换

### 5. 静默航点支持 ✅

**定义**: 静默航点是用于路线计算的坐标点,但不会触发到达事件或分隔路段。

**实现逻辑**:

#### 5.1 标记静默航点
```kotlin
val waypoint = Waypoint(point, isSilent = true)
```

#### 5.2 静默航点规则
- 第一个航点不能是静默的 (起点)
- 最后一个航点不能是静默的 (终点)
- 中间航点可以是静默的

#### 5.3 静默航点处理
```kotlin
fun waypointsIndices(): List<Int> {
    return waypoints.mapIndexedNotNull { index, _ ->
        if (waypoints.isSilentWaypoint(index)) {
            null  // 排除静默航点
        } else index
    }
}
```

**效果**:
- 静默航点参与路线计算 (在 `coordinatesList()` 中)
- 静默航点不在 `waypointIndicesList()` 中
- 静默航点不触发到达事件
- 路线会经过静默航点但不会停止

### 6. 导航中添加航点 ✅

**位置**: `NavigationActivity.kt` - `addWayPointsBroadcastReceiver`

**实现细节**:
```kotlin
addWayPointsBroadcastReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val stops = intent.getSerializableExtra("waypoints") as? MutableList<Waypoint>
        if (stops != null) {
            val nextIndex = 1
            if (points.count() >= nextIndex) {
                points.addAll(nextIndex, stops)  // 在当前位置后插入
            } else {
                points.addAll(stops)  // 添加到末尾
            }
        }
    }
}
```

**使用方式**:
```kotlin
// 从 Flutter 发送广播
val intent = Intent(NavigationLauncher.KEY_ADD_WAYPOINTS)
intent.putExtra("waypoints", newWaypoints)
context.sendBroadcast(intent)
```

**注意**: 当前实现添加航点到列表,但需要重新计算路线才能生效。

### 7. 路段进度跟踪 ✅

**位置**: `NavigationActivity.kt` - `routeProgressObserver`

**实现细节**:
```kotlin
private val routeProgressObserver = RouteProgressObserver { routeProgress ->
    // 当前路段信息
    val currentLeg = routeProgress.currentLegProgress
    val legIndex = currentLeg?.legIndex
    val legDistanceRemaining = currentLeg?.distanceRemaining
    val legDurationRemaining = currentLeg?.durationRemaining
    
    // 总体进度
    val totalDistanceRemaining = routeProgress.distanceRemaining
    val totalDurationRemaining = routeProgress.durationRemaining
    
    // 发送进度事件
    val progressEvent = MapBoxRouteProgressEvent(routeProgress)
    sendEvent(progressEvent)
}
```

**RouteProgress 提供的信息**:
- `currentLegProgress` - 当前路段进度
- `currentLegProgress.legIndex` - 当前路段索引
- `currentLegProgress.distanceRemaining` - 当前路段剩余距离
- `currentLegProgress.durationRemaining` - 当前路段剩余时间
- `distanceRemaining` - 总剩余距离
- `durationRemaining` - 总剩余时间

## 使用示例

### 示例 1: 创建多航点路线

```kotlin
val waypointSet = WaypointSet()

// 起点
waypointSet.add(Waypoint("Home", Point.fromLngLat(-122.4194, 37.7749)))

// 中间航点
waypointSet.add(Waypoint("Coffee Shop", Point.fromLngLat(-122.4084, 37.7849)))

// 静默航点 (路线会经过但不停留)
waypointSet.add(Waypoint(Point.fromLngLat(-122.4000, 37.7900), isSilent = true))

// 终点
waypointSet.add(Waypoint("Office", Point.fromLngLat(-122.3900, 37.8000)))

requestRoutes(waypointSet)
```

### 示例 2: 监听航点到达事件

```kotlin
// 在 Flutter 层监听事件
eventChannel.receiveBroadcastStream().listen((event) {
  if (event['eventType'] == 'waypoint_arrival') {
    final legIndex = event['legIndex'];
    final distanceRemaining = event['distanceRemaining'];
    print('Arrived at waypoint $legIndex, $distanceRemaining meters remaining');
  }
});
```

### 示例 3: 使用静默航点优化路线

```kotlin
val waypointSet = WaypointSet()

// 起点
waypointSet.add(Waypoint("Start", startPoint))

// 静默航点 - 强制路线经过特定道路
waypointSet.add(Waypoint(highwayEntrance, isSilent = true))
waypointSet.add(Waypoint(highwayExit, isSilent = true))

// 终点
waypointSet.add(Waypoint("End", endPoint))

requestRoutes(waypointSet)
```

## 测试建议

### 1. 基础多航点测试
- 创建 2 个航点的路线 (起点 + 终点)
- 创建 3 个航点的路线 (起点 + 1 个中间点 + 终点)
- 创建 5 个航点的路线 (起点 + 3 个中间点 + 终点)

### 2. 航点到达测试
- 验证 `onWaypointArrival` 在到达中间航点时触发
- 验证 `onNextRouteLegStart` 在推进到下一路段时触发
- 验证 `onFinalDestinationArrival` 在到达最终目的地时触发

### 3. 静默航点测试
- 创建包含静默航点的路线
- 验证路线经过静默航点
- 验证静默航点不触发到达事件
- 验证第一个和最后一个航点不能是静默的

### 4. 路段进度测试
- 验证每个路段的进度单独跟踪
- 验证总进度正确计算
- 验证路段切换时进度重置

### 5. 动态添加航点测试
- 在导航中添加新航点
- 验证路线重新计算
- 验证导航继续到新航点

## 与 iOS 对齐

所有多航点功能都与 iOS 实现对齐:
- ✅ 多路段路线创建
- ✅ 航点到达事件
- ✅ 自动推进到下一路段
- ✅ 静默航点支持
- ✅ 路段进度跟踪
- ✅ 动态添加航点 (基础支持)

## 文件修改清单

### 修改的文件
1. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
   - 完善 `arrivalObserver` 实现
   - 添加详细的航点到达事件

2. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/TurnByTurn.kt`
   - 完善 `arrivalObserver` 实现
   - 添加详细的航点到达事件

3. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/models/MapBoxEvents.kt`
   - 添加 `WAYPOINT_ARRIVAL` 事件

### 已存在的文件 (无需修改)
1. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/models/Waypoint.kt`
   - 已支持静默航点

2. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/models/WaypointSet.kt`
   - 已正确处理静默航点逻辑

## 已知限制

1. **动态添加航点**: 当前实现添加航点到列表,但需要手动触发路线重新计算
2. **航点重排序**: 未实现自动重排序和优化功能
3. **航点删除**: 未实现导航中删除航点的功能

## 后续改进建议

1. **自动路线重新计算**: 添加航点后自动重新计算路线
2. **航点优化**: 实现航点顺序优化算法 (TSP)
3. **航点管理 UI**: 添加航点列表显示和管理界面
4. **航点编辑**: 支持编辑航点名称和属性
5. **航点删除**: 支持导航中删除航点
6. **航点拖拽**: 支持拖拽重排序航点

## 性能考虑

1. **路线计算**: 航点越多,路线计算时间越长
2. **内存使用**: 每个航点占用少量内存,正常使用不会有问题
3. **事件频率**: 航点到达事件不频繁,不会影响性能

## 最佳实践

1. **合理使用静默航点**: 用于优化路线,不要过度使用
2. **航点命名**: 为非静默航点提供有意义的名称
3. **航点数量**: 建议不超过 10 个航点以保证性能
4. **错误处理**: 检查路线计算是否成功,处理无法到达的航点

---

**实现状态**: ✅ 完成
**测试状态**: ⏳ 待测试
**文档状态**: ✅ 完成
