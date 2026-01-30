# iOS Top Banner 自定义主题实现总结

## 需求

根据 Mapbox 官方示例 [Styled-UI-Elements.swift](https://github.com/mapbox/mapbox-navigation-ios/blob/main/Examples/AdditionalExamples/Examples/Styled-UI-Elements.swift)，自定义 iOS 导航界面的 Top Banner（顶部指示栏）：

- **背景色**：`#040608`（深色背景）
- **主文字颜色**：`#01E47C`（亮绿色）
- **次文字颜色**：比主颜色亮度低一点（`#00B85F`）

## 实现方案

### 1. 创建主题颜色文件

**文件**：`ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/ThemeColors.swift`

这个文件包含：

#### a) NavigationViewController 扩展

```swift
extension NavigationViewController {
    func applyCustomTheme() {
        // 定义自定义颜色
        let backgroundColor = UIColor(hex: "#040608")
        let primaryTextColor = UIColor(hex: "#01E47C")
        let secondaryTextColor = UIColor(hex: "#00B85F")
        
        // 应用到各个 UI 元素
        // - Top Banner (InstructionsBannerView)
        // - Primary/Secondary/Distance Labels
        // - Maneuver View (转向图标)
        // - Bottom Banner
        // - Speed Limit View
        // - Lane View
    }
}
```

#### b) UIColor 十六进制扩展

```swift
extension UIColor {
    convenience init(hex: String) {
        // 支持 "#01E47C" 或 "01E47C" 格式
    }
}
```

### 2. 在导航启动时应用主题

**文件**：`ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/NavigationFactory.swift`

在 `startNavigation()` 方法中，创建 `NavigationViewController` 后立即应用主题：

```swift
self._navigationViewController = NavigationViewController(
    navigationRoutes: navigationRoutes,
    navigationOptions: navigationOptions
)

// 应用自定义主题颜色
self._navigationViewController!.applyCustomTheme()
```

## 自定义的 UI 元素

### 1. Top Banner (顶部指示栏)

| 元素 | 颜色 | 说明 |
|------|------|------|
| 背景 | `#040608` | 深色背景 |
| 主要指示文字 | `#01E47C` | 例如："左转到 Main Street" |
| 次要指示文字 | `#00B85F` | 例如："然后右转" |
| 距离标签 | `#01E47C` | 例如："500 米" |

### 2. Maneuver View (转向图标)

| 元素 | 颜色 |
|------|------|
| 背景 | `#040608` |
| 主要颜色 | `#01E47C` |
| 次要颜色 | `#00B85F` |

### 3. 其他元素

- **Bottom Banner**：背景色 `#040608`
- **Speed Limit View**：背景色 `#040608`，文字 `#01E47C`
- **Lane View**：主要颜色 `#01E47C`，次要颜色 `#00B85F`

## 技术细节

### UIAppearance API

使用 UIKit 的 `UIAppearance` API 来全局自定义 UI 元素：

```swift
let topBannerAppearance = InstructionsBannerView.appearance(
    whenContainedInInstancesOf: [NavigationViewController.self]
)
topBannerAppearance.backgroundColor = backgroundColor
topBannerAppearance.primaryLabel.textColor = primaryTextColor
```

### 优点

1. **全局生效**：一次设置，所有导航界面都会应用
2. **官方推荐**：遵循 Mapbox 官方示例的实现方式
3. **作用域限制**：使用 `whenContainedInInstancesOf` 避免影响其他界面
4. **易于维护**：颜色集中管理，修改方便

### 应用时机

必须在 `NavigationViewController` 创建后、显示前调用 `applyCustomTheme()`。

## 如何修改颜色

### 方法 1：直接修改源码

编辑 `ThemeColors.swift` 文件：

```swift
let backgroundColor = UIColor(hex: "#你的背景色")
let primaryTextColor = UIColor(hex: "#你的主文字颜色")
let secondaryTextColor = UIColor(hex: "#你的次文字颜色")
```

### 方法 2：未来扩展 - 通过 Flutter 传递

可以扩展 API，允许从 Flutter 端传递颜色：

```dart
MapboxNavigation.startNavigation(
  wayPoints: wayPoints,
  customTheme: NavigationTheme(
    backgroundColor: '#040608',
    primaryTextColor: '#01E47C',
    secondaryTextColor: '#00B85F',
  ),
);
```

## 测试方法

1. 运行示例应用
2. 启动任意导航功能
3. 观察 Top Banner：
   - 背景应为深色 (`#040608`)
   - 主要文字应为亮绿色 (`#01E47C`)
   - 次要文字应为稍暗的绿色 (`#00B85F`)

### 调试日志

```
🎨 应用自定义主题颜色
✅ 自定义主题颜色应用完成
```

## 文件清单

### 新增文件

1. `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/ThemeColors.swift`
   - 主题颜色定义和应用逻辑

2. `docs/IOS_TOP_BANNER_CUSTOMIZATION.md`
   - 英文技术文档

3. `docs/IOS_TOP_BANNER_自定义主题实现.md`
   - 中文实现总结（本文档）

### 修改文件

1. `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/NavigationFactory.swift`
   - 在 `startNavigation()` 中添加 `applyCustomTheme()` 调用

## 颜色对比

| 颜色名称 | 十六进制 | RGB | 说明 |
|---------|---------|-----|------|
| 背景色 | `#040608` | `rgb(4, 6, 8)` | 非常深的蓝黑色 |
| 主文字颜色 | `#01E47C` | `rgb(1, 228, 124)` | 明亮的绿色 |
| 次文字颜色 | `#00B85F` | `rgb(0, 184, 95)` | 稍暗的绿色（亮度约为主颜色的 80%） |

## 参考资料

- [Mapbox Navigation iOS - Styled UI Elements](https://github.com/mapbox/mapbox-navigation-ios/blob/main/Examples/AdditionalExamples/Examples/Styled-UI-Elements.swift)
- [UIAppearance Protocol](https://developer.apple.com/documentation/uikit/uiappearance)
- [Mapbox Navigation UIKit](https://docs.mapbox.com/ios/navigation/guides/)

## 完成状态

✅ 已完成 Top Banner 背景色自定义  
✅ 已完成主文字颜色自定义  
✅ 已完成次文字颜色自定义  
✅ 已完成转向图标颜色自定义  
✅ 已完成底部栏颜色自定义  
✅ 已完成速度限制标志颜色自定义  
✅ 已完成车道指示颜色自定义  
✅ 已创建技术文档  

## 下一步建议

1. **测试验证**：在真机上测试各种导航场景
2. **扩展 API**：考虑添加 Flutter 端的颜色配置接口
3. **夜间模式**：考虑添加自动切换的夜间主题
4. **更多元素**：根据需要自定义更多 UI 元素（按钮、卡片等）
