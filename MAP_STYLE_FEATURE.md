# 地图样式选择功能完整指南

## 🎯 功能概述

本功能为 Flutter Mapbox Navigation 插件提供了完整的地图样式管理系统。通过**插件内置的原生样式选择器**，用户可以：

1. ✅ **一键设置地图样式** - 无需编写代码
2. ✅ **自动持久化存储** - 设置一次，全局生效
3. ✅ **智能 Light Preset** - 根据时间自动选择光照效果
4. ✅ **iOS 原生界面** - 完全符合 iOS 设计规范
5. ✅ **地图实时预览** - 选择时即可看到效果
6. ✅ **自动定位** - 地图显示用户当前位置

## 🗺️ 支持的地图样式

### 支持 Light Preset 的样式（推荐）✨

这些样式支持根据时间设置不同的光照效果：

#### 1. **Standard**（标准样式）

- URI: `mapbox://styles/mapbox/standard`
- 特点：Mapbox 最新的标准样式
- 支持：✨ Light Preset（dawn/day/dusk/night）
- 推荐用途：通用场景

#### 2. **Standard Satellite**（卫星样式）

- URI: `mapbox://styles/mapbox/standard-satellite`
- 特点：卫星图像 + 街道标签
- 支持：✨ Light Preset
- 推荐用途：需要卫星图的场景

#### 3. **Faded**（褪色主题）

- URI: `mapbox://styles/mapbox/standard`（主题变体）
- 特点：柔和的配色方案
- 支持：✨ Light Preset
- 推荐用途：突出其他地图元素时

#### 4. **Monochrome**（单色主题）

- URI: `mapbox://styles/mapbox/standard`（主题变体）
- 特点：黑白灰配色
- 支持：✨ Light Preset
- 推荐用途：极简风格或打印场景

### 传统样式

这些样式不支持 Light Preset，但提供了特定的视觉效果：

#### 5. **Light**（浅色样式）

- URI: `mapbox://styles/mapbox/light-v11`
- 特点：浅色背景，简洁明快
- 推荐用途：数据可视化、浅色主题

#### 6. **Dark**（深色样式）

- URI: `mapbox://styles/mapbox/dark-v11`
- 特点：深色背景，适合夜间
- 推荐用途：夜间模式、节省电量

#### 7. **Outdoors**（户外样式）

- URI: `mapbox://styles/mapbox/outdoors-v12`
- 特点：地形、等高线、步道
- 推荐用途：徒步、骑行等户外活动

## ✨ Light Preset（光照预设）

对于支持 Light Preset 的样式（Standard、Standard Satellite、Faded、Monochrome），可以设置不同时段的光照效果：

### 可用的 Light Preset

| Preset | 图标 | 时间段 | 效果描述 |
|--------|------|--------|----------|
| **Dawn** | 🌅 | 5:00-7:00 | 黎明 - 清晨的柔和光线 |
| **Day** | ☀️ | 7:00-17:00 | 白天 - 明亮的日光（默认）|
| **Dusk** | 🌇 | 17:00-19:00 | 黄昏 - 傍晚的温暖光线 |
| **Night** | 🌙 | 19:00-5:00 | 夜晚 - 夜间的深色调 |

### 智能时间匹配

样式选择器会自动根据当前时间选择最合适的 Light Preset，用户也可以手动选择其他时段查看效果。

### 动态切换（演示功能）

启用"动态切换"后，地图会每 5 秒自动循环切换 Light Preset，适合演示和测试：

```text
dawn → day → dusk → night → dawn ...
```

## 🚀 使用方法

### 推荐方式：使用插件样式选择器

这是**最简单、最推荐**的方式：

```dart
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

// 1. 显示样式选择器（一键设置）
await MapboxStylePicker.show();

// 2. 后续所有导航自动使用设置的样式
await MapBoxNavigation.instance.startNavigation(
  wayPoints: [origin, destination],
  // 完全不需要传递样式参数！
);
```

**就这么简单！** 用户设置一次，全局生效。

### 高级用法：查询和清除设置

```dart
// 获取当前设置
final settings = await MapboxStylePicker.getStoredStyle();
print('当前样式: ${settings['mapStyle']}');
print('Light Preset: ${settings['lightPreset']}');

// 清除设置（恢复默认）
await MapboxStylePicker.clearStoredStyle();
```

### 传统方式（不推荐）：手动传参

如果你需要完全自定义，可以使用传统方式：

```dart
final options = MapBoxOptions(
  // 自定义样式 URL
  mapStyleUrlDay: 'mapbox://styles/your-style',
  mapStyleUrlNight: 'mapbox://styles/your-night-style',
  zoom: 15,
);

await MapBoxNavigation.instance.startNavigation(
  wayPoints: [origin, destination],
  options: options,
);
```

**注意**：不推荐手动传参，因为：
- ❌ 需要手动管理样式设置
- ❌ 每次导航都要传递参数
- ❌ 无法全局生效
- ✅ 推荐使用样式选择器自动管理

## 📱 样式选择器界面

### iOS 原生界面特性

插件提供了完全符合 iOS 设计规范的原生样式选择器：

#### 1. **标准导航栏**

- ✅ UINavigationBar 标准样式
- ✅ 标题居中显示"地图样式"
- ✅ 取消按钮在左上角

#### 2. **地图实时预览**

- ✅ 占据屏幕上部 30%
- ✅ 显示用户当前位置
- ✅ 切换样式即时更新
- ✅ 支持缩放和拖动

#### 3. **iOS 标准卡片列表**

- ✅ 圆角 12pt 卡片设计
- ✅ 选中时蓝色边框 + checkmark图标
- ✅ 清晰的标题和描述层次
- ✅ 完美支持深色模式

#### 4. **固定底部按钮**

- ✅ 蓝色"应用"按钮始终可见
- ✅ 无需滚动到底部
- ✅ 高度适配 Safe Area
- ✅ 带顶部分隔线

### 使用流程

```text
用户打开App
    ↓
点击"地图样式设置"
    ↓
查看7种样式 + 地图预览
    ↓
选择喜欢的样式
    ↓
配置 Light Preset（可选）
    ↓
点击"应用"按钮
    ↓
设置自动保存到 UserDefaults ✅
    ↓
后续所有导航自动使用 🎉
```

## 💾 持久化存储机制

### UserDefaults 键值

样式设置存储在 iOS UserDefaults 中：

| Key | 类型 | 说明 |
|-----|------|------|
| `mapbox_map_style` | String | 地图样式（standard/faded/monochrome等） |
| `mapbox_light_preset` | String? | Light Preset（dawn/day/dusk/night） |
| `mapbox_enable_dynamic_light_preset` | Bool | 动态切换开关 |

### 存储时机

- ✅ 用户在样式选择器中点击"应用"按钮
- ✅ 立即同步写入 UserDefaults
- ✅ 不需要应用重启

### 加载时机

- ✅ NavigationFactory 初始化时自动加载
- ✅ 每次启动导航时自动应用
- ✅ 无需手动管理

### 生命周期

```text
应用启动
    ↓
NavigationFactory.init()
    ↓
自动从 UserDefaults 加载样式设置
    ↓
_mapStyle, _lightPreset, _enableDynamicLightPreset 已设置 ✅
    ↓
用户启动导航
    ↓
自动应用加载的样式 🎊
```

## 🏗️ 技术实现

### iOS 架构

#### 1. **StylePickerViewController**

原生样式选择器视图控制器：

```swift
import UIKit
import MapboxMaps
import CoreLocation

class StylePickerViewController: UIViewController {
    // 地图预览
    private var mapView: MapView?
    private let locationManager = CLLocationManager()
    
    // UI 组件
    private let mapContainerView = UIView()
    private let scrollView = UIScrollView()
    private let bottomButtonContainer = UIView()
    
    // 样式配置
    private var selectedStyle: String = "standard"
    private var selectedLightPreset: String = "day"
    private var enableDynamicLightPreset: Bool = false
}
```

**核心功能**：
- 显示地图预览（用户当前位置）
- 提供样式和 Light Preset 选择
- 实时更新地图预览
- 返回用户选择的配置

#### 2. **StylePickerHandler**

处理 Flutter 和原生的通信：

```swift
class StylePickerHandler: NSObject {
    private let channel: FlutterMethodChannel
    
    func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "showStylePicker":
            // 显示样式选择器
        case "getStoredStyle":
            // 读取存储的样式
        case "clearStoredStyle":
            // 清除存储的样式
        }
    }
    
    private func saveStyleSettings(_ pickerResult: StylePickerResult) {
        // 保存到 UserDefaults
    }
}
```

**核心功能**：
- 响应 Flutter 方法调用
- 显示样式选择器
- 保存设置到 UserDefaults
- 提供查询和清除功能

#### 3. **NavigationFactory**

导航工厂，自动加载和应用样式：

```swift
class NavigationFactory {
    private var _mapStyle: String?
    private var _lightPreset: String?
    private var _enableDynamicLightPreset: Bool = false
    
    init() {
        // 自动从 UserDefaults 加载样式设置
        loadStoredStyleSettings()
    }
    
    private func loadStoredStyleSettings() {
        let defaults = UserDefaults.standard
        _mapStyle = defaults.string(forKey: "mapbox_map_style")
        _lightPreset = defaults.string(forKey: "mapbox_light_preset")
        _enableDynamicLightPreset = defaults.bool(forKey: "mapbox_enable_dynamic_light_preset")
    }
}
```

**核心功能**：
- 初始化时自动加载存储的样式
- 启动导航时自动应用样式
- 不被 Flutter 参数覆盖（除非明确传入）

### Dart API

```dart
class MapboxStylePicker {
  static const MethodChannel _channel = 
    MethodChannel('flutter_mapbox_navigation/style_picker');

  /// 显示样式选择器
  static Future<bool> show() async {
    try {
      final result = await _channel.invokeMethod('showStylePicker');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// 获取存储的样式设置
  static Future<Map<String, dynamic>> getStoredStyle() async {
    final result = await _channel.invokeMethod('getStoredStyle');
    return Map<String, dynamic>.from(result ?? {});
  }

  /// 清除存储的样式设置
  static Future<bool> clearStoredStyle() async {
    try {
      await _channel.invokeMethod('clearStoredStyle');
      return true;
    } catch (e) {
      return false;
    }
  }
}
```

### 样式应用流程

```text
1. 用户打开样式选择器
   ↓
2. StylePickerViewController 显示
   - 地图定位到用户位置
   - 显示所有可用样式
   - 自动选择当前时间对应的 Light Preset
   ↓
3. 用户选择样式和配置
   - 实时更新地图预览
   - 可以切换不同 Light Preset 查看效果
   ↓
4. 用户点击"应用"
   ↓
5. StylePickerHandler.saveStyleSettings()
   - 保存到 UserDefaults
   - 同步存储
   ↓
6. 返回 true 到 Flutter
   ↓
7. 下次启动导航
   ↓
8. NavigationFactory.init()
   - 自动加载存储的样式
   ↓
9. 地图自动应用样式 ✅
```

## 🎨 UI 设计亮点

### 符合 iOS Human Interface Guidelines

#### 1. **Clarity（清晰性）**

- ✅ 标准导航栏清晰标题
- ✅ 明确的视觉层次
- ✅ 清晰的选中状态（蓝色边框 + checkmark）

#### 2. **Deference（顺从性）**

- ✅ 使用系统标准组件（UINavigationBar）
- ✅ 遵循系统颜色方案（支持深色模式）
- ✅ 系统图标（SF Symbols checkmark.circle.fill）

#### 3. **Depth（深度感）**

- ✅ 卡片式设计有层次
- ✅ 固定按钮与滚动内容分离
- ✅ 适当的圆角和阴影

### 布局结构

```text
┌─────────────────────────┐
│ [取消]     地图样式      │ ← UINavigationBar
├─────────────────────────┤
│                         │
│    地图预览（30%）       │ ← 固定，显示用户位置
│                         │
├─────────────────────────┤
│   ScrollView            │
│  ┌──────────────────┐   │
│  │ ✓ Standard       │   │ ← iOS 标准卡片
│  │   Standard Sat   │   │
│  │   Faded          │   │
│  │   ...            │   │
│  │                  │   │
│  │ Light Preset:    │   │
│  │ 🌅 Dawn          │   │
│  │ ✓ ☀️ Day         │   │
│  │   🌇 Dusk        │   │
│  │   🌙 Night       │   │
│  │                  │   │
│  │ □ 动态切换        │   │
│  └──────────────────┘   │
├─────────────────────────┤ ← 固定分隔线
│   [  应用按钮  ]         │ ← 始终可见
└─────────────────────────┘
```

### 深色模式支持

所有颜色使用系统语义颜色，完美适配深色模式：

```swift
// 背景色
.systemBackground
.systemGroupedBackground  
.secondarySystemGroupedBackground

// 文字颜色
.label
.secondaryLabel

// 分隔线
.separator

// 强调色
.systemBlue
```

## 📊 数据流图

```text
Flutter Layer:
┌──────────────────────────────────────┐
│  MapboxStylePicker.show()            │
│  ↓                                   │
│  MethodChannel.invokeMethod()        │
└──────────────────────────────────────┘
                ↓
Platform Channel (iOS)
                ↓
┌──────────────────────────────────────┐
│  StylePickerHandler                  │
│  ↓                                   │
│  presentStylePicker()                │
│  ↓                                   │
│  StylePickerViewController.show()   │
│  ↓                                   │
│  User makes selection                │
│  ↓                                   │
│  saveStyleSettings()                 │
│  ↓                                   │
│  UserDefaults.set()                  │
│  ↓                                   │
│  return true                         │
└──────────────────────────────────────┘
                ↓
┌──────────────────────────────────────┐
│  Next Navigation Start               │
│  ↓                                   │
│  NavigationFactory.init()            │
│  ↓                                   │
│  loadStoredStyleSettings()           │
│  ↓                                   │
│  UserDefaults.get()                  │
│  ↓                                   │
│  Apply to mapView ✅                 │
└──────────────────────────────────────┘
```

## 🔍 示例代码

### 完整示例

```dart
import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

class StylePickerExample extends StatefulWidget {
  const StylePickerExample({Key? key}) : super(key: key);

  @override
  State<StylePickerExample> createState() => _StylePickerExampleState();
}

class _StylePickerExampleState extends State<StylePickerExample> {
  Map<String, dynamic> _currentSettings = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final settings = await MapboxStylePicker.getStoredStyle();
    setState(() {
      _currentSettings = settings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图样式设置'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 显示当前设置
            if (_currentSettings.isNotEmpty) ...[
              Text('当前样式: ${_currentSettings['mapStyle'] ?? '未设置'}'),
              const SizedBox(height: 8),
              Text('Light Preset: ${_currentSettings['lightPreset'] ?? '未设置'}'),
              const SizedBox(height: 32),
            ],
            
            // 打开样式选择器
            ElevatedButton.icon(
              onPressed: () async {
                final success = await MapboxStylePicker.show();
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('样式设置成功！')),
                  );
                  _loadCurrentSettings();
                }
              },
              icon: const Icon(Icons.palette),
              label: const Text('选择地图样式'),
            ),
            
            const SizedBox(height: 16),
            
            // 清除设置
            TextButton(
              onPressed: () async {
                await MapboxStylePicker.clearStoredStyle();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复默认样式')),
                );
                _loadCurrentSettings();
              },
              child: const Text('恢复默认'),
            ),
            
            const SizedBox(height: 32),
            
            // 测试导航
            ElevatedButton(
              onPressed: () {
                // 启动导航，自动使用存储的样式
                // 无需传递任何样式参数
                Navigator.pushNamed(context, '/navigation');
              },
              child: const Text('开始导航（自动使用设置的样式）'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## ⚠️ 注意事项

### 1. **权限配置**

iOS 需要在 Info.plist 中配置位置权限：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Shows your location on the map and helps improve the map</string>
```

### 2. **样式 URI 处理**

- Faded 和 Monochrome 是 Standard 的主题变体
- 需要通过 `setStyleImportConfigProperty` 设置 theme
- 不是独立的样式 URI

### 3. **Light Preset 支持**

- 仅支持 Standard 系列样式（standard/standardSatellite/faded/monochrome）
- 传统样式（light/dark/outdoors）不支持 Light Preset
- 选择不支持的样式时，Light Preset 不会保存

### 4. **存储机制**

- 使用 iOS UserDefaults 存储
- 应用卸载后设置会丢失
- 如需云同步需自行实现

### 5. **性能考虑**

- 切换样式会触发地图重新渲染
- 不建议频繁切换样式
- 动态 Light Preset 切换主要用于演示

## 🎉 主要优势

| 方面 | 传统方式 | 新方式（样式选择器） | 改进 |
|------|---------|---------------------|------|
| **设置方式** | 编写代码 | 点击界面 | ✅ 100% 更简单 |
| **参数传递** | 每次都传 | 无需传递 | ✅ 减少 100% |
| **全局生效** | 手动管理 | 自动管理 | ✅ 零维护成本 |
| **用户体验** | 开发者设置 | 用户自主选择 | ✅ 更加个性化 |
| **持久化** | 需自己实现 | 自动持久化 | ✅ 开箱即用 |
| **界面设计** | 无 | iOS 原生 | ✅ 完美符合规范 |

## 📚 相关文档

- [Mapbox iOS Maps - Set a Style](https://docs.mapbox.com/ios/maps/guides/styles/set-a-style/)
- [Mapbox Standard Style](https://docs.mapbox.com/mapbox-gl-js/guides/styles/#mapbox-standard)
- [Light Presets Documentation](https://docs.mapbox.com/mapbox-gl-js/style-spec/light/)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

## 🔄 版本历史

### v3.1.1 (2024-11-16)

- ✅ 添加地图预览自动定位到用户当前位置
- ✅ 智能请求位置权限
- ✅ 优雅的降级处理（无位置时使用北京）

### v3.1.0 (2024-11-16)

- ✅ 完全重构 UI，符合 iOS 设计规范
- ✅ 添加标准 UINavigationBar
- ✅ 固定底部按钮，始终可见
- ✅ iOS 标准卡片样式
- ✅ 完美支持深色模式

### v3.0.0 (2024-11-15)

- ✅ 重构为自动存储模式
- ✅ 移除手动传参逻辑
- ✅ 添加 UserDefaults 持久化
- ✅ 简化 Dart API
- ✅ 清理旧代码和示例

### v2.0.0

- ✅ 添加 Faded 和 Monochrome 主题支持
- ✅ 实现 Light Preset 功能
- ✅ 添加动态切换功能

### v1.0.0

- ✅ 初始实现地图样式选择
- ✅ 支持 7 种预定义样式

## 🚀 后续计划

- [ ] Android 端实现
- [ ] 可自定义动态切换间隔
- [ ] 支持更多 Mapbox 样式
- [ ] 根据系统暗黑模式自动切换
- [ ] 添加样式预览缩略图
- [ ] 支持自定义样式 URL

## 📧 反馈与支持

如有问题或建议，请通过以下方式联系：

- GitHub Issues: [flutter_mapbox_navigation](https://github.com/your-repo/flutter_mapbox_navigation)
- Email: support@example.com

---

**最后更新**: 2024-11-16  
**版本**: v3.1.1  
**维护者**: Cascade AI
