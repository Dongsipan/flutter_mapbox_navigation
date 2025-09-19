import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

/// 导航历史记录功能测试页面
class NavigationHistoryTest extends StatefulWidget {
  @override
  _NavigationHistoryTestState createState() => _NavigationHistoryTestState();
}

class _NavigationHistoryTestState extends State<NavigationHistoryTest> {
  List<NavigationHistory> _historyList = [];
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadHistoryList();
  }

  /// 加载历史记录列表
  Future<void> _loadHistoryList() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在加载历史记录...';
    });

    try {
      final historyList = await MapBoxNavigation.instance.getNavigationHistoryList();
      setState(() {
        _historyList = historyList;
        _isLoading = false;
        _statusMessage = '加载完成，共 ${historyList.length} 条记录';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '加载失败: $e';
      });
    }
  }

  /// 测试启用历史记录的导航
  Future<void> _testNavigationWithHistory() async {
    setState(() {
      _statusMessage = '正在启动导航（启用历史记录）...';
    });

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
      simulateRoute: true, // 使用模拟路线进行测试
    );

    try {
      final success = await MapBoxNavigation.instance.startNavigation(
        wayPoints: wayPoints,
        options: options,
      );
      
      if (success == true) {
        setState(() {
          _statusMessage = '导航已启动，历史记录功能已启用';
        });
      } else {
        setState(() {
          _statusMessage = '导航启动失败';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '导航启动失败: $e';
      });
    }
  }

  /// 测试不启用历史记录的导航
  Future<void> _testNavigationWithoutHistory() async {
    setState(() {
      _statusMessage = '正在启动导航（不启用历史记录）...';
    });

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
      enableHistoryRecording: false, // 不启用历史记录
      voiceInstructionsEnabled: true,
      bannerInstructionsEnabled: true,
      simulateRoute: true, // 使用模拟路线进行测试
    );

    try {
      final success = await MapBoxNavigation.instance.startNavigation(
        wayPoints: wayPoints,
        options: options,
      );
      
      if (success == true) {
        setState(() {
          _statusMessage = '导航已启动，历史记录功能已禁用';
        });
      } else {
        setState(() {
          _statusMessage = '导航启动失败';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '导航启动失败: $e';
      });
    }
  }

  /// 删除历史记录
  Future<void> _deleteHistory(String historyId) async {
    setState(() {
      _statusMessage = '正在删除历史记录...';
    });

    try {
      final success = await MapBoxNavigation.instance.deleteNavigationHistory(historyId);
      if (success) {
        _loadHistoryList(); // 重新加载列表
        setState(() {
          _statusMessage = '删除成功';
        });
      } else {
        setState(() {
          _statusMessage = '删除失败';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '删除失败: $e';
      });
    }
  }

  /// 清除所有历史记录
  Future<void> _clearAllHistory() async {
    setState(() {
      _statusMessage = '正在清除所有历史记录...';
    });

    try {
      final success = await MapBoxNavigation.instance.clearAllNavigationHistory();
      if (success) {
        _loadHistoryList(); // 重新加载列表
        setState(() {
          _statusMessage = '清除成功';
        });
      } else {
        setState(() {
          _statusMessage = '清除失败';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '清除失败: $e';
      });
    }
  }

  /// 停止导航
  Future<void> _stopNavigation() async {
    try {
      await MapBoxNavigation.instance.finishNavigation();
      setState(() {
        _statusMessage = '导航已停止';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '停止导航失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('导航历史记录测试'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadHistoryList,
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态信息
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Text(
              _statusMessage,
              style: TextStyle(fontSize: 14),
            ),
          ),
          
          // 测试按钮
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testNavigationWithHistory,
                        child: Text('测试导航（启用历史记录）'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testNavigationWithoutHistory,
                        child: Text('测试导航（禁用历史记录）'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _stopNavigation,
                        child: Text('停止导航'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _clearAllHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: Text('清除所有历史'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 历史记录列表
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _historyList.isEmpty
                    ? Center(
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
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Icon(Icons.history),
                              ),
                              title: Text(history.startPointName ?? '未知起点'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('终点: ${history.endPointName ?? '未知终点'}'),
                                  Text('开始时间: ${_formatDateTime(history.startTime)}'),
                                  if (history.distance != null)
                                    Text('距离: ${(history.distance! / 1000).toStringAsFixed(2)} km'),
                                  if (history.duration != null)
                                    Text('时长: ${_formatDuration(history.duration!)}'),
                                  Text('文件路径: ${history.historyFilePath}'),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteHistory(history.id);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
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
      return '${hours}小时${minutes}分钟';
    } else if (minutes > 0) {
      return '${minutes}分钟${remainingSeconds}秒';
    } else {
      return '${remainingSeconds}秒';
    }
  }
}
