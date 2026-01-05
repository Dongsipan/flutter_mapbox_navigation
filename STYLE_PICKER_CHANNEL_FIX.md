# Style Picker Channel 修复

## 日期
2026-01-05

## 问题
```
MissingPluginException(No implementation found for method showStylePicker on channel flutter_mapbox_navigation/style_picker)
```

## 原因
Flutter 层有一个 `MapboxStylePicker` 类使用 `flutter_mapbox_navigation/style_picker` channel，但 Android 端没有注册这个 channel。

## 修复内容

### 1. 注册 style_picker channel
在 `FlutterMapboxNavigationPlugin.kt` 的 `onAttachedToEngine` 方法中添加：

```kotlin
// 注册样式选择器 channel
stylePickerChannel = MethodChannel(messenger, "flutter_mapbox_navigation/style_picker")
stylePickerChannel.setMethodCallHandler { call, result ->
    handleStylePickerMethod(call, result)
}
```

### 2. 实现 handleStylePickerMethod 方法
添加了处理样式选择器相关方法的函数：

```kotlin
private fun handleStylePickerMethod(call: MethodCall, result: Result) {
    when (call.method) {
        "showStylePicker" -> {
            // 目前返回 false，表示功能未实现
            // TODO: 实现样式选择器 UI
            result.success(false)
        }
        "getStoredStyle" -> {
            // 返回当前存储的样式设置
            val styleSettings = mapOf(
                "mapStyle" to (mapStyleUrlDay ?: Style.MAPBOX_STREETS),
                "lightPreset" to "day",
                "lightPresetMode" to "manual"
            )
            result.success(styleSettings)
        }
        "clearStoredStyle" -> {
            // 清除存储的样式，恢复默认值
            mapStyleUrlDay = null
            mapStyleUrlNight = null
            result.success(true)
        }
        else -> result.notImplemented()
    }
}
```

### 3. 添加必要的导入
```kotlin
import com.mapbox.maps.Style
```

## 功能状态

| 方法 | 状态 | 说明 |
|------|------|------|
| showStylePicker | ⚠️ 占位实现 | 返回 false，UI 未实现 |
| getStoredStyle | ✅ 完成 | 返回当前样式设置 |
| clearStoredStyle | ✅ 完成 | 清除样式设置 |

## 编译状态
✅ **编译通过** - 无错误无警告

## 后续工作

### showStylePicker UI 实现
如果需要实现样式选择器 UI，可以：

1. 创建一个 Dialog 或 Activity 显示样式选项
2. 让用户选择样式
3. 保存选择到 SharedPreferences
4. 返回 true 表示成功

示例实现：
```kotlin
"showStylePicker" -> {
    val styles = arrayOf("Streets", "Outdoors", "Light", "Dark", "Satellite")
    val builder = AlertDialog.Builder(currentActivity)
    builder.setTitle("选择地图样式")
        .setItems(styles) { dialog, which ->
            when (which) {
                0 -> mapStyleUrlDay = Style.MAPBOX_STREETS
                1 -> mapStyleUrlDay = Style.OUTDOORS
                2 -> mapStyleUrlDay = Style.LIGHT
                3 -> mapStyleUrlDay = Style.DARK
                4 -> mapStyleUrlDay = Style.SATELLITE
            }
            result.success(true)
        }
        .setNegativeButton("取消") { dialog, _ ->
            dialog.dismiss()
            result.success(false)
        }
        .show()
}
```

## 总结
- ✅ 修复了 MissingPluginException 错误
- ✅ 注册了 style_picker channel
- ✅ 实现了基础方法处理
- ⚠️ showStylePicker UI 待实现（可选）

---

**状态**: ✅ 错误已修复  
**编译**: ✅ 通过  
**最后更新**: 2026-01-05
