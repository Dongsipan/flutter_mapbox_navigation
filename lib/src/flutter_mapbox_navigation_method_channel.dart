import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mapbox_navigation/src/flutter_mapbox_navigation_platform_interface.dart';
import 'package:flutter_mapbox_navigation/src/models/models.dart';

/// An implementation of [FlutterMapboxNavigationPlatform]
/// that uses method channels.
class MethodChannelFlutterMapboxNavigation
    extends FlutterMapboxNavigationPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_mapbox_navigation');

  /// The event channel used to interact with the native platform.
  @visibleForTesting
  final eventChannel = const EventChannel('flutter_mapbox_navigation/events');

  late StreamSubscription<RouteEvent> _routeEventSubscription;
  ValueSetter<RouteEvent>? _onRouteEvent;

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<double?> getDistanceRemaining() async {
    final distance =
        await methodChannel.invokeMethod<double?>('getDistanceRemaining');
    return distance;
  }

  @override
  Future<double?> getDurationRemaining() async {
    final duration =
        await methodChannel.invokeMethod<double?>('getDurationRemaining');
    return duration;
  }

  @override
  Future<bool?> startFreeDrive(MapBoxOptions options) async {
    _routeEventSubscription = routeEventsListener!.listen(_onProgressData);
    final args = options.toMap();
    final result = await methodChannel.invokeMethod('startFreeDrive', args);
    if (result is bool) return result;
    log(result.toString());
    return false;
  }

  @override
  Future<bool?> startNavigation(
    List<WayPoint> wayPoints,
    MapBoxOptions options,
  ) async {
    assert(wayPoints.length > 1, 'Error: WayPoints must be at least 2');
    if (Platform.isIOS && wayPoints.length > 3) {
      assert(options.mode != MapBoxNavigationMode.drivingWithTraffic, '''
            Error: Cannot use drivingWithTraffic Mode when you have more than 3 Stops
          ''');
    }

    final pointList = _getPointListFromWayPoints(wayPoints);
    var i = 0;
    final wayPointMap = {for (final e in pointList) i++: e};

    final args = options.toMap();
    args['wayPoints'] = wayPointMap;

    _routeEventSubscription = routeEventsListener!.listen(_onProgressData);
    final result = await methodChannel.invokeMethod('startNavigation', args);
    if (result is bool) return result;
    log(result.toString());
    return false;
  }

  @override
  Future<dynamic> addWayPoints({required List<WayPoint> wayPoints}) async {
    assert(wayPoints.isNotEmpty, 'Error: WayPoints must be at least 1');
    final pointList = _getPointListFromWayPoints(wayPoints);
    var i = 0;
    final wayPointMap = {for (final e in pointList) i++: e};
    final args = <String, dynamic>{};
    args['wayPoints'] = wayPointMap;
    await methodChannel.invokeMethod('addWayPoints', args);
  }

  @override
  Future<bool?> finishNavigation() async {
    final success = await methodChannel.invokeMethod<bool?>('finishNavigation');
    return success;
  }

  /// Will download the navigation engine and the user's region
  /// to allow offline routing
  @override
  Future<bool?> enableOfflineRouting() async {
    final success =
        await methodChannel.invokeMethod<bool?>('enableOfflineRouting');
    return success;
  }

  @override
  Future<dynamic> registerRouteEventListener(
    ValueSetter<RouteEvent> listener,
  ) async {
    _onRouteEvent = listener;
  }

  @override
  Future<List<NavigationHistory>> getNavigationHistoryList() async {
    try {
      log('Calling getNavigationHistoryList method');
      final result = await methodChannel
          .invokeMethod<List<dynamic>>('getNavigationHistoryList');
      log('Received result from native: $result');

      if (result != null) {
        log('Result is not null, processing ${result.length} items');
        final historyList = result.map(
          (item) {
            log('Processing item: $item');
            try {
              // 安全地转换 Map<Object?, Object?> 到 Map<String, dynamic>
              final itemMap = Map<String, dynamic>.from(item as Map);
              log('Converted item map: $itemMap');
              final history = NavigationHistory.fromMap(itemMap);
              log('Successfully created NavigationHistory: $history');
              return history;
            } catch (e, stackTrace) {
              log('Error creating NavigationHistory from item: $item');
              log('Error: $e');
              log('StackTrace: $stackTrace');
              rethrow;
            }
          },
        ).toList();
        log('Successfully created ${historyList.length} NavigationHistory objects');
        return historyList;
      }
      log('Result is null, returning empty list');
      return [];
    } catch (e) {
      log('Error getting navigation history list: $e');
      return [];
    }
  }

  @override
  Future<bool> deleteNavigationHistory(String historyId) async {
    try {
      final result =
          await methodChannel.invokeMethod<bool>('deleteNavigationHistory', {
        'historyId': historyId,
      });
      return result ?? false;
    } catch (e) {
      log('Error deleting navigation history: $e');
      return false;
    }
  }

  @override
  Future<bool> clearAllNavigationHistory() async {
    try {
      final result =
          await methodChannel.invokeMethod<bool>('clearAllNavigationHistory');
      return result ?? false;
    } catch (e) {
      log('Error clearing all navigation history: $e');
      return false;
    }
  }

  @override
  Future<bool> startHistoryReplay({
    required String historyFilePath,
    bool enableReplayUI = true,
  }) async {
    try {
      log('Starting history replay with file: $historyFilePath');
      final result = await methodChannel.invokeMethod<bool>(
        'startHistoryReplay',
        {
          'historyFilePath': historyFilePath,
          'enableReplayUI': enableReplayUI,
        },
      );
      return result ?? false;
    } catch (e) {
      log('Error starting history replay: $e');
      return false;
    }
  }

  @override
  Future<String?> generateHistoryCover({
    required String historyFilePath,
    String? historyId,
  }) async {
    try {
      final result = await methodChannel.invokeMethod<String>(
        'generateHistoryCover',
        {
          'historyFilePath': historyFilePath,
          'historyId': historyId,
        },
      );
      return result;
    } catch (e) {
      log('Error generating history cover: $e');
      return null;
    }
  }

  @override
  Future<NavigationHistoryEvents> getNavigationHistoryEvents(
    String historyId,
  ) async {
    // 参数验证
    if (historyId.isEmpty) {
      throw ArgumentError('historyId cannot be empty');
    }

    try {
      log('Calling getNavigationHistoryEvents with historyId: $historyId');
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getNavigationHistoryEvents',
        {'historyId': historyId},
      );

      if (result == null) {
        throw Exception('Failed to get navigation history events: null result');
      }

      log('Received result from native: $result');
      // 安全地转换 Map<dynamic, dynamic> 到 Map<String, dynamic>
      final resultMap = Map<String, dynamic>.from(result);
      return NavigationHistoryEvents.fromMap(resultMap);
    } on PlatformException catch (e) {
      log('Platform error getting navigation history events: ${e.code} - ${e.message}');
      throw Exception(
        'Failed to get navigation history events: ${e.message ?? e.code}',
      );
    } catch (e) {
      log('Error getting navigation history events: $e');
      rethrow;
    }
  }

  /// Events Handling
  Stream<RouteEvent>? get routeEventsListener {
    return eventChannel.receiveBroadcastStream().map((dynamic event) {
      if (event == null) {
        // 如果事件为空，返回一个默认的事件
        return RouteEvent(
          eventType: MapBoxEvent.map_ready,
          data: 'null event received',
        );
      }
      return _parseRouteEvent(event as String);
    });
  }

  void _onProgressData(RouteEvent event) {
    if (_onRouteEvent != null) _onRouteEvent?.call(event);
    switch (event.eventType) {
      case MapBoxEvent.navigation_finished:
        _routeEventSubscription.cancel();
        break;
      // ignore: no_default_cases
      default:
        break;
    }
  }

  RouteEvent _parseRouteEvent(String jsonString) {
    try {
      if (jsonString.isEmpty) {
        return RouteEvent(
          eventType: MapBoxEvent.map_ready,
          data: 'empty json string',
        );
      }

      final map = json.decode(jsonString);
      if (map == null) {
        return RouteEvent(
          eventType: MapBoxEvent.map_ready,
          data: 'null json data',
        );
      }

      // 直接使用 RouteEvent.fromJson 来解析，它会根据 eventType 正确处理不同类型的事件
      return RouteEvent.fromJson(map as Map<String, dynamic>);
    } catch (e) {
      // 如果解析失败，返回一个错误事件
      debugPrint('Error parsing route event: $e, jsonString: $jsonString');
      return RouteEvent(
        eventType: MapBoxEvent.map_ready,
        data: 'parse error: $e',
      );
    }
  }

  List<Map<String, Object?>> _getPointListFromWayPoints(
    List<WayPoint> wayPoints,
  ) {
    final pointList = <Map<String, Object?>>[];

    for (var i = 0; i < wayPoints.length; i++) {
      final wayPoint = wayPoints[i];
      assert(wayPoint.name != null, 'Error: waypoints need name');
      assert(wayPoint.latitude != null, 'Error: waypoints need latitude');
      assert(wayPoint.longitude != null, 'Error: waypoints need longitude');

      final pointMap = <String, dynamic>{
        'Order': i,
        'Name': wayPoint.name,
        'Latitude': wayPoint.latitude,
        'Longitude': wayPoint.longitude,
        'IsSilent': wayPoint.isSilent,
      };
      pointList.add(pointMap);
    }
    return pointList;
  }
}
