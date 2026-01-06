# 导航测试调试指南

## 最新修复 (2026-01-05 - 第四轮 - 关键修复！)

### 🎯 找到根本原因！

根据 Mapbox Navigation SDK v3 官方文档，在 SDK v3 中：
- `startReplayTripSession()` **不会自动生成模拟位置**
- 需要使用 `mapboxReplayer` 来推送模拟事件

### ✅ 实施的修复

1. **添加 ReplayRouteMapper**：
   ```kotlin
   private val replayRouteMapper = com.mapbox.navigation.core.replay.route.ReplayRouteMapper()
   ```

2. **在 startNavigation 中推送 replay 事件**：
   ```kotlin
   if (FlutterMapboxNavigationPlugin.simulateRoute) {
       // 启动 replay trip session
       mapboxNavigation.startReplayTripSession()
       
       // 关键：将路线几何图形映射为模拟数据
       val replayData = replayRouteMapper.mapDirectionsRouteGeometry(
           routes.first().directionsRoute
       )
       
       // 推送事件并播放
       mapboxNavigation.mapboxReplayer.pushEvents(replayData)
       mapboxNavigation.mapboxReplayer.seekTo(replayData.first())
       mapboxNavigation.mapboxReplayer.play()
   }
   ```

3. **在 stopNavigation 中停止 replayer**：
   ```kotlin
   if (FlutterMapboxNavigationPlugin.simulateRoute) {
       mapboxNavigation.mapboxReplayer.stop()
       mapboxNavigation.mapboxReplayer.clearEvents()
   }
   ```

## 测试步骤

### 1. 重新安装应用

```bash
cd example
flutter build apk --debug
flutter install
```

### 2. 启动应用并查看日志

```bash
adb logcat -c  # 清空日志
adb logcat | grep -E "(NavigationActivity|Mapbox)"
```

### 3. 点击 "Start A to B"

### 4. 预期日志输出

现在应该看到完整的日志序列：

```
D/NavigationActivity: 🔗 MapboxNavigationObserver onAttached - registering observers
D/NavigationActivity: ✅ All observers registered successfully
D/NavigationActivity: Starting navigation with 2 routes, simulateRoute=true
D/NavigationActivity: isNavigationInProgress set to true
D/NavigationActivity: Routes set, count: 2
I/Mapbox: [nav-sdk]: [MapboxTripSession] Start trip session, replay enabled: true
D/NavigationActivity: Started replay trip session for simulation
D/NavigationActivity: Generated XXX replay events
D/NavigationActivity: Mapbox replayer started playing
D/NavigationActivity: Route drawn on map
D/NavigationActivity: Route has 136 points
D/NavigationActivity: Route bounds: minLat=37.76, maxLat=37.77, minLon=-122.44, maxLon=-122.42
D/NavigationActivity: Camera adjusted to route bounds (immediate)
D/NavigationActivity: 📍 Raw location: lat=37.7744, lng=-122.4354
D/NavigationActivity: 📍 Location update: lat=37.7744, lng=-122.4354, bearing=..., speed=..., isNavigationInProgress=true
D/NavigationActivity: 📷 Camera updated to follow location
```

### 5. 预期行为

- ✅ 地图缩放到显示完整路线
- ✅ 看到蓝色路线
- ✅ **位置点开始沿路线移动**（这是新修复的！）
- ✅ 相机跟随位置点移动
- ✅ 看到导航指示和进度更新

## 关键检查点

### ✅ 检查点 1：观察者注册
```
D/NavigationActivity: 🔗 MapboxNavigationObserver onAttached
D/NavigationActivity: ✅ All observers registered successfully
```

### ✅ 检查点 2：Replay 事件生成
```
D/NavigationActivity: Generated XXX replay events
D/NavigationActivity: Mapbox replayer started playing
```
**这是关键！** 如果看到这个日志，说明 replayer 已经开始工作。

### ✅ 检查点 3：位置更新
```
D/NavigationActivity: 📍 Raw location: ...
D/NavigationActivity: 📍 Location update: ...
D/NavigationActivity: 📷 Camera updated to follow location
```
**这应该现在能看到了！**

## 技术说明

### SDK v3 Replay 机制

在 Mapbox Navigation SDK v3 中，模拟导航的工作流程是：

1. **请求路线** → 获取 `NavigationRoute`
2. **设置路线** → `mapboxNavigation.setNavigationRoutes(routes)`
3. **启动 replay session** → `mapboxNavigation.startReplayTripSession()`
4. **生成 replay 数据** → `replayRouteMapper.mapDirectionsRouteGeometry(route)`
5. **推送事件** → `mapboxReplayer.pushEvents(replayData)`
6. **开始播放** → `mapboxReplayer.play()`

### 与 SDK v2 的区别

- **SDK v2**: `startReplayTripSession()` 会自动沿路线生成模拟位置
- **SDK v3**: 需要手动使用 `mapboxReplayer` 推送事件

这就是为什么之前的代码在 SDK v3 中不工作的原因！

## 故障排除

### 问题：仍然没有位置更新

**检查 replay 事件生成日志**：
```bash
adb logcat | grep "Generated.*replay events"
```

如果看不到这个日志：
- 检查 `replayRouteMapper` 是否正确初始化
- 检查路线是否有有效的 geometry 数据

### 问题：Replayer 启动但没有位置

**检查 replayer 播放日志**：
```bash
adb logcat | grep "replayer.*play"
```

如果 replayer 启动了但没有位置更新：
- 可能是 `seekTo` 的问题
- 尝试使用 `replayData[0]` 或 `replayData.first()`

### 问题：位置更新太快或太慢

可以调整 replayer 的速度：
```kotlin
mapboxNavigation.mapboxReplayer.playbackSpeed(1.0) // 1.0 = 正常速度
```

## 调试命令

### 查看完整导航日志
```bash
adb logcat | grep -E "NavigationActivity|MapboxTripSession|Replayer"
```

### 只看关键事件
```bash
adb logcat | grep -E "🔗|✅|📍|📷|Generated.*replay|replayer.*play"
```

### 检查 replay 事件
```bash
adb logcat | grep -i "replay"
```

## 参考资料

- [Mapbox Navigation SDK v3 - Get Started Guide](https://docs.mapbox.com/android/navigation/guides/)
- [Mapbox Navigation SDK v3 - Turn-by-turn Experience](https://docs.mapbox.com/android/navigation/guides/turn-by-turn-experience/)
- [Mapbox Navigation SDK v3 - Location simulation guide](https://docs.mapbox.com/android/navigation/guides/location-simulation/)

---

**最后更新**: 2026-01-05 (第四轮修复 - 关键修复！)
**修复内容**: 
- 添加 ReplayRouteMapper
- 在 startNavigation 中推送 replay 事件
- 在 stopNavigation 中停止 replayer
**状态**: 应该可以工作了！等待测试结果
**关键发现**: SDK v3 需要手动使用 mapboxReplayer 推送事件
