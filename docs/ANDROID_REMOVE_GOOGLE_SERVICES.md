# Android 移除 Google Play Services 依赖

## 问题描述

当 `autoBuildRoute = true` 时，如果设备没有安装 Google Play Services 或 Google Services 不可用，会导致路线选择界面无法显示，并报 Google Service 错误。

## 根本原因

`LocationHelper.kt` 使用了 Google Play Services 的 `FusedLocationProviderClient` 来获取用户位置，这在以下场景中会被调用：
- 搜索功能（SearchActivity）
- 获取当前位置作为起点
- 反向地理编码

## 解决方案

### 1. 移除 Google Play Services 依赖

**文件：** `android/build.gradle`

移除以下依赖：
```gradle
// 已移除
// implementation "com.google.android.gms:play-services-location:21.1.0"
```

### 2. 使用 Android 原生 LocationManager

**文件：** `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/utilities/LocationHelper.kt`

**主要更改：**

#### 替换定位服务提供者
```kotlin
// 旧代码（使用 Google Play Services）
private val fusedLocationClient: FusedLocationProviderClient by lazy {
    LocationServices.getFusedLocationProviderClient(context)
}

// 新代码（使用 Android 原生）
private val locationManager: LocationManager by lazy {
    context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
}
```

#### 重写 getCurrentLocation() 方法

新实现的特点：
1. **优先使用最后已知位置**：快速返回结果，避免等待
2. **支持多个位置提供者**：GPS、网络定位等
3. **超时机制**：10秒超时，避免无限等待
4. **单次位置更新**：使用 `requestSingleUpdate()` 而不是持续监听
5. **无需 Google Services**：完全使用 Android 原生 API

```kotlin
suspend fun getCurrentLocation(): Point? = withTimeoutOrNull(LOCATION_TIMEOUT_MS) {
    suspendCancellableCoroutine { continuation ->
        // 1. 首先尝试获取最后已知位置（快速）
        val lastKnownLocation = getLastKnownLocation()
        if (lastKnownLocation != null) {
            continuation.resume(lastKnownLocation)
            return@suspendCancellableCoroutine
        }

        // 2. 如果没有，请求单次位置更新
        val providers = locationManager.getProviders(true)
        val provider = when {
            providers.contains(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            providers.contains(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            else -> providers.first()
        }

        locationManager.requestSingleUpdate(
            provider,
            locationListener,
            android.os.Looper.getMainLooper()
        )
    }
}
```

#### 新增 getLastKnownLocation() 方法

```kotlin
private fun getLastKnownLocation(): Point? {
    val providers = locationManager.getProviders(true)
    var bestLocation: Location? = null

    // 遍历所有提供者，选择精度最高的位置
    for (provider in providers) {
        val location = locationManager.getLastKnownLocation(provider) ?: continue
        
        if (bestLocation == null || location.accuracy < bestLocation.accuracy) {
            bestLocation = location
        }
    }

    return bestLocation?.let {
        Point.fromLngLat(it.longitude, it.latitude)
    }
}
```

## 优势

### 1. 无需 Google Services
- ✅ 在没有 Google Play Services 的设备上也能正常工作
- ✅ 在中国大陆等 Google Services 受限的地区可用
- ✅ 减少应用体积和依赖

### 2. 更好的兼容性
- ✅ 支持所有 Android 设备（包括定制 ROM）
- ✅ 不依赖第三方服务的可用性
- ✅ 使用标准 Android API

### 3. 性能优化
- ✅ 优先使用缓存的最后已知位置（快速响应）
- ✅ 10秒超时机制，避免无限等待
- ✅ 单次位置更新，节省电量

## 位置提供者优先级

新实现按以下优先级选择位置提供者：

1. **GPS_PROVIDER**：最高精度，户外环境
2. **NETWORK_PROVIDER**：中等精度，室内可用
3. **其他可用提供者**：作为后备

## 测试建议

### 测试场景

1. **无 Google Services 设备**
   - 测试在华为鸿蒙系统等设备上的表现
   - 验证定位功能正常工作

2. **不同位置提供者**
   - 关闭 GPS，仅使用网络定位
   - 关闭网络，仅使用 GPS
   - 测试室内外不同环境

3. **权限场景**
   - 首次请求位置权限
   - 拒绝位置权限
   - 授予位置权限后的行为

4. **超时场景**
   - 在无法获取位置的环境（如地下室）
   - 验证 10秒超时机制

### 测试命令

```bash
# 清理并重新构建
cd example/android
./gradlew clean
./gradlew assembleDebug

# 运行测试
./gradlew test
```

## 向后兼容性

此更改完全向后兼容，不影响现有功能：
- ✅ 所有公共 API 保持不变
- ✅ 方法签名未改变
- ✅ 返回值类型一致
- ✅ 错误处理逻辑相同

## 相关文件

- `android/build.gradle` - 移除 Google Play Services 依赖
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/utilities/LocationHelper.kt` - 使用原生 LocationManager
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/SearchActivity.kt` - 使用 LocationHelper 的地方

## 注意事项

1. **位置权限**：仍然需要 `ACCESS_FINE_LOCATION` 和 `ACCESS_COARSE_LOCATION` 权限
2. **位置服务**：用户需要在设备设置中启用位置服务
3. **精度**：在某些情况下，原生 LocationManager 的精度可能略低于 FusedLocationProviderClient
4. **首次定位**：如果设备没有缓存位置，首次定位可能需要几秒钟

## 总结

通过移除 Google Play Services 依赖并使用 Android 原生 LocationManager，我们解决了 `autoBuildRoute = true` 时的 Google Service 错误问题，同时提高了应用的兼容性和可用性。这个改动对于在中国大陆或其他 Google Services 受限地区使用的应用尤其重要。
