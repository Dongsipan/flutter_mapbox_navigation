import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

/// 导航历史记录功能使用示例
class NavigationHistoryExample extends StatefulWidget {
  const NavigationHistoryExample({super.key});

  @override
  _NavigationHistoryExampleState createState() =>
      _NavigationHistoryExampleState();
}

class _NavigationHistoryExampleState extends State<NavigationHistoryExample> {
  List<NavigationHistory> _historyList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistoryList();
  }

  /// 加载历史记录列表
  Future<void> _loadHistoryList() async {
    setState(() {
      _isLoading = true;
    });

    try {
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

  /// 开始导航（启用历史记录）
  Future<void> _startNavigationWithHistory() async {
    final wayPoints = [
      WayPoint(
        name: "起点",
        latitude: 39.9042,
        longitude: 116.4074,
      ),
      WayPoint(
        name: "终点",
        latitude: 39.9042,
        longitude: 116.4074,
      ),
    ];

    final options = MapBoxOptions(
      enableHistoryRecording: true, // 启用历史记录
      voiceInstructionsEnabled: true,
      bannerInstructionsEnabled: true,
    );

    try {
      await MapBoxNavigation.instance.startNavigation(
        wayPoints: wayPoints,
        options: options,
      );
    } catch (e) {
      _showErrorDialog('启动导航失败: $e');
    }
  }

  /// 删除历史记录
  Future<void> _deleteHistory(String historyId) async {
    try {
      final success =
          await MapBoxNavigation.instance.deleteNavigationHistory(historyId);
      if (success) {
        _loadHistoryList(); // 重新加载列表
        _showSuccessDialog('删除成功');
      } else {
        _showErrorDialog('删除失败');
      }
    } catch (e) {
      _showErrorDialog('删除失败: $e');
    }
  }

  /// 清除所有历史记录
  Future<void> _clearAllHistory() async {
    try {
      final success =
          await MapBoxNavigation.instance.clearAllNavigationHistory();
      if (success) {
        _loadHistoryList(); // 重新加载列表
        _showSuccessDialog('清除成功');
      } else {
        _showErrorDialog('清除失败');
      }
    } catch (e) {
      _showErrorDialog('清除失败: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导航历史记录示例'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoryList,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_all') {
                _clearAllHistory();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Text('清除所有历史记录'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 开始导航按钮
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startNavigationWithHistory,
                child: const Text('开始导航（启用历史记录）'),
              ),
            ),
          ),

          // 历史记录列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _historyList.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无历史记录',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _historyList.length,
                        itemBuilder: (context, index) {
                          final history = _historyList[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.history),
                              ),
                              title: Text(history.startPointName ?? '未知起点'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('终点: ${history.endPointName ?? '未知终点'}'),
                                  Text(
                                      '开始时间: ${_formatDateTime(history.startTime)}'),
                                  if (history.distance != null)
                                    Text(
                                        '距离: ${(history.distance! / 1000).toStringAsFixed(2)} km'),
                                  if (history.duration != null)
                                    Text(
                                        '时长: ${_formatDuration(history.duration!)}'),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteHistory(history.id);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('删除'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化时长
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours小时$minutes分钟';
    } else if (minutes > 0) {
      return '$minutes分钟$remainingSeconds秒';
    } else {
      return '$remainingSeconds秒';
    }
  }
}
