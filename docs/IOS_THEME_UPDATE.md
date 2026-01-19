# iOS 主题配置更新

## 概述
已将 iOS 端的主题配置更新为与 Flutter 主题保持一致的深色主题。

## 主题色配置

### 颜色定义
创建了新文件 `ThemeColors.swift`，定义了以下主题色：

```swift
// 主题色
static let appPrimary = UIColor(hex: "#01E47C")        // 主色 - 绿色
static let appPrimaryDark = UIColor(hex: "#00B35F")    // 主色深色版本
static let appAccent = UIColor(hex: "#01E47C")         // 强调色

// 背景色
static let appBackground = UIColor(hex: "#040608")     // 主背景色 - 深色
static let appSurface = UIColor(hex: "#040608")        // 表面颜色
static let appCardBackground = UIColor(hex: "#1A1C1E") // 卡片背景色

// 文字颜色
static let appTextPrimary = UIColor.white              // 主文字 - 白色
static let appTextSecondary = UIColor.white.withAlphaComponent(0.54)  // 次要文字
static let appTextDisabled = UIColor.white.withAlphaComponent(0.38)   // 禁用文字
```

### 与 Flutter 主题对应关系

| Flutter | iOS |
|---------|-----|
| `Color(0xFF01E47C)` (primary) | `.appPrimary` |
| `Color(0xFF040608)` (surface/background) | `.appBackground` |
| `Colors.white` (text) | `.appTextPrimary` |
| `Colors.white54` (secondary text) | `.appTextSecondary` |
| `Brightness.dark` | 深色主题配置 |

## 更新的文件

### 1. ThemeColors.swift (新建)
- 定义了所有主题颜色常量
- 提供了十六进制颜色转换方法
- 提供了颜色转十六进制字符串方法

### 2. RouteSelectionViewController.swift
更新内容：
- 顶部栏背景：`.white` → `.appBackground`
- 返回按钮颜色：`.systemBlue` → `.appPrimary`
- 标题文字颜色：添加 `.appTextPrimary`
- 全览按钮背景：`.white` → `.appCardBackground`
- 全览按钮图标：`.systemBlue` → `.appPrimary`
- 底部容器背景：`.white` → `.appBackground`
- 取消按钮文字：`.systemGray` → `.appTextSecondary`
- 开始导航按钮：`.systemBlue` → `.appPrimary`

### 3. StylePickerViewController.swift
更新内容：
- 主背景：`.systemGroupedBackground` → `.appBackground`
- 地图容器背景：`.systemGray6` → `.appCardBackground`
- 样式卡片背景：`.secondarySystemGroupedBackground` → `.appCardBackground`
- 选中边框：`.systemBlue` → `.appPrimary`
- 标题文字：`.label` → `.appTextPrimary`
- 描述文字：`.secondaryLabel` → `.appTextSecondary`
- 选中图标：`.systemBlue` → `.appPrimary`
- 应用按钮：`.systemBlue` → `.appPrimary`
- 底部容器：`.systemBackground` → `.appBackground`

### 4. HistoryReplayViewController.swift
更新内容：
- 导航栏背景：`.systemBackground` → `.appBackground`
- 导航栏标题：`.label` → `.appTextPrimary`
- 导航栏按钮：`.systemBlue` → `.appPrimary`
- 导航栏样式：`.default` → `.black` (适配深色主题)

### 5. EmbeddedNavigationView.swift
更新内容：
- 容器背景：`.lightGray` → `.appBackground`

## 颜色使用规范

### ✅ 正确的使用方式

| 元素 | 应使用的颜色 | 说明 |
|------|-------------|------|
| **导航栏背景** | `.appBackground` (#040608) | 深色背景 |
| **导航栏标题** | `.appTextPrimary` (白色) | 白色文字 |
| **导航栏按钮/图标** | `.appPrimary` (#01E47C) | 绿色主题色 |
| **状态栏** | 深色背景 | 与导航栏一致 |
| **页面背景** | `.appBackground` (#040608) | 深色背景 |
| **卡片背景** | `.appCardBackground` (#1A1C1E) | 稍亮的深色 |
| **按钮背景** | `.appPrimary` (#01E47C) | 绿色主题色 |
| **按钮文字** | `.white` | 白色 |
| **次要按钮文字** | `.appTextSecondary` | 半透明白色 |
| **图标/链接** | `.appPrimary` (#01E47C) | 绿色主题色 |

### ❌ 常见错误

- ❌ 导航栏背景使用 `.appPrimary` (会变成绿色)
- ❌ 按钮背景使用 `.appBackground` (会变成深色，看不清)
- ❌ 状态栏使用 `.appPrimary` (会变成绿色)

## 视觉效果

### 深色主题特性
- ✅ 主背景色为深色 (#040608)
- ✅ 导航栏背景为深色 (#040608)
- ✅ 所有文字为白色或半透明白色
- ✅ 主题色为绿色 (#01E47C)，用于按钮和图标
- ✅ 卡片和按钮使用稍亮的深色背景
- ✅ 阴影效果增强以适配深色背景

### 一致性
- ✅ 与 Flutter Material 3 深色主题完全一致
- ✅ 与 Android 主题配置保持统一
- ✅ 所有 UI 组件使用统一的颜色系统

## 使用方法

在任何 Swift 文件中，直接使用主题色：

```swift
// 设置背景色
view.backgroundColor = .appBackground

// 设置主题色按钮
button.backgroundColor = .appPrimary
button.setTitleColor(.white, for: .normal)

// 设置文字颜色
label.textColor = .appTextPrimary
secondaryLabel.textColor = .appTextSecondary

// 设置卡片背景
cardView.backgroundColor = .appCardBackground
```

## 注意事项

1. **状态栏样式**：深色背景需要使用 `.black` 或 `.darkContent` 状态栏样式
2. **阴影效果**：深色背景下阴影透明度需要增加（0.1 → 0.3）
3. **对比度**：确保文字和背景有足够的对比度
4. **系统颜色**：避免使用 `.systemBlue` 等系统颜色，统一使用主题色

## 测试建议

- [ ] 测试所有页面的视觉效果
- [ ] 检查文字可读性
- [ ] 验证按钮交互状态
- [ ] 确认导航栏和状态栏样式
- [ ] 测试深色模式下的阴影效果
