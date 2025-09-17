# Flutter Mapbox Navigation 开发指南

## 🎯 项目概述

这是一个基于Mapbox的Flutter导航插件，提供完整的转弯导航功能。本指南将帮助您快速上手并开发自己的导航功能。

## 📋 前置要求

### 开发环境
- Flutter SDK >= 2.5.0
- Dart SDK >= 2.19.4
- Android Studio / VS Code
- Xcode (iOS开发)

### Mapbox账户设置
1. 注册 [Mapbox账户](https://account.mapbox.com/)
2. 创建访问令牌（需要 `DOWNLOADS:READ` 权限）
3. 获取公开访问令牌用于地图显示

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone <your-fork-url>
cd flutter_mapbox_navigation
```

### 2. 安装依赖
```bash
flutter pub get
cd example
flutter pub get
```

### 3. 配置Mapbox令牌

#### Android配置
创建文件 `example/android/app/src/main/res/values/mapbox_access_token.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools">
    <string name="mapbox_access_token" translatable="false" tools:ignore="UnusedResources">YOUR_MAPBOX_TOKEN</string>
</resources>
```

在 `android/gradle.properties` 中添加：
```properties
MAPBOX_DOWNLOADS_TOKEN=sk.YOUR_DOWNLOAD_TOKEN
```

#### iOS配置
在 `example/ios/Runner/Info.plist` 中添加：
```xml
<key>MBXAccessToken</key>
<string>YOUR_MAPBOX_TOKEN</string>
```

### 4. 运行示例
```bash
cd example
flutter run
```

## 🏗️ 项目架构

### 核心文件结构
```
lib/
├── flutter_mapbox_navigation.dart    # 主入口文件
└── src/
    ├── models/                       # 数据模型
    │   ├── options.dart             # 导航选项
    │   ├── way_point.dart           # 路径点
    │   ├── events.dart              # 事件类型
    │   └── ...
    ├── embedded/                     # 嵌入式视图
    │   ├── view.dart                # 导航视图组件
    │   └── controller.dart          # 视图控制器
    ├── flutter_mapbox_navigation.dart # 核心导航类
    └── extensions/                   # 功能扩展（新增）
        └── navigation_extensions.dart
```

### 平台特定代码
- `android/src/main/kotlin/` - Android原生实现
- `ios/Classes/` - iOS原生实现（Swift）

## 💡 核心概念

### 1. MapBoxNavigation 单例类
主要的导航控制类，提供所有导航功能的入口点。

```dart
// 获取实例
final navigation = MapBoxNavigation.instance;

// 设置默认选项
navigation.setDefaultOptions(options);

// 开始导航
await navigation.startNavigation(wayPoints: wayPoints);
```

### 2. WayPoint 路径点
定义导航路线中的关键点。

```dart
final wayPoint = WayPoint(
  name: "目的地名称",
  latitude: 39.9042,
  longitude: 116.4074,
  isSilent: false, // 是否静音
);
```

### 3. MapBoxOptions 导航选项
配置导航行为和界面。

```dart
final options = MapBoxOptions(
  mode: MapBoxNavigationMode.drivingWithTraffic,
  language: "zh-CN",
  units: VoiceUnits.metric,
  simulateRoute: true, // 开发时使用
  voiceInstructionsEnabled: true,
  bannerInstructionsEnabled: true,
);
```

### 4. 事件监听
监听导航过程中的各种事件。

```dart
MapBoxNavigation.instance.registerRouteEventListener((event) {
  switch (event.eventType) {
    case MapBoxEvent.navigation_running:
      // 导航开始
      break;
    case MapBoxEvent.progress_change:
      // 进度更新
      break;
    case MapBoxEvent.on_arrival:
      // 到达目的地
      break;
  }
});
```

## 🔧 开发自定义功能

### 1. 扩展导航功能
参考 `lib/src/extensions/navigation_extensions.dart` 示例：

```dart
class NavigationExtensions {
  // 计算两点距离
  static double calculateDistance(lat1, lon1, lat2, lon2) { ... }
  
  // 优化路线
  List<WayPoint> optimizeRoute(List<WayPoint> wayPoints) { ... }
  
  // 保存路线历史
  void saveRouteToHistory(List<WayPoint> wayPoints) { ... }
}
```

### 2. 自定义UI组件
创建自定义的导航界面：

```dart
class CustomNavigationView extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return MapBoxNavigationView(
      options: customOptions,
      onRouteEvent: handleRouteEvent,
      onCreated: (controller) {
        // 初始化控制器
      },
    );
  }
}
```

### 3. 添加新的数据模型
在 `lib/src/models/` 目录下创建新的模型类：

```dart
class CustomRouteInfo {
  final String id;
  final List<WayPoint> wayPoints;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;
  
  CustomRouteInfo({...});
  
  // JSON序列化方法
  Map<String, dynamic> toJson() { ... }
  factory CustomRouteInfo.fromJson(Map<String, dynamic> json) { ... }
}
```

## 🧪 测试

### 运行单元测试
```bash
flutter test
```

### 运行集成测试
```bash
cd example
flutter drive --target=test_driver/app.dart
```

### 测试最佳实践
1. 为新功能编写单元测试
2. 使用模拟数据进行测试
3. 测试不同的导航场景
4. 验证错误处理逻辑

## 📱 平台特定开发

### Android开发
- 主要文件：`android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/`
- 使用Mapbox Navigation SDK for Android
- 处理权限请求和生命周期

### iOS开发
- 主要文件：`ios/Classes/`
- 使用Mapbox Navigation SDK for iOS
- 处理后台模式和位置权限

## 🔍 调试技巧

### 1. 启用详细日志
```dart
MapBoxOptions(
  // 其他选项...
  simulateRoute: true, // 开发时启用模拟
);
```

### 2. 使用Flutter Inspector
- 检查Widget树结构
- 调试布局问题
- 监控性能

### 3. 平台特定调试
- Android: 使用 `adb logcat`
- iOS: 使用 Xcode Console

## 📚 常用API参考

### 导航控制
```dart
// 开始导航
await MapBoxNavigation.instance.startNavigation(wayPoints: points);

// 结束导航
await MapBoxNavigation.instance.finishNavigation();

// 开始自由驾驶
await MapBoxNavigation.instance.startFreeDrive();

// 获取剩余距离
double? distance = await MapBoxNavigation.instance.getDistanceRemaining();

// 获取剩余时间
double? duration = await MapBoxNavigation.instance.getDurationRemaining();
```

### 嵌入式视图控制
```dart
// 构建路线
await controller.buildRoute(wayPoints: points);

// 开始导航
await controller.startNavigation();

// 清除路线
await controller.clearRoute();
```

## 🚀 发布准备

### 1. 版本管理
更新 `pubspec.yaml` 中的版本号：
```yaml
version: 1.0.0+1
```

### 2. 文档更新
- 更新 README.md
- 更新 CHANGELOG.md
- 添加API文档

### 3. 测试检查
- 运行所有测试
- 在真实设备上测试
- 验证不同平台的兼容性

## 🤝 贡献指南

1. Fork项目
2. 创建功能分支
3. 提交更改
4. 创建Pull Request
5. 等待代码审查

## 📞 获取帮助

- 查看官方文档：[Mapbox Navigation SDK](https://docs.mapbox.com/)
- 提交Issue：在GitHub仓库中报告问题
- 社区讨论：Flutter社区论坛

---

祝您开发愉快！🎉
