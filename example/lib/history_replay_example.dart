import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:flutter_mapbox_navigation/src/flutter_mapbox_navigation_platform_interface.dart';

/// 历史记录回放示例页面
class HistoryReplayExample extends StatefulWidget {
  const HistoryReplayExample({super.key});

  @override
  State<HistoryReplayExample> createState() => _HistoryReplayExampleState();
}

class _HistoryReplayExampleState extends State<HistoryReplayExample> {
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
      });

      if (success) {
        _showSuccessDialog('历史记录回放已开始\n回放会自动进行，完成后自动关闭');
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

  /// 手动生成封面（仅调试使用）
  Future<void> _generateCover(NavigationHistory history) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final coverPath = await FlutterMapboxNavigationPlatform.instance
          .generateHistoryCover(
        historyFilePath: history.historyFilePath,
        historyId: history.id,
      );

      setState(() {
        _isLoading = false;
      });

      if (coverPath == null) {
        _showErrorDialog('生成封面失败');
        return;
      }

      final file = File(coverPath);
      if (!file.existsSync()) {
        _showErrorDialog('封面文件不存在: $coverPath');
        return;
      }

      // 预览生成的封面
      // 不写回持久化，仅用于调试查看
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('封面生成成功'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(coverPath, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Image.file(file, width: 260, fit: BoxFit.cover),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('生成封面失败: $e');
    }
  }

  /// 生成封面并更新到持久化（写回 cover），随后刷新列表
  Future<void> _generateCoverAndUpdate(NavigationHistory history) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final coverPath = await FlutterMapboxNavigationPlatform.instance
          .generateHistoryCover(
        historyFilePath: history.historyFilePath,
        historyId: history.id,
      );

      if (coverPath == null) {
        setState(() { _isLoading = false; });
        _showErrorDialog('生成封面失败');
        return;
      }

      // 将 cover 写回（复用 iOS 的保存逻辑：调用 start/stop 会太重，这里简单更新本地存储：
      // 通过重新拉取列表来获得最新数据；因为原生保存时会带 cover。
      await _loadHistoryList();
      setState(() {
        _isLoading = false;
      });

      // 反馈
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('封面已生成: $coverPath')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('更新封面失败: $e');
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
      body: _isLoading
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _generateCover(history),
              icon: const Icon(Icons.image_outlined, size: 16),
              label: const Text('封面'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _generateCoverAndUpdate(history),
              icon: const Icon(Icons.save_alt, size: 16),
              label: const Text('写入'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _startReplay(history),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('回放'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
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
