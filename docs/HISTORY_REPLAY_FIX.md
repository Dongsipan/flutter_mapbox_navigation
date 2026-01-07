# History Replay Fix - Launch Failure and Empty Events

## Problem 1: Activity Not Declared
When clicking the replay button in the history list, the replay failed with error:
```
Unable to find explicit activity class {com.eopeter.fluttermapboxnavigationexample/com.eopeter.fluttermapboxnavigation.NavigationReplayActivity}; have you declared this activity in your AndroidManifest.xml
```

## Problem 2: Empty Replay Events
After fixing the manifest issue, the replay activity launched but showed no trajectory:
```
W/NavigationHistoryManager: History file loading temporarily disabled - SDK v3 API needs verification
D/NavigationReplayActivity: 加载回放事件完成，事件数量: 0
W/NavigationReplayActivity: 未能加载回放事件
```

## Root Causes

### Issue 1: Missing Manifest Declaration
`NavigationReplayActivity` was not declared in `AndroidManifest.xml`.

### Issue 2: Unimplemented History Loading
The `NavigationHistoryManager.loadReplayEvents()` method was returning an empty list with a TODO comment. The SDK v3 API for loading history files was not implemented.

## Solutions

### 1. Added Activity to Manifest
Added `NavigationReplayActivity` declaration to `android/src/main/AndroidManifest.xml`:

```xml
<activity 
    android:name="com.eopeter.fluttermapboxnavigation.NavigationReplayActivity"
    android:theme="@style/Theme.AppCompat.Light.NoActionBar"
    android:exported="false" />
```

### 2. Implemented History File Loading
Implemented proper SDK v3 history loading using `MapboxHistoryReader` and `ReplayHistoryMapper`:

```kotlin
fun loadReplayEvents(filePath: String): List<ReplayEventBase> {
    return try {
        val file = File(filePath)
        if (!file.exists()) {
            Log.e(TAG, "History file does not exist: $filePath")
            return emptyList()
        }
        
        Log.d(TAG, "Loading history file: $filePath")
        
        // 使用 MapboxHistoryReader 读取历史文件
        val historyReader = MapboxHistoryReader(filePath)
        
        // 使用 Builder 创建 ReplayHistoryMapper 实例
        val replayHistoryMapper = ReplayHistoryMapper.Builder()
            .build()
        
        val events = mutableListOf<ReplayEventBase>()
        
        // 使用 hasNext() 判断是否还有更多元素，避免在文件末尾抛异常
        while (historyReader.hasNext()) {
            val historyEvent = historyReader.next()
            val replayEvent = replayHistoryMapper.mapToReplayEvent(historyEvent)
            if (replayEvent != null) {
                events.add(replayEvent)
            }
        }
        
        Log.d(TAG, "Successfully loaded ${events.size} replay events from history file")
        events
    } catch (e: Exception) {
        Log.e(TAG, "Failed to load replay events: ${e.message}", e)
        emptyList()
    }
}
```

**Important Notes**: 
- `MapboxHistoryReader` implements `Iterator<HistoryEvent>`, so we must use `hasNext()` to check for more elements. Calling `next()` without checking `hasNext()` will throw an exception when reaching the end of the file.
- `ReplayHistoryMapper` constructor is private, so we must use `ReplayHistoryMapper.Builder().build()` to create an instance. The Builder pattern allows for optional custom mappers (locationMapper, setRouteMapper, etc.) if needed in the future.

### 3. Fixed Intent Extra Key
Changed from `"historyFilePath"` to `"replayFilePath"` in the plugin to match what `NavigationReplayActivity` expects.

## How It Works Now

1. User clicks replay button in Flutter UI
2. Flutter calls `MapBoxNavigation.instance.startHistoryReplay(historyFilePath: "...")`
3. Method channel invokes `startHistoryReplay` in the plugin
4. Plugin creates an Intent and launches `NavigationReplayActivity`
5. Activity reads `"replayFilePath"` from intent
6. Activity calls `NavigationHistoryManager.loadReplayEvents()`
7. `MapboxHistoryReader` reads the .pbf.gz file
8. `ReplayHistoryMapper` converts history events to replay events
9. Events are pushed to `mapboxReplayer`
10. Replay starts and trajectory is displayed on the map

## SDK v3 API Used

- `MapboxHistoryReader(filePath)` - Reads history files saved by `MapboxHistoryRecorder`
- `ReplayHistoryMapper()` - Converts history events to replay events
- `replayHistoryMapper.mapToReplayEvent(historyEvent)` - Maps individual events
- `mapboxReplayer.pushEvents(events)` - Pushes events for replay
- `mapboxReplayer.play()` - Starts the replay

## Testing
After this fix:
1. Navigate a route (or simulate one)
2. Complete or cancel navigation (history is saved)
3. Go to history list
4. Click the replay button
5. `NavigationReplayActivity` should launch
6. The saved trajectory should be displayed and replayed on the map

## Files Modified
- `android/src/main/AndroidManifest.xml`
  - Added `NavigationReplayActivity` declaration

- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/FlutterMapboxNavigationPlugin.kt`
  - Implemented `startHistoryReplay()` to launch `NavigationReplayActivity`
  - Fixed intent extra key from `"historyFilePath"` to `"replayFilePath"`
  - Added proper error handling and logging
  - Added null check for `currentActivity`

- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/utilities/NavigationHistoryManager.kt`
  - Implemented `loadReplayEvents()` using SDK v3 APIs
  - Added `MapboxHistoryReader` to read history files
  - Added `ReplayHistoryMapper` to convert events
  - Added proper error handling and logging

## Related Components
- `NavigationReplayActivity` - The activity that handles history replay
- `MapboxHistoryReader` - SDK v3 class for reading history files
- `ReplayHistoryMapper` - SDK v3 class for converting history events to replay events
- `MapboxReplayer` - Handles the actual replay of events
- `MapboxHistoryRecorder` - Records navigation history (used during navigation)
