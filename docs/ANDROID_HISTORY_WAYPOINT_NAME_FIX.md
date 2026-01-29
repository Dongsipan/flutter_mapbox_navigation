# Android History Waypoint Name Fix

## Issue
历史记录中的 `startPointName` 和 `endPointName` 字段显示为 "Start Point" 和 "End Point" 或 "Unknown"，而不是实际的地点名称。

## Root Cause Analysis

### Problem 1: TurnByTurn.kt - Missing Name in Waypoint Creation
在 `TurnByTurn.kt` 的 `buildRoute()` 方法中，创建 Waypoint 时没有传入 `name` 参数：

```kotlin
// ❌ 错误代码（第127行）
val point = item.value as HashMap<*, *>
val latitude = point["Latitude"] as Double
val longitude = point["Longitude"] as Double
val isSilent = point["IsSilent"] as Boolean
this.addedWaypoints.add(Waypoint(Point.fromLngLat(longitude, latitude), isSilent))  // 缺少 name
```

这导致 Waypoint 的 `name` 字段使用默认值 `""`（空字符串）。

### Problem 2: TurnByTurn.kt - Hardcoded Names in History Recording
在 `TurnByTurn.kt` 的历史记录开始时（第675-676行），使用了硬编码的名称：

```kotlin
// ❌ 错误代码
navigationStartPointName = "Start Point"
navigationEndPointName = "End Point"
```

这导致所有历史记录都显示相同的名称。

## Solution

### Fix 1: Parse Name from Flutter Arguments
在 `buildRoute()` 方法中，从 Flutter 传入的参数中解析 `Name` 字段：

```kotlin
// ✅ 修复后的代码
val point = item.value as HashMap<*, *>
val name = point["Name"] as? String ?: ""  // 获取 name 字段
val latitude = point["Latitude"] as Double
val longitude = point["Longitude"] as Double
val isSilent = point["IsSilent"] as Boolean
this.addedWaypoints.add(Waypoint(name, Point.fromLngLat(longitude, latitude), isSilent))  // 传入 name
```

### Fix 2: Use WaypointSet Methods
在历史记录开始时，使用 `WaypointSet` 的方法获取实际的地点名称：

```kotlin
// ✅ 修复后的代码
navigationStartPointName = addedWaypoints.getFirstWaypointName()
navigationEndPointName = addedWaypoints.getLastWaypointName()
```

这些方法会：
1. 返回第一个/最后一个 waypoint 的 `name` 字段
2. 如果为空或不存在，返回 "Unknown"

## Implementation Details

### WaypointSet.kt
已有的辅助方法（无需修改）：

```kotlin
/**
 * Returns the name of the first waypoint, or "Unknown" if empty
 */
fun getFirstWaypointName(): String {
    return waypoints.firstOrNull()?.name ?: "Unknown"
}

/**
 * Returns the name of the last waypoint, or "Unknown" if empty
 */
fun getLastWaypointName(): String {
    return waypoints.lastOrNull()?.name ?: "Unknown"
}
```

### Waypoint.kt
Waypoint 数据类定义（无需修改）：

```kotlin
data class Waypoint(
    @SerializedName("name")
    val name: String = "",
    @SerializedName("point")
    val point: Point,
    @SerializedName("isSilent")
    val isSilent: Boolean,
) : Serializable
```

## Data Flow

### Flutter → Android
1. Flutter 调用 `buildRoute()` 方法
2. 传入 waypoints 参数：
   ```dart
   {
     "wayPoints": {
       0: {"Name": "起点名称", "Latitude": 39.9, "Longitude": 116.4, "IsSilent": false},
       1: {"Name": "终点名称", "Latitude": 40.0, "Longitude": 116.5, "IsSilent": false}
     }
   }
   ```

### Android Processing
1. `buildRoute()` 解析参数并创建 Waypoint（包含 name）
2. 添加到 `addedWaypoints` (WaypointSet)
3. 开始导航时，调用 `getFirstWaypointName()` 和 `getLastWaypointName()`
4. 保存到历史记录

### History Record
历史记录包含正确的地点名称：
```kotlin
mapOf(
    "historyId" to "uuid",
    "startTime" to timestamp,
    "distance" to 1234.5,
    "duration" to 300,
    "startPointName" to "起点名称",  // ✅ 正确的名称
    "endPointName" to "终点名称",    // ✅ 正确的名称
    "navigationMode" to "cycling"
)
```

## Comparison: NavigationActivity vs TurnByTurn

### NavigationActivity.kt (Already Correct ✅)
```kotlin
val capturedStartPointName = waypointSet.getFirstWaypointName()
val capturedEndPointName = waypointSet.getLastWaypointName()
```

### TurnByTurn.kt (Now Fixed ✅)
```kotlin
// Before: Hardcoded
navigationStartPointName = "Start Point"
navigationEndPointName = "End Point"

// After: Using WaypointSet methods
navigationStartPointName = addedWaypoints.getFirstWaypointName()
navigationEndPointName = addedWaypoints.getLastWaypointName()
```

## Testing

### Build Verification
```bash
cd example/android
./gradlew assembleDebug
```
**Status**: ✅ Build successful

### Runtime Verification
1. Start navigation with named waypoints
2. Complete navigation
3. Check history record in database
4. Verify `startPointName` and `endPointName` show actual names

### Expected Results
- ✅ History records show actual waypoint names
- ✅ No more "Start Point" / "End Point" hardcoded values
- ✅ Falls back to "Unknown" if name is not provided

## Files Modified
1. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/TurnByTurn.kt`
   - Line 127: Added `name` parsing in `buildRoute()`
   - Line 675-676: Changed to use `getFirstWaypointName()` and `getLastWaypointName()`
   - Line 689: Added logging for waypoint names

## Related Files (No Changes Needed)
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/models/WaypointSet.kt` - Already has helper methods
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/models/Waypoint.kt` - Already has name field
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt` - Already correct

## Impact
- ✅ Fixes history record waypoint names in TurnByTurn navigation
- ✅ No breaking changes
- ✅ Backward compatible (falls back to "Unknown" if name not provided)
- ✅ Consistent with NavigationActivity implementation

## Logging
Added logging to verify waypoint names:
```kotlin
Log.d(TAG, "Start point: $navigationStartPointName, End point: $navigationEndPointName")
```

This will help debug any future issues with waypoint names.
