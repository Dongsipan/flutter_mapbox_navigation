// ignore_for_file: public_member_api_docs

/// 地图样式枚举
/// 支持Mapbox提供的各种预设样式
enum MapStyle {
  /// 标准样式 - Mapbox Standard style
  standard,
  
  /// 标准卫星样式 - Mapbox Standard style with satellite imagery
  standardSatellite,
  
  /// 街道样式 - Mapbox Streets style
  streets,
  
  /// 浅色样式 - 适合数据可视化的浅色背景
  light,
  
  /// 深色样式 - 适合数据可视化的深色背景
  dark,
  
  /// 户外样式 - 适合户外活动的地图样式
  outdoors,
}

/// 时间段光照预设枚举
/// 仅适用于MapStyle.standard样式
enum TimeOfDayPreset {
  /// 黎明
  dawn,
  
  /// 白天（默认）
  day,
  
  /// 黄昏
  dusk,
  
  /// 夜晚
  night,
}

/// 扩展MapStyle枚举，提供样式URL获取方法
extension MapStyleExtension on MapStyle {
  /// 获取对应的Mapbox样式URL
  String get styleUrl {
    switch (this) {
      case MapStyle.standard:
        return 'mapbox://styles/mapbox/standard';
      case MapStyle.standardSatellite:
        return 'mapbox://styles/mapbox/standard-satellite';
      case MapStyle.streets:
        return 'mapbox://styles/mapbox/streets-v12';
      case MapStyle.light:
        return 'mapbox://styles/mapbox/light-v11';
      case MapStyle.dark:
        return 'mapbox://styles/mapbox/dark-v11';
      case MapStyle.outdoors:
        return 'mapbox://styles/mapbox/outdoors-v12';
    }
  }
  
  /// 获取样式的显示名称
  String get displayName {
    switch (this) {
      case MapStyle.standard:
        return 'Standard';
      case MapStyle.standardSatellite:
        return 'Standard Satellite';
      case MapStyle.streets:
        return 'Streets';
      case MapStyle.light:
        return 'Light';
      case MapStyle.dark:
        return 'Dark';
      case MapStyle.outdoors:
        return 'Outdoors';
    }
  }
  
  /// 判断是否支持时间段光照预设
  bool get supportsTimeOfDayPreset {
    return this == MapStyle.standard;
  }
  
  /// 从字符串转换为MapStyle
  static MapStyle? fromString(String styleString) {
    for (MapStyle style in MapStyle.values) {
      if (style.toString().split('.').last == styleString) {
        return style;
      }
    }
    return null;
  }
}

/// 扩展TimeOfDayPreset枚举
extension TimeOfDayPresetExtension on TimeOfDayPreset {
  /// 获取对应的lightPreset值
  String get presetValue {
    switch (this) {
      case TimeOfDayPreset.dawn:
        return 'dawn';
      case TimeOfDayPreset.day:
        return 'day';
      case TimeOfDayPreset.dusk:
        return 'dusk';
      case TimeOfDayPreset.night:
        return 'night';
    }
  }
  
  /// 获取显示名称
  String get displayName {
    switch (this) {
      case TimeOfDayPreset.dawn:
        return '黎明';
      case TimeOfDayPreset.day:
        return '白天';
      case TimeOfDayPreset.dusk:
        return '黄昏';
      case TimeOfDayPreset.night:
        return '夜晚';
    }
  }
  
  /// 从字符串转换为TimeOfDayPreset
  static TimeOfDayPreset? fromString(String presetString) {
    for (TimeOfDayPreset preset in TimeOfDayPreset.values) {
      if (preset.toString().split('.').last == presetString) {
        return preset;
      }
    }
    return null;
  }
}
