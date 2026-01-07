# History Recording Fix - Empty List Issue

## Problem
History files were being saved successfully by the Mapbox SDK, but `getNavigationHistoryList()` was returning an empty list.

## Root Cause
When history recording stopped, the file was saved to disk by Mapbox SDK at:
```
/data/user/0/com.eopeter.fluttermapboxnavigationexample/files/mbx_nav/history/2026-01-07T14-59-45Z_cb0f2788-5088-4977-a79f-1ce352bc0838.pbf.gz
```

However, the metadata about this history record was never saved to the `HistoryManager` database (SharedPreferences). The `HistoryManager.getHistoryList()` method reads from SharedPreferences, so it returned an empty list even though the files existed on disk.

## Solution

### 1. Track Navigation Start Time
Added a new variable to track when navigation starts:
```kotlin
private var navigationStartTime: Long = 0L
```

This is set when history recording starts in `startHistoryRecording()`:
```kotlin
navigationStartTime = System.currentTimeMillis()
```

### 2. Save History Metadata on Stop
Modified `stopHistoryRecording()` to save the history record metadata to `HistoryManager`:

```kotlin
// Calculate duration
val duration = if (navigationStartTime > 0) {
    ((System.currentTimeMillis() - navigationStartTime) / 1000).toInt()
} else {
    0
}

// Extract origin and destination names from waypoints
val startPointName = if (waypointSet.waypoints.isNotEmpty()) {
    waypointSet.waypoints.first().name ?: "Unknown"
} else {
    "Unknown"
}

val endPointName = if (waypointSet.waypoints.size > 1) {
    waypointSet.waypoints.last().name ?: "Unknown"
} else {
    "Unknown"
}

// Save history record to HistoryManager
val historyData = mapOf(
    "id" to java.util.UUID.randomUUID().toString(),
    "filePath" to historyFilePath,
    "startTime" to navigationStartTime,
    "duration" to duration.toLong(),
    "startPointName" to startPointName,
    "endPointName" to endPointName,
    "navigationMode" to if (FlutterMapboxNavigationPlugin.simulateRoute) "simulation" else "real"
)

FlutterMapboxNavigationPlugin.historyManager.saveHistoryRecord(historyData)
```

### 3. Enhanced Logging
Added detailed logging to both:
- `NavigationActivity.stopHistoryRecording()` - logs when history metadata is saved
- `FlutterMapboxNavigationPlugin.getNavigationHistoryList()` - logs how many records are retrieved

## Testing
After this fix:
1. Start navigation
2. Complete or cancel navigation
3. Call `getNavigationHistoryList()`
4. The list should now contain the history record with:
   - Unique ID
   - File path to the .pbf.gz file
   - Start time
   - Duration in seconds
   - Start point name
   - End point name
   - Navigation mode (simulation/real)

## Files Modified
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
  - Added `navigationStartTime` variable
  - Modified `startHistoryRecording()` to capture start time
  - Modified `stopHistoryRecording()` to save metadata to HistoryManager

- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/FlutterMapboxNavigationPlugin.kt`
  - Enhanced logging in `getNavigationHistoryList()`

- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/models/WaypointSet.kt`
  - Added `getFirstWaypointName()` method to access first waypoint name
  - Added `getLastWaypointName()` method to access last waypoint name
  - Maintains encapsulation while providing needed functionality

## Related Components
- `HistoryManager` - Manages history records in SharedPreferences
- `HistoryRecord` - Data class for history metadata
- Mapbox SDK `historyRecorder` - Saves the actual .pbf.gz files
