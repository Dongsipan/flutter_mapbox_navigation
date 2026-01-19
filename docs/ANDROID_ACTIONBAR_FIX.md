# Android ActionBar 背景色修复

## 问题描述
在使用 Material Components 主题时，`colorPrimary` 会被自动应用为 ActionBar 的背景色，导致导航栏显示为绿色 (#01E47C) 而不是期望的深色背景 (#040608)。

## 问题原因
Material Components 主题的默认行为：
- `colorPrimary` 用于 ActionBar/Toolbar 背景
- `colorAccent` 用于按钮和交互元素

但我们的设计要求：
- ActionBar 背景应该是深色 (#040608)
- 按钮和图标应该使用主题色 (#01E47C)

## 解决方案

### 方案 1：在 styles.xml 中配置（已实现）
通过设置 `colorPrimarySurface` 来覆盖 ActionBar 的背景色：

```xml
<style name="KtMaterialTheme" parent="Theme.MaterialComponents.DayNight.DarkActionBar">
    <!-- 主题色用于按钮、图标 -->
    <item name="colorPrimary">@color/colorPrimary</item>
    
    <!-- ActionBar 背景使用深色 -->
    <item name="colorPrimarySurface">@color/colorBackground</item>
    <item name="colorOnPrimary">@color/textPrimary</item>
</style>
```

**问题**：这个方案在某些情况下不生效，特别是当 Activity 动态设置 ActionBar 时。

### 方案 2：在代码中明确设置（最终方案）
在每个使用 ActionBar 的 Activity 中，明确设置背景色：

```kotlin
supportActionBar?.apply {
    title = "标题"
    setDisplayHomeAsUpEnabled(true)
    elevation = 4f
    // 设置 ActionBar 背景为深色
    setBackgroundDrawable(
        android.graphics.drawable.ColorDrawable(
            resources.getColor(R.color.colorBackground, null)
        )
    )
}
```

## 已修复的文件

### 1. SearchActivity.kt
**位置**：`android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/SearchActivity.kt`

**修改内容**：
```kotlin
// 设置 ActionBar（使用深色背景而非主题色）
supportActionBar?.apply {
    title = getString(R.string.simple_ui_toolbar_title)
    setDisplayHomeAsUpEnabled(true)
    elevation = 4f
    // 设置 ActionBar 背景为深色
    setBackgroundDrawable(
        android.graphics.drawable.ColorDrawable(
            resources.getColor(R.color.colorBackground, null)
        )
    )
}
```

### 2. StylePickerActivity.kt
**位置**：`android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/StylePickerActivity.kt`

**修改内容**：
```kotlin
// 设置标题和返回按钮（使用深色背景）
supportActionBar?.apply {
    title = "地图样式设置"
    setDisplayHomeAsUpEnabled(true)
    elevation = 4f
    // 设置 ActionBar 背景为深色
    setBackgroundDrawable(
        android.graphics.drawable.ColorDrawable(
            resources.getColor(R.color.colorBackground, null)
        )
    )
}
```

### 3. NavigationReplayActivity.kt
**位置**：`android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationReplayActivity.kt`

**修改内容**：
```kotlin
supportActionBar?.apply {
    if (!customTitle.isNullOrEmpty()) {
        title = customTitle
    } else {
        title = getString(R.string.navigation_replay_title)
    }
    
    setDisplayHomeAsUpEnabled(true)
    elevation = 4f
    // 设置 ActionBar 背景为深色
    setBackgroundDrawable(
        android.graphics.drawable.ColorDrawable(
            resources.getColor(R.color.colorBackground, null)
        )
    )
}
```

## 验证清单

- [x] SearchActivity - 搜索地点页面
- [x] StylePickerActivity - 样式选择器页面
- [x] NavigationReplayActivity - 历史回放页面
- [x] NavigationActivity - 不使用 ActionBar，无需修改

## 视觉效果

### 修复前
- ❌ ActionBar 背景：绿色 (#01E47C)
- ✅ ActionBar 图标：绿色 (#01E47C)
- ✅ ActionBar 文字：白色

### 修复后
- ✅ ActionBar 背景：深色 (#040608)
- ✅ ActionBar 图标：绿色 (#01E47C)
- ✅ ActionBar 文字：白色

## 注意事项

1. **颜色资源引用**：使用 `resources.getColor(R.color.colorBackground, null)` 而不是硬编码颜色值
2. **主题一致性**：确保所有 Activity 都使用相同的背景色
3. **状态栏颜色**：状态栏颜色已在 styles.xml 中统一设置为深色
4. **图标颜色**：ActionBar 的图标颜色由 `colorPrimary` 控制，保持为绿色

## 测试建议

1. 启动 SearchActivity，检查导航栏背景是否为深色
2. 启动 StylePickerActivity，检查导航栏背景是否为深色
3. 启动 NavigationReplayActivity，检查导航栏背景是否为深色
4. 检查所有页面的返回按钮是否为绿色
5. 检查所有页面的标题文字是否为白色

## 相关文档

- [Android 主题配置](./ANDROID_THEME_UPDATE.md)
- [主题配置总结](./THEME_CONFIGURATION_SUMMARY.md)

## 更新日期

2024-01-19
