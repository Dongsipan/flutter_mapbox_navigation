import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import '../lib/src/extensions/navigation_extensions.dart';

void main() {
  group('NavigationExtensions Tests', () {
    late NavigationExtensions extensions;

    setUp(() {
      extensions = NavigationExtensions();
    });

    tearDown(() {
      // 不在tearDown中dispose，让每个测试自己管理
    });

    group('Distance Calculation', () {
      test('should calculate distance between two points correctly', () {
        // 北京天安门到故宫的距离（大约1.2公里）
        const lat1 = 39.9042;
        const lon1 = 116.4074;
        const lat2 = 39.9163;
        const lon2 = 116.3972;

        final distance = NavigationExtensions.calculateDistance(lat1, lon1, lat2, lon2);
        
        // 验证距离在合理范围内（1000-1700米）
        expect(distance, greaterThan(1000));
        expect(distance, lessThan(1700));
      });

      test('should return 0 for same coordinates', () {
        const lat = 39.9042;
        const lon = 116.4074;

        final distance = NavigationExtensions.calculateDistance(lat, lon, lat, lon);
        
        expect(distance, equals(0));
      });
    });

    group('Route Optimization', () {
      test('should return same route for 2 waypoints', () {
        final wayPoints = [
          WayPoint(name: "Start", latitude: 39.9042, longitude: 116.4074),
          WayPoint(name: "End", latitude: 39.9163, longitude: 116.3972),
        ];

        final optimized = extensions.optimizeRoute(wayPoints);
        
        expect(optimized.length, equals(2));
        expect(optimized[0].name, equals("Start"));
        expect(optimized[1].name, equals("End"));
      });

      test('should optimize route with multiple waypoints', () {
        final wayPoints = [
          WayPoint(name: "Start", latitude: 39.9042, longitude: 116.4074), // 天安门
          WayPoint(name: "Far", latitude: 39.9500, longitude: 116.4500),   // 远点
          WayPoint(name: "Near", latitude: 39.9100, longitude: 116.4100),  // 近点
          WayPoint(name: "End", latitude: 39.9163, longitude: 116.3972),   // 故宫
        ];

        final optimized = extensions.optimizeRoute(wayPoints);
        
        expect(optimized.length, equals(4));
        expect(optimized[0].name, equals("Start")); // 起点不变
        expect(optimized[3].name, equals("End"));   // 终点不变
        
        // 验证中间点被重新排序（近点应该在远点之前）
        final nearIndex = optimized.indexWhere((wp) => wp.name == "Near");
        final farIndex = optimized.indexWhere((wp) => wp.name == "Far");
        expect(nearIndex, lessThan(farIndex));
      });
    });

    group('Route Validation', () {
      test('should validate correct waypoints', () {
        final wayPoints = [
          WayPoint(name: "Start", latitude: 39.9042, longitude: 116.4074),
          WayPoint(name: "End", latitude: 39.9163, longitude: 116.3972),
        ];

        final isValid = extensions.validateWayPoints(wayPoints);
        
        expect(isValid, isTrue);
      });

      test('should reject single waypoint', () {
        final wayPoints = [
          WayPoint(name: "Only", latitude: 39.9042, longitude: 116.4074),
        ];

        final isValid = extensions.validateWayPoints(wayPoints);
        
        expect(isValid, isFalse);
      });

      test('should reject invalid coordinates', () {
        final wayPoints = [
          WayPoint(name: "Start", latitude: 39.9042, longitude: 116.4074),
          WayPoint(name: "Invalid", latitude: 91.0, longitude: 181.0), // 超出范围
        ];

        final isValid = extensions.validateWayPoints(wayPoints);
        
        expect(isValid, isFalse);
      });
    });

    group('Random Waypoint Generation', () {
      test('should generate correct number of waypoints', () {
        final wayPoints = extensions.generateRandomWayPoints(
          centerLat: 39.9042,
          centerLon: 116.4074,
          radiusKm: 5.0,
          count: 5,
        );

        expect(wayPoints.length, equals(5));
      });

      test('should generate waypoints within radius', () {
        const centerLat = 39.9042;
        const centerLon = 116.4074;
        const radiusKm = 1.0;

        final wayPoints = extensions.generateRandomWayPoints(
          centerLat: centerLat,
          centerLon: centerLon,
          radiusKm: radiusKm,
          count: 10,
        );

        for (final wayPoint in wayPoints) {
          final distance = NavigationExtensions.calculateDistance(
            centerLat, centerLon,
            wayPoint.latitude!, wayPoint.longitude!,
          );
          
          // 验证距离在半径范围内（加上一些容差）
          expect(distance, lessThanOrEqualTo(radiusKm * 1000 + 100));
        }
      });
    });

    group('Total Distance Calculation', () {
      test('should calculate total distance for route', () {
        final wayPoints = [
          WayPoint(name: "A", latitude: 39.9042, longitude: 116.4074),
          WayPoint(name: "B", latitude: 39.9100, longitude: 116.4100),
          WayPoint(name: "C", latitude: 39.9163, longitude: 116.3972),
        ];

        final totalDistance = extensions.calculateTotalDistance(wayPoints);
        
        expect(totalDistance, greaterThan(0));
        
        // 验证总距离等于各段距离之和
        final distanceAB = NavigationExtensions.calculateDistance(
          wayPoints[0].latitude!, wayPoints[0].longitude!,
          wayPoints[1].latitude!, wayPoints[1].longitude!,
        );
        final distanceBC = NavigationExtensions.calculateDistance(
          wayPoints[1].latitude!, wayPoints[1].longitude!,
          wayPoints[2].latitude!, wayPoints[2].longitude!,
        );
        
        expect(totalDistance, closeTo(distanceAB + distanceBC, 1.0));
      });

      test('should return 0 for single waypoint', () {
        final wayPoints = [
          WayPoint(name: "Only", latitude: 39.9042, longitude: 116.4074),
        ];

        final totalDistance = extensions.calculateTotalDistance(wayPoints);
        
        expect(totalDistance, equals(0));
      });
    });

    group('Route History', () {
      test('should save and retrieve route history', () {
        final wayPoints = [
          WayPoint(name: "Start", latitude: 39.9042, longitude: 116.4074),
          WayPoint(name: "End", latitude: 39.9163, longitude: 116.3972),
        ];

        extensions.saveRouteToHistory(wayPoints);
        
        final history = extensions.getRouteHistory();
        
        expect(history.length, equals(1));
        expect(history[0].length, equals(2));
        expect(history[0][0].name, equals("Start"));
        expect(history[0][1].name, equals("End"));
      });

      test('should clear route history', () {
        // 先清除之前测试的历史记录
        extensions.clearRouteHistory();

        final wayPoints = [
          WayPoint(name: "Start", latitude: 39.9042, longitude: 116.4074),
          WayPoint(name: "End", latitude: 39.9163, longitude: 116.3972),
        ];

        extensions.saveRouteToHistory(wayPoints);
        expect(extensions.getRouteHistory().length, equals(1));

        extensions.clearRouteHistory();
        expect(extensions.getRouteHistory().length, equals(0));
      });
    });

    group('Formatting', () {
      test('should format distance correctly', () {
        expect(extensions.formatDistance(500), equals("500 米"));
        expect(extensions.formatDistance(1000), equals("1.0 公里"));
        expect(extensions.formatDistance(1500), equals("1.5 公里"));
        expect(extensions.formatDistance(12345), equals("12.3 公里"));
      });

      test('should format duration correctly', () {
        expect(extensions.formatDuration(30), equals("0分钟"));
        expect(extensions.formatDuration(60), equals("1分钟"));
        expect(extensions.formatDuration(90), equals("1分钟"));
        expect(extensions.formatDuration(3600), equals("1小时0分钟"));
        expect(extensions.formatDuration(3660), equals("1小时1分钟"));
        expect(extensions.formatDuration(7320), equals("2小时2分钟"));
      });
    });

    group('Event Stream', () {
      test('should emit events when saving route', () async {
        final wayPoints = [
          WayPoint(name: "Start", latitude: 39.9042, longitude: 116.4074),
          WayPoint(name: "End", latitude: 39.9163, longitude: 116.3972),
        ];

        // 监听事件
        NavigationExtensionEvent? receivedEvent;
        final subscription = extensions.eventStream.listen((event) {
          receivedEvent = event;
        });

        // 触发事件
        extensions.saveRouteToHistory(wayPoints);

        // 等待事件处理
        await Future.delayed(const Duration(milliseconds: 10));

        expect(receivedEvent, isNotNull);
        expect(receivedEvent!.type, equals(NavigationExtensionEventType.routeSaved));
        expect(receivedEvent!.data, equals(wayPoints));

        await subscription.cancel();
      });
    });
  });
}
