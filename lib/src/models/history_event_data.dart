/// 历史事件数据模型
/// 表示单个历史事件，包含事件类型和事件数据
class HistoryEventData {
  HistoryEventData({
    required this.eventType,
    required this.data,
  });

  /// 从 Map 创建 HistoryEventData 对象
  factory HistoryEventData.fromMap(Map<String, dynamic> map) {
    return HistoryEventData(
      eventType: map['eventType'] as String,
      data: Map<String, dynamic>.from(map['data'] as Map),
    );
  }

  /// 事件类型标识符
  /// 可能的值: 'locationUpdate', 'routeAssignment', 'userPushed', 'unknown'
  final String eventType;

  /// 事件数据
  /// 不同类型的事件有不同的数据结构
  final Map<String, dynamic> data;

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'eventType': eventType,
      'data': data,
    };
  }

  @override
  String toString() {
    return 'HistoryEventData{eventType: $eventType, data: $data}';
  }
}
