# iOS 样式选择器重构文档

## 概述

将 iOS 端的 `StylePickerViewController` 重构为更简洁的设计，对标 Android 端的实现，使用 `UIPickerView` 替代卡片列表，提升用户体验和代码可维护性。

## 重构目标

1. **简化 UI**：使用 iOS 原生的 `UIPickerView` 替代自定义卡片列表
2. **对标 Android**：保持与 Android 端相同的功能和交互逻辑
3. **保留地图预览**：继续在顶部显示地图预览（Android 端没有）
4. **符合 iOS 规范**：使用系统标准颜色和组件

## 主要变更

### 1. UI 组件变更

#### 之前（卡片列表）
```swift
private let styleStackView = UIStackView()
private let lightPresetStackView = UIStackView()

// 为每个样式创建卡片按钮
func createStyleButton(value: String, title: String, description: String) -> UIView
func createLightPresetButton(value: String, title: String, time: String) -> UIView
```

#### 之后（UIPickerView）
```swift
private let stylePickerView = UIPickerView()
private let lightPresetPickerView = UIPickerView()

// 实现 UIPickerViewDelegate 和 UIPickerViewDataSource
extension StylePickerViewController: UIPickerViewDelegate, UIPickerViewDataSource
```

### 2. 数据结构优化

```swift
// 样式数据
private let styles: [(value: String, title: String, description: String)] = [
    ("standard", "Standard", "默认样式 - 支持 Light Preset"),
    ("standardSatellite", "Standard Satellite", "卫星图像 - 支持 Light Preset"),
    ("faded", "Faded", "褪色主题 - 支持 Light Preset"),
    ("monochrome", "Monochrome", "单色主题 - 支持 Light Preset"),
    ("light", "Light", "浅色背景"),
    ("dark", "Dark", "深色背景"),
    ("outdoors", "Outdoors", "户外地形")
]

// Light Preset 数据
private let lightPresets: [(value: String, title: String, time: String)] = [
    ("dawn", "🌅 Dawn", "黎明 5:00-7:00"),
    ("day", "☀️ Day", "白天 7:00-17:00"),
    ("dusk", "🌇 Dusk", "黄昏 17:00-19:00"),
    ("night", "🌙 Night", "夜晚 19:00-5:00")
]
```

### 3. 颜色系统变更

#### 之前（自定义颜色）
```swift
.appBackground
.appCardBackground
.appTextPrimary
.appTextSecondary
.appPrimary
```

#### 之后（系统颜色）
```swift
.systemGroupedBackground
.secondarySystemGroupedBackground
.label
.secondaryLabel
.systemBlue
```

### 4. UI 布局结构

```
┌─────────────────────────────────────┐
│  Navigation Bar (地图样式设置)      │
├─────────────────────────────────────┤
│                                     │
│  地图预览区域 (25% 高度)            │
│                                     │
├─────────────────────────────────────┤
│  ScrollView                         │
│  ┌───────────────────────────────┐  │
│  │ 说明卡片                      │  │
│  │ 🎨 自定义地图外观             │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ 地图样式                      │  │
│  │ [UIPickerView]                │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ Light Preset（光照效果）      │  │
│  │ [UIPickerView]                │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ 根据日出日落自动调整    [开关]│  │
│  └───────────────────────────────┘  │
├─────────────────────────────────────┤
│  [应用按钮]                         │
└─────────────────────────────────────┘
```

### 5. 功能保持不变

- ✅ 地图样式选择（7 种样式）
- ✅ Light Preset 选择（4 种光照效果）
- ✅ 自动调整开关（根据时间自动切换）
- ✅ 实时地图预览
- ✅ 样式支持检测（只有 4 种样式支持 Light Preset）
- ✅ 自动模式禁用手动选择

### 6. 交互优化

#### 自动模式行为
```swift
@objc private func automaticModeSwitchChanged() {
    lightPresetMode = automaticModeSwitch.isOn ? "automatic" : "manual"
    
    // 更新 Picker 的启用状态
    lightPresetPickerView.isUserInteractionEnabled = !automaticModeSwitch.isOn
    lightPresetPickerView.alpha = automaticModeSwitch.isOn ? 0.5 : 1.0
    
    // 更新地图预览
    applyLightPresetToMap()
}
```

#### Light Preset 区域可见性
```swift
private func updateLightPresetSectionVisibility() {
    let isSupported = stylesWithLightPreset.contains(selectedStyle)
    lightPresetSection.isHidden = !isSupported
}
```

## 代码简化对比

### 代码行数减少
- **之前**：~700 行
- **之后**：~450 行
- **减少**：~35%

### 方法数量减少
- **删除的方法**：
  - `setupStyleButtons()`
  - `createStyleButton()`
  - `styleButtonTapped()`
  - `createLightPresetButton()`
  - `lightPresetTapped()`
  - `refreshLightPresetButtons()`
  - `getCurrentTimeBasedLightPreset()`

- **新增的方法**：
  - `createInfoCard()`
  - `createStylePickerCard()`
  - UIPickerView delegate 方法（4 个标准方法）

## 与 Android 端对比

### 相同点
1. 使用原生选择器组件（Android: Spinner, iOS: UIPickerView）
2. 卡片式布局设计
3. 相同的功能逻辑
4. 相同的自动调整开关

### 不同点
1. **iOS 保留了地图预览**（Android 没有）
2. **iOS 使用系统颜色**（Android 使用自定义主题色）
3. **iOS 使用 NavigationBar**（Android 使用 ActionBar）

## 测试要点

### 功能测试
- [ ] 样式选择器正常工作
- [ ] Light Preset 选择器正常工作
- [ ] 自动调整开关正常工作
- [ ] 地图预览实时更新
- [ ] Light Preset 区域根据样式显示/隐藏
- [ ] 自动模式禁用手动选择

### UI 测试
- [ ] 所有卡片正确显示
- [ ] UIPickerView 可滚动选择
- [ ] 按钮样式正确
- [ ] 深色模式适配
- [ ] 不同屏幕尺寸适配

### 边界测试
- [ ] 不支持 Light Preset 的样式（light, dark, outdoors）
- [ ] 自动模式切换
- [ ] 取消操作
- [ ] 应用操作

## 优势总结

1. **代码更简洁**：减少 35% 代码量
2. **更易维护**：使用标准组件，减少自定义代码
3. **更符合 iOS 规范**：使用系统颜色和标准组件
4. **性能更好**：UIPickerView 比动态创建卡片更高效
5. **用户体验更好**：原生滚动选择器更符合用户习惯

## 后续优化建议

1. **添加样式预览图**：在 Picker 中显示样式缩略图
2. **优化地图加载**：使用占位图减少等待时间
3. **添加动画效果**：区域显示/隐藏时添加过渡动画
4. **支持横屏**：优化横屏布局

## 相关文件

- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/StylePickerViewController.swift`
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/StylePickerActivity.kt`
- `android/src/main/res/layout/activity_style_picker.xml`

## 更新日期

2026-01-31
