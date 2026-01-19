# Android 主题配置更新

## 概述
已将 Android 端的主题配置更新为与 Flutter 主题保持一致的深色主题。

## 主题色配置

### 颜色定义 (colors.xml)

```xml
<!-- 主题色 - 用于按钮、图标等交互元素 -->
<color name="colorPrimary">#01E47C</color>
<color name="colorPrimaryDark">#00B35F</color>
<color name="colorAccent">#01E47C</color>

<!-- 背景色 - 用于页面、导航栏等 -->
<color name="colorBackground">#040608</color>
<color name="colorSurface">#040608</color>

<!-- 文字颜色 -->
<color name="textPrimary">#FFFFFF</color>
<color name="textSecondary">#8AFFFFFF</color> <!-- 54% 不透明度 -->
<color name="textDisabled">#61FFFFFF</color>  <!-- 38% 不透明度 -->
```

### 与 Flutter 主题对应关系

| Flutter | Android |
|---------|---------|
| `Color(0xFF01E47C)` (primary) | `@color/colorPrimary` |
| `Color(0xFF040608)` (surface/background) | `@color/colorBackground` |
| `Colors.white` (text) | `@color/textPrimary` |
| `Colors.white54` (secondary text) | `@color/textSecondary` |
| `Brightness.dark` | `Theme.MaterialComponents.DayNight` |

## 颜色使用规范

### ✅ 正确的使用方式

| 元素 | 应使用的颜色 | 说明 |
|------|-------------|------|
| **ActionBar/Toolbar 背景** | `@color/colorBackground` (#040608) | 深色背景 |
| **ActionBar/Toolbar 图标** | `@color/colorPrimary` (#01E47C) | 绿色主题色 |
| **ActionBar/Toolbar 文字** | `@color/textPrimary` (白色) | 白色文字 |
| **状态栏** | `@color/colorBackground` (#040608) | 深色背景 |
| **导航栏** | `@color/colorBackground` (#040608) | 深色背景 |
| **页面背景** | `@color/colorBackground` (#040608) | 深色背景 |
| **按钮背景** | `@color/colorPrimary` (#01E47C) | 绿色主题色 |
| **按钮文字** | `@color/white` | 白色 |
| **图标/链接** | `@color/colorPrimary` (#01E47C) | 绿色主题色 |

### ❌ 常见错误

- ❌ ActionBar 背景使用 `colorPrimary` (会变成绿色)
- ❌ 按钮背景使用 `colorBackground` (会变成深色，看不清)
- ❌ 状态栏使用 `colorPrimary` (会变成绿色)

## 主题样式配置 (styles.xml)

### 关键配置项

```xml
<!-- 带 ActionBar 的主题 -->
<style name="KtMaterialTheme" parent="Theme.MaterialComponents.DayNight.DarkActionBar">
    <!-- 主题色 - 用于按钮、图标等交互元素 -->
    <item name="colorPrimary">@color/colorPrimary</item>
    <item name="colorAccent">@color/colorAccent</item>
    
    <!-- ActionBar 背景色 - 使用深色背景而非主题色 -->
    <item name="colorPrimarySurface">@color/colorBackground</item>
    <item name="colorOnPrimary">@color/textPrimary</item>
    
    <!-- 页面背景 -->
    <item name="android:windowBackground">@color/colorBackground</item>
    
    <!-- 状态栏和导航栏 - 使用深色背景 -->
    <item name="android:statusBarColor">@color/colorBackground</item>
    <item name="android:navigationBarColor">@color/colorBackground</item>
    <item name="android:windowLightStatusBar">false</item>
</style>
```

### 重要属性说明

| 属性 | 作用 | 配置值 |
|------|------|--------|
| `colorPrimary` | 主题色，用于按钮、图标等 | `#01E47C` (绿色) |
| `colorPrimarySurface` | ActionBar 背景色 | `#040608` (深色) |
| `colorOnPrimary` | ActionBar 上的文字颜色 | 白色 |
| `android:statusBarColor` | 状态栏背景色 | `#040608` (深色) |
| `android:navigationBarColor` | 导航栏背景色 | `#040608` (深色) |
| `android:windowLightStatusBar` | 状态栏图标颜色 | `false` (白色图标) |

## Material 3 颜色系统

为了更好地支持 Material 3，还定义了以下颜色：

```xml
<!-- Material 3 颜色系统 -->
<color name="md_theme_primary">#01E47C</color>
<color name="md_theme_onPrimary">#FFFFFF</color>
<color name="md_theme_primaryContainer">#00B35F</color>
<color name="md_theme_onPrimaryContainer">#FFFFFF</color>

<color name="md_theme_secondary">#01E47C</color>
<color name="md_theme_onSecondary">#FFFFFF</color>

<color name="md_theme_background">#040608</color>
<color name="md_theme_onBackground">#FFFFFF</color>

<color name="md_theme_surface">#040608</color>
<color name="md_theme_onSurface">#FFFFFF</color>

<color name="md_theme_error">#FF0000</color>
<color name="md_theme_onError">#FFFFFF</color>
```

## 已更新的主题样式

### 1. AppTheme
- 基础应用主题
- 无 ActionBar
- 深色背景

### 2. KtMaterialTheme_NoActionBar
- 无 ActionBar 的深色主题
- 用于全屏页面

### 3. KtMaterialTheme
- 带 ActionBar 的深色主题
- **ActionBar 背景使用深色 (#040608)**
- **ActionBar 图标和文字使用主题色和白色**

### 4. StylePickerTheme
- 样式选择器主题
- 带 ActionBar
- **ActionBar 背景使用深色 (#040608)**

## 视觉效果

### 深色主题特性
- ✅ 所有背景为深色 (#040608)
- ✅ ActionBar/Toolbar 背景为深色 (#040608)
- ✅ 所有文字为白色或半透明白色
- ✅ 主题色 (#01E47C) 用于按钮、图标等交互元素
- ✅ 状态栏和导航栏为深色背景

### 一致性
- ✅ 与 Flutter Material 3 深色主题完全一致
- ✅ 与 iOS 主题配置保持统一
- ✅ 所有 UI 组件使用统一的颜色系统

## 在代码中使用

### XML 布局中使用

```xml
<!-- 按钮使用主题色 -->
<Button
    android:background="@color/colorPrimary"
    android:textColor="@color/white" />

<!-- 文字使用白色 -->
<TextView
    android:textColor="@color/textPrimary" />

<!-- 次要文字使用半透明白色 -->
<TextView
    android:textColor="@color/textSecondary" />

<!-- 背景使用深色 -->
<LinearLayout
    android:background="@color/colorBackground" />
```

### Kotlin 代码中使用

```kotlin
// 获取颜色资源
val primaryColor = ContextCompat.getColor(context, R.color.colorPrimary)
val backgroundColor = ContextCompat.getColor(context, R.color.colorBackground)
val textColor = ContextCompat.getColor(context, R.color.textPrimary)

// 设置背景色
view.setBackgroundColor(backgroundColor)

// 设置文字颜色
textView.setTextColor(textColor)

// 设置按钮颜色
button.setBackgroundColor(primaryColor)
```

## 测试建议

- [ ] 测试所有 Activity 的 ActionBar 背景色是否为深色
- [ ] 检查按钮和图标是否使用主题色
- [ ] 验证文字可读性（白色文字在深色背景上）
- [ ] 确认状态栏和导航栏为深色
- [ ] 测试深色模式下的整体视觉效果
- [ ] 检查 Material 组件（CardView、Dialog 等）的颜色

## 注意事项

1. **ActionBar 背景色**：必须使用 `colorPrimarySurface` 而不是 `colorPrimary`
2. **状态栏图标**：深色背景需要设置 `windowLightStatusBar=false` 以显示白色图标
3. **文字对比度**：确保白色文字在深色背景上有足够的对比度
4. **Material 组件**：某些 Material 组件可能需要单独设置颜色
5. **兼容性**：`DayNight` 主题会根据系统设置自动切换，但我们已强制使用深色
