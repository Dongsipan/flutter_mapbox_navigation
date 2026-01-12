# Light Preset 模式重构总结

## 🎯 重构目标

1. **重命名功能**：将"动态切换"重命名为"演示模式"，明确这是用于展示而非日常使用
2. **添加真实时间模式**：根据当前时间自动选择合适的 Light Preset（官方推荐方式）
3. **遵循官方最佳实践**：按照 Mapbox 官方文档的建议实现 Light Preset 功能

## 📊 三种模式对比

| 模式 | 说明 | 使用场景 | Light Preset 来源 |
|------|------|----------|------------------|
| **手动模式** (manual) | 使用用户选择的固定 preset | 日常导航，用户有特定偏好 | 用户在样式选择器中选择 |
| **真实时间模式** (realTime) | 根据当前时间自动选择 | 日常导航，自动适应环境 | 系统根据时间自动选择 |
| **演示模式** (demo) | 每 5 秒循环切换所有 preset | 产品演示、功能展示 | 自动循环（dawn→day→dusk→night） |

## 🎨 真实时间模式详情

根据一天中的不同时间段自动选择合适的 Light Preset：

```swift
func getLightPresetForRealTime() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    
    switch hour {
    case 5..<7:
        return "dawn"    // 黎明 (5:00-7:00)
    case 7..<18:
        return "day"     // 白天 (7:00-18:00)
    case 18..<20:
        return "dusk"    // 黄昏 (18:00-20:00)
    default:
        return "night"   // 夜晚 (20:00-5:00)
    }
}
```

### 时间段说明

- **🌅 Dawn (黎明)**: 5:00 - 7:00 - 柔和的清晨光线
- **☀️ Day (白天)**: 7:00 - 18:00 - 明亮的日间光照
- **🌆 Dusk (黄昏)**: 18:00 - 20:00 - 温暖的黄昏光线
- **🌙 Night (夜晚)**: 20:00 - 5:00 - 柔和的夜间照明

## 🔧 代码变更

### 1. 新增枚举定义

**文件**：`NavigationFactory.swift`

```swift
/// Light Preset 模式枚举
enum LightPresetMode: String {
    case manual = "manual"          // 手动模式：使用用户选择的固定 preset
    case realTime = "realTime"      // 真实时间模式：根据当前时间自动选择 preset
    case demo = "demo"              // 演示模式：每 5 秒循环切换（用于展示）
    
    /// 从字符串解析，默认为手动模式
    static func from(_ string: String?) -> LightPresetMode {
        guard let string = string else { return .manual }
        return LightPresetMode(rawValue: string) ?? .manual
    }
}
```

### 2. 变量重命名

**NavigationFactory.swift**：
```swift
// 旧代码
var _enableDynamicLightPreset: Bool = false  

// 新代码
var _lightPresetMode: LightPresetMode = .manual
```

**StylePickerViewController.swift**：
```swift
// 旧代码
private var enableDynamicLightPreset: Bool = false

// 新代码
private var lightPresetMode: String = "manual"  // manual, realTime, demo
```

### 3. UI 组件更新

**StylePickerViewController.swift** - 从 Switch 改为 Segmented Control：

```swift
// 旧代码
private let dynamicSwitch = UISwitch()

// 新代码
private let modeSegmentedControl = UISegmentedControl(items: ["手动选择", "真实时间", "演示模式"])
```

### 4. 存储逻辑更新

**StylePickerHandler.swift** - UserDefaults 键名：

```swift
// 旧代码
private static let keyEnableDynamic = "mapbox_enable_dynamic_light_preset"

// 新代码
private static let keyLightPresetMode = "mapbox_light_preset_mode"
```

### 5. 应用逻辑更新

**NavigationFactory.swift** - `applyStoredMapStyle` 方法：

```swift
// 根据模式应用 Light Preset
switch self._lightPresetMode {
case .manual:
    // 手动模式：使用用户选择的固定 preset
    if let preset = self._lightPreset {
        self.applyLightPreset(preset, to: mapView)
        print("✅ Light Preset 模式：手动 (\(preset))")
    }
    
case .realTime:
    // 真实时间模式：根据当前时间自动选择
    let preset = self.getLightPresetForRealTime()
    self.applyLightPreset(preset, to: mapView)
    print("✅ Light Preset 模式：真实时间 (\(preset))")
    
case .demo:
    // 演示模式：启动 5 秒循环切换
    self.startDemoMode(mapView: mapView)
    print("✅ Light Preset 模式：演示（5秒循环）")
}
```

## 📁 修改的文件

### iOS Native 文件

1. **NavigationFactory.swift**
   - 添加 `LightPresetMode` 枚举
   - 添加 `getLightPresetForRealTime()` 方法
   - 重命名 `startDynamicLightPresetSwitch()` → `startDemoMode()`
   - 重命名 `stopDynamicLightPresetSwitch()` → `stopDemoMode()`
   - 更新 `loadStoredStyleSettings()` 方法
   - 更新 `parseFlutterArguments()` 方法
   - 更新 `applyStoredMapStyle()` 方法

2. **EmbeddedNavigationView.swift**
   - 更新样式应用逻辑以使用新的模式枚举

3. **StylePickerHandler.swift**
   - 更新 UserDefaults 键名
   - 更新 `showStylePicker()` 方法
   - 更新 `getStoredStyle()` 方法
   - 更新 `clearStoredStyle()` 方法
   - 更新 `saveStyleSettings()` 方法
   - 更新 `loadStoredStyleSettings()` 返回值
   - 更新 `presentStylePicker()` 参数

4. **StylePickerViewController.swift**
   - 将 `enableDynamicLightPreset: Bool` 改为 `lightPresetMode: String`
   - 将 `dynamicSwitch: UISwitch` 改为 `modeSegmentedControl: UISegmentedControl`
   - 重写 `createDynamicSwitchContainer()` 方法
   - 添加 `getModeDescription()` 方法
   - 添加 `modeChanged()` 方法
   - 更新 `applyTapped()` 方法
   - 更新 `StylePickerResult` 结构体

## 🎨 新 UI 界面

### 模式选择器

```
┌──────────────────────────────────────┐
│ Light Preset 模式                    │
│                                      │
│ ┌──────────┬──────────┬──────────┐  │
│ │ 手动选择 │ 真实时间 │ 演示模式 │  │
│ └──────────┴──────────┴──────────┘  │
│                                      │
│ 真实时间模式：根据当前时间自动选择     │
│ 合适的 Light Preset                 │
│ （黎明/白天/黄昏/夜晚）                │
└──────────────────────────────────────┘
```

### 模式说明

- **手动选择**：显示"手动模式：使用您选择的固定 Light Preset"
- **真实时间**：显示"真实时间模式：根据当前时间自动选择合适的 Light Preset（黎明/白天/黄昏/夜晚）"
- **演示模式**：显示"演示模式：每 5 秒自动循环切换所有 Light Preset（仅用于展示）"

## 🔄 数据流

### 保存流程

```
用户在样式选择器中选择模式
    ↓
选择 Segmented Control (手动/真实时间/演示)
    ↓
点击"应用"按钮
    ↓
创建 StylePickerResult (lightPresetMode: String)
    ↓
StylePickerHandler.saveStyleSettings()
    ↓
保存到 UserDefaults (key: "mapbox_light_preset_mode")
    ↓
NavigationFactory.loadStoredStyleSettings()
    ↓
解析为 LightPresetMode 枚举
    ↓
存储在 _lightPresetMode 属性
```

### 应用流程

```
启动导航
    ↓
创建 NavigationViewController
    ↓
调用 applyStoredMapStyle()
    ↓
读取 _lightPresetMode
    ↓
switch lightPresetMode:
    ├── manual: 应用用户选择的 preset
    ├── realTime: 根据当前时间选择 preset
    └── demo: 启动 5 秒循环定时器
    ↓
应用到地图 MapView
```

## ✅ 优势

### 1. 更清晰的命名
- ❌ "启用动态切换" - 含义不明确
- ✅ "演示模式" - 明确说明用途

### 2. 更实用的功能
- ✅ 真实时间模式符合实际使用需求
- ✅ 自动适应环境光线变化
- ✅ 符合 Mapbox 官方最佳实践

### 3. 更好的用户体验
- ✅ 三种模式一目了然
- ✅ 详细的说明文字
- ✅ 符合 iOS 设计规范

## 📝 使用示例

### Dart/Flutter 端

```dart
// 1. 打开样式选择器
await MapboxStylePicker.show();

// 2. 获取存储的设置
final settings = await MapboxStylePicker.getStoredStyle();
print(settings['lightPresetMode']); // "manual", "realTime", 或 "demo"

// 3. 清除设置
await MapboxStylePicker.clearStoredStyle();
```

### iOS Native 端

```swift
// 读取模式
let mode = LightPresetMode.from(settings.lightPresetMode)

// 根据真实时间获取 preset
let preset = getLightPresetForRealTime()

// 应用 preset
applyLightPreset(preset, to: mapView)

// 启动演示模式
startDemoMode(mapView: mapView)
```

## 🧪 测试步骤

### 1. 测试手动模式

1. 打开样式选择器
2. 选择"手动选择"模式
3. 选择一个 Light Preset（如 "Dusk"）
4. 点击"应用"
5. 启动导航
6. ✅ 验证地图显示选择的 preset

### 2. 测试真实时间模式

1. 打开样式选择器
2. 选择"真实时间"模式
3. 点击"应用"
4. 启动导航
5. ✅ 验证地图根据当前时间显示合适的 preset
6. ✅ 检查控制台日志，确认选择的 preset 符合当前时间

### 3. 测试演示模式

1. 打开样式选择器
2. 选择"演示模式"
3. 点击"应用"
4. 启动导航
5. ✅ 验证地图每 5 秒自动切换 preset
6. ✅ 观察循环顺序：dawn → day → dusk → night → dawn...

## 📊 对比总结

| 方面 | 重构前 | 重构后 |
|------|--------|--------|
| **模式数量** | 2种（手动/动态） | 3种（手动/真实时间/演示） |
| **UI 控件** | Switch 开关 | Segmented Control |
| **命名** | "启用动态切换" | "Light Preset 模式" |
| **真实时间** | ❌ 不支持 | ✅ 支持 |
| **说明文字** | ❌ 无 | ✅ 详细说明 |
| **存储键** | `mapbox_enable_dynamic_light_preset` (Bool) | `mapbox_light_preset_mode` (String) |
| **官方最佳实践** | ⚠️ 部分符合 | ✅ 完全符合 |

## 🎉 总结

本次重构完成了以下目标：

1. ✅ 重命名"动态切换"为"演示模式"，明确用途
2. ✅ 添加"真实时间模式"，根据当前时间自动选择 Light Preset
3. ✅ 优化 UI，使用 Segmented Control 替代 Switch
4. ✅ 添加详细的模式说明，提升用户体验
5. ✅ 遵循 Mapbox 官方最佳实践
6. ✅ 保持向后兼容，支持从旧版本迁移

现在用户可以根据实际需求选择最合适的 Light Preset 模式：
- **日常使用**：推荐使用"真实时间模式"或"手动选择"
- **产品演示**：使用"演示模式"展示所有效果
- **个性化**：使用"手动选择"固定喜欢的风格

---

**重构日期**: 2024-11-17  
**版本**: v3.2.0  
**参考文档**: [Mapbox Maps SDK for iOS - Light Presets](https://docs.mapbox.com/ios/maps/api/3.9.2/)
