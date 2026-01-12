# Android Mapbox Navigation SDK v3 升级指南

## 概述

本指南提供从Mapbox Navigation SDK v2.16.0升级到v3.17.2的详细步骤和注意事项。

## 当前状态

- **当前版本**: v2.16.0
- **目标版本**: v3.17.2
- **升级类型**: 重大版本升级（Breaking Changes）
- **预计工作量**: 2-3周

## 主要变更

### 1. 包名变更

| v2 | v3 |
|----|-----|
| `com.mapbox.navigation.ui.app` | `com.mapbox.navigation.dropin` |
| `com.mapbox.navigation.core` | `com.mapbox.navigation.base` |
| `com.mapbox.navigation.ui.maps` | `com.mapbox.navigation.ui.maps` (保持) |

### 2. 依赖项变更

#### v2依赖（当前）
```gradle
dependencies {
    implementation "com.mapbox.navigation:copilot:2.16.0"
    implementation "com.mapbox.navigation:ui-app:2.16.0"
    implementation "com.mapbox.navigation:ui-dropin:2.16.0"
}
```

#### v3依赖（目标）
```gradle
dependencies {
    // 核心导航SDK
    implementation "com.mapbox.navigation:android:3.17.2"
    
    // Drop-in UI（推荐）
    implementation "com.mapbox.navigation:ui-dropin:3.17.2"
    
    // 或者使用自定义UI组件
    implementation "com.mapbox.navigation:ui-components:3.17.2"
    
    // 地图SDK（必需）
    implementation "com.mapbox.maps:android:11.0.0"
}
```

### 3. 初始化变更

#### v2初始化
```kotlin
val navigationOptions = NavigationOptions.Builder(context)
    .accessToken(accessToken)
    .build()

val mapboxNavigation = MapboxNavigation(navigationOptions)
```

#### v3初始化
```kotlin
val navigationOptions = NavigationOptions.Builder(context)
    .accessToken(accessToken)
    .build()

val mapboxNavigation = MapboxNavigationProvider.create(navigationOptions)
```

### 4. NavigationView变更

#### v2
```kotlin
// 使用 NavigationView
val navigationView = findViewById<NavigationView>(R.id.navigationView)
```

#### v3
```kotlin
// 使用 MapboxNavigationView (Drop-in UI)
val navigationView = findViewById<MapboxNavigationView>(R.id.navigationView)
```

### 5. 事件监听变更

#### v2
```kotlin
mapboxNavigation.registerRouteProgressObserver(object : RouteProgressObserver {
    override fun onRouteProgressChanged(routeProgress: RouteProgress) {
        // 处理进度更新
    }
})
```

#### v3
```kotlin
mapboxNavigation.registerRouteProgressObserver(object : RouteProgressObserver {
    override fun onRouteProgressChanged(routeProgress: RouteProgress) {
        // 处理进度更新
    }
})
// API保持相似，但内部实现有变化
```

### 6. 历史记录API变更

#### v2
```kotlin
val historyRecorder = mapboxNavigation.historyRecorder
historyRecorder.startRecording()
```

#### v3
```kotlin
// 使用新的History API
val historyRecorder = MapboxHistoryRecorder()
historyRecorder.startRecording()

// 读取历史记录
val historyReader = MapboxHistoryReader(historyFilePath)
val events = historyReader.parse()
```

## 升级步骤

### 步骤1：更新Gradle配置

1. 更新 `android/build.gradle`:

```gradle
buildscript {
    ext.kotlin_version = '1.9.22'  // 从1.7.10升级
    ext.android_gradle_version = '8.1.4'  // 从7.4.2升级
    
    dependencies {
        classpath "com.android.tools.build:gradle:$android_gradle_version"
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

android {
    compileSdkVersion 34  // 从33升级
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34  // 从33升级
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17  // 从1.8升级
        targetCompatibility JavaVersion.VERSION_17
    }
    
    kotlinOptions {
        jvmTarget = '17'  // 从1.8升级
    }
}

dependencies {
    // 移除v2依赖
    // implementation "com.mapbox.navigation:copilot:2.16.0"
    // implementation "com.mapbox.navigation:ui-app:2.16.0"
    // implementation "com.mapbox.navigation:ui-dropin:2.16.0"
    
    // 添加v3依赖
    implementation "com.mapbox.navigation:android:3.17.2"
    implementation "com.mapbox.navigation:ui-dropin:3.17.2"
    
    // 更新其他依赖
    implementation "androidx.core:core-ktx:1.12.0"
    implementation "com.google.android.material:material:1.11.0"
    implementation "androidx.appcompat:appcompat:1.6.1"
}
```

2. 更新 `gradle.properties`:

```properties
# 添加v3所需的配置
android.useAndroidX=true
android.enableJetifier=true
org.gradle.jvmargs=-Xmx4096m
```

### 步骤2：更新导入语句

在所有Kotlin文件中更新导入：

```kotlin
// 移除v2导入
// import com.mapbox.navigation.ui.app.*
// import com.mapbox.navigation.copilot.*

// 添加v3导入
import com.mapbox.navigation.dropin.*
import com.mapbox.navigation.base.*
import com.mapbox.navigation.core.*
```

### 步骤3：迁移NavigationActivity

#### 当前代码（v2）
```kotlin
class NavigationActivity : AppCompatActivity() {
    private lateinit var mapboxNavigation: MapboxNavigation
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val navigationOptions = NavigationOptions.Builder(this)
            .accessToken(getString(R.string.mapbox_access_token))
            .build()
            
        mapboxNavigation = MapboxNavigation(navigationOptions)
    }
}
```

#### 升级后代码（v3）
```kotlin
class NavigationActivity : AppCompatActivity() {
    private lateinit var mapboxNavigation: MapboxNavigation
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val navigationOptions = NavigationOptions.Builder(this)
            .accessToken(getString(R.string.mapbox_access_token))
            .build()
            
        mapboxNavigation = MapboxNavigationProvider.create(navigationOptions)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        MapboxNavigationProvider.destroy()
    }
}
```

### 步骤4：迁移历史记录功能

#### v2代码
```kotlin
// 开始记录
val historyRecorder = mapboxNavigation.historyRecorder
historyRecorder.startRecording()

// 停止记录
historyRecorder.stopRecording { filePath ->
    // 保存文件路径
}
```

#### v3代码
```kotlin
// 开始记录
val historyRecorder = MapboxHistoryRecorder()
historyRecorder.startRecording()

// 停止记录
historyRecorder.stopRecording { result ->
    result.onValue { filePath ->
        // 保存文件路径
    }.onError { error ->
        // 处理错误
    }
}

// 读取历史记录
val historyReader = MapboxHistoryReader(filePath)
val events = historyReader.parse()
```

### 步骤5：迁移事件监听

#### v2代码
```kotlin
mapboxNavigation.registerRouteProgressObserver(routeProgressObserver)
mapboxNavigation.registerArrivalObserver(arrivalObserver)
```

#### v3代码
```kotlin
// API基本保持一致，但需要注意生命周期管理
mapboxNavigation.registerRouteProgressObserver(routeProgressObserver)
mapboxNavigation.registerArrivalObserver(arrivalObserver)

// 记得在适当时机注销
override fun onDestroy() {
    mapboxNavigation.unregisterRouteProgressObserver(routeProgressObserver)
    mapboxNavigation.unregisterArrivalObserver(arrivalObserver)
    super.onDestroy()
}
```

### 步骤6：更新UI组件

#### v2 Drop-in UI
```xml
<com.mapbox.navigation.ui.app.NavigationView
    android:id="@+id/navigationView"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

#### v3 Drop-in UI
```xml
<com.mapbox.navigation.dropin.MapboxNavigationView
    android:id="@+id/navigationView"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

### 步骤7：测试清单

完成升级后，需要测试以下功能：

- [ ] 基本导航启动和停止
- [ ] 路线计算和显示
- [ ] 转弯指示和语音播报
- [ ] 到达目的地检测
- [ ] 路线偏离和重新规划
- [ ] 自由驾驶模式
- [ ] 历史记录录制
- [ ] 历史记录读取
- [ ] 嵌入式导航视图
- [ ] 地图样式切换
- [ ] 事件传递到Flutter层

## 常见问题

### Q1: 编译错误 "Cannot find symbol: class NavigationView"

**A**: 确保已更新导入语句，v3中使用 `MapboxNavigationView` 而不是 `NavigationView`。

### Q2: 运行时错误 "MapboxNavigationProvider not initialized"

**A**: 确保在使用前调用 `MapboxNavigationProvider.create()`，并在销毁时调用 `MapboxNavigationProvider.destroy()`。

### Q3: 历史记录文件格式不兼容

**A**: v3的历史记录格式与v2不同，可能需要转换工具。检查Mapbox官方文档了解迁移方案。

### Q4: 性能下降

**A**: v3进行了大量优化，如果遇到性能问题，检查：
- 是否正确管理了生命周期
- 是否有内存泄漏
- 是否使用了推荐的API

### Q5: UI样式不一致

**A**: v3的Drop-in UI有新的样式系统，需要重新配置主题和样式。

## 回滚计划

如果升级遇到严重问题，可以回滚到v2：

1. 恢复 `android/build.gradle` 到v2配置
2. 恢复所有代码文件
3. 运行 `flutter clean`
4. 重新构建项目

建议在升级前：
- 创建Git分支
- 备份当前工作代码
- 记录所有修改

## 参考资源

- [官方迁移指南](https://docs.mapbox.com/android/navigation/guides/migration-from-v2/)
- [v3 API文档](https://docs.mapbox.com/android/navigation/api/coreframework/3.17.2/)
- [v3示例代码](https://github.com/mapbox/mapbox-navigation-android-examples)
- [v3发布说明](https://github.com/mapbox/mapbox-navigation-android/releases/tag/v3.17.2)

## 时间线

| 阶段 | 任务 | 预计时间 |
|------|------|----------|
| 1 | 依赖更新和编译修复 | 2-3天 |
| 2 | API迁移 | 3-5天 |
| 3 | UI组件迁移 | 2-3天 |
| 4 | 历史记录功能迁移 | 2-3天 |
| 5 | 测试和修复 | 3-5天 |
| 6 | 文档更新 | 1-2天 |
| **总计** | | **2-3周** |

## 下一步

完成SDK升级后，可以开始实现以下功能：
1. 历史记录事件解析（HistoryEventsParser）
2. 完整的历史记录回放
3. 搜索功能集成
4. 路由选择功能
5. 地图样式选择器增强

---

**创建日期**: 2026-01-05
**维护者**: Flutter Mapbox Navigation Team
**状态**: 待执行
