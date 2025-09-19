import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'dart:math';

class AdvancedFeaturesExample extends StatefulWidget {
  const AdvancedFeaturesExample({super.key});

  @override
  State<AdvancedFeaturesExample> createState() => _AdvancedFeaturesExampleState();
}

class _AdvancedFeaturesExampleState extends State<AdvancedFeaturesExample> {
  final List<WayPoint> _currentWayPoints = [];
  final List<List<WayPoint>> _routeHistory = [];
  MapBoxNavigationViewController? _controller;

  bool _isNavigating = false;
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
      default:
        break;
    }
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
      final lonOffset = distance * sin(angle) / (111.0 * cos(centerLat * pi / 180));

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
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // 地球半径（米）

    final double dLat = (lat2 - lat1) * pi / 180;
    final double dLon = (lon2 - lon1) * pi / 180;

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);

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
      _statusMessage = "路线已保存到历史记录（${_currentWayPoints.length}个点，共${_routeHistory.length}条历史）";
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
                        '${route.length}个路径点 - ${_formatDistance(distance)}'
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore, color: Colors.green),
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

  // 开始导航
  Future<void> _startNavigation() async {
    if (!_validateWayPoints(_currentWayPoints)) {
      return;
    }

    try {
      final options = MapBoxOptions(
        mode: MapBoxNavigationMode.drivingWithTraffic,
        simulateRoute: true,
        language: "zh-CN",
        units: VoiceUnits.metric,
        voiceInstructionsEnabled: true,
        bannerInstructionsEnabled: true,
      );

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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_totalDistance != null)
                  Text('总距离: ${_formatDistance(_totalDistance!)}'),
                if (_statusMessage != null)
                  Text('状态: $_statusMessage'),
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
                      onPressed: _currentWayPoints.length >= 3 ? _optimizeCurrentRoute : null,
                      child: const Text('优化路线'),
                    ),
                    ElevatedButton(
                      onPressed: _currentWayPoints.isNotEmpty ? _saveCurrentRoute : null,
                      child: const Text('保存路线'),
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
                      onPressed: _currentWayPoints.length >= 2 && !_isNavigating 
                        ? _startNavigation 
                        : null,
                      child: const Text('开始导航'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 路径点列表
          Expanded(
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
                                  : index == _currentWayPoints.length - 1
                                    ? Colors.red
                                    : Colors.blue,
                                child: Text('${index + 1}'),
                              ),
                              title: Text(wayPoint.name ?? '路径点 ${index + 1}'),
                              subtitle: Text(
                                '${wayPoint.latitude?.toStringAsFixed(4) ?? 'N/A'}, ${wayPoint.longitude?.toStringAsFixed(4) ?? 'N/A'}'
                              ),
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
