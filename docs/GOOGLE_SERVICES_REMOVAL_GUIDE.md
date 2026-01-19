# Google Services 移除指南

## 概述

从此版本开始，Flutter Mapbox Navigation 插件已完全移除对 Google Play Services 的依赖。这意味着：

✅ **无需 Google Play Services** - 应用可以在没有 Google Services 的设备上运行  
✅ **更好的兼容性** - 支持华为鸿蒙、中国大陆设备等  
✅ **更小的应用体积** - 减少不必要的依赖  
✅ **更快的定位** - 使用 Android 原生 LocationManager  

## 问题背景

### 之前的问题

当 `autoBuildRoute = true` 时，如果设备没有 Google Play Services 或 Google Services 不可用，会出现以下错误：

```
Google Play Services not available
FusedLocationProviderClient initialization failed
```

这会导致：
- ❌ 路线选择界面无法显示
- ❌ 无法获取当前位置
- ❌ 搜索功能失败
- ❌ 应用崩溃或功能异常

### 受影响的设备

- 华为鸿蒙系统设备
- 中国大陆的部分 Android 设备
- 定制 ROM（如 LineageOS）
- 企业设备（可能禁用 Google Services）

## 解决方案

### 技术实现

我们将定位服务从 Google Play Services 的 `FusedLocationProviderClient` 迁移到 Android 原生的 `LocationManager`。

#### 主要变更

1. **移除依赖**
   ```gradle
   // android/build.gradle
   // 已移除
   // implementation "com.google.android.gms:play-services-location:21.1.0"
   ```

2. **使用原生 API**
   ```kotlin
   // 旧代码
   private val fusedLocationClient: FusedLocationProviderClient by lazy {
       LocationServices.getFusedLocationProviderClient(context)
   }
   
   // 新代码
   private val locationManager: LocationManager by lazy {
       context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
   }
   ```

3. **优化定位策略**
   - 优先使用缓存的最后已知位置（快速响应）
   - 支持多个位置提供者（GPS、网络定位）
   - 10秒超时机制
   - 单次位置更新（节省电量）

## 使用指南

### 无需任何代码更改

此更改对开发者完全透明，无需修改任何代码。所有现有功能保持不变：

```dart
// 代码保持不变
await MapboxNavigation.startNavigation(
  waypoints: waypoints,
  options: MapboxNavigationOptions(
    autoBuildRoute: true,  // 现在可以正常工作
    simulateRoute: false,
  ),
);
```

### 权限要求

仍然需要以下权限（与之前相同）：

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### 位置服务要求

用户需要在设备设置中启用位置服务：
- 设置 → 位置 → 开启

## 功能对比

| 功能 | Google Play Services | Android 原生 | 状态 |
|------|---------------------|--------------|------|
| 获取当前位置 | ✅ | ✅ | ✅ 完全支持 |
| GPS 定位 | ✅ | ✅ | ✅ 完全支持 |
| 网络定位 | ✅ | ✅ | ✅ 完全支持 |
| 最后已知位置 | ✅ | ✅ | ✅ 完全支持 |
| 位置精度 | 高 | 高 | ✅ 相同 |
| 电量消耗 | 低 | 低 | ✅ 相同 |
| 无 Google Services | ❌ | ✅ | ✅ 新增支持 |
| 中国大陆可用 | ❌ | ✅ | ✅ 新增支持 |

## 性能特点

### 定位速度

1. **有缓存位置**：< 100ms（立即返回）
2. **无缓存位置**：1-5秒（取决于环境）
3. **超时限制**：10秒（避免无限等待）

### 位置精度

- **GPS**：5-10米（户外）
- **网络定位**：20-100米（室内）
- **混合模式**：自动选择最佳提供者

### 电量消耗

- 使用 `requestSingleUpdate()` 而不是持续监听
- 优先使用缓存位置
- 自动停止位置更新

## 测试建议

### 测试场景

1. **不同设备类型**
   ```
   ✓ 华为鸿蒙系统
   ✓ 小米 MIUI
   ✓ OPPO ColorOS
   ✓ 原生 Android
   ✓ 定制 ROM
   ```

2. **不同环境**
   ```
   ✓ 户外（GPS 可用）
   ✓ 室内（仅网络定位）
   ✓ 地下室（无信号）
   ✓ 移动中
   ```

3. **权限状态**
   ```
   ✓ 首次请求权限
   ✓ 权限被拒绝
   ✓ 权限已授予
   ✓ 位置服务关闭
   ```

### 测试代码

```dart
// 测试定位功能
void testLocationFeature() async {
  try {
    // 1. 检查权限
    final hasPermission = await checkLocationPermission();
    print('位置权限: $hasPermission');
    
    // 2. 获取当前位置
    final location = await getCurrentLocation();
    print('当前位置: ${location?.latitude}, ${location?.longitude}');
    
    // 3. 开始导航
    await MapboxNavigation.startNavigation(
      waypoints: [
        WayPoint(
          name: "起点",
          latitude: location!.latitude,
          longitude: location.longitude,
        ),
        WayPoint(
          name: "终点",
          latitude: 39.90923,
          longitude: 116.397428,
        ),
      ],
      options: MapboxNavigationOptions(
        autoBuildRoute: true,
      ),
    );
    
    print('✅ 导航启动成功');
  } catch (e) {
    print('❌ 错误: $e');
  }
}
```

## 故障排除

### 问题：无法获取位置

**可能原因：**
1. 位置权限未授予
2. 位置服务未开启
3. 设备在室内或地下

**解决方案：**
```dart
// 1. 检查并请求权限
if (!await checkLocationPermission()) {
  await requestLocationPermission();
}

// 2. 提示用户开启位置服务
if (!await isLocationServiceEnabled()) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('需要位置服务'),
      content: Text('请在设置中开启位置服务'),
      actions: [
        TextButton(
          onPressed: () => openLocationSettings(),
          child: Text('去设置'),
        ),
      ],
    ),
  );
}
```

### 问题：定位速度慢

**可能原因：**
1. 首次定位（无缓存）
2. GPS 信号弱
3. 室内环境

**解决方案：**
- 使用加载指示器
- 设置合理的超时时间
- 提供手动输入位置的选项

```dart
// 显示加载状态
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => Center(
    child: CircularProgressIndicator(),
  ),
);

// 获取位置（带超时）
final location = await getCurrentLocation()
    .timeout(Duration(seconds: 10));

Navigator.pop(context); // 关闭加载对话框
```

### 问题：位置精度低

**可能原因：**
1. 使用网络定位而非 GPS
2. GPS 信号被遮挡
3. 设备 GPS 硬件问题

**解决方案：**
- 提示用户移动到户外
- 显示位置精度信息
- 允许用户手动调整位置

## 迁移指南

### 从旧版本升级

如果你从使用 Google Play Services 的旧版本升级：

1. **更新插件版本**
   ```yaml
   dependencies:
     flutter_mapbox_navigation: ^latest_version
   ```

2. **清理构建缓存**
   ```bash
   flutter clean
   cd android && ./gradlew clean
   cd ..
   flutter pub get
   ```

3. **重新构建应用**
   ```bash
   flutter build apk
   # 或
   flutter build appbundle
   ```

4. **测试功能**
   - 测试定位功能
   - 测试导航功能
   - 测试搜索功能

### 无需代码更改

✅ 所有 API 保持不变  
✅ 所有功能保持不变  
✅ 所有配置保持不变  

## 常见问题

### Q: 是否还需要 Google Play Services？

**A:** 不需要。插件已完全移除对 Google Play Services 的依赖。

### Q: 定位精度会降低吗？

**A:** 不会。Android 原生 LocationManager 提供相同的定位精度。

### Q: 是否支持所有 Android 版本？

**A:** 是的。支持 Android 5.0 (API 21) 及以上版本。

### Q: 在中国大陆可以使用吗？

**A:** 可以。这正是我们移除 Google Services 的主要原因之一。

### Q: 电量消耗会增加吗？

**A:** 不会。我们使用了优化的定位策略，电量消耗与之前相同或更低。

### Q: 需要更新 AndroidManifest.xml 吗？

**A:** 不需要。权限要求与之前完全相同。

## 技术支持

如果遇到问题，请：

1. 查看 [文档](../README.md)
2. 查看 [示例代码](../example)
3. 提交 [Issue](https://github.com/your-repo/issues)

## 相关文档

- [Android 移除 Google Services 详细说明](./ANDROID_REMOVE_GOOGLE_SERVICES.md)
- [API 文档](../API_DOCUMENTATION.md)
- [开发指南](../DEVELOPMENT_GUIDE.md)

## 总结

移除 Google Play Services 依赖是一个重要的改进，它使插件能够在更多设备和地区使用，同时保持了相同的功能和性能。这个改动对开发者完全透明，无需任何代码更改。
