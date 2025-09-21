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
  double _replaySpeed = 1.0;
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

  /// 停止回放
  Future<void> _stopReplay() async {
    try {
      final success = await MapBoxNavigation.instance.stopHistoryReplay();
      setState(() {
        _isReplaying = !success;
        _currentReplayFile = success ? null : _currentReplayFile;
      });

      if (success) {
        _showSuccessDialog('历史记录回放已停止');
      } else {
        _showErrorDialog('停止历史记录回放失败');
      }
    } catch (e) {
      _showErrorDialog('停止历史记录回放失败: $e');
    }
  }

  /// 暂停回放
  Future<void> _pauseReplay() async {
    try {
      final success = await MapBoxNavigation.instance.pauseHistoryReplay();
      if (success) {
        _showSuccessDialog('历史记录回放已暂停');
      } else {
        _showErrorDialog('暂停历史记录回放失败');
      }
    } catch (e) {
      _showErrorDialog('暂停历史记录回放失败: $e');
    }
  }

  /// 恢复回放
  Future<void> _resumeReplay() async {
    try {
      final success = await MapBoxNavigation.instance.resumeHistoryReplay();
      if (success) {
        _showSuccessDialog('历史记录回放已恢复');
      } else {
        _showErrorDialog('恢复历史记录回放失败');
      }
    } catch (e) {
      _showErrorDialog('恢复历史记录回放失败: $e');
    }
  }

  /// 设置回放速度
  Future<void> _setReplaySpeed(double speed) async {
    try {
      final success = await MapBoxNavigation.instance.setHistoryReplaySpeed(speed);
      setState(() {
        _replaySpeed = speed;
      });

      if (success) {
        _showSuccessDialog('回放速度已设置为 ${speed}x');
      } else {
        _showErrorDialog('设置回放速度失败');
      }
    } catch (e) {
      _showErrorDialog('设置回放速度失败: $e');
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
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.stop, color: Colors.red),
                onPressed: _stopReplay,
                tooltip: '停止回放',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '文件: ${_currentReplayFile?.split('/').last ?? '未知'}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          // 回放控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _pauseReplay,
                icon: const Icon(Icons.pause, size: 16),
                label: const Text('暂停'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _resumeReplay,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('恢复'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 速度控制
          Row(
            children: [
              const Text('回放速度: '),
              Text(
                '${_replaySpeed}x',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Slider(
                  value: _replaySpeed,
                  min: 0.5,
                  max: 3.0,
                  divisions: 5,
                  label: '${_replaySpeed}x',
                  onChanged: (value) {
                    _setReplaySpeed(value);
                  },
                ),
              ),
            ],
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
    return '${minutes}分${remainingSeconds}秒';
  }
}
