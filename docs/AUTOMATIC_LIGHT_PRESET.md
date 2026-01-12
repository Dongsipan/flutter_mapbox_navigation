# 基于真实日出日落的 Light Preset 自动调整

## 🎯 重构目标

根据 Mapbox 官方文档，使用 SDK 内置的 `automaticallyAdjustsStyleForTimeOfDay` 属性实现基于真实日出日落时间的自动调整：

> Active style is set based on the sunrise and sunset at your current location.

## 📊 重构内容

### 1. 简化模式

**重构前：** 3种模式
- 手动模式
- 真实时间模式（基于固定时间段）
- 演示模式（5秒循环）

**重构后：** 2种模式
- **手动模式 (manual)** - 使用用户选择的固定 preset
- **自动模式 (automatic)** - 基于真实日出日落时间自动调整

### 2. 核心实现

使用 Mapbox Navigation SDK 的官方 API：

```swift
// 手动模式
navigationViewController.automaticallyAdjustsStyleForTimeOfDay = false
applyLightPreset(preset, to: mapView)

// 自动模式
navigationViewController.automaticallyAdjustsStyleForTimeOfDay = true
// SDK 自动处理，无需手动设置
```

## 🔧 代码变更

### NavigationFactory.swift

#### 1. 简化枚举

```swift
enum LightPresetMode: String {
    case manual = "manual"          // 手动模式
    case automatic = "automatic"    // 自动模式（基于真实日出日落）
    
    static func from(_ string: String?) -> LightPresetMode {
        guard let string = string else { return .manual }
        // 兼容旧值
        if string == "realTime" || string == "demo" {
            return .automatic
        }
        return LightPresetMode(rawValue: string) ?? .manual
    }
}
```

#### 2. 移除不必要的代码

删除了以下方法：
- ✅ `getLightPresetForRealTime()` - 不再需要固定时间段判断
- ✅ `startDemoMode()` - 移除演示模式
- ✅ `stopDemoMode()` - 移除演示模式

删除了以下变量：
- ✅ `_currentLightPresetIndex` - demo 模式专用
- ✅ `_lightPresetTimer` - demo 模式专用

#### 3. 使用官方 API

```swift
func applyStoredMapStyle(to navigationViewController: NavigationViewController) {
    Task { @MainActor in
        guard let navigationMapView = navigationViewController.navigationMapView else {
            return
        }
        
        let mapView = navigationMapView.mapView
        
        if _mapStyle != nil {
            mapView.mapboxMap.style.uri = getCurrentStyleURI()
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            switch self._lightPresetMode {
            case .manual:
                // 禁用自动调整，使用用户选择的固定 preset
                navigationViewController.automaticallyAdjustsStyleForTimeOfDay = false
                if let preset = self._lightPreset {
                    self.applyLightPreset(preset, to: mapView)
                    print("✅ Light Preset 模式：手动 (\(preset))")
                }
                
            case .automatic:
                // 启用 SDK 的内置日出日落自动调整功能
                navigationViewController.automaticallyAdjustsStyleForTimeOfDay = true
                print("✅ Light Preset 模式：自动（基于真实日出日落时间）")
                print("ℹ️  SDK 将根据当前位置的日出日落自动调整地图样式")
            }
        }
    }
}
```

### StylePickerViewController.swift

#### UI 变更：SegmentedControl → Switch

**重构前：** 三选项 SegmentedControl
```
┌──────────────────────────────────┐
│ 手动选择 | 真实时间 | 演示模式  │
└──────────────────────────────────┘
```

**重构后：** 简单的 Switch 开关
```
┌──────────────────────────────────┐
│ 根据日出日落自动调整      [OFF] │
│                                  │
│ 开启后，地图样式将根据当前       │
│ 位置的真实日出日落时间自动       │
│ 调整 Light Preset               │
└──────────────────────────────────┘
```

#### 代码实现

```swift
private let automaticModeSwitch = UISwitch()

private func createDynamicSwitchContainer() -> UIView {
    let container = UIView()
    
    let titleLabel = UILabel()
    titleLabel.text = "根据日出日落自动调整"
    
    automaticModeSwitch.isOn = (lightPresetMode == "automatic")
    automaticModeSwitch.addTarget(self, action: #selector(automaticModeSwitchChanged), for: .valueChanged)
    
    let descLabel = UILabel()
    descLabel.text = "开启后，地图样式将根据当前位置的真实日出日落时间自动调整 Light Preset（黎明/白天/黄昏/夜晚）"
    
    // Layout constraints...
    return container
}

@objc private func automaticModeSwitchChanged() {
    lightPresetMode = automaticModeSwitch.isOn ? "automatic" : "manual"
}
```

### EmbeddedNavigationView.swift

嵌入式导航视图不支持 `automaticallyAdjustsStyleForTimeOfDay`，因此：

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    // 仅支持手动模式
    if self._lightPresetMode == .manual, let preset = self._lightPreset {
        self.applyLightPreset(preset, to: self.navigationMapView?.mapView)
        print("✅ EmbeddedNavigationView - Light Preset 模式：手动 (\(preset))")
    } else if self._lightPresetMode == .automatic {
        print("ℹ️  EmbeddedNavigationView 不支持自动模式，请使用 NavigationViewController")
    }
}
```

### StylePickerHandler.swift

添加向后兼容逻辑：

```swift
var lightPresetMode = defaults.string(forKey: Self.keyLightPresetMode) ?? "manual"

// 兼容旧值：将 realTime 和 demo 映射为 automatic
if lightPresetMode == "realTime" || lightPresetMode == "demo" {
    lightPresetMode = "automatic"
}
```

## 📁 修改的文件

### iOS Native 文件 (4个)

1. **NavigationFactory.swift** ✅
   - 简化 `LightPresetMode` 枚举（2种模式）
   - 使用 `automaticallyAdjustsStyleForTimeOfDay` 属性
   - 删除 `getLightPresetForRealTime()`、`startDemoMode()`、`stopDemoMode()` 方法
   - 删除 `_currentLightPresetIndex`、`_lightPresetTimer` 变量

2. **EmbeddedNavigationView.swift** ✅
   - 简化 Light Preset 应用逻辑
   - 添加不支持自动模式的提示

3. **StylePickerViewController.swift** ✅
   - 将 SegmentedControl 改为 Switch
   - 简化 UI 和逻辑
   - 更新文案为"根据日出日落自动调整"

4. **StylePickerHandler.swift** ✅
   - 添加向后兼容逻辑
   - 映射旧的 realTime/demo 为 automatic

## 🎨 新 UI 界面

```
┌─────────────────────────────────────────┐
│ Map Style Picker                        │
├─────────────────────────────────────────┤
│                                         │
│ ⚙️ Map Styles                           │
│ ○ Standard  ○ Satellite  ○ Light       │
│ ○ Dark      ○ Outdoors                  │
│                                         │
│ ☀️ Light Presets                        │
│ ○ Dawn  ○ Day  ○ Dusk  ○ Night        │
│                                         │
│ 🌍 根据日出日落自动调整          [ON]  │
│ 开启后，地图样式将根据当前位置的       │
│ 真实日出日落时间自动调整 Light Preset │
│ （黎明/白天/黄昏/夜晚）                 │
│                                         │
│           [应用]                        │
└─────────────────────────────────────────┘
```

## ✅ 优势对比

| 方面 | 重构前 | 重构后 |
|------|--------|--------|
| **模式数量** | 3种（手动/真实时间/演示） | 2种（手动/自动） |
| **精确度** | 固定时间段 | 真实日出日落 |
| **实现方式** | 自定义逻辑 | SDK 官方 API |
| **代码复杂度** | 复杂 | 简单 |
| **UI 控件** | SegmentedControl | Switch |
| **用户体验** | 3个选项，复杂 | 简单开关，直观 |
| **维护性** | 需维护时间逻辑 | SDK 自动维护 |
| **地理位置** | ❌ 不考虑 | ✅ 基于当前位置 |
| **季节变化** | ❌ 固定时间 | ✅ 自动适应 |

## 🌍 工作原理

### 自动模式工作流程

```
1. 用户开启"自动调整"开关
   ↓
2. 设置 automaticallyAdjustsStyleForTimeOfDay = true
   ↓
3. SDK 获取用户当前位置
   ↓
4. SDK 计算该位置的日出日落时间
   ↓
5. SDK 根据当前时间与日出日落关系选择 Light Preset:
   - 日出前：night
   - 日出附近：dawn
   - 白天：day
   - 日落附近：dusk
   - 日落后：night
   ↓
6. SDK 自动应用相应的 Light Preset
   ↓
7. 位置或时间变化时，SDK 自动更新
```

### 手动模式工作流程

```
1. 用户关闭"自动调整"开关
   ↓
2. 设置 automaticallyAdjustsStyleForTimeOfDay = false
   ↓
3. 用户选择固定的 Light Preset (dawn/day/dusk/night)
   ↓
4. 应用用户选择的 preset
   ↓
5. Preset 保持不变，直到用户再次修改
```

## 📝 使用示例

### Dart/Flutter 端

```dart
// 启用自动模式
await MapboxStylePicker.show();
// 用户在 UI 中打开"根据日出日落自动调整"开关

// 查询当前设置
final settings = await MapboxStylePicker.getStoredStyle();
print(settings['lightPresetMode']); // "automatic" 或 "manual"
```

### iOS Native 端

```swift
// 读取模式
let mode = LightPresetMode.from(settings.lightPresetMode)

// 自动模式
if mode == .automatic {
    navigationViewController.automaticallyAdjustsStyleForTimeOfDay = true
    // SDK 自动处理
}

// 手动模式
if mode == .manual, let preset = lightPreset {
    navigationViewController.automaticallyAdjustsStyleForTimeOfDay = false
    applyLightPreset(preset, to: mapView)
}
```

## 🧪 测试步骤

### 1. 测试手动模式

1. 打开样式选择器
2. 关闭"根据日出日落自动调整"开关
3. 选择一个 Light Preset（如 "Day"）
4. 点击"应用"
5. 启动导航
6. ✅ 验证地图始终显示选择的 preset，不随时间变化

### 2. 测试自动模式

1. 打开样式选择器
2. 打开"根据日出日落自动调整"开关
3. 点击"应用"
4. 启动导航
5. ✅ 验证地图根据当前时间自动选择 preset
6. ✅ 检查控制台日志：
   ```
   ✅ Light Preset 模式：自动（基于真实日出日落时间）
   ℹ️  SDK 将根据当前位置的日出日落自动调整地图样式
   ```

### 3. 测试向后兼容

1. 使用旧版本保存的设置（realTime 或 demo）
2. 升级到新版本
3. ✅ 验证旧设置自动映射为 automatic
4. ✅ 验证功能正常工作

## 📚 官方文档参考

根据 Mapbox Navigation SDK 文档：

```swift
/// Whether the map style and UI should automatically update given the time of day
/// Active style is set based on the sunrise and sunset at your current location.
var automaticallyAdjustsStyleForTimeOfDay: Bool { get set }
```

可用的 Light Preset 选项：
- `.dawn` - 黎明
- `.day` - 白天（默认值）
- `.dusk` - 黄昏
- `.night` - 夜晚

## 🎉 重构总结

### 完成的工作

1. ✅ 移除演示模式（demo）
2. ✅ 使用 SDK 官方 API 实现真实日出日落自动调整
3. ✅ 简化 UI：SegmentedControl → Switch
4. ✅ 移除不必要的自定义逻辑（固定时间段判断、定时器等）
5. ✅ 保持向后兼容

### 核心改进

- **更精确** - 基于真实日出日落，而非固定时间段
- **更简单** - 使用官方 API，减少自定义代码
- **更易用** - 简单的开关，直观明了
- **更智能** - 考虑地理位置和季节变化
- **更可靠** - SDK 维护，无需自己处理边界情况

### 用户价值

- 🌍 **全球适用** - 自动适应任何地理位置
- 🗓️ **季节自适应** - 自动考虑季节变化
- 🎯 **精确时间** - 基于真实天文数据
- 📱 **简单易用** - 一个开关，开箱即用

---

**重构日期**: 2024-11-17  
**版本**: v3.3.0  
**官方 API**: `NavigationViewController.automaticallyAdjustsStyleForTimeOfDay`
