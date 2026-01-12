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

### 4. 历史记录回放

```dart
// 开始历史记录回放（带UI）
final success = await MapBoxNavigation.instance.startHistoryReplay(
  historyFilePath: '/path/to/history/file.pbf.gz',
  enableReplayUI: true,
);

// 开始历史记录回放（无UI，仅数据回放）
final success = await MapBoxNavigation.instance.startHistoryReplay(
  historyFilePath: '/path/to/history/file.pbf.gz',
  enableReplayUI: false,
);

// 停止历史记录回放
final success = await MapBoxNavigation.instance.stopHistoryReplay();

// 暂停历史记录回放
final success = await MapBoxNavigation.instance.pauseHistoryReplay();

// 恢复历史记录回放
final success = await MapBoxNavigation.instance.resumeHistoryReplay();

// 设置回放速度（1.0为正常速度，2.0为2倍速，0.5为0.5倍速）
final success = await MapBoxNavigation.instance.setHistoryReplaySpeed(2.0);
```

## 完整的历史记录回放示例

```dart
import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

class HistoryReplayExample extends StatefulWidget {
  @override
  _HistoryReplayExampleState createState() => _HistoryReplayExampleState();
}

class _HistoryReplayExampleState extends State<HistoryReplayExample> {
  List<NavigationHistory> _historyList = [];
  bool _isReplaying = false;

  @override
  void initState() {
    super.initState();
    _loadHistoryList();
  }

  Future<void> _loadHistoryList() async {
    try {
      final historyList = await MapBoxNavigation.instance.getNavigationHistoryList();
      setState(() {
        _historyList = historyList;
      });
    } catch (e) {
      print('加载历史记录失败: $e');
    }
  }

  Future<void> _startReplay(NavigationHistory history) async {
    try {
      final success = await MapBoxNavigation.instance.startHistoryReplay(
        historyFilePath: history.historyFilePath,
        enableReplayUI: true,
      );

      if (success) {
        setState(() {
          _isReplaying = true;
        });
        print('历史记录回放已开始');
      }
    } catch (e) {
      print('启动历史记录回放失败: $e');
    }
  }

  Future<void> _stopReplay() async {
    try {
      final success = await MapBoxNavigation.instance.stopHistoryReplay();
      if (success) {
        setState(() {
          _isReplaying = false;
        });
        print('历史记录回放已停止');
      }
    } catch (e) {
      print('停止历史记录回放失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('历史记录回放'),
        actions: [
          if (_isReplaying)
            IconButton(
              icon: Icon(Icons.stop),
              onPressed: _stopReplay,
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: _historyList.length,
        itemBuilder: (context, index) {
          final history = _historyList[index];
          return ListTile(
            title: Text('${history.startPointName} → ${history.endPointName}'),
            subtitle: Text('开始时间: ${history.startTime}'),
            trailing: ElevatedButton(
              onPressed: _isReplaying ? null : () => _startReplay(history),
              child: Text('回放'),
            ),
          );
        },
      ),
    );
  }
}
```

## 平台支持

### iOS
- ✅ 完全支持历史记录回放功能
- ✅ 支持带UI和无UI的回放模式
- ✅ 支持回放控制（开始、停止、暂停、恢复）
- ✅ 支持回放速度调节
- ✅ 基于Mapbox Navigation SDK v3的HistoryReplayController

### Android
- ⚠️ 当前版本暂不支持历史记录回放功能
- 📝 Android端的Mapbox Navigation SDK可能不提供相同的历史记录回放API
- 🔄 未来版本将根据Android SDK的支持情况进行实现

## 注意事项

1. **文件路径**: 历史记录文件路径必须是设备上的有效文件路径
2. **文件格式**: 历史记录文件通常是`.pbf.gz`格式的压缩文件
3. **权限**: 确保应用有读取历史记录文件的权限
4. **内存使用**: 回放大型历史记录文件可能消耗较多内存
5. **UI模式**: 启用UI模式时会显示完整的导航界面，禁用时仅进行数据回放

## 故障排除

### 常见问题

1. **文件不存在错误**
   ```
   解决方案：检查历史记录文件路径是否正确，文件是否存在
   ```

2. **回放启动失败**
   ```
   解决方案：确保历史记录文件格式正确，没有损坏
   ```

3. **Android端不支持**
   ```
   解决方案：当前版本仅iOS支持，Android端将在未来版本中实现
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
