# 导航历史记录功能

本功能为 Flutter Mapbox Navigation 插件添加了导航历史记录和回放功能。

## 功能特性

1. **启用/禁用历史记录**: 通过 `MapBoxOptions.enableHistoryRecording` 参数控制是否记录导航历史
2. **历史记录查询**: 获取所有导航历史记录列表
3. **历史记录管理**: 删除指定历史记录或清除所有历史记录
4. **历史记录数据**: 包含文件路径、封面、时间、距离等信息

## 使用方法

### 1. 启用历史记录

```dart
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

// 创建导航选项，启用历史记录
final options = MapBoxOptions(
  enableHistoryRecording: true, // 启用历史记录功能
  voiceInstructionsEnabled: true,
  bannerInstructionsEnabled: true,
);

// 开始导航
await MapBoxNavigation.instance.startNavigation(
  wayPoints: wayPoints,
  options: options,
);
```

### 2. 查询历史记录列表

```dart
// 获取所有历史记录
final historyList = await MapBoxNavigation.instance.getNavigationHistoryList();

// 遍历历史记录
for (final history in historyList) {
  print('历史记录ID: ${history.id}');
  print('文件路径: ${history.historyFilePath}');
  print('开始时间: ${history.startTime}');
  print('距离: ${history.distance}');
  print('起点: ${history.startPointName}');
  print('终点: ${history.endPointName}');
}
```

### 3. 删除历史记录

```dart
// 删除指定的历史记录
final success = await MapBoxNavigation.instance.deleteNavigationHistory(historyId);

// 清除所有历史记录
final success = await MapBoxNavigation.instance.clearAllNavigationHistory();
```

## 数据模型

### NavigationHistory

```dart
class NavigationHistory {
  final String id;                    // 历史记录唯一标识符
  final String historyFilePath;       // 导航历史文件路径
  final String? cover;                // 封面图片路径（可选）
  final DateTime startTime;           // 导航开始时间
  final DateTime? endTime;            // 导航结束时间
  final double? distance;             // 导航距离（米）
  final int? duration;                // 导航持续时间（秒）
  final String? startPointName;       // 起点名称
  final String? endPointName;         // 终点名称
  final String? navigationMode;       // 导航模式
}
```

## 平台实现

### Android 平台

Android 平台使用 Mapbox Navigation SDK 的 `HistoryRecorder` 功能：

- 启动记录: `mapboxNavigation.historyRecorder.startRecording()`
- 停止记录: `mapboxNavigation.historyRecorder.stopRecording()`
- 历史文件存储在: `<app_directory>/files/mbx_nav/history`
- 使用 `HistoryManager` 类管理历史记录的存储和查询
- 支持 SharedPreferences 持久化存储历史记录元数据

### iOS 平台

iOS 平台使用 Mapbox Navigation SDK 的 `HistoryRecording` 功能：

- 开始记录: `startRecordingHistory()`
- 停止记录: `stopRecordingHistory(writingFileWith: fileURL)`
- 历史文件存储在应用沙盒目录中
- 使用 `HistoryManager` 类管理历史记录的存储和查询
- 支持 UserDefaults 持久化存储历史记录元数据

## 注意事项

1. **存储空间**: 历史记录文件会占用设备存储空间，建议定期清理
2. **隐私保护**: 历史记录包含位置信息，请确保符合隐私政策
3. **性能影响**: 启用历史记录可能会对导航性能产生轻微影响
4. **文件格式**: 历史记录文件为 JSON 格式，可用于回放功能

## 完整示例

参考以下文件查看完整的使用示例：

- `example/lib/navigation_history_example.dart` - 基本使用示例
- `example/lib/navigation_history_test.dart` - 功能测试示例

## 测试功能

使用测试页面可以验证历史记录功能的完整流程：

1. 启动导航（启用历史记录）
2. 启动导航（禁用历史记录）
3. 查看历史记录列表
4. 删除指定历史记录
5. 清除所有历史记录

## API 参考

### MapBoxOptions 新增参数

- `enableHistoryRecording`: 是否启用导航历史记录功能（默认: false）

### 新增方法

- `getNavigationHistoryList()`: 获取所有导航历史记录列表
- `deleteNavigationHistory(String historyId)`: 删除指定的导航历史记录
- `clearAllNavigationHistory()`: 清除所有导航历史记录

## 更新日志

- **v0.2.3**: 添加导航历史记录功能
  - 新增 `enableHistoryRecording` 参数
  - 新增 `NavigationHistory` 数据模型
  - 新增历史记录管理 API
  - 支持 Android 和 iOS 平台
