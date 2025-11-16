/// Mapbox 地图样式类型
enum MapStyle {
  /// Mapbox Standard 样式（默认）- 支持 LightPreset
  standard,

  /// Mapbox Standard Satellite 样式（标准卫星）- 支持 LightPreset
  standardSatellite,

  /// Mapbox Faded 样式（褪色主题）- 支持 LightPreset
  faded,

  /// Mapbox Monochrome 样式（单色主题）- 支持 LightPreset
  monochrome,

  /// Mapbox Light 样式（浅色）
  light,

  /// Mapbox Dark 样式（深色）
  dark,

  /// Mapbox Outdoors 样式（户外）
  outdoors,
}

/// 扩展方法：将 MapStyle 转换为 Mapbox StyleURI 字符串
extension MapStyleExtension on MapStyle {
  String get uri {
    switch (this) {
      case MapStyle.standard:
        return 'mapbox://styles/mapbox/standard';
      case MapStyle.standardSatellite:
        return 'mapbox://styles/mapbox/standard-satellite';
      case MapStyle.faded:
        return 'mapbox://styles/mapbox/faded';
      case MapStyle.monochrome:
        return 'mapbox://styles/mapbox/monochrome';
      case MapStyle.light:
        return 'mapbox://styles/mapbox/light-v11';
      case MapStyle.dark:
        return 'mapbox://styles/mapbox/dark-v11';
      case MapStyle.outdoors:
        return 'mapbox://styles/mapbox/outdoors-v12';
    }
  }

  String get displayName {
    switch (this) {
      case MapStyle.standard:
        return 'Standard';
      case MapStyle.standardSatellite:
        return 'Standard Satellite';
      case MapStyle.faded:
        return 'Faded';
      case MapStyle.monochrome:
        return 'Monochrome';
      case MapStyle.light:
        return 'Light';
      case MapStyle.dark:
        return 'Dark';
      case MapStyle.outdoors:
        return 'Outdoors';
    }
  }

  /// 是否支持 LightPreset
  /// 只有 standard, standardSatellite, faded, monochrome 支持 LightPreset
  bool get supportsLightPreset {
    return this == MapStyle.standard ||
        this == MapStyle.standardSatellite ||
        this == MapStyle.faded ||
        this == MapStyle.monochrome;
  }

  /// 从字符串转换为 MapStyle 枚举
  static MapStyle fromString(String value) {
    switch (value.toLowerCase()) {
      case 'standard':
        return MapStyle.standard;
      case 'standardsatellite':
        return MapStyle.standardSatellite;
      case 'faded':
        return MapStyle.faded;
      case 'monochrome':
        return MapStyle.monochrome;
      case 'light':
        return MapStyle.light;
      case 'dark':
        return MapStyle.dark;
      case 'outdoors':
        return MapStyle.outdoors;
      default:
        return MapStyle.standard;
    }
  }
}

/// Light Preset - 用于 Standard 样式的 time-of-day 状态
enum LightPreset {
  /// 黎明
  dawn,

  /// 白天（默认）
  day,

  /// 黄昏
  dusk,

  /// 夜晚
  night,
}

/// 扩展方法：将 LightPreset 转换为字符串
extension LightPresetExtension on LightPreset {
  String get value {
    switch (this) {
      case LightPreset.dawn:
        return 'dawn';
      case LightPreset.day:
        return 'day';
      case LightPreset.dusk:
        return 'dusk';
      case LightPreset.night:
        return 'night';
    }
  }

  String get displayName {
    switch (this) {
      case LightPreset.dawn:
        return '黎明';
      case LightPreset.day:
        return '白天';
      case LightPreset.dusk:
        return '黄昏';
      case LightPreset.night:
        return '夜晚';
    }
  }

  /// 从字符串转换为 LightPreset 枚举
  static LightPreset fromString(String value) {
    switch (value.toLowerCase()) {
      case 'dawn':
        return LightPreset.dawn;
      case 'day':
        return LightPreset.day;
      case 'dusk':
        return LightPreset.dusk;
      case 'night':
        return LightPreset.night;
      default:
        return LightPreset.day;
    }
  }
}
