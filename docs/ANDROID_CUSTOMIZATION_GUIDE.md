# Android 自定义配置指南

本文档说明如何在使用 flutter_mapbox_navigation 插件时自定义 Android 端的颜色、样式等资源。

## 自定义颜色

### 方法：使用 Android 资源覆盖机制

Android 的资源系统支持自动合并和覆盖。应用可以定义与插件相同名称的资源来覆盖默认值。

### 步骤

1. 在你的 Flutter 项目中，打开或创建文件：
   ```
   android/app/src/main/res/values/colors.xml
   ```

2. 添加你想要覆盖的颜色定义：

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- 覆盖插件的主题颜色 -->
    <color name="colorPrimary">#YOUR_PRIMARY_COLOR</color>
    <color name="colorPrimaryDark">#YOUR_PRIMARY_DARK_COLOR</color>
    <color name="colorAccent">#YOUR_ACCENT_COLOR</color>
    
    <!-- 覆盖插件的其他颜色 -->
    <color name="ic_launcher_background">#YOUR_LAUNCHER_BG_COLOR</color>
    <color name="red">#YOUR_RED_COLOR</color>
    <color name="white">#YOUR_WHITE_COLOR</color>
</resources>
```

### 可覆盖的颜色资源

插件默认提供以下颜色资源（位于 `android/src/main/res/values/colors.xml`）：

| 颜色名称 | 默认值 | 用途 |
|---------|--------|------|
| `colorPrimary` | `#2D4E73` | 主题主色 |
| `colorPrimaryDark` | `#2D4E73` | 状态栏颜色 |
| `colorAccent` | `#2D4E73` | 强调色 |
| `ic_launcher_background` | `#2D4E73` | 启动图标背景色 |
| `red` | `#FF0000` | 红色（用于警告等） |
| `white` | `#FFFFFF` | 白色 |

### 示例

假设你想使用蓝色主题：

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="colorPrimary">#1976D2</color>
    <color name="colorPrimaryDark">#1565C0</color>
    <color name="colorAccent">#2196F3</color>
</resources>
```

### 注意事项

1. **只覆盖需要的颜色**：你不需要定义所有颜色，只定义想要修改的即可
2. **颜色格式**：使用标准的 Android 颜色格式（`#RRGGBB` 或 `#AARRGGBB`）
3. **构建清理**：修改颜色后，建议执行 `flutter clean` 然后重新构建
4. **资源合并优先级**：应用的资源优先级高于插件，所以你的定义会覆盖插件的默认值

## 自定义样式

类似地，你也可以覆盖插件的样式定义。在 `android/app/src/main/res/values/styles.xml` 中定义相同名称的样式即可。

## 验证配置

修改后，可以通过以下方式验证：

1. 运行 `flutter clean`
2. 运行 `flutter run`
3. 检查应用界面是否使用了你定义的颜色

## 故障排除

### 颜色没有生效

1. 确认文件路径正确：`android/app/src/main/res/values/colors.xml`
2. 确认 XML 格式正确
3. 执行 `flutter clean` 清理缓存
4. 重新构建项目

### 构建错误

如果出现资源相关的构建错误，检查：
- XML 文件格式是否正确
- 颜色值格式是否符合 Android 规范
- 是否有重复的资源定义

## 高级配置

如果需要更复杂的自定义（如不同屏幕密度、夜间模式等），可以使用 Android 的资源限定符：

```
android/app/src/main/res/
├── values/colors.xml           # 默认颜色
├── values-night/colors.xml     # 夜间模式颜色
└── values-zh/colors.xml        # 中文环境颜色（如果需要）
```

## 相关文档

- [Android 资源概览](https://developer.android.com/guide/topics/resources/providing-resources)
- [Android 颜色资源](https://developer.android.com/guide/topics/resources/more-resources#Color)
