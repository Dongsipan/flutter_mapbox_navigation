# iOS 样式选择器主题色优化文档

## 概述

将 iOS 样式选择器页面的颜色系统从 iOS 系统默认颜色更新为应用的自定义主题色，保持与应用其他页面的视觉一致性。

## 主题色系统

### 应用主题色定义（来自 Day.swift）

```swift
// 主题色
static var appBackground: UIColor {
    return UIColor(hex: "#040608")  // 深色背景
}

static var appPrimary: UIColor {
    return UIColor(hex: "#01E47C")  // 亮绿色（主色调）
}

static var appSecondary: UIColor {
    return UIColor(hex: "#00B85F")  // 稍暗的绿色（次要色）
}

static var appTextPrimary: UIColor {
    return UIColor(hex: "#01E47C")  // 主文字色（亮绿色）
}

static var appTextSecondary: UIColor {
    return UIColor(hex: "#00B85F")  // 次要文字色（稍暗绿色）
}

static var appCardBackground: UIColor {
    return UIColor(hex: "#0A0C0E")  // 卡片背景色（稍亮于主背景）
}
```

## 颜色映射对比

### 之前（iOS 系统颜色）

| 元素 | 之前颜色 | 说明 |
|------|---------|------|
| 页面背景 | `.systemGroupedBackground` | 系统分组背景色 |
| 卡片背景 | `.secondarySystemGroupedBackground` | 系统次要分组背景色 |
| 主要文字 | `.label` | 系统标签色 |
| 次要文字 | `.secondaryLabel` | 系统次要标签色 |
| 主色调 | `.systemBlue` | 系统蓝色 |
| 分隔线 | `.separator` | 系统分隔线色 |

### 之后（应用主题色）

| 元素 | 之后颜色 | 说明 |
|------|---------|------|
| 页面背景 | `.appBackground` (#040608) | 深色背景 |
| 卡片背景 | `.appCardBackground` (#0A0C0E) | 稍亮于主背景 |
| 主要文字 | `.appTextPrimary` (#01E47C) | 亮绿色 |
| 次要文字 | `.appTextSecondary` (#00B85F) | 稍暗绿色 |
| 主色调 | `.appPrimary` (#01E47C) | 亮绿色 |
| 分隔线 | `.appPrimary.withAlphaComponent(0.2)` | 半透明亮绿色 |

## 详细变更

### 1. 导航栏

```swift
// 之前
title = "地图样式设置"
navigationItem.leftBarButtonItem = cancelBarButton

// 之后
title = "地图样式设置"
navigationBar.tintColor = .appPrimary
navigationBar.titleTextAttributes = [.foregroundColor: UIColor.appTextPrimary]

let appearance = UINavigationBarAppearance()
appearance.backgroundColor = .appBackground
appearance.titleTextAttributes = [.foregroundColor: UIColor.appTextPrimary]
navigationBar.standardAppearance = appearance
navigationBar.scrollEdgeAppearance = appearance

cancelBarButton.tintColor = .appPrimary
```

### 2. 页面背景和容器

```swift
// 之前
view.backgroundColor = .systemGroupedBackground
mapContainerView.backgroundColor = .secondarySystemGroupedBackground
bottomButtonContainer.backgroundColor = .systemGroupedBackground

// 之后
view.backgroundColor = .appBackground
mapContainerView.backgroundColor = .appCardBackground
bottomButtonContainer.backgroundColor = .appBackground
```

### 3. 说明卡片

```swift
// 之前
card.backgroundColor = .secondarySystemGroupedBackground
iconView.tintColor = .systemBlue
titleLabel.textColor = .label
descLabel.textColor = .secondaryLabel

// 之后
card.backgroundColor = .appCardBackground
iconView.tintColor = .appPrimary
titleLabel.textColor = .appTextPrimary
descLabel.textColor = .appTextSecondary
```

### 4. 样式选择器卡片

```swift
// 之前
card.backgroundColor = .secondarySystemGroupedBackground
titleLabel.textColor = .secondaryLabel

// 之后
card.backgroundColor = .appCardBackground
titleLabel.textColor = .appTextSecondary
```

### 5. Light Preset 区域

```swift
// 之前
lightPresetCard.backgroundColor = .secondarySystemGroupedBackground
titleLabel.textColor = .secondaryLabel
subtitleLabel.textColor = .secondaryLabel
autoCard.backgroundColor = .secondarySystemGroupedBackground
autoTitleLabel.textColor = .label
autoDescLabel.textColor = .secondaryLabel

// 之后
lightPresetCard.backgroundColor = .appCardBackground
titleLabel.textColor = .appTextSecondary
subtitleLabel.textColor = .appTextSecondary
autoCard.backgroundColor = .appCardBackground
autoTitleLabel.textColor = .appTextPrimary
autoDescLabel.textColor = .appTextSecondary
automaticModeSwitch.onTintColor = .appPrimary
```

### 6. UIPickerView 文字颜色

```swift
// 新增方法
func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
    let title: String
    if pickerView == stylePickerView {
        title = styles[row].title
    } else {
        title = lightPresets[row].title
    }
    
    return NSAttributedString(
        string: title,
        attributes: [
            .foregroundColor: UIColor.appTextPrimary,
            .font: UIFont.systemFont(ofSize: 17)
        ]
    )
}
```

### 7. 应用按钮

```swift
// 之前
applyButton.backgroundColor = .systemBlue
applyButton.setTitleColor(.white, for: .normal)

// 之后
applyButton.backgroundColor = .appPrimary
applyButton.setTitleColor(.appBackground, for: .normal)  // 深色背景作为文字色，对比度高
```

### 8. 分隔线

```swift
// 之前
separatorLine.backgroundColor = .separator
separatorLine.heightAnchor.constraint(equalToConstant: 0.5)

// 之后
separatorLine.backgroundColor = UIColor.appPrimary.withAlphaComponent(0.2)
separatorLine.heightAnchor.constraint(equalToConstant: 1)
```

## 视觉效果对比

### 之前（系统颜色）
- 浅色背景（白色/浅灰）
- 蓝色主色调
- 标准 iOS 外观
- 与应用其他页面不一致

### 之后（主题色）
- 深色背景 (#040608)
- 亮绿色主色调 (#01E47C)
- 统一的视觉风格
- 与应用其他页面完全一致

## 主题色使用原则

### 1. 背景层次
- **主背景**：`appBackground` (#040608) - 最深
- **卡片背景**：`appCardBackground` (#0A0C0E) - 稍亮
- **分隔线**：`appPrimary.withAlphaComponent(0.2)` - 半透明

### 2. 文字层次
- **主要文字**：`appTextPrimary` (#01E47C) - 最亮，用于标题和重要信息
- **次要文字**：`appTextSecondary` (#00B85F) - 稍暗，用于说明和辅助信息

### 3. 交互元素
- **按钮背景**：`appPrimary` (#01E47C)
- **按钮文字**：`appBackground` (#040608) - 深色，对比度高
- **图标**：`appPrimary` (#01E47C)
- **开关**：`appPrimary` (#01E47C)

### 4. 对比度考虑
- 亮绿色 (#01E47C) 在深色背景 (#040608) 上有极高的对比度
- 符合 WCAG AAA 级别的可访问性标准
- 确保所有文字清晰可读

## 与其他页面的一致性

### SearchViewController
- ✅ 使用相同的背景色 (#040608)
- ✅ 使用相同的主色调 (#01E47C)
- ✅ 使用相同的卡片背景色 (#0A0C0E)

### RouteSelectionViewController
- ✅ 使用相同的背景色 (#040608)
- ✅ 使用相同的主色调 (#01E47C)
- ✅ 使用相同的文字颜色

### NavigationViewController (Day.swift)
- ✅ 使用相同的主题色系统
- ✅ 统一的视觉语言

## 测试要点

### 视觉测试
- [ ] 所有文字清晰可读
- [ ] 颜色对比度符合标准
- [ ] 卡片层次分明
- [ ] 按钮状态明显

### 交互测试
- [ ] UIPickerView 文字颜色正确
- [ ] 开关颜色正确
- [ ] 按钮点击反馈正常
- [ ] 导航栏颜色正确

### 一致性测试
- [ ] 与 SearchViewController 视觉一致
- [ ] 与 RouteSelectionViewController 视觉一致
- [ ] 与导航页面视觉一致

## 优势总结

1. **视觉一致性**：与应用其他页面完全统一
2. **品牌识别**：强化亮绿色主题色的品牌形象
3. **可读性**：高对比度确保文字清晰
4. **专业感**：深色主题更现代、更专业
5. **用户体验**：统一的视觉语言减少认知负担

## 相关文件

- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/StylePickerViewController.swift`
- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/styles/Day.swift`
- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/SearchViewController.swift`
- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/RouteSelectionViewController.swift`

## 更新日期

2026-01-31
