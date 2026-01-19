// ignore_for_file: use_setters_to_change_properties

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mapbox_navigation/src/flutter_mapbox_navigation_platform_interface.dart';
import 'package:flutter_mapbox_navigation/src/models/models.dart';

/// Turn-By-Turn Navigation Provider
class MapBoxNavigation {
  static final MapBoxNavigation _instance = MapBoxNavigation();

  /// get current instance of this class
  static MapBoxNavigation get instance => _instance;

  MapBoxOptions _defaultOptions = MapBoxOptions(
    zoom: 15,
    tilt: 0,
    bearing: 0,
    enableRefresh: false,
    alternatives: true,
    voiceInstructionsEnabled: true,
    bannerInstructionsEnabled: true,
    allowsUTurnAtWayPoints: true,
    mode: MapBoxNavigationMode.cycling,
    units: VoiceUnits.metric,
    simulateRoute: false,
    animateBuildRoute: true,
    longPressDestinationEnabled: true,
    language: 'en',
  );

  /// setter to set default options
  void setDefaultOptions(MapBoxOptions options) {
    _defaultOptions = options;
  }

  /// Getter to retriev default options
  MapBoxOptions getDefaultOptions() {
    return _defaultOptions;
  }

  ///Current Device OS Version
  Future<String?> getPlatformVersion() {
    return FlutterMapboxNavigationPlatform.instance.getPlatformVersion();
  }

  ///Total distance remaining in meters along route.
  Future<double?> getDistanceRemaining() {
    return FlutterMapboxNavigationPlatform.instance.getDistanceRemaining();
  }

  ///Total seconds remaining on all legs.
  Future<double?> getDurationRemaining() {
    return FlutterMapboxNavigationPlatform.instance.getDurationRemaining();
  }

  ///Adds waypoints or stops to an on-going navigation
  ///
  /// [wayPoints] must not be null and have at least 1 item. The way points will
  /// be inserted after the currently navigating waypoint
  /// in the existing navigation
  Future<dynamic> addWayPoints({required List<WayPoint> wayPoints}) async {
    return FlutterMapboxNavigationPlatform.instance
        .addWayPoints(wayPoints: wayPoints);
  }

  /// Free-drive mode is a unique Mapbox Navigation SDK feature that allows
  /// drivers to navigate without a set destination.
  /// This mode is sometimes referred to as passive navigation.
  /// Begins to generate Route Progress
  ///
  Future<bool?> startFreeDrive({MapBoxOptions? options}) async {
    options ??= _defaultOptions;
    return FlutterMapboxNavigationPlatform.instance.startFreeDrive(options);
  }

  ///Show the Navigation View and Begins Direction Routing
  ///
  /// [wayPoints] must not be null and have at least 2 items. A collection of
  /// [WayPoint](longitude, latitude and name). Must be at least 2 or
  /// at most 25. Cannot use drivingWithTraffic mode if more than 3-waypoints.
  /// [options] options used to generate the route and used while navigating
  /// Begins to generate Route Progress
  ///
  Future<bool?> startNavigation({
    required List<WayPoint> wayPoints,
    MapBoxOptions? options,
  }) async {
    options ??= _defaultOptions;
    return FlutterMapboxNavigationPlatform.instance
        .startNavigation(wayPoints, options);
  }

  ///Ends Navigation and Closes the Navigation View
  Future<bool?> finishNavigation() async {
    return FlutterMapboxNavigationPlatform.instance.finishNavigation();
  }

  /// Will download the navigation engine and the user's region
  /// to allow offline routing
  Future<bool?> enableOfflineRouting() async {
    return FlutterMapboxNavigationPlatform.instance.enableOfflineRouting();
  }

  /// Event listener for RouteEvents
  Future<dynamic> registerRouteEventListener(
    ValueSetter<RouteEvent> listener,
  ) async {
    return FlutterMapboxNavigationPlatform.instance
        .registerRouteEventListener(listener);
  }

  /// 获取所有导航历史记录列表
  Future<List<NavigationHistory>> getNavigationHistoryList() async {
    return FlutterMapboxNavigationPlatform.instance.getNavigationHistoryList();
  }

  /// 获取导航历史记录的详细事件数据
  /// [historyId] 历史记录ID
  /// 返回包含所有事件、原始位置和初始路线的详细数据
  /// 如果历史记录不存在或解析失败，将抛出异常
  Future<NavigationHistoryEvents> getNavigationHistoryEvents({
    required String historyId,
  }) async {
    return FlutterMapboxNavigationPlatform.instance.getNavigationHistoryEvents(
      historyId,
    );
  }

  /// 删除指定的导航历史记录
  Future<bool> deleteNavigationHistory(String historyId) async {
    return FlutterMapboxNavigationPlatform.instance
        .deleteNavigationHistory(historyId);
  }

  /// 清除所有导航历史记录
  Future<bool> clearAllNavigationHistory() async {
    return FlutterMapboxNavigationPlatform.instance.clearAllNavigationHistory();
  }

  /// 开始历史记录回放
  /// [historyFilePath] 历史记录文件路径
  /// [enableReplayUI] 是否启用回放UI界面，默认为true
  Future<bool> startHistoryReplay({
    required String historyFilePath,
    bool enableReplayUI = true,
  }) async {
    return FlutterMapboxNavigationPlatform.instance.startHistoryReplay(
      historyFilePath: historyFilePath,
      enableReplayUI: enableReplayUI,
    );
  }

  /// 手动生成历史封面（仅调试用，不写入记录）
  Future<String?> generateHistoryCover({
    required String historyFilePath,
    String? historyId,
  }) async {
    return FlutterMapboxNavigationPlatform.instance.generateHistoryCover(
      historyFilePath: historyFilePath,
      historyId: historyId,
    );
  }
}
