import 'dart:async';
import 'dart:math';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

/// 导航功能扩展类
/// 提供额外的导航功能和工具方法
class NavigationExtensions {
  factory NavigationExtensions() => _instance;
  NavigationExtensions._internal();
  static final NavigationExtensions _instance = NavigationExtensions._internal();

  // 路线历史记录
  final List<List<WayPoint>> _routeHistory = [];
  
  // 当前路线信息
  RouteInfo? _currentRoute;
  
  // 事件流控制器
  final StreamController<NavigationExtensionEvent> _eventController = 
      StreamController<NavigationExtensionEvent>.broadcast();

  /// 获取事件流
  Stream<NavigationExtensionEvent> get eventStream => _eventController.stream;

  /// 计算两点之间的距离（米）
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // 地球半径（米）
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// 创建优化的路线
  /// 自动排序路径点以获得最短路径
  List<WayPoint> optimizeRoute(List<WayPoint> wayPoints) {
    if (wayPoints.length <= 2) return wayPoints;

    final optimized = <WayPoint>[wayPoints.first]; // 起点
    final remaining = wayPoints.sublist(1, wayPoints.length - 1);
    final destination = wayPoints.last; // 终点

    var current = wayPoints.first;
    
    while (remaining.isNotEmpty) {
      // 找到距离当前点最近的下一个点
      var nearest = remaining.first;
      var minDistance = calculateDistance(
        current.latitude!, current.longitude!,
        nearest.latitude!, nearest.longitude!,
      );

      for (final wayPoint in remaining) {
        final distance = calculateDistance(
          current.latitude!, current.longitude!,
          wayPoint.latitude!, wayPoint.longitude!,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearest = wayPoint;
        }
      }

      optimized.add(nearest);
      remaining.remove(nearest);
      current = nearest;
    }

    optimized.add(destination); // 添加终点
    return optimized;
  }

  /// 保存路线到历史记录
  void saveRouteToHistory(List<WayPoint> wayPoints) {
    _routeHistory.add(List.from(wayPoints));
    if (!_eventController.isClosed) {
      _eventController.add(NavigationExtensionEvent(
        type: NavigationExtensionEventType.routeSaved,
        data: wayPoints,
      ),);
    }
  }

  /// 获取路线历史记录
  List<List<WayPoint>> getRouteHistory() {
    return List.from(_routeHistory);
  }

  /// 清除路线历史记录
  void clearRouteHistory() {
    _routeHistory.clear();
    if (!_eventController.isClosed) {
      _eventController.add(NavigationExtensionEvent(
        type: NavigationExtensionEventType.historyCleared,
        data: null,
      ),);
    }
  }

  /// 创建圆形区域内的随机路径点
  List<WayPoint> generateRandomWayPoints({
    required double centerLat,
    required double centerLon,
    required double radiusKm,
    required int count,
  }) {
    final wayPoints = <WayPoint>[];
    final random = Random();

    for (var i = 0; i < count; i++) {
      // 在圆形区域内生成随机点
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * radiusKm * 1000; // 转换为米
      
      final deltaLat = distance * cos(angle) / 111320; // 纬度度数
      final deltaLon = distance * sin(angle) / (111320 * cos(_degreesToRadians(centerLat)));
      
      wayPoints.add(WayPoint(
        name: '随机点 ${i + 1}',
        latitude: centerLat + deltaLat,
        longitude: centerLon + deltaLon,
      ),);
    }

    return wayPoints;
  }

  /// 验证路径点是否有效
  bool validateWayPoints(List<WayPoint> wayPoints) {
    if (wayPoints.length < 2) {
      if (!_eventController.isClosed) {
        _eventController.add(NavigationExtensionEvent(
          type: NavigationExtensionEventType.validationError,
          data: '至少需要2个路径点',
        ),);
      }
      return false;
    }

    for (final wayPoint in wayPoints) {
      if (!_isValidCoordinate(wayPoint.latitude!, wayPoint.longitude!)) {
        if (!_eventController.isClosed) {
          _eventController.add(NavigationExtensionEvent(
            type: NavigationExtensionEventType.validationError,
            data: '无效的坐标: ${wayPoint.name}',
          ),);
        }
        return false;
      }
    }

    return true;
  }

  bool _isValidCoordinate(double lat, double lon) {
    return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
  }

  /// 计算路线总距离
  double calculateTotalDistance(List<WayPoint> wayPoints) {
    if (wayPoints.length < 2) return 0;

    double totalDistance = 0;
    for (var i = 0; i < wayPoints.length - 1; i++) {
      totalDistance += calculateDistance(
        wayPoints[i].latitude!,
        wayPoints[i].longitude!,
        wayPoints[i + 1].latitude!,
        wayPoints[i + 1].longitude!,
      );
    }

    return totalDistance;
  }

  /// 格式化距离显示
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} 米';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} 公里';
    }
  }

  /// 格式化时间显示
  String formatDuration(double seconds) {
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    
    if (hours > 0) {
      return '$hours小时$minutes分钟';
    } else {
      return '$minutes分钟';
    }
  }

  /// 释放资源
  void dispose() {
    _eventController.close();
  }
}

/// 路线信息类
class RouteInfo {

  RouteInfo({
    required this.wayPoints,
    required this.totalDistance,
    required this.createdAt,
    this.name,
  });
  final List<WayPoint> wayPoints;
  final double totalDistance;
  final DateTime createdAt;
  final String? name;
}

/// 扩展事件类
class NavigationExtensionEvent {

  NavigationExtensionEvent({
    required this.type,
    required this.data,
  });
  final NavigationExtensionEventType type;
  final dynamic data;
}

/// 扩展事件类型
enum NavigationExtensionEventType {
  routeSaved,
  historyCleared,
  validationError,
  routeOptimized,
}
