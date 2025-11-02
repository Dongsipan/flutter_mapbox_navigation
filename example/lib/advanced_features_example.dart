import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'dart:math';
import 'dart:convert';

// 路由事件日志类
class RouteEventLog {
  final DateTime timestamp;
  final MapBoxEvent eventType;
  final String eventName;
  final dynamic data; // 改为 dynamic 类型以匹配 RouteEvent.data

  RouteEventLog({
    required this.timestamp,
    required this.eventType,
    required this.eventName,
    this.data,
  });

  String get formattedTime => '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}';
}

class AdvancedFeaturesExample extends StatefulWidget {
  const AdvancedFeaturesExample({super.key});

  @override
  State<AdvancedFeaturesExample> createState() =>
      _AdvancedFeaturesExampleState();
}

class _AdvancedFeaturesExampleState extends State<AdvancedFeaturesExample> {
  final List<WayPoint> _currentWayPoints = [];
  final List<List<WayPoint>> _routeHistory = [];
  final List<RouteEventLog> _eventLogs = [];
  MapBoxNavigationViewController? _controller;

  bool _isNavigating = false;
  bool _simulateRoute = true;
  String? _statusMessage;
  double? _totalDistance;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
  }

  void _setupEventListeners() {
    // 监听导航事件
    MapBoxNavigation.instance.registerRouteEventListener(_onRouteEvent);
  }

  Future<void> _onRouteEvent(RouteEvent event) async {
    // 记录事件日志
    final eventLog = RouteEventLog(
      timestamp: DateTime.now(),
      eventType: event.eventType ?? MapBoxEvent.map_ready,
      eventName: _getEventName(event.eventType ?? MapBoxEvent.map_ready),
      data: event.data,
    );

    // 打印日志
    debugPrint('🚗 导航事件: ${eventLog.eventName} - ${eventLog.formattedTime}');
    if (event.data != null && _hasValidData(event.data)) {
      // 为不同类型的数据提供更有用的日志信息
      if (event.data is RouteProgressEvent) {
        final progress = event.data as RouteProgressEvent;
        debugPrint(
            '📊 导航进度: 剩余${((progress.distance ?? 0) / 1000).toStringAsFixed(1)}km, '
            '预计${((progress.duration ?? 0) / 60).toStringAsFixed(0)}分钟, '
            '指令: ${progress.currentStepInstruction ?? "无"}');
      } else {
        debugPrint('📊 事件数据: ${event.data}');
      }
    }

    setState(() {
      _eventLogs.insert(0, eventLog); // 最新事件在顶部
      // 限制日志数量，避免内存过多占用
      if (_eventLogs.length > 100) {
        _eventLogs.removeRange(100, _eventLogs.length);
      }
    });

    // 处理特定事件的状态更新
    switch (event.eventType) {
      case MapBoxEvent.navigation_running:
        setState(() {
          _isNavigating = true;
          _statusMessage = "导航进行中...";
        });
        break;
      case MapBoxEvent.navigation_finished:
      case MapBoxEvent.navigation_cancelled:
        setState(() {
          _isNavigating = false;
          _statusMessage = "导航已结束";
        });
        break;
      case MapBoxEvent.on_arrival:
        setState(() {
          _statusMessage = "已到达目的地";
        });
        break;
      case MapBoxEvent.route_building:
        setState(() {
          _statusMessage = "正在规划路线...";
        });
        break;
      case MapBoxEvent.route_built:
        setState(() {
          _statusMessage = "路线规划完成";
        });
        break;
      case MapBoxEvent.progress_change:
        // 可以在这里更新进度信息
        if (event.data != null && event.data is RouteProgressEvent) {
          final progressEvent = event.data as RouteProgressEvent;
          final distance = progressEvent.distance;
          final duration = progressEvent.duration;
          if (distance != null && duration != null) {
            setState(() {
              _statusMessage =
                  "剩余距离: ${(distance / 1000).toStringAsFixed(1)}km, "
                  "预计时间: ${(duration / 60).toStringAsFixed(0)}分钟";
            });
          }
        }
        break;
      default:
        break;
    }
  }

  // 获取事件名称的辅助方法
  String _getEventName(MapBoxEvent eventType) {
    switch (eventType) {
      case MapBoxEvent.map_ready:
        return '地图准备就绪';
      case MapBoxEvent.navigation_running:
        return '导航开始';
      case MapBoxEvent.navigation_finished:
        return '导航完成';
      case MapBoxEvent.navigation_cancelled:
        return '导航取消';
      case MapBoxEvent.on_arrival:
        return '到达目的地';
      case MapBoxEvent.route_building:
        return '路线规划中';
      case MapBoxEvent.route_built:
        return '路线规划完成';
      case MapBoxEvent.route_build_failed:
        return '路线规划失败';
      case MapBoxEvent.route_build_cancelled:
        return '路线规划取消';
      case MapBoxEvent.route_build_no_routes_found:
        return '未找到路线';
      case MapBoxEvent.progress_change:
        return '导航进度更新';
      case MapBoxEvent.user_off_route:
        return '偏离路线';
      case MapBoxEvent.milestone_event:
        return '里程碑事件';
      case MapBoxEvent.faster_route_found:
        return '发现更快路线';
      case MapBoxEvent.speech_announcement:
        return '语音播报';
      case MapBoxEvent.banner_instruction:
        return '横幅指令';
      case MapBoxEvent.failed_to_reroute:
        return '重新规划失败';
      case MapBoxEvent.reroute_along:
        return '重新规划路线';
      case MapBoxEvent.on_map_tap:
        return '地图点击';
      case MapBoxEvent.history_recording_started:
        return '历史记录开始';
      case MapBoxEvent.history_recording_stopped:
        return '历史记录停止';
      case MapBoxEvent.history_recording_error:
        return '历史记录错误';
      default:
        return '未知事件 (${eventType.toString()})';
    }
  }

  // 获取事件颜色的辅助方法
  Color _getEventColor(MapBoxEvent eventType) {
    switch (eventType) {
      case MapBoxEvent.navigation_running:
        return Colors.green;
      case MapBoxEvent.navigation_finished:
        return Colors.blue;
      case MapBoxEvent.navigation_cancelled:
        return Colors.red;
      case MapBoxEvent.on_arrival:
        return Colors.purple;
      case MapBoxEvent.route_building:
        return Colors.orange;
      case MapBoxEvent.route_built:
        return Colors.teal;
      case MapBoxEvent.route_build_failed:
        return Colors.red;
      case MapBoxEvent.progress_change:
        return Colors.lightBlue;
      case MapBoxEvent.user_off_route:
        return Colors.amber;
      case MapBoxEvent.faster_route_found:
        return Colors.indigo;
      case MapBoxEvent.speech_announcement:
        return Colors.deepPurple;
      case MapBoxEvent.banner_instruction:
        return Colors.cyan;
      case MapBoxEvent.history_recording_started:
        return Colors.green[700]!;
      case MapBoxEvent.history_recording_stopped:
        return Colors.grey;
      case MapBoxEvent.history_recording_error:
        return Colors.red[700]!;
      default:
        return Colors.grey;
    }
  }

  // 获取事件图标的辅助方法
  IconData _getEventIcon(MapBoxEvent eventType) {
    switch (eventType) {
      case MapBoxEvent.navigation_running:
        return Icons.play_arrow;
      case MapBoxEvent.navigation_finished:
        return Icons.check_circle;
      case MapBoxEvent.navigation_cancelled:
        return Icons.cancel;
      case MapBoxEvent.on_arrival:
        return Icons.location_on;
      case MapBoxEvent.route_building:
        return Icons.route;
      case MapBoxEvent.route_built:
        return Icons.done;
      case MapBoxEvent.route_build_failed:
        return Icons.error;
      case MapBoxEvent.progress_change:
        return Icons.trending_up;
      case MapBoxEvent.user_off_route:
        return Icons.warning;
      case MapBoxEvent.faster_route_found:
        return Icons.flash_on;
      case MapBoxEvent.speech_announcement:
        return Icons.volume_up;
      case MapBoxEvent.banner_instruction:
        return Icons.info;
      case MapBoxEvent.history_recording_started:
        return Icons.fiber_manual_record;
      case MapBoxEvent.history_recording_stopped:
        return Icons.stop;
      case MapBoxEvent.history_recording_error:
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }

  // 显示事件详情的方法
  void _showEventDetails(RouteEventLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getEventIcon(log.eventType),
              color: _getEventColor(log.eventType),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                log.eventName,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('时间: ${log.formattedTime}'),
            const SizedBox(height: 8),
            Text('事件类型: ${log.eventType.toString()}'),
            if (log.data != null) ...[
              const SizedBox(height: 8),
              const Text('事件数据:'),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatEventData(log.data),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 格式化事件数据的辅助方法
  String _formatEventData(dynamic data) {
    if (data == null) return 'null';

    try {
      // 如果是 RouteProgressEvent 对象
      if (data is RouteProgressEvent) {
        final buffer = StringBuffer();
        buffer.writeln('📍 导航进度信息:');
        buffer.writeln(
            '- 剩余距离: ${((data.distance ?? 0) / 1000).toStringAsFixed(1)} km');
        buffer.writeln(
            '- 预计时间: ${((data.duration ?? 0) / 60).toStringAsFixed(0)} 分钟');
        buffer.writeln(
            '- 已行驶: ${((data.distanceTraveled ?? 0) / 1000).toStringAsFixed(1)} km');
        buffer.writeln('- 当前指令: ${data.currentStepInstruction ?? "无"}');
        buffer.writeln('- 是否到达: ${data.arrived == true ? "是" : "否"}');
        if (data.legIndex != null) {
          buffer.writeln('- 路段索引: ${data.legIndex}');
        }
        if (data.stepIndex != null) {
          buffer.writeln('- 步骤索引: ${data.stepIndex}');
        }
        return buffer.toString().trim();
      }

      // 如果是 WayPoint 对象
      if (data is WayPoint) {
        return '路径点:\n'
            '- 名称: ${data.name ?? 'N/A'}\n'
            '- 纬度: ${data.latitude?.toStringAsFixed(6) ?? 'N/A'}\n'
            '- 经度: ${data.longitude?.toStringAsFixed(6) ?? 'N/A'}';
      }

      // 如果是字符串，尝试解析为 JSON
      if (data is String) {
        if (data.isEmpty) return '(空字符串)';

        // 尝试解析 JSON
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map) {
            return _formatMapData(decoded);
          }
          return data;
        } catch (e) {
          // 不是 JSON，直接返回字符串
          return data;
        }
      }

      // 如果是 Map
      if (data is Map) {
        return _formatMapData(data);
      }

      // 其他类型，直接转换为字符串
      return data.toString();
    } catch (e) {
      return '数据格式化错误: $e';
    }
  }

  // 格式化 Map 数据
  String _formatMapData(Map data) {
    final buffer = StringBuffer();
    data.forEach((key, value) {
      buffer.writeln('- $key: $value');
    });
    return buffer.toString().trim();
  }

  // 检查数据是否有效（不为空且有内容）
  bool _hasValidData(dynamic data) {
    if (data == null) return false;

    // 如果是字符串，检查是否非空
    if (data is String) {
      return data.isNotEmpty;
    }

    // 如果是 RouteProgressEvent，总是认为有效（因为它包含导航信息）
    if (data is RouteProgressEvent) {
      return true;
    }

    // 如果是 WayPoint，检查是否有坐标
    if (data is WayPoint) {
      return data.latitude != null && data.longitude != null;
    }

    // 如果是 Map，检查是否非空
    if (data is Map) {
      return data.isNotEmpty;
    }

    // 如果是 List，检查是否非空
    if (data is List) {
      return data.isNotEmpty;
    }

    // 其他类型，总是认为有效
    return true;
  }

  // 添加预设的示例路径点
  void _addSampleWayPoints() {
    setState(() {
      _currentWayPoints.clear();
      _currentWayPoints.addAll([
        WayPoint(name: "北京站", latitude: 39.9021, longitude: 116.4272),
        WayPoint(name: "天安门广场", latitude: 39.9042, longitude: 116.4074),
        WayPoint(name: "故宫博物院", latitude: 39.9163, longitude: 116.3972),
        WayPoint(name: "景山公园", latitude: 39.9239, longitude: 116.3979),
        WayPoint(name: "北海公园", latitude: 39.9252, longitude: 116.3883),
      ]);
      _calculateTotalDistance();
    });
  }

  // 生成随机路径点
  void _generateRandomWayPoints() {
    final random = Random();
    const centerLat = 39.9042; // 天安门为中心
    const centerLon = 116.4074;
    const radiusKm = 5.0; // 5公里半径
    const count = 5;

    final randomPoints = <WayPoint>[];
    for (int i = 0; i < count; i++) {
      // 生成随机角度和距离
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * radiusKm;

      // 转换为经纬度偏移
      final latOffset = distance * cos(angle) / 111.0; // 大约111km每度
      final lonOffset =
          distance * sin(angle) / (111.0 * cos(centerLat * pi / 180));

      randomPoints.add(WayPoint(
        name: "随机点${i + 1}",
        latitude: centerLat + latOffset,
        longitude: centerLon + lonOffset,
      ));
    }

    setState(() {
      _currentWayPoints.clear();
      _currentWayPoints.addAll(randomPoints);
      _calculateTotalDistance();
      _statusMessage = "已生成${randomPoints.length}个随机路径点";
    });
  }

  // 优化当前路线
  void _optimizeCurrentRoute() {
    if (_currentWayPoints.length < 3) {
      setState(() {
        _statusMessage = "需要至少3个路径点才能优化";
      });
      return;
    }

    final optimizedPoints = _optimizeRoute(_currentWayPoints);
    setState(() {
      _currentWayPoints.clear();
      _currentWayPoints.addAll(optimizedPoints);
      _calculateTotalDistance();
      _statusMessage = "路线已优化，总距离: ${_formatDistance(_totalDistance ?? 0)}";
    });
  }

  // 简单的路线优化算法（最近邻算法）
  List<WayPoint> _optimizeRoute(List<WayPoint> wayPoints) {
    if (wayPoints.length < 2) return wayPoints;

    final optimizedPoints = <WayPoint>[];
    final remainingPoints = List<WayPoint>.from(wayPoints);

    // 从第一个点开始
    optimizedPoints.add(remainingPoints.removeAt(0));

    while (remainingPoints.isNotEmpty) {
      final currentPoint = optimizedPoints.last;
      double minDistance = double.infinity;
      int nearestIndex = 0;

      for (int i = 0; i < remainingPoints.length; i++) {
        final distance = _calculateDistance(
          currentPoint.latitude!,
          currentPoint.longitude!,
          remainingPoints[i].latitude!,
          remainingPoints[i].longitude!,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestIndex = i;
        }
      }

      optimizedPoints.add(remainingPoints.removeAt(nearestIndex));
    }

    return optimizedPoints;
  }

  // 计算总距离
  void _calculateTotalDistance() {
    if (_currentWayPoints.length < 2) {
      _totalDistance = 0;
      return;
    }

    double total = 0;
    for (int i = 0; i < _currentWayPoints.length - 1; i++) {
      total += _calculateDistance(
        _currentWayPoints[i].latitude!,
        _currentWayPoints[i].longitude!,
        _currentWayPoints[i + 1].latitude!,
        _currentWayPoints[i + 1].longitude!,
      );
    }
    _totalDistance = total;
  }

  // 计算两点间距离（Haversine公式）
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // 地球半径（米）

    final double dLat = (lat2 - lat1) * pi / 180;
    final double dLon = (lon2 - lon1) * pi / 180;

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // 格式化距离显示
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return "${meters.toStringAsFixed(0)}米";
    } else {
      return "${(meters / 1000).toStringAsFixed(2)}公里";
    }
  }

  // 计算指定路线的总距离
  double _calculateTotalDistanceForRoute(List<WayPoint> wayPoints) {
    if (wayPoints.length < 2) return 0;

    double total = 0;
    for (int i = 0; i < wayPoints.length - 1; i++) {
      total += _calculateDistance(
        wayPoints[i].latitude!,
        wayPoints[i].longitude!,
        wayPoints[i + 1].latitude!,
        wayPoints[i + 1].longitude!,
      );
    }
    return total;
  }

  // 验证路径点
  bool _validateWayPoints(List<WayPoint> wayPoints) {
    if (wayPoints.length < 2) {
      setState(() {
        _statusMessage = "至少需要2个路径点才能开始导航";
      });
      return false;
    }

    for (int i = 0; i < wayPoints.length; i++) {
      final wayPoint = wayPoints[i];
      if (wayPoint.latitude == null || wayPoint.longitude == null) {
        setState(() {
          _statusMessage = "路径点${i + 1}的坐标无效";
        });
        return false;
      }
    }

    return true;
  }

  // 保存当前路线
  void _saveCurrentRoute() {
    if (_currentWayPoints.isEmpty) {
      setState(() {
        _statusMessage = "没有路线可保存";
      });
      return;
    }

    // 检查是否已经存在相同的路线
    bool isDuplicate = false;
    for (var existingRoute in _routeHistory) {
      if (existingRoute.length == _currentWayPoints.length) {
        bool same = true;
        for (int i = 0; i < existingRoute.length; i++) {
          if (existingRoute[i].latitude != _currentWayPoints[i].latitude ||
              existingRoute[i].longitude != _currentWayPoints[i].longitude) {
            same = false;
            break;
          }
        }
        if (same) {
          isDuplicate = true;
          break;
        }
      }
    }

    if (isDuplicate) {
      setState(() {
        _statusMessage = "此路线已存在于历史记录中";
      });
      return;
    }

    _routeHistory.add(List<WayPoint>.from(_currentWayPoints));
    setState(() {
      _statusMessage =
          "路线已保存到历史记录（${_currentWayPoints.length}个点，共${_routeHistory.length}条历史）";
    });

    // 添加调试信息
    print('路线已保存，历史记录数量: ${_routeHistory.length}');

    // 显示成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('路线已保存！当前共有${_routeHistory.length}条历史记录'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: '查看',
          textColor: Colors.white,
          onPressed: _showRouteHistory,
        ),
      ),
    );
  }

  // 显示路线历史
  void _showRouteHistory() {
    final history = _routeHistory;

    // 添加调试信息
    print('显示历史记录，当前历史数量: ${history.length}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('路线历史记录 (${history.length}条)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: history.isEmpty
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('暂无历史记录'),
                    SizedBox(height: 8),
                    Text(
                      '先添加一些路径点，然后点击"保存路线"',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final route = history[index];
                    final distance = _calculateTotalDistanceForRoute(route);

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text('${index + 1}'),
                        ),
                        title: Text('路线 ${index + 1}'),
                        subtitle: Text(
                            '${route.length}个路径点 - ${_formatDistance(distance)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore,
                                  color: Colors.green),
                              tooltip: '恢复此路线',
                              onPressed: () {
                                setState(() {
                                  _currentWayPoints.clear();
                                  _currentWayPoints.addAll(route);
                                  _calculateTotalDistance();
                                  _statusMessage = "已恢复路线 ${index + 1}";
                                });
                                Navigator.of(context).pop();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: '删除此路线',
                              onPressed: () {
                                setState(() {
                                  _routeHistory.removeAt(index);
                                });
                                Navigator.of(context).pop();
                                _showRouteHistory(); // 重新显示对话框
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
              setState(() {
                _routeHistory.clear();
              });
              Navigator.of(context).pop();
            },
            child: const Text('清除历史'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 搜索并导航
  Future<void> _searchAndNavigate() async {
    try {
      setState(() {
        _statusMessage = "正在打开搜索界面...";
      });

      // 显示搜索界面并获取wayPoints数组
      final wayPointsData = await MapboxSearch.showSearchView();

      if (wayPointsData != null && wayPointsData.isNotEmpty) {
        // 将搜索结果转换为WayPoint对象
        final List<WayPoint> wayPoints = wayPointsData.map((data) {
          return WayPoint(
            name: data['name'] as String? ?? '未知位置',
            latitude: (data['latitude'] as num?)?.toDouble(),
            longitude: (data['longitude'] as num?)?.toDouble(),
            isSilent: data['isSilent'] as bool? ?? false,
          );
        }).toList();

        // 更新当前路径点
        setState(() {
          _currentWayPoints.clear();
          _currentWayPoints.addAll(wayPoints);
          _calculateTotalDistance();
          _statusMessage = "已添加${wayPoints.length}个路径点，准备开始导航";
        });

        // 如果有足够的路径点，直接开始导航
        if (wayPoints.length >= 2) {
          await _startNavigation();
        } else {
          setState(() {
            _statusMessage = "需要至少2个路径点才能开始导航";
          });
        }
      } else {
        setState(() {
          _statusMessage = "未选择任何位置";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "搜索导航失败: $e";
      });
      debugPrint('搜索导航错误: $e');
    }
  }

  // 清除所有路径点
  void _clearWayPoints() {
    setState(() {
      _currentWayPoints.clear();
      _totalDistance = null;
      _statusMessage = "已清除所有路径点";
    });
  }

  // 清除事件日志
  void _clearEventLogs() {
    setState(() {
      _eventLogs.clear();
      _statusMessage = "已清除事件日志";
    });
  }

  // 开始导航
  Future<void> _startNavigation() async {
    if (!_validateWayPoints(_currentWayPoints)) {
      return;
    }

    try {
      final options = MapBoxOptions(
          mode: MapBoxNavigationMode.cycling,
          simulateRoute: _simulateRoute,
          language: "zh-CN",
          units: VoiceUnits.metric,
          voiceInstructionsEnabled: true,
          bannerInstructionsEnabled: true,
          enableHistoryRecording: true);

      await MapBoxNavigation.instance.startNavigation(
        wayPoints: _currentWayPoints,
        options: options,
      );
    } catch (e) {
      setState(() {
        _statusMessage = "导航启动失败: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('高级功能示例'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // 状态面板
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前路径点: ${_currentWayPoints.length}个',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_totalDistance != null)
                  Text('总距离: ${_formatDistance(_totalDistance!)}'),
                if (_statusMessage != null) Text('状态: $_statusMessage'),
              ],
            ),
          ),

          // 功能按钮组
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 第一行按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _addSampleWayPoints,
                      child: const Text('示例路线'),
                    ),
                    ElevatedButton(
                      onPressed: _generateRandomWayPoints,
                      child: const Text('随机路线'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 第二行按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _currentWayPoints.length >= 3
                          ? _optimizeCurrentRoute
                          : null,
                      child: const Text('优化路线'),
                    ),
                    ElevatedButton(
                      onPressed: _currentWayPoints.isNotEmpty
                          ? _saveCurrentRoute
                          : null,
                      child: const Text('保存路线'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 模拟导航开关
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('开启模拟导航'),
                    Switch(
                      value: _simulateRoute,
                      onChanged: (value) {
                        setState(() {
                          _simulateRoute = value;
                        });
                      },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 第三行按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _showRouteHistory,
                      child: const Text('历史记录'),
                    ),
                    ElevatedButton(
                      onPressed: !_isNavigating ? _searchAndNavigate : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('搜索导航'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 第四行按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _currentWayPoints.length >= 2 && !_isNavigating
                          ? _startNavigation
                          : null,
                      child: const Text('开始导航'),
                    ),
                    ElevatedButton(
                      onPressed:
                          _currentWayPoints.isNotEmpty ? _clearWayPoints : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('清除路线'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 路径点列表和事件日志 - 上下排列
          Expanded(
            child: Column(
              children: [
                // 路径点列表 (上半部分)
                Expanded(
                  flex: 1,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
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
                            '当前路径点',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _currentWayPoints.isEmpty
                              ? const Center(
                                  child: Text('暂无路径点\n点击上方按钮添加路线'),
                                )
                              : ListView.builder(
                                  itemCount: _currentWayPoints.length,
                                  itemBuilder: (context, index) {
                                    final wayPoint = _currentWayPoints[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: index == 0
                                            ? Colors.green
                                            : index ==
                                                    _currentWayPoints.length - 1
                                                ? Colors.red
                                                : Colors.blue,
                                        child: Text('${index + 1}'),
                                      ),
                                      title: Text(
                                          wayPoint.name ?? '路径点 ${index + 1}'),
                                      subtitle: Text(
                                          '${wayPoint.latitude?.toStringAsFixed(4) ?? 'N/A'}, ${wayPoint.longitude?.toStringAsFixed(4) ?? 'N/A'}'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () {
                                          setState(() {
                                            _currentWayPoints.removeAt(index);
                                            _calculateTotalDistance();
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8), // 间距

                // 事件日志列表 (下半部分)
                Expanded(
                  flex: 1,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
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
                            color: Colors.green,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '导航事件日志',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${_eventLogs.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _clearEventLogs,
                                    child: const Icon(
                                      Icons.clear_all,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _eventLogs.isEmpty
                              ? const Center(
                                  child: Text('暂无事件日志\n开始导航后会显示事件'),
                                )
                              : ListView.builder(
                                  itemCount: _eventLogs.length,
                                  itemBuilder: (context, index) {
                                    final log = _eventLogs[index];
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 12,
                                        backgroundColor:
                                            _getEventColor(log.eventType),
                                        child: Icon(
                                          _getEventIcon(log.eventType),
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: Text(
                                        log.eventName,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      subtitle: Text(
                                        log.formattedTime,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      onTap: () => _showEventDetails(log),
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

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
