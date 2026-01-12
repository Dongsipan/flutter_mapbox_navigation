# 地图样式设置实现指南

## 概述

本项目按照 Mapbox 官方推荐的方式实现了地图样式和 Light Preset 的设置，采用了两种不同的方法来适配不同的使用场景。

## 架构说明

### 1. 全屏导航界面（NavigationViewController）

**实现方式：自定义 UI Style（官方推荐）**

```
用户设置（UserDefaults）
    ↓
StylePickerHandler.loadStoredStyleSettings()
    ↓
NavigationFactory (加载样式配置)
    ↓
CustomStyleFactory.createStyles()
    ↓
CustomDayStyle / CustomNightStyle
    ↓
NavigationOptions(styles: customStyles)
    ↓
NavigationViewController
    ↓
setupLightPresetObserver() (监听样式应用事件)
    ↓
应用 Light Preset 和 Theme
```

#### 关键文件

1. **CustomNavigationStyles.swift**
   - `CustomStyleFactory`: 样式工厂类，根据用户设置创建自定义样式
   - `CustomDayStyle`: 自定义白天样式，继承 `StandardDayStyle`
   - `CustomNightStyle`: 自定义夜间样式，继承 `StandardNightStyle`
   - `NavigationViewController Extension`: 提供 Light Preset 应用逻辑

2. **NavigationFactory.swift**
   - `startNavigation()`: 使用自定义样式创建 NavigationViewController

#### 工作流程

1. **样式创建阶段**
   ```swift
   let customStyles = CustomStyleFactory.createStyles(
       mapStyle: _mapStyle,          // "standard", "dark", etc.
       lightPreset: _lightPreset,     // "day", "night", etc.
       lightPresetMode: _lightPresetMode  // .manual 或 .automatic
   )
   ```

2. **NavigationOptions 配置**
   ```swift
   let navigationOptions = NavigationOptions(
       mapboxNavigation: mapboxNavigation,
       voiceController: routeVoiceController,
       eventsManager: eventsManager,
       styles: customStyles  // ← 关键：传递自定义样式
   )
   ```

3. **Light Preset 应用**
   - CustomDayStyle/CustomNightStyle 在 `apply()` 方法中发送通知
   - NavigationViewController 通过 `setupLightPresetObserver()` 监听通知
   - 延迟 300ms 后应用 Light Preset 和 Theme 配置

#### 优势

✅ 符合 Mapbox 官方推荐的实现方式  
✅ 地图样式与导航 UI 其他元素保持一致  
✅ 支持白天/夜间自动切换  
✅ 代码结构清晰，易于维护  

### 2. 路线选择界面（RouteSelectionViewController）

**实现方式：直接设置 MapView 样式**

由于 RouteSelectionViewController 使用的是 `NavigationMapView` 而不是完整的 `NavigationViewController`，它不涉及导航 UI 样式系统，因此采用直接设置地图样式的方法。

#### 实现代码

```swift
// 在 viewDidLoad 后调用
private func applyMapStyle() {
    Task { @MainActor in
        let mapView = navigationMapView.mapView
        
        // 设置样式 URI
        mapView.mapboxMap.style.uri = getCurrentStyleURI()
        
        // 等待样式加载
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // 应用 Light Preset
        if let preset = lightPreset {
            applyLightPreset(preset, to: mapView)
        }
    }
}
```

### 3. 嵌入式导航（EmbeddedNavigationView）

**实现方式：直接设置 MapView 样式**

与路线选择界面类似，嵌入式导航使用 `NavigationMapView`，采用直接设置样式的方法。

## 支持的地图样式

| 样式标识 | StyleURI | 支持 Light Preset | 说明 |
|---------|----------|------------------|------|
| standard | .standard | ✅ | 标准样式 |
| standardSatellite | .standardSatellite | ✅ | 卫星样式 |
| faded | .standard + theme:faded | ✅ | 褪色主题 |
| monochrome | .standard + theme:monochrome | ✅ | 单色主题 |
| light | .light | ❌ | 浅色样式 |
| dark | .dark | ❌ | 深色样式 |
| outdoors | .outdoors | ❌ | 户外样式 |

## Light Preset 说明

### 支持的 Preset 值

- `dawn`: 黎明（5:00-7:00）
- `day`: 白天（7:00-17:00，默认）
- `dusk`: 黄昏（17:00-19:00）
- `night`: 夜晚（19:00-5:00）

### Light Preset 模式

#### 手动模式（Manual）
```swift
lightPresetMode = .manual
lightPreset = "night"
```
- 禁用自动调整
- 使用用户选择的固定 preset
- 设置 `automaticallyAdjustsStyleForTimeOfDay = false`

#### 自动模式（Automatic）
```swift
lightPresetMode = .automatic
```
- 启用 SDK 内置的日出日落自动调整
- 根据用户位置和当前时间自动切换
- 设置 `automaticallyAdjustsStyleForTimeOfDay = true`

## 配置应用流程

### 1. 用户设置样式

```dart
// Flutter 端
await MapboxStylePicker.show();
```

### 2. 样式存储到 UserDefaults

```swift
// iOS 端
UserDefaults.standard.set("dark", forKey: "mapbox_map_style")
UserDefaults.standard.set("night", forKey: "mapbox_light_preset")
UserDefaults.standard.set("manual", forKey: "mapbox_light_preset_mode")
```

### 3. NavigationFactory 自动加载

```swift
override init() {
    super.init()
    loadStoredStyleSettings()  // 从 UserDefaults 加载
}
```

### 4. 创建导航时应用

```swift
// 全屏导航
let customStyles = CustomStyleFactory.createStyles(...)
let navigationOptions = NavigationOptions(..., styles: customStyles)
let navigationViewController = NavigationViewController(...)
```

## 调试日志

启用详细日志来跟踪样式应用过程：

```
✅ NavigationFactory: 已加载存储的地图样式: dark
✅ NavigationFactory: 已加载存储的 Light Preset: night
✅ CustomDayStyle 初始化: mapStyle=dark, lightPreset=night, mode=manual
✅ CustomDayStyle.apply() 被调用
✅ Light Preset 模式：手动 (night)
✅ Light preset 已应用: night
✅ Theme 已应用: default
```

## 常见问题

### Q: 为什么全屏导航要用 UI Style 而路线选择不用？

A: NavigationViewController 包含完整的导航 UI（顶部横幅、底部状态栏等），使用 UI Style 可以确保地图样式与这些 UI 元素保持一致。而 RouteSelectionViewController 只是一个简单的地图预览，不需要复杂的 UI 样式系统。

### Q: Light Preset 什么时候应用？

A: 在全屏导航中，Light Preset 在样式 apply() 后 300ms 应用，确保地图样式已完全加载。在其他场景中，延迟 500ms 应用。

### Q: 如何确保样式在所有场景下一致？

A: 所有场景都从同一个 UserDefaults 读取配置，确保数据源一致。全屏导航使用 CustomStyleFactory 统一创建样式。

## 参考文档

- [Mapbox Navigation SDK - Custom Styles](https://docs.mapbox.com/ios/navigation/guides/custom-styles/)
- [Mapbox Maps SDK - Style Specification](https://docs.mapbox.com/mapbox-gl-js/style-spec/)
- [Light Preset Documentation](https://docs.mapbox.com/mapbox-gl-js/style-spec/light/)

## 版本历史

### v4.0.0 (2024-11-18) - 官方推荐重构
- ✅ 采用官方推荐的 UI Style 方式实现全屏导航样式
- ✅ 创建 CustomDayStyle 和 CustomNightStyle
- ✅ 通过 NavigationOptions.styles 传递自定义样式
- ✅ 使用通知中心机制应用 Light Preset
- ✅ 简化代码结构，提高可维护性

### v3.1.0 (2024-11-16)
- ✅ 修复全屏导航样式应用时机问题
- ✅ 修复路线选择界面样式应用
- ✅ 添加延迟和重试机制

### v3.0.0 (2024-11-15)
- ✅ 重构为自动存储模式
- ✅ 添加 UserDefaults 持久化
- ✅ 简化 Dart API
