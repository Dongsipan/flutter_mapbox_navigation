# Android autoBuildRoute 参数修复

## 问题描述

路线选择功能示例中的 `autoBuildRoute` 参数在 Android 端没有生效。该参数在 iOS 端已经实现，但 Android 端缺少相应的实现。

同时，Android 端使用了 `showAlternateRoutes` 变量名，与 iOS 端的 `alternatives` 不一致。

## 问题分析

1. **iOS 端实现**：iOS 端在 `NavigationFactory.swift` 中已经实现了 `autoBuildRoute` 和 `alternatives` 参数的处理
2. **Android 端缺失**：Android 端只实现了 `showAlternateRoutes` 参数（从 `alternatives` 选项读取），但没有实现 `autoBuildRoute` 参数
3. **命名不一致**：Android 端使用 `showAlternateRoutes`，iOS 端使用 `_alternatives`
4. **行为不一致**：导致 iOS 和 Android 在路线选择功能上的行为不一致

## 解决方案

### 1. 统一参数命名

将 Android 端的 `showAlternateRoutes` 重命名为 `alternatives`，与 iOS 端保持一致：

```kotlin
// 修改前
var showAlternateRoutes: Boolean = true

// 修改后
var alternatives: Boolean = true
```

### 2. 添加 autoBuildRoute 参数定义

在 `FlutterMapboxNavigationPlugin.kt` 中添加 `autoBuildRoute` 静态变量：

```kotlin
var alternatives: Boolean = true
var autoBuildRoute: Boolean = true  // 新增
var longPressDestinationEnabled: Boolean = true
```

### 3. 解析参数

在 `checkPermissionAndBeginNavigation` 方法中添加参数解析：

```kotlin
val alternateRoutes = arguments?.get("alternatives") as? Boolean
if (alternateRoutes != null) {
    alternatives = alternateRoutes
}

// 新增：解析 autoBuildRoute 参数
val autoBuild = arguments?.get("autoBuildRoute") as? Boolean
if (autoBuild != null) {
    autoBuildRoute = autoBuild
}
```

### 4. 更新路线选择逻辑

在 `NavigationActivity.kt` 中更新路线选择的判断逻辑，与 iOS 保持一致：

```kotlin
currentRoutes = routes

// Check autoBuildRoute parameter (consistent with iOS behavior)
if (!FlutterMapboxNavigationPlugin.autoBuildRoute) {
    // When autoBuildRoute is false, always show route selection UI
    showRouteSelection(routes)
} else {
    // When autoBuildRoute is true, start navigation immediately
    startNavigation(routes)
}
```

## 参数说明

### alternatives（备选路线）
- **作用**：控制是否请求多条备选路线
- **默认值**：`true`
- **iOS 对应**：`_alternatives` → `includesAlternativeRoutes`
- **Android 对应**：`alternatives` → `RouteOptions.alternatives()`

### autoBuildRoute（自动构建路线）
- **作用**：控制是否自动开始导航还是显示路线选择界面
- **默认值**：`true`
- **行为**：
  - `true`：直接计算路线并开始导航
  - `false`：先显示路线选择界面，用户选择后再开始导航

## 参数独立性

这两个参数是独立的，可以组合使用：

| alternatives | autoBuildRoute | 行为 |
|-------------|----------------|------|
| true | true | 请求多条路线，自动开始导航（使用第一条路线） |
| true | false | 请求多条路线，显示路线选择界面 |
| false | true | 只请求一条路线，自动开始导航 |
| false | false | 只请求一条路线，显示路线选择界面（只有一条路线可选） |

## 使用示例

```dart
// 示例 1：请求多条路线并显示选择界面
final options = MapBoxOptions(
  mode: MapBoxNavigationMode.drivingWithTraffic,
  simulateRoute: true,
  language: 'zh-Hans',
  alternatives: true,        // 请求备选路线
  autoBuildRoute: false,     // 显示路线选择界面
  voiceInstructionsEnabled: true,
  bannerInstructionsEnabled: true,
);

// 示例 2：请求多条路线但自动开始导航
final options2 = MapBoxOptions(
  alternatives: true,        // 请求备选路线
  autoBuildRoute: true,      // 自动开始导航（默认值）
);

// 示例 3：只请求一条路线并自动开始导航
final options3 = MapBoxOptions(
  alternatives: false,       // 不请求备选路线
  autoBuildRoute: true,      // 自动开始导航
);
```

## 测试验证

1. **alternatives = true, autoBuildRoute = true**：应该请求多条路线并直接开始导航
2. **alternatives = true, autoBuildRoute = false**：应该请求多条路线并显示路线选择界面
3. **alternatives = false, autoBuildRoute = false**：应该请求一条路线并显示路线选择界面

## 影响范围

- ✅ Android 端现在支持 `autoBuildRoute` 参数
- ✅ Android 端参数命名与 iOS 端保持一致（`alternatives`）
- ✅ 与 iOS 端行为完全一致
- ✅ 不影响现有功能，默认值为 `true`（保持向后兼容）
- ✅ 移除了 `showAlternateRoutes` 变量，统一使用 `alternatives`

## 相关文件

- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/FlutterMapboxNavigationPlugin.kt`
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/NavigationFactory.swift`
- `lib/src/models/options.dart`
- `example/lib/route_selection_example.dart`
