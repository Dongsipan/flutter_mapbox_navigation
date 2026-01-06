# Kotlin 编译错误修复

## 问题描述

在升级到 Gradle 8.7 和 Kotlin 2.1.0 后，编译时出现以下错误：

```
e: NavigationActivity.kt:1212:24 Argument type mismatch: actual type is 'kotlin.Unit?', but 'R & Any' was expected.
```

错误位置：`routeProgressObserver` 中的 `maneuvers.fold()` 调用

## 根本原因

Kotlin 的 `fold` 方法要求两个 lambda 分支返回相同的非空类型 `R & Any`。

原始代码问题：
```kotlin
maneuvers.fold(
    { error -> android.util.Log.e(TAG, "Maneuver error: ${error.errorMessage}") },
    { binding.maneuverView?.renderManeuvers(maneuvers) }
)
```

- 第一个 lambda 隐式返回 `Unit`（`Log.e` 的返回值）
- 第二个 lambda 返回 `Unit?`（因为 `?.` 安全调用操作符）
- `fold` 方法期望两个分支返回相同的非空类型，但得到了 `Unit` 和 `Unit?`

## 解决方案

参考 Mapbox 官方示例代码（TurnByTurnExperienceActivity.kt），在两个 lambda 分支末尾显式返回 `Unit`：

```kotlin
val maneuvers = maneuverApi.getManeuvers(routeProgress)
maneuvers.fold(
    { error ->
        android.util.Log.e(TAG, "Maneuver error: ${error.errorMessage}")
        Unit  // 显式返回 Unit
    },
    {
        binding.maneuverView?.visibility = View.VISIBLE
        binding.maneuverView?.renderManeuvers(maneuvers)
        Unit  // 显式返回 Unit
    }
)
```

## 关键要点

1. **`fold` 方法的类型要求**：两个 lambda 必须返回相同的非空类型
2. **安全调用操作符 `?.`**：会将返回类型从 `T` 变为 `T?`
3. **显式返回 `Unit`**：确保两个分支都返回相同的非空类型
4. **官方示例模式**：`renderManeuvers` 接受 `Expected` 类型参数，而不是解包后的值

## 修复文件

- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt` (第 1209-1218 行)

## 编译结果

✅ 编译成功
```
Running Gradle task 'assembleDebug'...                             92.5s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

## 参考

- Mapbox Navigation Android 官方示例：`TurnByTurnExperienceActivity.kt`
- Kotlin `fold` 方法文档
- Mapbox SDK v3 `Expected<Error, Value>` 模式
