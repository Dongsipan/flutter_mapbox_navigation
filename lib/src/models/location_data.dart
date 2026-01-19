/// 位置数据模型
/// 表示位置信息，包含经纬度、海拔、精度、速度、方向和时间戳
class LocationData {
  LocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.horizontalAccuracy,
    this.verticalAccuracy,
    this.speed,
    this.course,
  }) {
    // 验证纬度范围
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError('Latitude must be between -90 and 90');
    }
    // 验证经度范围
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError('Longitude must be between -180 and 180');
    }
  }

  /// 从 Map 创建 LocationData 对象
  factory LocationData.fromMap(Map<String, dynamic> map) {
    // 安全地转换数值类型
    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.parse(value);
      return 0;
    }

    double? parseOptionalDouble(dynamic value) {
      if (value == null) return null;
      return parseDouble(value);
    }

    // 安全地转换时间戳
    int parseTimestamp(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.parse(value);
      return 0;
    }

    return LocationData(
      latitude: parseDouble(map['latitude']),
      longitude: parseDouble(map['longitude']),
      altitude: parseOptionalDouble(map['altitude']),
      horizontalAccuracy: parseOptionalDouble(map['horizontalAccuracy']),
      verticalAccuracy: parseOptionalDouble(map['verticalAccuracy']),
      speed: parseOptionalDouble(map['speed']),
      course: parseOptionalDouble(map['course']),
      timestamp: parseTimestamp(map['timestamp']),
    );
  }

  /// 纬度（-90 到 90）
  final double latitude;

  /// 经度（-180 到 180）
  final double longitude;

  /// 海拔（米）
  final double? altitude;

  /// 水平精度（米）
  final double? horizontalAccuracy;

  /// 垂直精度（米）
  final double? verticalAccuracy;

  /// 速度（米/秒）
  final double? speed;

  /// 方向（度，0-360）
  final double? course;

  /// 时间戳（毫秒）
  final int timestamp;

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'horizontalAccuracy': horizontalAccuracy,
      'verticalAccuracy': verticalAccuracy,
      'speed': speed,
      'course': course,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() {
    return 'LocationData{latitude: $latitude, longitude: $longitude, timestamp: $timestamp}';
  }
}
