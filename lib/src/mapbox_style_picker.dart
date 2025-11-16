import 'package:flutter/services.dart';

/// Mapbox 地图样式选择器
///
/// 新逻辑：用户选择后自动存储到插件内部，后续导航自动应用
/// 无需手动传递样式参数
class MapboxStylePicker {
  static const MethodChannel _channel =
      MethodChannel('flutter_mapbox_navigation/style_picker');

  /// 显示样式选择器
  ///
  /// 用户选择后会自动存储到插件内部，后续所有导航会自动使用存储的样式
  ///
  /// 返回值：
  /// - true: 用户选择并成功保存
  /// - false: 用户取消
  ///
  /// 示例：
  /// ```dart
  /// // 1. 打开样式选择器（自动存储）
  /// final saved = await MapboxStylePicker.show();
  ///
  /// if (saved) {
  ///   print('样式已保存，后续导航会自动使用');
  /// }
  ///
  /// // 2. 后续导航自动使用存储的样式
  /// await MapBoxNavigation.instance.startNavigation(
  ///   wayPoints: wayPoints,
  ///   // 不需要传递 mapStyle 等参数，会自动使用存储的样式
  /// );
  /// ```
  static Future<bool> show() async {
    try {
      final result = await _channel.invokeMethod('showStylePicker');
      return result == true;
    } catch (e) {
      print('❌ 显示样式选择器失败: $e');
      return false;
    }
  }

  /// 获取当前存储的样式设置
  ///
  /// 返回存储在插件中的样式配置
  ///
  /// 返回值：
  /// - Map 包含 mapStyle, lightPreset, enableDynamicLightPreset
  ///
  /// 示例：
  /// ```dart
  /// final settings = await MapboxStylePicker.getStoredStyle();
  /// print('当前样式: ${settings['mapStyle']}');
  /// print('Light Preset: ${settings['lightPreset']}');
  /// print('动态切换: ${settings['enableDynamicLightPreset']}');
  /// ```
  static Future<Map<String, dynamic>> getStoredStyle() async {
    try {
      final result = await _channel.invokeMethod('getStoredStyle');
      if (result != null && result is Map) {
        return Map<String, dynamic>.from(result);
      }

      // 返回默认值
      return {
        'mapStyle': 'standard',
        'lightPreset': 'day',
        'enableDynamicLightPreset': false,
      };
    } catch (e) {
      print('❌ 获取存储样式失败: $e');
      return {
        'mapStyle': 'standard',
        'lightPreset': 'day',
        'enableDynamicLightPreset': false,
      };
    }
  }

  /// 清除存储的样式设置
  ///
  /// 清除后会恢复为默认样式（standard + day）
  ///
  /// 返回值：
  /// - true: 清除成功
  /// - false: 清除失败
  ///
  /// 示例：
  /// ```dart
  /// await MapboxStylePicker.clearStoredStyle();
  /// print('已恢复默认样式');
  /// ```
  static Future<bool> clearStoredStyle() async {
    try {
      final result = await _channel.invokeMethod('clearStoredStyle');
      return result == true;
    } catch (e) {
      print('❌ 清除存储样式失败: $e');
      return false;
    }
  }
}
