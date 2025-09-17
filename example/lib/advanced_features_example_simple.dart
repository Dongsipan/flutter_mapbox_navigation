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
  MapBoxNavigationViewController? _controller;
  
  bool _isNavigating = false;
  String? _statusMessage;
  double? _totalDistance;

  @override
  void initState() {
    super.initState();
    
    // 添加一些示例路径点
    _currentWayPoints.addAll([
      WayPoint(name: "天安门", latitude: 39.9042, longitude: 116.4074),
      WayPoint(name: "故宫", latitude: 39.9163, longitude: 116.3972),
    ]);
    
    _calculateTotalDistance();
    
    // 注册导航事件监听器
    MapBoxNavigation.instance.registerRouteEventListener(_onRouteEvent);
  }

  Future<void> _onRouteEvent(RouteEvent event) async {
    switch (event.eventType) {
      case MapBoxEvent.navigation_running:
        setState(() {
          _isNavigating = true;
          _statusMessage = "导航进行中";
        });
        break;
      case MapBoxEvent.navigation_cancelled:
        setState(() {
          _isNavigating = false;
          _statusMessage = "导航已取消";
        });
        break;
      case MapBoxEvent.navigation_finished:
        setState(() {
          _isNavigating = false;
          _statusMessage = "导航已完成";
        });
        break;
      default:
        break;
    }
  }

  // 生成随机路径点
  void _generateRandomWayPoints() {
    final random = Random();
    final centerLat = 39.9042; // 天安门为中心
    final centerLon = 116.4074;
    final radiusKm = 5.0; // 5公里半径
    
    final randomPoints = <WayPoint>[];
    for (int i = 0; i < 3; i++) {
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

  // 简单的路线优化（按距离排序）
  void _optimizeRoute() {
    if (_currentWayPoints.length < 2) {
      setState(() {
        _statusMessage = "至少需要2个路径点才能优化路线";
      });
      return;
    }

    // 简单的最近邻算法
    final optimizedPoints = <WayPoint>[];
    final remainingPoints = List<WayPoint>.from(_currentWayPoints);
    
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
    
    setState(() {
      _currentWayPoints.clear();
      _currentWayPoints.addAll(optimizedPoints);
      _calculateTotalDistance();
      _statusMessage = "路线已优化，总距离: ${_formatDistance(_totalDistance ?? 0)}";
    });
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

  // 保存路线到历史记录（模拟）
  void _saveRouteToHistory() {
    if (_currentWayPoints.isEmpty) {
      setState(() {
        _statusMessage = "没有路径点可保存";
      });
      return;
    }
    
    // 这里可以实现实际的保存逻辑
    setState(() {
      _statusMessage = "路线已保存到历史记录（${_currentWayPoints.length}个点）";
    });
  }

  // 开始导航
  Future<void> _startNavigation() async {
    if (_currentWayPoints.isEmpty) {
      setState(() {
        _statusMessage = "请先添加路径点";
      });
      return;
    }

    try {
      final options = MapBoxOptions(
        initialLatitude: _currentWayPoints.first.latitude!,
        initialLongitude: _currentWayPoints.first.longitude!,
        language: "zh-Hans",
        zoom: 15.0,
        voiceInstructionsEnabled: true,
        bannerInstructionsEnabled: true,
        allowsUTurnAtWayPoints: true,
        mode: MapBoxNavigationMode.drivingWithTraffic,
        units: VoiceUnits.metric,
        simulateRoute: true, // 模拟模式，便于测试
      );

      await MapBoxNavigation.instance.startNavigation(
        wayPoints: _currentWayPoints,
        options: options,
      );
    } catch (e) {
      setState(() {
        _statusMessage = "启动导航失败: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('高级功能示例'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 状态信息卡片
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '路线状态',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('路径点数量: ${_currentWayPoints.length}'),
                  if (_totalDistance != null)
                    Text('总距离: ${_formatDistance(_totalDistance!)}'),
                  if (_statusMessage != null)
                    Text(
                      '状态: $_statusMessage',
                      style: TextStyle(
                        color: _isNavigating ? Colors.green : Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // 功能按钮
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildFeatureCard(
                  '生成随机点',
                  Icons.shuffle,
                  Colors.purple,
                  _generateRandomWayPoints,
                ),
                _buildFeatureCard(
                  '优化路线',
                  Icons.route,
                  Colors.orange,
                  _optimizeRoute,
                ),
                _buildFeatureCard(
                  '保存路线',
                  Icons.save,
                  Colors.green,
                  _saveRouteToHistory,
                ),
                _buildFeatureCard(
                  '开始导航',
                  Icons.navigation,
                  Colors.blue,
                  _startNavigation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
