import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

/// 历史记录回放示例页面
class HistoryReplayExample extends StatefulWidget {
  const HistoryReplayExample({super.key});

  @override
  State<HistoryReplayExample> createState() => _HistoryReplayExampleState();
}

class _HistoryReplayExampleState extends State<HistoryReplayExample> {
  List<NavigationHistory> _historyList = [];
  bool _isLoading = false;
  bool _isReplaying = false;
  String? _currentReplayFile;

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

  /// 开始回放历史记录
  Future<void> _startReplay(NavigationHistory history) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await MapBoxNavigation.instance.startHistoryReplay(
        historyFilePath: history.historyFilePath,
        enableReplayUI: true,
      );

      setState(() {
        _isLoading = false;
        _isReplaying = success;
        _currentReplayFile = success ? history.historyFilePath : null;
      });

      if (success) {
        _showSuccessDialog('历史记录回放已开始');
      } else {
        _showErrorDialog('启动历史记录回放失败');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('启动历史记录回放失败: $e');
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
        title: const Text('历史记录回放'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoryList,
          ),
        ],
      ),
      body: Column(
        children: [
          // 回放控制面板
          if (_isReplaying) _buildReplayControlPanel(),

          // 历史记录列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _historyList.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无历史记录\n请先进行一次导航以生成历史记录',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _historyList.length,
                        itemBuilder: (context, index) {
                          final history = _historyList[index];
                          return _buildHistoryItem(history);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// 构建回放控制面板
  Widget _buildReplayControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_filled, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                '正在回放',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '文件: ${_currentReplayFile?.split('/').last ?? '未知'}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            '回放会自动进行，完成后自动关闭',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// 构建历史记录项
  Widget _buildHistoryItem(NavigationHistory history) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.history, color: Colors.white),
        ),
        title: Text(
          '${history.startPointName} → ${history.endPointName}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('开始时间: ${_formatDateTime(history.startTime)}'),
            if (history.duration != null)
              Text('持续时间: ${_formatDuration(history.duration!)}'),
            Text('导航模式: ${history.navigationMode ?? '未知'}'),
          ],
        ),
        trailing: ElevatedButton.icon(
          onPressed: _isReplaying ? null : () => _startReplay(history),
          icon: const Icon(Icons.play_arrow, size: 16),
          label: const Text('回放'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        isThreeLine: true,
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
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes分$remainingSeconds秒';
  }
}
