# iOS 样式选择器最终重新设计文档

## 概述

将 iOS 样式选择器从 UIPickerView 方案重新设计为 UITableView 方案，采用类似 iOS 设置应用的标准列表样式，并将所有 emoji 表情替换为 SF Symbols 图标，提供更专业、更符合 iOS 设计规范的用户体验。

## 设计理念

### 参照主流应用
- **iOS 设置**：使用分组列表（Grouped Table View）
- **地图应用**：简洁的选项列表
- **Apple Music**：清晰的层次结构

### 核心原则
1. **简洁性**：减少视觉噪音，突出重要信息
2. **一致性**：与 iOS 系统设计语言保持一致
3. **可访问性**：使用 SF Symbols 而非 emoji
4. **专业性**：符合企业级应用标准

## 主要变更

### 1. 从 UIPickerView 到 UITableView

#### 之前（UIPickerView）
```swift
private let stylePickerView = UIPickerView()
private let lightPresetPickerView = UIPickerView()

// 需要实现 UIPickerViewDelegate 和 UIPickerViewDataSource
func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int
func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String?
```

**问题：**
- 滚动选择不够直观
- 无法显示图标和详细信息
- 占用空间大
- 不符合 iOS 设置风格

#### 之后（UITableView）
```swift
private let tableView = UITableView(frame: .zero, style: .insetGrouped)

// 使用自定义 Cell
tableView.register(StyleCell.self, forCellReuseIdentifier: "StyleCell")
tableView.register(LightPresetCell.self, forCellReuseIdentifier: "LightPresetCell")
tableView.register(SwitchCell.self, forCellReuseIdentifier: "SwitchCell")
```

**优势：**
- 更直观的点击选择
- 可以显示图标、标题、描述
- 更符合 iOS 设计规范
- 节省空间

### 2. Emoji 替换为 SF Symbols

#### 之前（Emoji）
```swift
("dawn", "🌅 Dawn", "黎明 5:00-7:00"),
("day", "☀️ Day", "白天 7:00-17:00"),
("dusk", "🌇 Dusk", "黄昏 17:00-19:00"),
("night", "🌙 Night", "夜晚 19:00-5:00")
```

**问题：**
- Emoji 在不同系统版本显示不一致
- 无法自定义颜色
- 不够专业
- 可访问性差

#### 之后（SF Symbols）
```swift
("dawn", "黎明", "5:00-7:00", "sunrise"),
("day", "白天", "7:00-17:00", "sun.max"),
("dusk", "黄昏", "17:00-19:00", "sunset"),
("night", "夜晚", "19:00-5:00", "moon.stars")
```

**优势：**
- 系统原生图标，显示一致
- 可以自定义颜色（主题色）
- 更专业
- 支持动态类型和可访问性

### 3. 图标映射表

| 功能 | SF Symbol | 说明 |
|------|-----------|------|
| 标准样式 | `map` | 地图图标 |
| 卫星样式 | `globe.americas` | 地球图标 |
| 褪色样式 | `circle.lefthalf.filled` | 半圆图标 |
| 单色样式 | `circle.grid.cross` | 网格图标 |
| 浅色样式 | `sun.max` | 太阳图标 |
| 深色样式 | `moon` | 月亮图标 |
| 户外样式 | `mountain.2` | 山峰图标 |
| 黎明 | `sunrise` | 日出图标 |
| 白天 | `sun.max` | 太阳图标 |
| 黄昏 | `sunset` | 日落图标 |
| 夜晚 | `moon.stars` | 月亮星星图标 |
| 选中标记 | `checkmark` | 对勾图标 |

### 4. 自定义 Cell 设计

#### StyleCell（样式选择单元格）
```swift
class StyleCell: UITableViewCell {
    private let iconView = UIImageView()        // SF Symbol 图标
    private let titleLabel = UILabel()          // 样式名称
    private let descLabel = UILabel()           // 样式描述
    private let badgeLabel = UILabel()          // ✨ 支持标记
    private let checkmarkView = UIImageView()   // 选中标记
}
```

**布局：**
```
┌────────────────────────────────────────┐
│ [图标] 标准                    ✨  ✓  │
│        默认地图样式                    │
└────────────────────────────────────────┘
```

#### LightPresetCell（光照效果单元格）
```swift
class LightPresetCell: UITableViewCell {
    private let iconView = UIImageView()        // SF Symbol 图标
    private let titleLabel = UILabel()          // 时段名称
    private let timeLabel = UILabel()           // 时间范围
    private let checkmarkView = UIImageView()   // 选中标记
}
```

**布局：**
```
┌────────────────────────────────────────┐
│ [图标] 黎明                        ✓  │
│        5:00-7:00                       │
└────────────────────────────────────────┘
```

#### SwitchCell（开关单元格）
```swift
class SwitchCell: UITableViewCell {
    private let titleLabel = UILabel()          // 标题
    private let descLabel = UILabel()           // 描述
    private let switchControl = UISwitch()      // 开关
}
```

**布局：**
```
┌────────────────────────────────────────┐
│ 自动调整                        [开关] │
│ 根据日出日落时间                       │
└────────────────────────────────────────┘
```

### 5. 页面结构

```
┌─────────────────────────────────────────┐
│ ← 取消          地图样式                │ 导航栏
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  │        地图预览区域 (22%)         │  │ 地图容器
│  │                                   │  │
│  └───────────────────────────────────┘  │
│                                         │
├─────────────────────────────────────────┤
│ 地图样式                                │ Section Header
│ ┌───────────────────────────────────┐  │
│ │ [图标] 标准              ✨  ✓   │  │
│ │        默认地图样式               │  │
│ ├───────────────────────────────────┤  │
│ │ [图标] 卫星              ✨      │  │
│ │        卫星图像视图               │  │
│ ├───────────────────────────────────┤  │
│ │ ...                               │  │
│ └───────────────────────────────────┘  │
│ 标有 ✨ 的样式支持光照效果调整          │ Section Footer
│                                         │
│ 光照效果                                │ Section Header
│ ┌───────────────────────────────────┐  │
│ │ 自动调整                   [开关] │  │
│ │ 根据日出日落时间                  │  │
│ ├───────────────────────────────────┤  │
│ │ [图标] 黎明                   ✓  │  │
│ │        5:00-7:00                  │  │
│ ├───────────────────────────────────┤  │
│ │ ...                               │  │
│ └───────────────────────────────────┘  │
│                                         │
├─────────────────────────────────────────┤
│ ┌───────────────────────────────────┐  │
│ │           应用                    │  │ 底部按钮
│ └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### 6. 交互逻辑

#### 样式选择
```swift
func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.section == 0 {
        // 选择样式
        selectedStyle = styles[indexPath.row].value
        tableView.reloadData()  // 刷新显示选中状态
        updateMapStyle()        // 更新地图预览
    }
}
```

#### 光照效果选择
```swift
func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.section == 1 && indexPath.row > 0 {
        // 选择光照效果
        selectedLightPreset = lightPresets[indexPath.row - 1].value
        tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
        applyLightPresetToMap()
    }
}
```

#### 自动模式切换
```swift
@objc private func automaticModeSwitchChanged(_ sender: UISwitch) {
    lightPresetMode = sender.isOn ? "automatic" : "manual"
    tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
    applyLightPresetToMap()
}
```

### 7. 动态 Section 显示

```swift
func numberOfSections(in tableView: UITableView) -> Int {
    // 只有支持 Light Preset 的样式才显示第二个 Section
    return stylesWithLightPreset.contains(selectedStyle) ? 2 : 1
}

func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
        return styles.count
    } else {
        // 自动模式只显示开关，手动模式显示开关+选项
        return lightPresetMode == "automatic" ? 1 : lightPresets.count + 1
    }
}
```

## 颜色系统

### Cell 颜色状态

| 状态 | 图标颜色 | 标题颜色 | 描述颜色 |
|------|---------|---------|---------|
| 未选中 | `.appTextSecondary.withAlphaComponent(0.6)` | `.appTextPrimary` | `.appTextSecondary.withAlphaComponent(0.7)` |
| 选中 | `.appPrimary` | `.appPrimary` | `.appTextSecondary.withAlphaComponent(0.7)` |

### 主题色应用

```swift
// Cell 背景
backgroundColor = .appCardBackground

// 图标颜色
iconView.tintColor = isSelected ? .appPrimary : .appTextSecondary.withAlphaComponent(0.6)

// 标题颜色
titleLabel.textColor = isSelected ? .appPrimary : .appTextPrimary

// 描述颜色
descLabel.textColor = .appTextSecondary.withAlphaComponent(0.7)

// 选中标记
checkmarkView.tintColor = .appPrimary

// 开关颜色
switchControl.onTintColor = .appPrimary
```

## 代码简化对比

### 代码行数
- **之前**：~450 行（UIPickerView 方案）
- **之后**：~550 行（UITableView 方案 + 3个自定义 Cell）
- **增加**：~100 行（但功能更强大，UI 更专业）

### 复杂度
- **之前**：需要管理两个 UIPickerView，手动刷新按钮
- **之后**：使用标准 TableView 模式，系统自动管理

## 优势总结

### 1. 用户体验
- ✅ 更直观的点击选择（vs 滚动选择）
- ✅ 清晰的视觉层次
- ✅ 符合 iOS 用户习惯
- ✅ 更快的操作速度

### 2. 视觉设计
- ✅ 专业的 SF Symbols 图标
- ✅ 统一的主题色系统
- ✅ 清晰的选中状态
- ✅ 优雅的动画效果

### 3. 可维护性
- ✅ 标准的 TableView 模式
- ✅ 可复用的自定义 Cell
- ✅ 清晰的代码结构
- ✅ 易于扩展

### 4. 可访问性
- ✅ SF Symbols 支持动态类型
- ✅ 支持 VoiceOver
- ✅ 高对比度模式兼容
- ✅ 更好的触摸目标

### 5. 性能
- ✅ TableView 复用机制
- ✅ 按需加载 Cell
- ✅ 流畅的滚动
- ✅ 低内存占用

## 测试要点

### 功能测试
- [ ] 样式选择正常工作
- [ ] 光照效果选择正常工作
- [ ] 自动模式开关正常工作
- [ ] 地图预览实时更新
- [ ] Section 动态显示/隐藏
- [ ] 选中状态正确显示

### UI 测试
- [ ] 所有图标正确显示
- [ ] 颜色主题正确应用
- [ ] Cell 高度合适
- [ ] 分隔线正确显示
- [ ] 动画流畅

### 交互测试
- [ ] 点击 Cell 选中
- [ ] 开关切换正常
- [ ] 滚动流畅
- [ ] 选中反馈明显

### 兼容性测试
- [ ] 不同屏幕尺寸
- [ ] 深色模式
- [ ] 动态类型
- [ ] VoiceOver

## 与 Android 端对比

### 相同点
- ✅ 使用列表样式（Android: RecyclerView, iOS: TableView）
- ✅ 相同的功能逻辑
- ✅ 相同的主题色系统

### 不同点
- iOS 保留了地图预览（Android 没有）
- iOS 使用 SF Symbols（Android 使用 Material Icons）
- iOS 使用 Grouped Table View（Android 使用 CardView）

## 相关文件

- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/StylePickerViewController.swift`
- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/styles/Day.swift`
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/StylePickerActivity.kt`

## 更新日期

2026-01-31

## 后续优化建议

1. **添加样式预览缩略图**：在 Cell 中显示样式预览
2. **支持自定义样式**：允许用户添加自定义地图样式
3. **添加搜索功能**：当样式很多时支持搜索
4. **支持拖拽排序**：允许用户自定义样式顺序
5. **添加收藏功能**：标记常用样式
