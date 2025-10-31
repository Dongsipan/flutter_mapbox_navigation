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

      final coverPath =
          await FlutterMapboxNavigationPlatform.instance.generateHistoryCover(
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

      final coverPath =
          await FlutterMapboxNavigationPlatform.instance.generateHistoryCover(
        historyFilePath: history.historyFilePath,
        historyId: history.id,
      );

      if (coverPath == null) {
        setState(() {
          _isLoading = false;
        });
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
    // iOS 端已经处理了沙箱路径问题，这里直接使用即可
    final hasCover = history.cover != null && 
        history.cover!.isNotEmpty && 
        File(history.cover!).existsSync();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图片区域
          if (hasCover)
            Stack(
              children: [
                Image.file(
                  File(history.cover!),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[300],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text('封面加载失败', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    );
                  },
                ),
                // 渐变遮罩，使底部文字更清晰
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
        ),
                    ),
                  ),
                ),
                // 封面上的路线信息
                Positioned(
                  bottom: 8,
                  left: 12,
                  right: 12,
                  child: Text(
          '${history.startPointName} → ${history.endPointName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
        ),
              ],
            ),

          // 信息和操作区域
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                // 如果没有封面，显示标题
                if (!hasCover)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.blue,
                          radius: 20,
                          child: Icon(Icons.history,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${history.startPointName} → ${history.endPointName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 详细信息
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _buildInfoChip(
                      icon: Icons.access_time,
                      label: _formatDateTime(history.startTime),
                    ),
            if (history.duration != null)
                      _buildInfoChip(
                        icon: Icons.timer,
                        label: _formatDuration(history.duration!),
                      ),
                    _buildInfoChip(
                      icon: Icons.navigation,
                      label: history.navigationMode ?? '未知',
                    ),
          ],
        ),

                const SizedBox(height: 12),

                // 操作按钮（使用 Wrap 防止溢出）
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!hasCover) ...[
                      OutlinedButton.icon(
                        onPressed:
                            _isLoading ? null : () => _generateCover(history),
                        icon: const Icon(Icons.image_outlined, size: 16),
                        label: const Text('生成封面'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                    if (hasCover) ...[
                      OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _generateCoverAndUpdate(history),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('更新封面'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                    if (!hasCover) ...[
                      OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _generateCoverAndUpdate(history),
                        icon: const Icon(Icons.save_alt, size: 16),
                        label: const Text('生成并保存'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                    ElevatedButton.icon(
                      onPressed:
                          _isLoading ? null : () => _startReplay(history),
          icon: const Icon(Icons.play_arrow, size: 16),
          label: const Text('回放'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
          ),
        ),
        ],
      ),
    );
  }

  /// 构建信息芯片
  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
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
