import 'package:flutter/services.dart';
import 'package:flutter_mapbox_navigation/src/models/search_models.dart';

/// Mapbox搜索服务
class MapboxSearch {
  static const MethodChannel _channel =
      MethodChannel('flutter_mapbox_navigation/search');

  /// 显示地图搜索视图
  ///
  /// 打开带有搜索框的完整地图界面，支持实时自动补全
  /// 返回包含起点和终点的wayPoints数组
  static Future<List<Map<String, dynamic>>?> showSearchView() async {
    try {
      final result = await _channel.invokeMethod('showSearchView');
      if (result != null && result is List) {
        // 安全地转换每个元素为 Map<String, dynamic>
        final wayPoints = <Map<String, dynamic>>[];
        for (final item in result) {
          if (item is Map) {
            // 将 Map<Object?, Object?> 转换为 Map<String, dynamic>
            final wayPoint = <String, dynamic>{};
            item.forEach((key, value) {
              if (key is String) {
                wayPoint[key] = value;
              }
            });
            wayPoints.add(wayPoint);
          }
        }
        return wayPoints.isNotEmpty ? wayPoints : null;
      }
      return null;
    } on PlatformException catch (e) {
      throw MapboxSearchException('显示搜索视图失败: ${e.message}', e.code);
    }
  }

  /// 搜索地点
  ///
  /// [options] 搜索选项
  /// 返回搜索结果列表
  static Future<List<MapboxSearchResult>> searchPlaces(
    MapboxSearchOptions options,
  ) async {
    try {
      final results = await _channel.invokeMethod(
        'searchPlaces',
        options.toMap(),
      ) as List<dynamic>;
      return results
          .map(
            (result) =>
                MapboxSearchResult.fromMap(result as Map<String, dynamic>),
          )
          .toList();
    } on PlatformException catch (e) {
      throw MapboxSearchException('搜索地点失败: ${e.message}', e.code);
    }
  }

  /// 搜索附近地点
  ///
  /// [options] 附近搜索选项
  /// 返回附近地点列表
  static Future<List<MapboxSearchResult>> searchNearby(
    MapboxNearbySearchOptions options,
  ) async {
    try {
      final results = await _channel.invokeMethod(
        'searchNearby',
        options.toMap(),
      ) as List<dynamic>;
      return results
          .map(
            (result) =>
                MapboxSearchResult.fromMap(result as Map<String, dynamic>),
          )
          .toList();
    } on PlatformException catch (e) {
      throw MapboxSearchException('搜索附近地点失败: ${e.message}', e.code);
    }
  }

  /// 反向地理编码
  ///
  /// [coordinate] 要查询的坐标
  /// 返回该坐标的地址信息
  static Future<List<MapboxSearchResult>> reverseGeocode(
    MapboxCoordinate coordinate,
  ) async {
    try {
      final results = await _channel.invokeMethod('reverseGeocode', {
        'coordinate': coordinate.toMap(),
      }) as List<dynamic>;
      return results
          .map(
            (result) =>
                MapboxSearchResult.fromMap(result as Map<String, dynamic>),
          )
          .toList();
    } on PlatformException catch (e) {
      throw MapboxSearchException('反向地理编码失败: ${e.message}', e.code);
    }
  }

  /// 获取搜索建议
  ///
  /// [query] 搜索查询字符串
  /// [proximity] 可选的搜索中心点
  /// [limit] 最大建议数量，默认为10
  /// 返回搜索建议列表
  static Future<List<MapboxSearchSuggestion>> getSearchSuggestions({
    required String query,
    MapboxCoordinate? proximity,
    int limit = 10,
  }) async {
    try {
      final params = <String, dynamic>{
        'query': query,
        'limit': limit,
      };

      if (proximity != null) {
        params['proximity'] = proximity.toMap();
      }

      final results = await _channel.invokeMethod(
        'getSearchSuggestions',
        params,
      ) as List<dynamic>;
      return results
          .map(
            (result) =>
                MapboxSearchSuggestion.fromMap(result as Map<String, dynamic>),
          )
          .toList();
    } on PlatformException catch (e) {
      throw MapboxSearchException('获取搜索建议失败: ${e.message}', e.code);
    }
  }

  /// 根据坐标搜索附近的兴趣点
  ///
  /// [coordinate] 搜索中心坐标
  /// [radius] 搜索半径（米），默认1000米
  /// [categories] 可选的类别过滤器
  /// [limit] 最大结果数量，默认为10
  static Future<List<MapboxSearchResult>> searchPointsOfInterest({
    required MapboxCoordinate coordinate,
    double radius = 1000.0,
    List<String>? categories,
    int limit = 10,
  }) async {
    final options = MapboxNearbySearchOptions(
      coordinate: coordinate,
      radius: radius,
      categories: categories,
      limit: limit,
    );
    return searchNearby(options);
  }

  /// 搜索特定类别的地点
  ///
  /// [query] 搜索查询
  /// [category] 地点类别
  /// [proximity] 可选的搜索中心点
  /// [limit] 最大结果数量，默认为10
  static Future<List<MapboxSearchResult>> searchByCategory({
    required String query,
    required String category,
    MapboxCoordinate? proximity,
    int limit = 10,
  }) async {
    final options = MapboxSearchOptions(
      query: query,
      proximity: proximity,
      limit: limit,
      categories: [category],
    );
    return searchPlaces(options);
  }

  /// 在指定边界框内搜索
  ///
  /// [query] 搜索查询
  /// [boundingBox] 搜索边界框
  /// [limit] 最大结果数量，默认为10
  static Future<List<MapboxSearchResult>> searchInBoundingBox({
    required String query,
    required MapboxBoundingBox boundingBox,
    int limit = 10,
  }) async {
    final options = MapboxSearchOptions(
      query: query,
      boundingBox: boundingBox,
      limit: limit,
    );
    return searchPlaces(options);
  }
}

/// Mapbox搜索异常
class MapboxSearchException implements Exception {
  const MapboxSearchException(this.message, [this.code]);

  /// 错误消息
  final String message;

  /// 错误代码
  final String? code;

  @override
  String toString() {
    if (code != null) {
      return 'MapboxSearchException($code): $message';
    }
    return 'MapboxSearchException: $message';
  }
}

/// 常用的地点类别
class MapboxSearchCategories {
  static const String restaurant = 'restaurant';
  static const String hotel = 'hotel';
  static const String gasStation = 'gas_station';
  static const String hospital = 'hospital';
  static const String pharmacy = 'pharmacy';
  static const String bank = 'bank';
  static const String atm = 'atm';
  static const String school = 'school';
  static const String university = 'university';
  static const String shopping = 'shopping';
  static const String supermarket = 'supermarket';
  static const String parking = 'parking';
  static const String airport = 'airport';
  static const String trainStation = 'train_station';
  static const String busStation = 'bus_station';
  static const String museum = 'museum';
  static const String park = 'park';
  static const String gym = 'gym';
  static const String cinema = 'cinema';
  static const String cafe = 'cafe';
}
