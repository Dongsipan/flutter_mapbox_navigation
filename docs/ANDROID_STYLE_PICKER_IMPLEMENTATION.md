# Android 样式选择器实现

## 问题描述

Android 端点击"打开样式选择器"按钮没有反应，因为 `showStylePicker` 方法只返回 `false`，没有实际实现。

## 解决方案

为 Android 端实现了完整的样式选择器功能，包括：

### 1. 创建 StylePickerActivity

**文件**: `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/StylePickerActivity.kt`

功能：
- 地图样式选择（7 种样式）
- Light Preset 选择（4 种光照效果）
- 自动调整开关（根据日出日落自动切换）
- 应用和取消按钮

支持的样式：
- Standard（标准）
- Standard Satellite（卫星）
- Faded（褪色）
- Monochrome（单色）
- Light（浅色）
- Dark（深色）
- Outdoors（户外）

支持的 Light Preset：
- 🌅 Dawn（黎明）
- ☀️ Day（白天）
- 🌇 Dusk（黄昏）
- 🌙 Night（夜晚）

### 2. 创建布局文件

**文件**: `android/src/main/res/layout/activity_style_picker.xml`

UI 组件：
- 说明卡片
- 地图样式 Spinner
- Light Preset Spinner（仅支持的样式显示）
- 自动调整 Switch
- 应用和取消按钮

### 3. 添加字符串资源

**文件**: `android/src/main/res/values/strings.xml`

添加了：
- `map_styles` 数组：7 种地图样式
- `light_presets` 数组：4 种光照效果

### 4. 注册 Activity

**文件**: `android/src/main/AndroidManifest.xml`

```xml
<activity 
    android:name="com.eopeter.fluttermapboxnavigation.activity.StylePickerActivity"
    android:theme="@style/Theme.AppCompat.Light" />
```

### 5. 更新插件实现

**文件**: `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/FlutterMapboxNavigationPlugin.kt`

#### 新增方法

1. **showStylePicker(result: Result)**
   - 从 SharedPreferences 读取当前设置
   - 启动 StylePickerActivity
   - 使用 `startActivityForResult` 等待用户选择

2. **getStoredStyle(result: Result)**
   - 从 SharedPreferences 读取存储的样式设置
   - 返回 mapStyle, lightPreset, lightPresetMode

3. **clearStoredStyle(result: Result)**
   - 清除 SharedPreferences 中的样式设置
   - 重置为默认值

4. **handleStylePickerResult(resultCode: Int, data: Intent?)**
   - 处理 StylePickerActivity 的返回结果
   - 保存用户选择到 SharedPreferences
   - 更新全局样式设置

5. **getStyleUrl(styleName: String): String**
   - 将样式名称转换为 Mapbox 样式 URL

#### Activity 结果监听

在 `onAttachedToActivity` 中添加了 `ActivityResultListener`：

```kotlin
binding.addActivityResultListener { requestCode, resultCode, data ->
    if (requestCode == STYLE_PICKER_REQUEST_CODE) {
        handleStylePickerResult(resultCode, data)
        return@addActivityResultListener true
    }
    false
}
```

## 数据存储

使用 SharedPreferences 存储样式设置：

```kotlin
val prefs = activity.getSharedPreferences("mapbox_style_settings", Context.MODE_PRIVATE)
prefs.edit().apply {
    putString("map_style", mapStyle)
    putString("light_preset", lightPreset)
    putString("light_preset_mode", lightPresetMode)
    apply()
}
```

存储的键：
- `map_style`: 地图样式名称
- `light_preset`: Light Preset 名称
- `light_preset_mode`: "manual" 或 "automatic"

## 样式映射

| 样式名称 | Mapbox URL |
|---------|-----------|
| standard | Style.MAPBOX_STREETS |
| standardSatellite | Style.SATELLITE_STREETS |
| faded | mapbox://styles/mapbox/light-v11 |
| monochrome | mapbox://styles/mapbox/dark-v11 |
| light | Style.LIGHT |
| dark | Style.DARK |
| outdoors | Style.OUTDOORS |

## 使用流程

1. 用户点击"打开样式选择器"按钮
2. Flutter 调用 `MapboxStylePicker.show()`
3. Android 端启动 `StylePickerActivity`
4. 用户选择样式和设置
5. 点击"应用"按钮
6. Activity 返回结果
7. 插件保存设置到 SharedPreferences
8. 返回 `true` 给 Flutter
9. Flutter 重新加载显示最新设置

## 测试验证

✅ 编译成功
```
Running Gradle task 'assembleDebug'...                             47.1s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

## 功能特性

1. ✅ **完整的 UI** - 美观的 Material Design 界面
2. ✅ **智能显示** - Light Preset 仅在支持的样式下显示
3. ✅ **自动存储** - 用户选择后自动保存
4. ✅ **持久化** - 使用 SharedPreferences 持久化存储
5. ✅ **取消支持** - 用户可以取消操作
6. ✅ **默认值** - 提供合理的默认设置

## 与 iOS 对比

| 功能 | iOS | Android |
|------|-----|---------|
| 样式选择器 UI | ✅ | ✅ |
| Light Preset | ✅ | ✅ |
| 自动调整 | ✅ | ✅ |
| 持久化存储 | UserDefaults | SharedPreferences |
| 样式数量 | 7 | 7 |
| Light Preset 数量 | 4 | 4 |

## 后续优化

可能的改进：
1. 添加样式预览图
2. 支持自定义样式 URL
3. 添加样式搜索功能
4. 支持样式收藏
5. 添加样式分类

## 相关文件

- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/StylePickerActivity.kt`
- `android/src/main/res/layout/activity_style_picker.xml`
- `android/src/main/res/values/strings.xml`
- `android/src/main/AndroidManifest.xml`
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/FlutterMapboxNavigationPlugin.kt`
- `lib/src/mapbox_style_picker.dart`
- `example/lib/style_picker_example.dart`
