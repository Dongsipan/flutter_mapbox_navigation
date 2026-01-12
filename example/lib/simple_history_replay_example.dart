import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

/// 简化的历史回放示例
/// 展示如何使用新的简化历史回放功能
/// 无需手动控制，自动开始回放，仅展示正常的导航界面
class SimpleHistoryReplayExample extends StatefulWidget {
  const SimpleHistoryReplayExample({Key? key}) : super(key: key);

  @override
  State<SimpleHistoryReplayExample> createState() =>
      _SimpleHistoryReplayExampleState();
}

class _SimpleHistoryReplayExampleState
    extends State<SimpleHistoryReplayExample> {
  List<NavigationHistory> _historyList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistoryList();
  }

  /// 加载历史记录列表
  Future<void> _loadHistoryList() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final historyList =
          await MapBoxNavigation.instance.getNavigationHistoryList();
      setState(() {
        _historyList = historyList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('加载历史记录失败: $e');
    }
  }

  /// 开始简化的历史回放
  /// 使用新的HistoryReplayViewController，自动开始，无需手动控制
  Future<void> _startSimpleReplay(NavigationHistory history) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 使用简化的历史回放功能
      // enableReplayUI设置为true，会自动展示导航界面
      final success = await MapBoxNavigation.instance.startHistoryReplay(
        historyFilePath: history.historyFilePath,
        enableReplayUI: true, // 启用UI，自动展示导航界面
      );

      setState(() {
        _isLoading = false;
      });

      if (success) {
        _showSuccessDialog('历史回放已开始\n将自动展示导航界面');
      } else {
        _showErrorDialog('启动历史回放失败');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('启动历史回放失败: $e');
    }
  }

  /// 显示成功对话框
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('成功'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示错误对话框
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('简化历史回放'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoryList,
            tooltip: '刷新历史记录',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('加载中...'),
                ],
              ),
            )
          : _historyList.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '暂无历史记录',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '请先进行一次导航以生成历史记录',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _historyList.length,
                  itemBuilder: (context, index) {
                    final history = _historyList[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(
                            Icons.route,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          '${history.startPointName ?? "未知起点"} → ${history.endPointName ?? "未知终点"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '开始时间: ${_formatDateTime(history.startTime)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (history.duration != null)
                              Text(
                                '持续时间: ${_formatDuration(history.duration!)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (history.distance != null)
                              Text(
                                '距离: ${_formatDistance(history.distance!)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _startSimpleReplay(history),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('回放'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化持续时间
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours小时$minutes分钟$remainingSeconds秒';
    } else if (minutes > 0) {
      return '$minutes分钟$remainingSeconds秒';
    } else {
      return '$remainingSeconds秒';
    }
  }

  /// 格式化距离
  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} 公里';
    } else {
      return '${meters.toInt()} 米';
    }
  }
}
