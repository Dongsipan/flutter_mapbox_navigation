import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

class HistoryTestPage extends StatefulWidget {
  const HistoryTestPage({super.key});

  @override
  State<HistoryTestPage> createState() => _HistoryTestPageState();
}

class _HistoryTestPageState extends State<HistoryTestPage> {
  List<NavigationHistory> _navigationHistoryList = [];
  String? _statusMessage;
  bool _isLoading = false;
  bool _enableHistoryRecording = true; // 默认启用历史记录

  @override
  void initState() {
    super.initState();
    _loadNavigationHistoryList();
    _setupNavigationListener();
  }

  /// 设置导航事件监听器
  void _setupNavigationListener() {
    MapBoxNavigation.instance.registerRouteEventListener((event) {
      print('Navigation Event: ${event.eventType}');
      setState(() {
        _statusMessage = '导航事件: ${event.eventType}';
      });

      // 监听历史记录相关事件
      switch (event.eventType) {
        case MapBoxEvent.history_recording_started:
          setState(() {
            _statusMessage = '历史记录开始记录: ${event.data}';
          });
          break;
        case MapBoxEvent.history_recording_stopped:
          setState(() {
            _statusMessage = '历史记录停止记录: ${event.data}';
          });
          // 延迟重新加载历史记录
          Future.delayed(const Duration(seconds: 2), () {
            _loadNavigationHistoryList();
          });
          break;
        case MapBoxEvent.history_recording_error:
          setState(() {
            _statusMessage = '历史记录错误: ${event.data}';
          });
          break;
        case MapBoxEvent.navigation_finished:
        case MapBoxEvent.navigation_cancelled:
        case MapBoxEvent.on_arrival:
          // 导航结束后延迟重新加载历史记录
          Future.delayed(const Duration(seconds: 3), () {
            print('Reloading navigation history after navigation ended');
            _loadNavigationHistoryList();
          });
          break;
        default:
          break;
      }
    });
  }

  /// 加载导航历史记录列表
  Future<void> _loadNavigationHistoryList() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在加载历史记录...';
    });

    try {
      final historyList =
          await MapBoxNavigation.instance.getNavigationHistoryList();
      setState(() {
        _navigationHistoryList = historyList;
        _statusMessage = '已加载 ${historyList.length} 条历史记录';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '加载历史记录失败: $e';
        _isLoading = false;
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
        latitude: 37.7749, // 旧金山
        longitude: -122.4194,
      ),
      WayPoint(
        name: "终点",
        latitude: 37.7849, // 旧金山附近
        longitude: -122.4094,
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

  /// 测试禁用历史记录的导航
  Future<void> _testNavigationWithoutHistory() async {
    setState(() {
      _statusMessage = '正在启动导航（禁用历史记录）...';
    });

    final wayPoints = [
      WayPoint(
        name: "起点",
        latitude: 37.7749, // 旧金山
        longitude: -122.4194,
      ),
      WayPoint(
        name: "终点",
        latitude: 37.7849, // 旧金山附近
        longitude: -122.4094,
      ),
    ];

    final options = MapBoxOptions(
      enableHistoryRecording: false, // 禁用历史记录
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

  /// 结束当前导航
  Future<void> _finishNavigation() async {
    setState(() {
      _statusMessage = '正在结束导航...';
    });

    try {
      final success = await MapBoxNavigation.instance.finishNavigation();
      if (success == true) {
        setState(() {
          _statusMessage = '导航已结束';
        });
        // 延迟重新加载历史记录
        Future.delayed(const Duration(seconds: 2), () {
          _loadNavigationHistoryList();
        });
      } else {
        setState(() {
          _statusMessage = '结束导航失败';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '结束导航失败: $e';
      });
    }
  }

  /// 创建测试历史记录（用于测试API）
  Future<void> _createTestHistoryRecord() async {
    setState(() {
      _statusMessage = '正在创建测试历史记录...';
    });

    try {
      // 模拟一个短暂的导航来触发历史记录
      final wayPoints = [
        WayPoint(
          name: "测试起点",
          latitude: 37.7749,
          longitude: -122.4194,
        ),
        WayPoint(
          name: "测试终点",
          latitude: 37.7849,
          longitude: -122.4094,
        ),
      ];

      final options = MapBoxOptions(
        enableHistoryRecording: true,
        voiceInstructionsEnabled: false,
        bannerInstructionsEnabled: false,
        simulateRoute: true,
      );

      // 启动导航
      await MapBoxNavigation.instance.startNavigation(
        wayPoints: wayPoints,
        options: options,
      );

      setState(() {
        _statusMessage = '测试导航已启动，请等待几秒后手动结束导航';
      });

      // 5秒后自动结束导航
      Future.delayed(const Duration(seconds: 5), () async {
        await _finishNavigation();
      });
    } catch (e) {
      setState(() {
        _statusMessage = '创建测试历史记录失败: $e';
      });
    }
  }

  /// 获取并显示历史事件详情
  Future<void> _showHistoryEvents(String historyId) async {
    setState(() {
      _statusMessage = '正在加载历史事件...';
    });

    try {
      final events = await MapBoxNavigation.instance.getNavigationHistoryEvents(
        historyId: historyId,
      );

      setState(() {
        _statusMessage = '已加载 ${events.events.length} 个事件';
      });

      // 显示事件详情对话框
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('历史事件详情'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('历史记录 ID: ${events.historyId}',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('总事件数: ${events.events.length}'),
                    Text('原始位置点数: ${events.rawLocations.length}'),
                    SizedBox(height: 16),
                    Text('事件列表:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    ...events.events.map((event) {
                      if (event.eventType == 'location_update') {
                        final locationData = LocationData.fromMap(event.data);
                        return Card(
                          child: ListTile(
                            leading:
                                Icon(Icons.location_on, color: Colors.blue),
                            title: Text('位置更新'),
                            subtitle: Text(
                              '坐标: ${locationData.latitude.toStringAsFixed(4)}, ${locationData.longitude.toStringAsFixed(4)}\n'
                              '速度: ${locationData.speed?.toStringAsFixed(2) ?? "N/A"} m/s\n'
                              '时间: ${locationData.timestamp}',
                            ),
                          ),
                        );
                      } else if (event.eventType == 'route_assignment') {
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.route, color: Colors.green),
                            title: Text('路线分配'),
                            subtitle: Text('路线数据: ${event.data}'),
                          ),
                        );
                      } else if (event.eventType == 'user_pushed') {
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.push_pin, color: Colors.orange),
                            title: Text('自定义事件'),
                            subtitle: Text('数据: ${event.data}'),
                          ),
                        );
                      } else {
                        return Card(
                          child: ListTile(
                            leading:
                                Icon(Icons.help_outline, color: Colors.grey),
                            title: Text('未知事件: ${event.eventType}'),
                          ),
                        );
                      }
                    }).toList(),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('关闭'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = '加载历史事件失败: $e';
      });
    }
  }

  /// 删除指定的导航历史记录
  Future<void> _deleteNavigationHistory(String historyId) async {
    setState(() {
      _statusMessage = '正在删除历史记录...';
    });

    try {
      final success =
          await MapBoxNavigation.instance.deleteNavigationHistory(historyId);
      if (success) {
        await _loadNavigationHistoryList(); // 重新加载列表
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

  /// 清除所有导航历史记录
  Future<void> _clearAllNavigationHistory() async {
    setState(() {
      _statusMessage = '正在清除所有历史记录...';
    });

    try {
      final success =
          await MapBoxNavigation.instance.clearAllNavigationHistory();
      if (success) {
        await _loadNavigationHistoryList(); // 重新加载列表
        setState(() {
          _statusMessage = '已清除所有历史记录';
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

  // 显示导航历史记录
  void _showNavigationHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('导航历史记录 (${_navigationHistoryList.length}条)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _navigationHistoryList.isEmpty
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('暂无导航历史记录'),
                    SizedBox(height: 8),
                    Text(
                      '启动导航（启用历史记录）后会自动保存',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: _navigationHistoryList.length,
                  itemBuilder: (context, index) {
                    final history = _navigationHistoryList[index];

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text('${index + 1}'),
                        ),
                        title: Text('导航记录 ${index + 1}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('开始时间: ${_formatDateTime(history.startTime)}'),
                            if (history.startPointName != null &&
                                history.startPointName!.isNotEmpty)
                              Text('起点: ${history.startPointName}'),
                            if (history.endPointName != null &&
                                history.endPointName!.isNotEmpty)
                              Text('终点: ${history.endPointName}'),
                            if (history.duration != null)
                              Text('时长: ${history.duration}秒'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline,
                                  color: Colors.blue),
                              tooltip: '查看事件详情',
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showHistoryEvents(history.id);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: '删除此记录',
                              onPressed: () {
                                Navigator.of(context).pop();
                                _deleteNavigationHistory(history.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllNavigationHistory();
            },
            child: const Text('清除全部'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导航历史记录测试'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNavigationHistoryList,
            tooltip: '刷新历史记录',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 状态显示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '导航历史记录: ${_navigationHistoryList.length}条',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (_statusMessage != null) Text('状态: $_statusMessage'),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 历史记录开关
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '启用历史记录',
                      style: TextStyle(fontSize: 16),
                    ),
                    Switch(
                      value: _enableHistoryRecording,
                      onChanged: (value) {
                        setState(() {
                          _enableHistoryRecording = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 操作按钮
            ElevatedButton.icon(
              onPressed: _testNavigationWithHistory,
              icon: const Icon(Icons.navigation),
              label: const Text('启动导航（启用历史记录）'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _testNavigationWithoutHistory,
              icon: const Icon(Icons.navigation),
              label: const Text('启动导航（禁用历史记录）'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _createTestHistoryRecord,
              icon: const Icon(Icons.science),
              label: const Text('创建测试历史记录'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _finishNavigation,
              icon: const Icon(Icons.stop),
              label: const Text('结束当前导航'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _showNavigationHistory,
              icon: const Icon(Icons.history),
              label: const Text('查看历史记录'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _navigationHistoryList.isNotEmpty
                  ? _clearAllNavigationHistory
                  : null,
              icon: const Icon(Icons.clear_all),
              label: const Text('清除所有历史记录'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // 历史记录列表预览
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '历史记录预览',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _navigationHistoryList.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history,
                                      size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('暂无历史记录'),
                                  Text(
                                    '启动导航（启用历史记录）后会自动保存',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _navigationHistoryList.length,
                              itemBuilder: (context, index) {
                                final history = _navigationHistoryList[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    child: Text('${index + 1}'),
                                  ),
                                  title: Text('导航记录 ${index + 1}'),
                                  subtitle:
                                      Text(_formatDateTime(history.startTime)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _deleteNavigationHistory(history.id),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
