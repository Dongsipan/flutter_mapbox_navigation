/// 导航历史记录数据模型
class NavigationHistory {
  NavigationHistory({
    required this.id,
    required this.historyFilePath,
    this.cover,
    required this.startTime,
    this.endTime,
    this.distance,
    this.duration,
    this.startPointName,
    this.endPointName,
    this.navigationMode,
  });

  /// 从 Map 创建 NavigationHistory 对象
  factory NavigationHistory.fromMap(Map<String, dynamic> map) {
    return NavigationHistory(
      id: map['id'] as String,
      historyFilePath: map['historyFilePath'] as String,
      cover: map['cover'] as String?,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int)
          : null,
      distance: map['distance'] as double?,
      duration: map['duration'] as int?,
      startPointName: map['startPointName'] as String?,
      endPointName: map['endPointName'] as String?,
      navigationMode: map['navigationMode'] as String?,
    );
  }

  /// 历史记录唯一标识符
  final String id;

  /// 导航历史文件路径
  final String historyFilePath;

  /// 封面图片路径（可选）
  final String? cover;

  /// 导航开始时间
  final DateTime startTime;

  /// 导航结束时间
  final DateTime? endTime;

  /// 导航距离（米）
  final double? distance;

  /// 导航持续时间（秒）
  final int? duration;

  /// 起点名称
  final String? startPointName;

  /// 终点名称
  final String? endPointName;

  /// 导航模式
  final String? navigationMode;

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'historyFilePath': historyFilePath,
      'cover': cover,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'distance': distance,
      'duration': duration,
      'startPointName': startPointName,
      'endPointName': endPointName,
      'navigationMode': navigationMode,
    };
  }

  @override
  String toString() {
    return 'NavigationHistory{id: $id, historyFilePath: $historyFilePath, startTime: $startTime}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationHistory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
