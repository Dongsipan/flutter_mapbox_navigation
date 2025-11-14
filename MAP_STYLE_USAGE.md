# 地图样式选择功能使用指南

本文档介绍如何在Flutter Mapbox Navigation插件中使用新的地图样式选择功能。

## 功能概述

新的地图样式功能支持：

1. **6种预设地图样式**：
   - `MapStyle.standard` - 标准样式
   - `MapStyle.standardSatellite` - 标准卫星样式
   - `MapStyle.streets` - 街道样式
   - `MapStyle.light` - 浅色样式
   - `MapStyle.dark` - 深色样式  
   - `MapStyle.outdoors` - 户外样式

2. **时间段光照预设**（仅适用于Standard样式）：
   - `TimeOfDayPreset.dawn` - 黎明
   - `TimeOfDayPreset.day` - 白天（默认）
   - `TimeOfDayPreset.dusk` - 黄昏
   - `TimeOfDayPreset.night` - 夜晚

3. **动态样式切换**：支持在运行时修改地图样式和时间段预设

## 基本用法

### 1. 设置初始地图样式

```dart
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

// 创建导航选项，设置地图样式
final options = MapBoxOptions(
  mapStyle: MapStyle.standard,  // 使用标准样式
  timeOfDayPreset: TimeOfDayPreset.day,  // 设置为白天模式
  enableTimeOfDaySwitch: true,  // 启用时间段动态切换
);

// 启动导航
await MapBoxNavigation.instance.startNavigation(
  wayPoints: wayPoints,
  options: options,
);
```

### 2. 运行时切换地图样式

```dart
// 切换到深色样式
await MapBoxNavigation.instance.setMapStyle(
  mapStyle: MapStyle.dark,
);

// 切换到标准样式并设置黄昏模式
await MapBoxNavigation.instance.setMapStyle(
  mapStyle: MapStyle.standard,
  timeOfDayPreset: TimeOfDayPreset.dusk,
  enableTimeOfDaySwitch: true,
);
```

### 3. 动态切换时间段预设

```dart
// 仅适用于MapStyle.standard样式
if (MapBoxNavigation.instance.supportsTimeOfDayPreset()) {
  await MapBoxNavigation.instance.setTimeOfDayPreset(
    TimeOfDayPreset.night
  );
}
```

## 完整示例

以下是一个完整的地图样式选择示例：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

class MapStyleSelector extends StatefulWidget {
  @override
  _MapStyleSelectorState createState() => _MapStyleSelectorState();
}

class _MapStyleSelectorState extends State<MapStyleSelector> {
  MapStyle _currentStyle = MapStyle.standard;
  TimeOfDayPreset _currentPreset = TimeOfDayPreset.day;
  bool _enableTimeOfDaySwitch = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('地图样式选择'),
      ),
      body: Column(
        children: [
          // 地图样式选择
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('地图样式'),
                  subtitle: Text(_currentStyle.displayName),
                ),
                Wrap(
                  children: MapStyle.values.map((style) {
                    return FilterChip(
                      label: Text(style.displayName),
                      selected: _currentStyle == style,
                      onSelected: (selected) {
                        if (selected) {
                          _setMapStyle(style);
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          
          // 时间段预设选择（仅当支持时显示）
          if (_currentStyle.supportsTimeOfDayPreset) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text('时间段预设'),
                    subtitle: Text(_currentPreset.displayName),
                  ),
                  Wrap(
                    children: TimeOfDayPreset.values.map((preset) {
                      return FilterChip(
                        label: Text(preset.displayName),
                        selected: _currentPreset == preset,
                        onSelected: (selected) {
                          if (selected) {
                            _setTimeOfDayPreset(preset);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
          
          // 动态切换开关
          SwitchListTile(
            title: Text('启用时间段动态切换'),
            subtitle: Text('开启后可以动态切换dawn、day、dusk、night状态'),
            value: _enableTimeOfDaySwitch,
            onChanged: (value) {
              setState(() {
                _enableTimeOfDaySwitch = value;
              });
              _updateMapStyle();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _setMapStyle(MapStyle style) async {
    setState(() {
      _currentStyle = style;
      // 如果新样式不支持时间段预设，重置为默认值
      if (!style.supportsTimeOfDayPreset) {
        _currentPreset = TimeOfDayPreset.day;
      }
    });
    await _updateMapStyle();
  }

  Future<void> _setTimeOfDayPreset(TimeOfDayPreset preset) async {
    setState(() {
      _currentPreset = preset;
    });
    
    if (_currentStyle.supportsTimeOfDayPreset) {
      await MapBoxNavigation.instance.setTimeOfDayPreset(preset);
    }
  }

  Future<void> _updateMapStyle() async {
    try {
      final success = await MapBoxNavigation.instance.setMapStyle(
        mapStyle: _currentStyle,
        timeOfDayPreset: _currentStyle.supportsTimeOfDayPreset 
            ? _currentPreset 
            : null,
        enableTimeOfDaySwitch: _enableTimeOfDaySwitch,
      );
      
      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('地图样式已更新为: ${_currentStyle.displayName}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('样式更新失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('样式更新出错: $e')),
      );
    }
  }
}
```

## 高级用法

### 1. 检查当前样式状态

```dart
// 获取当前地图样式
MapStyle? currentStyle = MapBoxNavigation.instance.getCurrentMapStyle();

// 获取当前时间段预设
TimeOfDayPreset? currentPreset = MapBoxNavigation.instance.getCurrentTimeOfDayPreset();

// 检查是否支持时间段预设
bool supportsPreset = MapBoxNavigation.instance.supportsTimeOfDayPreset();
```

### 2. 样式配置的持久化

```dart
import 'package:shared_preferences/shared_preferences.dart';

class MapStyleManager {
  static const String _styleKey = 'map_style';
  static const String _presetKey = 'time_of_day_preset';
  
  // 保存样式设置
  static Future<void> saveStylePreferences({
    required MapStyle style,
    TimeOfDayPreset? preset,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, style.toString());
    if (preset != null) {
      await prefs.setString(_presetKey, preset.toString());
    }
  }
  
  // 恢复样式设置
  static Future<void> restoreStylePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    final styleString = prefs.getString(_styleKey);
    final presetString = prefs.getString(_presetKey);
    
    if (styleString != null) {
      final style = MapStyleExtension.fromString(
        styleString.split('.').last
      );
      
      TimeOfDayPreset? preset;
      if (presetString != null) {
        preset = TimeOfDayPresetExtension.fromString(
          presetString.split('.').last
        );
      }
      
      if (style != null) {
        await MapBoxNavigation.instance.setMapStyle(
          mapStyle: style,
          timeOfDayPreset: preset,
        );
      }
    }
  }
}
```

## 注意事项

1. **时间段预设仅适用于Standard样式**：只有`MapStyle.standard`支持`TimeOfDayPreset`功能。

2. **iOS优先实现**：当前版本优先实现了iOS功能，Android功能将在后续版本中支持。

3. **样式切换性能**：频繁切换样式可能会影响性能，建议合理控制切换频率。

4. **网络依赖**：某些样式可能需要网络连接来加载地图瓦片。

5. **权限要求**：确保已正确配置Mapbox访问令牌和相关权限。

## API参考

### MapStyle枚举

- `MapStyle.standard`: 标准样式，支持lightPreset
- `MapStyle.standardSatellite`: 标准卫星样式
- `MapStyle.streets`: 街道样式
- `MapStyle.light`: 浅色样式
- `MapStyle.dark`: 深色样式
- `MapStyle.outdoors`: 户外样式

### TimeOfDayPreset枚举

- `TimeOfDayPreset.dawn`: 黎明（仅Standard样式）
- `TimeOfDayPreset.day`: 白天（仅Standard样式，默认）
- `TimeOfDayPreset.dusk`: 黄昏（仅Standard样式）
- `TimeOfDayPreset.night`: 夜晚（仅Standard样式）

### 主要方法

- `setMapStyle()`: 设置地图样式
- `setTimeOfDayPreset()`: 设置时间段预设
- `getCurrentMapStyle()`: 获取当前样式
- `getCurrentTimeOfDayPreset()`: 获取当前预设
- `supportsTimeOfDayPreset()`: 检查是否支持时间段预设
