# iOS 样式选择器现代化重新设计

## 概述

基于 Android 端的实现和现代 iOS 应用设计模式，完全重新设计了 iOS 样式选择器界面，采用卡片式布局和 UIPickerView 组件，提供更现代、更直观的用户体验。

## 设计目标

1. **参照 Android 实现** - 保持跨平台一致性
2. **现代卡片式布局** - 使用圆角卡片分组内容
3. **简洁直观** - 使用 UIPickerView 替代复杂的列表
4. **保留 iOS 特色** - 保留实时地图预览功能
5. **视觉平衡** - 合理使用主题色，避免过度使用绿色

## 设计参考

### Android 端设计特点
- 使用 Material Card 组件
- Spinner 下拉选择器
- 清晰的卡片分组
- 说明卡片提供上下文信息
- 底部固定按钮栏

### iOS 现代设计模式
- ScrollView + 卡片布局
- UIPickerView 滚轮选择器
- 圆角卡片（12px）
- 深色主题背景
- 清晰的视觉层次

## 界面结构

```
NavigationBar (深色背景 + 白色标题 + 绿色按钮)
├── ScrollView
│   ├── 地图预览卡片 (200px 高度)
│   │   └── MapView (实时预览)
│   ├── 说明卡片
│   │   ├── 图标 (paintpalette)
│   │   ├── 标题: "自定义地图外观"
│   │   └── 描述: "调整地图样式和光照效果..."
│   ├── 样式选择卡片
│   │   ├── 标题: "地图样式"
│   │   └── UIPickerView (120px 高度)
│   ├── Light Preset 卡片 (动态显示)
│   │   ├── 标题: "Light Preset（光照效果）"
│   │   ├── 描述: "选择不同时段的光照效果"
│   │   └── UIPickerView (120px 高度)
│   └── 自动调整卡片 (动态显示)
│       ├── 标题: "根据日出日落自动调整"
│       ├── 描述: "自动根据时间切换光照效果"
│       └── UISwitch
└── 底部按钮栏 (固定)
    ├── 取消按钮 (灰色边框)
    └── 应用按钮 (绿色填充)
```

## 主要组件

### 1. 地图预览卡片
```swift
- 高度: 200px
- 圆角: 12px
- 背景: .appCardBackground (#0A0C0E)
- 功能: 实时预览选中的地图样式和光照效果
```

### 2. 说明卡片
```swift
- 图标: SF Symbol "paintpalette" (绿色)
- 标题: 白色，15px，semibold
- 描述: 浅灰色，13px，多行
- 作用: 提供功能说明和上下文信息
```

### 3. 样式选择卡片
```swift
- UIPickerView 显示格式: "标题 - 描述"
- 样式列表:
  - 标准 - 默认地图样式
  - 卫星 - 卫星图像视图
  - 褪色 - 柔和色调
  - 单色 - 黑白风格
  - 浅色 - 明亮背景
  - 深色 - 暗色背景
  - 户外 - 地形显示
```

### 4. Light Preset 卡片
```swift
- 动态显示: 仅当选中支持 Light Preset 的样式时显示
- UIPickerView 显示格式: "标题 (时间范围)"
- 光照列表:
  - 黎明 (5:00-7:00)
  - 白天 (7:00-17:00)
  - 黄昏 (17:00-19:00)
  - 夜晚 (19:00-5:00)
```

### 5. 自动调整卡片
```swift
- 动态显示: 仅当选中支持 Light Preset 的样式时显示
- UISwitch: 绿色主题色
- 功能: 开启后禁用手动选择，自动根据时间调整
```

### 6. 底部按钮栏
```swift
- 固定在底部，高度 90px
- 取消按钮: 灰色边框，透明背景
- 应用按钮: 绿色填充，深色文字
- 布局: 水平排列，等宽，8px 间距
```

## 配色方案

### 主题色
```swift
- 背景色: #040608 (深色背景)
- 卡片背景: #0A0C0E (稍亮于主背景)
- 主色调: #01E47C (亮绿色) - 用于强调元素
- 次要色: #00B85F (稍暗的绿色)
```

### 文字颜色
```swift
- 主标题: 白色 (#FFFFFF)
- 次标题: 浅灰色 (white: 0.7)
- 描述文字: 中灰色 (white: 0.6)
- Picker 文字: 白色，16px
```

### 绿色使用原则
只在以下元素使用绿色，避免过度使用：
- 导航栏按钮
- 说明卡片图标
- UISwitch 开关
- 应用按钮背景
- 分隔线（20% 透明度）

## 交互行为

### 样式选择
1. 用户滚动 UIPickerView 选择样式
2. 立即更新地图预览
3. 如果样式支持 Light Preset，显示相关卡片
4. 如果不支持，隐藏 Light Preset 和自动调整卡片

### Light Preset 选择
1. 用户滚动 UIPickerView 选择光照效果
2. 立即更新地图预览
3. 如果开启自动模式，Picker 变灰且不可交互

### 自动调整开关
1. 开启: lightPresetMode = "automatic"
   - Light Preset Picker 变灰（alpha: 0.5）
   - 禁用用户交互
2. 关闭: lightPresetMode = "manual"
   - Light Preset Picker 恢复正常
   - 允许用户手动选择

### 按钮操作
- **取消**: 返回 nil，关闭页面
- **应用**: 返回选中的配置，关闭页面

## 代码结构

### 主要属性
```swift
- selectedStyle: String
- selectedLightPreset: String
- lightPresetMode: String ("manual" | "automatic")
- stylesWithLightPreset: Set<String>
```

### UI 组件
```swift
- scrollView: UIScrollView
- mapPreviewCard: UIView
- infoCard: UIView
- styleCard: UIView
- lightPresetCard: UIView
- autoAdjustCard: UIView
- stylePickerView: UIPickerView
- lightPresetPickerView: UIPickerView
- autoAdjustSwitch: UISwitch
```

### 关键方法
```swift
- setupMapPreviewCard()
- setupInfoCard()
- setupStyleCard()
- setupLightPresetCard()
- setupAutoAdjustCard()
- setupBottomButtons()
- updateLightPresetVisibility()
- updateMapStyle()
- applyLightPresetToMap()
```

## 与 Android 端对比

| 特性 | Android | iOS |
|------|---------|-----|
| 布局方式 | NestedScrollView + LinearLayout | ScrollView + UIView |
| 选择器 | Spinner | UIPickerView |
| 卡片组件 | MaterialCardView | UIView + cornerRadius |
| 地图预览 | ❌ 无 | ✅ 有 (iOS 特色) |
| 说明卡片 | ✅ 有 | ✅ 有 |
| 按钮布局 | 水平排列，等宽 | 水平排列，等宽 |
| 主题色 | #01E47C | #01E47C |
| 动态显示 | ✅ 支持 | ✅ 支持 |

## 优势

### 1. 现代化设计
- 卡片式布局符合现代 iOS 应用设计趋势
- 圆角和间距营造清晰的视觉层次
- 深色主题提供舒适的视觉体验

### 2. 简洁直观
- UIPickerView 比列表更直观
- 减少点击次数，提高效率
- 实时预览提供即时反馈

### 3. 跨平台一致性
- 功能与 Android 端完全一致
- 布局结构相似
- 交互逻辑统一

### 4. iOS 特色
- 保留地图实时预览功能
- 使用 iOS 原生 UIPickerView
- 符合 iOS 设计规范

### 5. 视觉平衡
- 合理使用主题色
- 避免过度使用绿色
- 文字颜色层次分明

## 代码行数对比

| 版本 | 代码行数 | 说明 |
|------|---------|------|
| TableView 版本 | ~550 行 | 包含 3 个自定义 Cell 类 |
| 现代卡片版本 | ~450 行 | 使用 UIPickerView，无需自定义 Cell |
| 减少 | ~100 行 | 代码更简洁，维护更容易 |

## 实现日期

2026-01-31

## 相关文档

- [Android 主题更新](./ANDROID_THEME_UPDATE.md)
- [iOS 主题更新](./IOS_THEME_UPDATE.md)
- [样式选择器主题修复](./STYLE_PICKER_THEME_FIX.md)
- [iOS 样式选择器重构](./IOS_STYLE_PICKER_REFACTOR.md)
- [iOS 样式选择器主题更新](./IOS_STYLE_PICKER_THEME_UPDATE.md)
- [iOS 样式选择器最终重新设计](./IOS_STYLE_PICKER_FINAL_REDESIGN.md)
