# Android SDK v3 运行时修复

## 日期
2026-01-05

## 问题描述

在 Android 14 (API 34) 设备上运行应用时,NavigationActivity 启动时崩溃:

```
java.lang.SecurityException: com.eopeter.fluttermapboxnavigationexample: 
One of RECEIVER_EXPORTED or RECEIVER_NOT_EXPORTED should be specified when 
a receiver isn't being registered exclusively for system broadcasts
```

## 根本原因

Android 14 (API 34) 引入了新的安全要求:
- 注册 BroadcastReceiver 时必须明确指定接收器的导出状态
- 必须使用 `RECEIVER_EXPORTED` 或 `RECEIVER_NOT_EXPORTED` 标志
- 这是为了防止意外暴露应用内部的广播接收器

## 解决方案

### 修改文件
`android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`

### 修改内容

#### 修改前
```kotlin
private fun setupBroadcastReceivers() {
    // ... 创建 receivers ...
    
    registerReceiver(
        finishBroadcastReceiver,
        IntentFilter(NavigationLauncher.KEY_STOP_NAVIGATION)
    )
    
    registerReceiver(
        addWayPointsBroadcastReceiver,
        IntentFilter(NavigationLauncher.KEY_ADD_WAYPOINTS)
    )
}
```

#### 修改后
```kotlin
private fun setupBroadcastReceivers() {
    // ... 创建 receivers ...
    
    // Android 14+ requires explicit export flag for BroadcastReceiver
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
        registerReceiver(
            finishBroadcastReceiver,
            IntentFilter(NavigationLauncher.KEY_STOP_NAVIGATION),
            Context.RECEIVER_NOT_EXPORTED
        )
        
        registerReceiver(
            addWayPointsBroadcastReceiver,
            IntentFilter(NavigationLauncher.KEY_ADD_WAYPOINTS),
            Context.RECEIVER_NOT_EXPORTED
        )
    } else {
        registerReceiver(
            finishBroadcastReceiver,
            IntentFilter(NavigationLauncher.KEY_STOP_NAVIGATION)
        )
        
        registerReceiver(
            addWayPointsBroadcastReceiver,
            IntentFilter(NavigationLauncher.KEY_ADD_WAYPOINTS)
        )
    }
}
```

## 技术细节

### RECEIVER_NOT_EXPORTED vs RECEIVER_EXPORTED

- **RECEIVER_NOT_EXPORTED**: 接收器只能接收来自同一应用或系统的广播
  - 用于应用内部通信
  - 更安全,防止其他应用发送恶意广播
  - 本例中使用此标志

- **RECEIVER_EXPORTED**: 接收器可以接收来自任何应用的广播
  - 用于跨应用通信
  - 需要谨慎使用,可能存在安全风险

### 版本检查

使用 `Build.VERSION_CODES.TIRAMISU` (API 33) 作为检查点:
- Android 13 (API 33) 引入了这个新 API
- Android 14 (API 34) 强制要求使用
- 为了兼容性,对 API 33+ 都使用新的 API

## 测试结果

### 修复前
- ❌ 应用在 Android 14 设备上启动 NavigationActivity 时崩溃
- ❌ SecurityException 异常

### 修复后
- ✅ 应用在 Android 14 设备上正常启动
- ✅ BroadcastReceiver 正常注册
- ✅ 向后兼容 Android 13 以下版本

## 相关资源

- [Android 14 Behavior Changes](https://developer.android.com/about/versions/14/behavior-changes-14)
- [Context.registerReceiver() Documentation](https://developer.android.com/reference/android/content/Context#registerReceiver(android.content.BroadcastReceiver,%20android.content.IntentFilter,%20int))
- [BroadcastReceiver Security Best Practices](https://developer.android.com/guide/components/broadcasts#security)

## 影响范围

### 受影响的组件
- NavigationActivity.kt

### 不受影响的组件
- 其他 Activity 文件没有使用动态注册的 BroadcastReceiver
- 静态注册的 BroadcastReceiver (在 AndroidManifest.xml 中) 不受影响

## 后续建议

1. 检查其他可能动态注册 BroadcastReceiver 的地方
2. 考虑使用 LocalBroadcastManager 替代全局广播(更安全)
3. 或者使用 EventBus、LiveData 等现代化的事件通信机制

## 总结

成功修复了 Android 14 运行时崩溃问题。通过添加版本检查和使用 `RECEIVER_NOT_EXPORTED` 标志,确保了应用在 Android 14+ 设备上的兼容性,同时保持了对旧版本的向后兼容。
