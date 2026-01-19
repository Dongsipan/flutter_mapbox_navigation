import 'package:flutter_mapbox_navigation/src/models/history_event_data.dart';
import 'package:flutter_mapbox_navigation/src/models/location_data.dart';

/// 导航历史事件数据模型
/// 包含历史记录的所有事件、原始位置数据和初始路线信息
class NavigationHistoryEvents {
  NavigationHistoryEvents({
    required this.historyId,
    required this.events,
    required this.rawLocations,
    this.initialRoute,
  });

  /// 从 Map 创建 NavigationHistoryEvents 对象
  factory NavigationHistoryEvents.fromMap(Map<String, dynamic> map) {
    // 解析事件列表
    final eventsList = map['events'] as List<dynamic>?;
    final events = eventsList
            ?.map(
              (e) => HistoryEventData.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList() ??
        [];

    // 解析原始位置数据
    final locationsList = map['rawLocations'] as List<dynamic>?;
    final rawLocations = locationsList
            ?.map(
              (e) => LocationData.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList() ??
        [];

    return NavigationHistoryEvents(
      historyId: map['historyId'] as String,
      events: events,
      rawLocations: rawLocations,
      initialRoute: map['initialRoute'] != null
          ? Map<String, dynamic>.from(map['initialRoute'] as Map)
          : null,
    );
  }

  /// 历史记录唯一标识符
  final String historyId;

  /// 历史事件列表
  final List<HistoryEventData> events;

  /// 原始位置数据列表
  final List<LocationData> rawLocations;

  /// 初始路线信息（可选）
  final Map<String, dynamic>? initialRoute;

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'historyId': historyId,
      'events': events.map((e) => e.toMap()).toList(),
      'rawLocations': rawLocations.map((e) => e.toMap()).toList(),
      'initialRoute': initialRoute,
    };
  }

  @override
  String toString() {
    return 'NavigationHistoryEvents{historyId: $historyId, events: ${events.length}, rawLocations: ${rawLocations.length}}';
  }
}
