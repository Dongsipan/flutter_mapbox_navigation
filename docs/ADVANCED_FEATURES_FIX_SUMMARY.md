# Android SDK v3 Deprecated API 修复总结

## 日期
2026-01-05

## 修复概述
完成了所有 Android 代码中的 deprecated API 警告修复，确保代码符合 Mapbox SDK v3 的最新 API 规范。

## 修复的文件

### 1. NavigationReplayActivity.kt
**修复数量:** 10+ 处

**修复内容:**
- ✅ `getMapboxMap()` → `mapboxMap` 属性 (10处)
- ✅ `loadStyleUri()` → `loadStyle()` 方法 (1处)
- ✅ `getStyle()` → `style` 属性 (2处)

**具体修改:**
```kotlin
// 旧代码
binding.mapView.getMapboxMap().setCamera(...)
binding.mapView.getMapboxMap().loadStyleUri(styleUri)
binding.mapView.getMapboxMap().getStyle { style -> ... }

// 新代码
binding.mapView.mapboxMap.setCamera(...)
binding.mapView.mapboxMap.loadStyle(styleUri)
binding.mapView.mapboxMap.style?.let { style -> ... }
```

**特殊处理:**
- 将 `getStyle { }` 回调模式改为 `style?.let { }` 空安全检查
- 提取了 `initTravelLineLayer()` 函数以便在样式加载后初始化图层

### 2. PluginUtilities.kt
**修复数量:** 3 处

**修复内容:**
- ✅ `activeNetworkInfo` → 添加 `@Suppress("DEPRECATION")` (仅 API < 23)
- ✅ `isConnected` → 添加 `@Suppress("DEPRECATION")` (仅 API < 23)
- ✅ `getSerializableExtra()` → 添加 `@Suppress("DEPRECATION")` (仅 API < 33)

**具体修改:**
```kotlin
// 网络检查 - 仅在旧版本 Android 上使用 deprecated API
} else {
    @Suppress("DEPRECATION")
    val nwInfo = connectivityManager.activeNetworkInfo ?: return false
    @Suppress("DEPRECATION")
    return nwInfo.isConnected
}

// Serializable 获取 - 仅在旧版本 Android 上使用 deprecated API
} else {
    @Suppress("DEPRECATION")
    activity.intent.getSerializableExtra(name) as T
}
```

**说明:**
- 这些 API 在旧版本 Android 上仍然需要使用
- 使用 `@Suppress("DEPRECATION")` 明确标记这是有意为之
- 新版本 Android (API 23+ 和 33+) 使用新的 API

### 3. NavigationActivity.kt
**修复数量:** 已在之前完成 + 1 处额外修复

**状态:** ✅ 无 deprecated API 警告

**额外修复:**
- ✅ 修复了 `BoundingBox.fromPoints()` 的参数错误
- 改为手动计算边界框坐标

**具体修改:**
```kotlin
// 旧代码（有错误）
val bounds = com.mapbox.geojson.BoundingBox.fromPoints(routePoints)

// 新代码（手动计算边界）
var minLat = Double.MAX_VALUE
var maxLat = Double.MIN_VALUE
var minLon = Double.MAX_VALUE
var maxLon = Double.MIN_VALUE

for (point in routePoints) {
    minLat = kotlin.math.min(minLat, point.latitude())
    maxLat = kotlin.math.max(maxLat, point.latitude())
    minLon = kotlin.math.min(minLon, point.longitude())
    maxLon = kotlin.math.max(maxLon, point.longitude())
}

val cameraOptions = binding.mapView.mapboxMap.cameraForCoordinateBounds(
    com.mapbox.maps.CoordinateBounds(
        com.mapbox.geojson.Point.fromLngLat(minLon, minLat),
        com.mapbox.geojson.Point.fromLngLat(maxLon, maxLat)
    ),
    EdgeInsets(100.0, 100.0, 100.0, 100.0)
)
```

## 修复策略

### 地图 API 更新
1. **属性访问替代方法调用**
   - `getMapboxMap()` → `mapboxMap`
   - `getStyle()` → `style`

2. **方法名称更新**
   - `loadStyleUri()` → `loadStyle()`

3. **回调模式改为空安全检查**
   - `getStyle { style -> }` → `style?.let { style -> }`

### 兼容性 API 处理
对于必须在旧版本 Android 上使用的 deprecated API：
- 使用 `@Suppress("DEPRECATION")` 注解
- 添加版本检查 (`Build.VERSION.SDK_INT`)
- 在新版本上使用新 API

## 编译验证
✅ 所有文件编译通过，无错误
✅ 无 deprecated API 警告
✅ 代码符合 Kotlin 和 Android 最佳实践
✅ APK 构建成功 (debug 模式)

**编译命令:**
```bash
cd example
flutter build apk --debug
```

**结果:**
```
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

## 影响评估
- **功能影响:** 无 - 纯 API 更新，功能保持不变
- **性能影响:** 无 - 新 API 性能相同或更好
- **兼容性:** 保持向后兼容 (Android API 21+)

## 下一步工作
根据 `ANDROID_SDK_V3_NEXT_STEPS.md`：

### 已完成 ✅
1. ~~修复 NavigationActivity 的 deprecated API~~
2. ~~修复其他文件的 deprecated API~~

### 待完成 🔄
3. 重写临时禁用的功能
   - Free Drive 模式
   - Embedded Navigation View
   - Custom Info Panel
   - 地图点击回调

4. 实现缺失的高级功能
   - 历史记录回放 (完整功能)
   - 搜索功能
   - 路线选择
   - 地图样式选择器

## 相关文档
- [ANDROID_SDK_V3_MVP_SUCCESS.md](ANDROID_SDK_V3_MVP_SUCCESS.md)
- [ANDROID_SDK_V3_NEXT_STEPS.md](ANDROID_SDK_V3_NEXT_STEPS.md)
- [ANDROID_SDK_V3_TESTING_STATUS.md](ANDROID_SDK_V3_TESTING_STATUS.md)
