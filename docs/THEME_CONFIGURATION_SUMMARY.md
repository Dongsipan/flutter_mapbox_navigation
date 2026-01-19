# 主题配置总结

## 概述
已完成 Android 和 iOS 端的主题配置更新，与 Flutter Material 3 深色主题保持完全一致。

## 核心配置原则

### 🎨 颜色定义

| 颜色名称 | 十六进制 | 用途 |
|---------|---------|------|
| **主题色** | `#01E47C` | 按钮、图标、链接等交互元素 |
| **主题色深色** | `#00B35F` | 主题色的深色变体 |
| **背景色** | `#040608` | 页面背景、导航栏背景、状态栏 |
| **卡片背景** | `#1A1C1E` | 卡片、对话框等表面元素 |
| **主文字** | `#FFFFFF` | 标题、正文等主要文字 |
| **次要文字** | `#FFFFFF` (54% 透明度) | 辅助说明、次要信息 |
| **禁用文字** | `#FFFFFF` (38% 透明度) | 禁用状态的文字 |

### ✅ 正确的颜色使用

| UI 元素 | 背景色 | 文字/图标颜色 |
|---------|--------|--------------|
| **导航栏/ActionBar** | `#040608` (深色) | 标题：白色，按钮/图标：`#01E47C` (绿色) |
| **状态栏** | `#040608` (深色) | 图标：白色 |
| **底部导航栏** | `#040608` (深色) | 图标：白色 |
| **页面背景** | `#040608` (深色) | 文字：白色 |
| **主按钮** | `#01E47C` (绿色) | 文字：白色 |
| **次要按钮** | 透明或深色 | 文字：`#01E47C` (绿色) |
| **卡片** | `#1A1C1E` (稍亮) | 文字：白色 |
| **输入框** | `#1A1C1E` (稍亮) | 文字：白色 |

### ❌ 常见错误

| 错误做法 | 正确做法 |
|---------|---------|
| ❌ 导航栏背景使用主题色 `#01E47C` | ✅ 导航栏背景使用深色 `#040608` |
| ❌ 按钮背景使用深色 `#040608` | ✅ 按钮背景使用主题色 `#01E47C` |
| ❌ 状态栏使用主题色 `#01E47C` | ✅ 状态栏使用深色 `#040608` |
| ❌ 导航栏图标使用白色 | ✅ 导航栏图标使用主题色 `#01E47C` |

## 平台实现

### Android 配置

#### colors.xml
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
<color name="textSecondary">#8AFFFFFF</color>
```

#### styles.xml 关键配置
```xml
<style name="KtMaterialTheme" parent="Theme.MaterialComponents.DayNight.DarkActionBar">
    <!-- 主题色用于按钮、图标 -->
    <item name="colorPrimary">@color/colorPrimary</item>
    
    <!-- ActionBar 背景使用深色 -->
    <item name="colorPrimarySurface">@color/colorBackground</item>
    <item name="colorOnPrimary">@color/textPrimary</item>
    
    <!-- 状态栏和导航栏使用深色 -->
    <item name="android:statusBarColor">@color/colorBackground</item>
    <item name="android:navigationBarColor">@color/colorBackground</item>
</style>
```

### iOS 配置

#### ThemeColors.swift
```swift
extension UIColor {
    // 主题色
    static let appPrimary = UIColor(hex: "#01E47C")
    static let appPrimaryDark = UIColor(hex: "#00B35F")
    
    // 背景色
    static let appBackground = UIColor(hex: "#040608")
    static let appCardBackground = UIColor(hex: "#1A1C1E")
    
    // 文字颜色
    static let appTextPrimary = UIColor.white
    static let appTextSecondary = UIColor.white.withAlphaComponent(0.54)
}
```

#### 导航栏配置示例
```swift
// 导航栏外观
let appearance = UINavigationBarAppearance()
appearance.configureWithOpaqueBackground()
appearance.backgroundColor = .appBackground  // 深色背景
appearance.titleTextAttributes = [.foregroundColor: UIColor.appTextPrimary]  // 白色标题

// 按钮颜色
navigationController.navigationBar.tintColor = .appPrimary  // 绿色图标

// 状态栏样式
navigationController.navigationBar.barStyle = .black  // 白色状态栏图标
```

## 与 Flutter 主题对应

### Flutter 配置参考
```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF01E47C),  // 主题色
    brightness: Brightness.dark,          // 深色模式
    primary: const Color(0xFF01E47C),     // 主色
    surface: const Color(0xFF040608),     // 表面颜色
  ),
  scaffoldBackgroundColor: const Color(0xFF040608),  // 背景色
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF040608),   // AppBar 背景 - 深色
    foregroundColor: Colors.white,        // AppBar 文字 - 白色
  ),
)
```

### 对应关系表

| Flutter | Android | iOS |
|---------|---------|-----|
| `primary: Color(0xFF01E47C)` | `colorPrimary` | `.appPrimary` |
| `surface: Color(0xFF040608)` | `colorBackground` | `.appBackground` |
| `appBarTheme.backgroundColor` | `colorPrimarySurface` | `appearance.backgroundColor` |
| `appBarTheme.foregroundColor` | `colorOnPrimary` | `appearance.titleTextAttributes` |
| `iconTheme.color` | `colorPrimary` | `navigationBar.tintColor` |

## 视觉效果检查清单

### ✅ 必须满足的要求

- [ ] 导航栏/ActionBar 背景为深色 `#040608`
- [ ] 导航栏标题为白色
- [ ] 导航栏按钮/图标为绿色 `#01E47C`
- [ ] 状态栏背景为深色 `#040608`
- [ ] 状态栏图标为白色
- [ ] 页面背景为深色 `#040608`
- [ ] 主按钮背景为绿色 `#01E47C`
- [ ] 主按钮文字为白色
- [ ] 所有文字在深色背景上清晰可读
- [ ] 卡片背景比页面背景稍亮 `#1A1C1E`

### 🎯 测试场景

1. **导航栏测试**
   - 背景色是否为深色
   - 标题是否为白色
   - 返回按钮/图标是否为绿色
   - 其他操作按钮是否为绿色

2. **按钮测试**
   - 主按钮背景是否为绿色
   - 主按钮文字是否为白色
   - 次要按钮文字是否为绿色
   - 禁用按钮是否有正确的视觉反馈

3. **文字测试**
   - 标题文字是否清晰可读
   - 正文文字是否清晰可读
   - 次要文字是否有适当的透明度
   - 禁用文字是否有正确的视觉状态

4. **背景测试**
   - 页面背景是否为深色
   - 卡片背景是否比页面背景稍亮
   - 对话框背景是否合适
   - 输入框背景是否清晰

## 相关文档

- [Android 主题配置详细说明](./ANDROID_THEME_UPDATE.md)
- [iOS 主题配置详细说明](./IOS_THEME_UPDATE.md)

## 更新日期

2024-01-19

## 维护说明

当需要更新主题色时，请同时更新以下文件：

### Android
- `android/src/main/res/values/colors.xml`
- `android/src/main/res/values/styles.xml`

### iOS
- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/ThemeColors.swift`

### 文档
- `docs/ANDROID_THEME_UPDATE.md`
- `docs/IOS_THEME_UPDATE.md`
- `docs/THEME_CONFIGURATION_SUMMARY.md`
