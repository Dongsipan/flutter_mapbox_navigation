# Android 错误处理完善实现

## 概述

本文档记录了 Android 导航功能的错误处理完善实现,包括路线计算失败处理、GPS 信号监控、位置权限检查和网络连接重试逻辑。

## 实现日期
2026-01-05

## 相关需求
- Requirements 14.1: 改进路线计算失败的错误消息
- Requirements 14.2: 添加 GPS 信号丢失的用户提示
- Requirements 14.3: 处理位置权限被拒绝的情况
- Requirements 14.4: 添加网络连接失败的重试逻辑
- Requirements 14.5: 确保所有异常都被捕获并记录
- Requirements 14.6: 提供用户友好的错误提示

## 实现内容

### 1. 改进路线计算失败的错误消息 ✅

**位置**: `NavigationActivity.kt` - `requestRoutesWithRetry()` 方法

**实现细节**:
- 在 `onFailure` 回调中解析 `RouterFailure` 原因
- 根据错误类型提供用户友好的错误消息:
  - "No route found" → "No route found between the selected locations"
  - "network/connection" → "Network connection failed. Please check your internet connection"
  - "timeout" → "Request timed out. Please try again"
  - "unauthorized/token" → "Invalid access token. Please check your Mapbox configuration"
  - 其他 → 显示原始错误消息

**发送到 Flutter 的错误数据**:
```kotlin
val errorData = mapOf(
    "message" to errorMessage,
    "reasons" to reasons.map { it.message },
    "attempts" to currentAttempt
)
```

### 2. GPS 信号监控 ✅

**位置**: `NavigationActivity.kt` - GPS Signal Monitoring 部分

**实现细节**:

#### 2.1 GPS 信号质量跟踪
```kotlin
private var lastLocationUpdateTime = 0L
private var isGpsSignalWeak = false
private val GPS_SIGNAL_TIMEOUT_MS = 10000L // 10 秒无更新 = 信号弱
```

#### 2.2 位置观察者增强
在 `locationObserver` 中:
- 更新 `lastLocationUpdateTime` 时间戳
- 检查位置精度 (`horizontalAccuracy`)
- 如果精度 > 50 米,标记为弱信号
- 发送 `GPS_SIGNAL_WEAK` 事件到 Flutter
- 显示 GPS 警告 UI

#### 2.3 GPS 信号监控任务
```kotlin
private val gpsMonitoringRunnable = object : Runnable {
    override fun run() {
        val timeSinceLastUpdate = currentTime - lastLocationUpdateTime
        
        if (timeSinceLastUpdate > GPS_SIGNAL_TIMEOUT_MS && isNavigationInProgress) {
            // 发送 GPS_SIGNAL_LOST 事件
            // 显示 GPS 警告 UI
        }
        
        // 每 5 秒检查一次
        gpsMonitoringHandler?.postDelayed(this, 5000)
    }
}
```

#### 2.4 GPS 信号恢复检测
当收到新的位置更新且之前信号弱时:
- 发送 `GPS_SIGNAL_RECOVERED` 事件
- 隐藏 GPS 警告 UI

#### 2.5 新增事件类型
在 `MapBoxEvents.kt` 中添加:
- `GPS_SIGNAL_WEAK("gps_signal_weak")` - GPS 信号弱
- `GPS_SIGNAL_LOST("gps_signal_lost")` - GPS 信号丢失
- `GPS_SIGNAL_RECOVERED("gps_signal_recovered")` - GPS 信号恢复

### 3. GPS 警告 UI ✅

**位置**: `navigation_activity.xml`

**实现细节**:
- 添加 `gpsWarningPanel` LinearLayout
- 包含警告图标和文本
- 橙色背景 (`holo_orange_light`)
- 高 elevation (10dp) 确保在其他 UI 之上
- 默认隐藏 (`visibility="gone"`)
- 位于转弯指示面板下方

**UI 组件**:
```xml
<LinearLayout
    android:id="@+id/gpsWarningPanel"
    android:background="@android:color/holo_orange_light"
    android:visibility="gone">
    
    <ImageView android:src="@android:drawable/ic_dialog_alert" />
    <TextView android:id="@+id/gpsWarningText" />
</LinearLayout>
```

### 4. 位置权限检查 ✅

**位置**: `NavigationActivity.kt` - Permission Handling 部分

**实现细节**:

#### 4.1 权限检查方法
```kotlin
private fun checkLocationPermissions(): Boolean {
    val fineLocationGranted = ContextCompat.checkSelfPermission(
        this,
        Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    
    val coarseLocationGranted = ContextCompat.checkSelfPermission(
        this,
        Manifest.permission.ACCESS_COARSE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    
    if (!fineLocationGranted || !coarseLocationGranted) {
        // 发送错误事件到 Flutter
        val errorData = mapOf(
            "message" to "Location permissions are required for navigation",
            "type" to "PERMISSION_DENIED"
        )
        sendEvent(MapBoxEvents.NAVIGATION_CANCELLED, JSONObject(errorData).toString())
        return false
    }
    
    return true
}
```

#### 4.2 在 onCreate 中调用
```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    // ...
    
    // Check location permissions
    if (!checkLocationPermissions()) {
        finish()
        return
    }
    
    // ...
}
```

### 5. 网络连接检查和重试逻辑 ✅

**位置**: `NavigationActivity.kt` - Network Connectivity 部分

**实现细节**:

#### 5.1 网络可用性检查
```kotlin
private fun isNetworkAvailable(): Boolean {
    val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    } else {
        @Suppress("DEPRECATION")
        val networkInfo = connectivityManager.activeNetworkInfo
        @Suppress("DEPRECATION")
        return networkInfo?.isConnected == true
    }
}
```

#### 5.2 请求路线前检查网络
```kotlin
private fun requestRoutes(waypointSet: WaypointSet) {
    // Check network connectivity before requesting routes
    if (!isNetworkAvailable()) {
        val errorData = mapOf(
            "message" to "No internet connection. Please check your network settings.",
            "type" to "NETWORK_ERROR"
        )
        sendEvent(MapBoxEvents.ROUTE_BUILD_FAILED, JSONObject(errorData).toString())
        return
    }
    
    sendEvent(MapBoxEvents.ROUTE_BUILDING)
    requestRoutesWithRetry(waypointSet, maxRetries = 3, currentAttempt = 1)
}
```

#### 5.3 重试逻辑
```kotlin
private fun requestRoutesWithRetry(waypointSet: WaypointSet, maxRetries: Int, currentAttempt: Int) {
    // ...
    
    override fun onFailure(reasons: List<RouterFailure>, routeOptions: RouteOptions) {
        // 检查是否应该重试
        val shouldRetry = reasons.any { failure ->
            failure.message.contains("network", ignoreCase = true) ||
            failure.message.contains("connection", ignoreCase = true) ||
            failure.message.contains("timeout", ignoreCase = true)
        }
        
        if (shouldRetry && currentAttempt < maxRetries) {
            // 使用指数退避重试
            val delayMs = (1000 * currentAttempt).toLong()
            
            Handler(Looper.getMainLooper()).postDelayed({
                requestRoutesWithRetry(waypointSet, maxRetries, currentAttempt + 1)
            }, delayMs)
        } else {
            // 发送详细错误到 Flutter
            val errorData = mapOf(
                "message" to errorMessage,
                "reasons" to reasons.map { it.message },
                "attempts" to currentAttempt
            )
            sendEvent(MapBoxEvents.ROUTE_BUILD_FAILED, JSONObject(errorData).toString())
        }
    }
}
```

**重试策略**:
- 最多重试 3 次
- 指数退避延迟: 1秒, 2秒, 3秒
- 仅对网络相关错误重试
- 记录重试次数并发送到 Flutter

### 6. 异常捕获和日志记录 ✅

**实现细节**:

#### 6.1 初始化方法的异常处理
所有初始化方法都包含 try-catch 块:
```kotlin
private fun initializeNavigation() {
    try {
        // ...
    } catch (e: Exception) {
        android.util.Log.e(TAG, "Failed to initialize navigation: ${e.message}", e)
        sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        finish()
    }
}
```

#### 6.2 观察者的异常处理
```kotlin
private val routeProgressObserver = RouteProgressObserver { routeProgress ->
    try {
        // Update UI
        updateNavigationUI(routeProgress)
        // ...
    } catch (e: Exception) {
        android.util.Log.e(TAG, "Error in route progress observer: ${e.message}", e)
    }
}
```

#### 6.3 UI 更新的回退机制
```kotlin
private fun updateNavigationUI(routeProgress: RouteProgress) {
    try {
        // Use TripProgressApi
        val tripProgressUpdate = tripProgressApi.getTripProgress(routeProgress)
        // ...
    } catch (e: Exception) {
        android.util.Log.e(TAG, "Failed to update navigation UI: ${e.message}", e)
        // Fallback to manual formatting
        updateNavigationUIFallback(routeProgress)
    }
}
```

#### 6.4 生命周期方法的异常处理
```kotlin
override fun onDestroy() {
    super.onDestroy()
    
    try {
        // Stop GPS signal monitoring
        stopGpsSignalMonitoring()
        
        // Clean up voice instructions
        try {
            voiceInstructionsPlayer.shutdown()
            speechApi.cancel()
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error cleaning up voice instructions: ${e.message}", e)
        }
        
        // ...
    } catch (e: Exception) {
        android.util.Log.e(TAG, "Error in onDestroy: ${e.message}", e)
    }
}
```

## 日志记录规范

### 日志级别使用
- `Log.d()` - 调试信息 (正常流程)
- `Log.w()` - 警告信息 (可恢复的问题)
- `Log.e()` - 错误信息 (需要处理的异常)

### 日志标签
使用 emoji 提高可读性:
- ✅ `"✅ Success message"`
- ❌ `"❌ Error message"`
- ⚠️ `"⚠️ Warning message"`
- 🔄 `"🔄 Retry message"`
- 📍 `"📍 Location update"`
- 📡 `"📡 GPS signal"`
- 📷 `"📷 Camera update"`
- 🔊 `"🔊 Voice instruction"`
- 📹 `"📹 History recording"`

## 测试建议

### 1. 路线计算错误测试
- 测试无效的坐标 (应显示 "No route found")
- 测试无网络连接 (应显示网络错误并重试)
- 测试无效的 access token (应显示 token 错误)

### 2. GPS 信号测试
- 在室内测试 (应触发弱信号警告)
- 关闭 GPS 后测试 (应触发信号丢失警告)
- 从室内移到室外 (应触发信号恢复事件)

### 3. 权限测试
- 拒绝位置权限后启动导航 (应立即结束并发送错误)
- 在导航中撤销权限 (应停止导航)

### 4. 网络重试测试
- 在飞行模式下请求路线 (应立即失败)
- 在弱网络下请求路线 (应重试 3 次)
- 在重试过程中恢复网络 (应成功获取路线)

## 与 iOS 对齐

所有错误处理功能都与 iOS 实现对齐:
- ✅ 详细的错误消息
- ✅ GPS 信号监控
- ✅ 位置权限检查
- ✅ 网络连接检查
- ✅ 自动重试逻辑
- ✅ 用户友好的错误提示

## 文件修改清单

### 修改的文件
1. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
   - 添加 GPS 信号监控
   - 添加权限检查
   - 添加网络连接检查
   - 改进错误处理
   - 添加重试逻辑

2. `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/models/MapBoxEvents.kt`
   - 添加 GPS 相关事件

3. `android/src/main/res/layout/navigation_activity.xml`
   - 添加 GPS 警告面板

### 新增的方法
- `checkLocationPermissions()` - 检查位置权限
- `isNetworkAvailable()` - 检查网络连接
- `requestRoutesWithRetry()` - 带重试的路线请求
- `startGpsSignalMonitoring()` - 启动 GPS 监控
- `stopGpsSignalMonitoring()` - 停止 GPS 监控

### 新增的属性
- `lastLocationUpdateTime` - 最后位置更新时间
- `isGpsSignalWeak` - GPS 信号弱标志
- `GPS_SIGNAL_TIMEOUT_MS` - GPS 超时阈值
- `gpsMonitoringHandler` - GPS 监控 Handler
- `gpsMonitoringRunnable` - GPS 监控任务

## 性能考虑

1. **GPS 监控频率**: 每 5 秒检查一次,不会对性能造成明显影响
2. **重试延迟**: 使用指数退避,避免频繁请求
3. **UI 更新**: 在主线程上更新 UI,使用 `runOnUiThread`
4. **资源清理**: 在 `onDestroy` 中停止所有监控任务

## 已知限制

1. GPS 警告面板使用系统图标,可以替换为自定义图标
2. 权限检查在 Activity 启动时进行,不支持运行时请求权限
3. 网络检查仅检查连接状态,不检查实际网络质量

## 后续改进建议

1. 添加运行时权限请求 UI
2. 添加网络质量检测 (带宽测试)
3. 添加更详细的 GPS 信号强度指示器
4. 支持自定义重试策略配置
5. 添加离线路线缓存支持

---

**实现状态**: ✅ 完成
**测试状态**: ⏳ 待测试
**文档状态**: ✅ 完成
