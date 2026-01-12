# Android SDK v3 MVP 编译状态

## 日期
2026-01-05

## 状态
✅ **编译完全成功** - 所有 Kotlin 和 Java 代码编译错误已修复  
✅ **MVP 版本可以构建** - 基础导航功能已实现并可以编译

## 已完成的工作

### 1. 修复了所有 Kotlin 编译错误

#### NavigationActivity.kt
- ✅ 修复 LocationObserver 接口实现（onNewRawLocation 方法签名）
- ✅ 修复 NavigationOptions.Builder 的 accessToken 配置（SDK v3 自动从资源获取）
- ✅ 修复 MapboxRouteLineApi 和 MapboxRouteLineView 的初始化
- ✅ 修复 Location 类型转换（com.mapbox.common.location.Location vs android.location.Location）
- ✅ 修复 VoiceInstructionsObserver 的 announcement() 返回值处理
- ✅ 添加 @OptIn 注解处理实验性 API

#### TurnByTurn.kt
- ✅ 修复 LocationObserver 接口实现
- ✅ 修复 NavigationOptions.Builder 配置
- ✅ 修复 Location 类型转换
- ✅ 注释掉 NavigationView 相关代码（SDK v3 已移除）
- ✅ 修复 NavigationRouterCallback 方法签名（routerOrigin 参数从 RouterOrigin 改为 String）

#### NavigationReplayActivity.kt
- ✅ 修复 LocationObserver 接口实现

#### EmbeddedNavigationMapView.kt
- ✅ 注释掉 NavigationView 和 MapViewObserver 相关代码（SDK v3 已移除）

#### CustomInfoPanelEndNavButtonBinder.kt
- ✅ 注释掉所有 Drop-in UI 相关代码（SDK v3 已移除）

### 2. SDK v3 API 变更适配

#### LocationObserver 接口变更
```kotlin
// SDK v2
interface LocationObserver {
    fun onNewLocationMatcherResult(locationMatcherResult: LocationMatcherResult)
    fun onNewRawLocation(rawLocation: android.location.Location)
}

// SDK v3
interface LocationObserver {
    fun onNewRawLocation(rawLocation: com.mapbox.common.location.Location)  // 方法顺序和类型都变了
    fun onNewLocationMatcherResult(locationMatcherResult: LocationMatcherResult)
}
```

#### NavigationRouterCallback 接口变更
```kotlin
// SDK v2
interface NavigationRouterCallback {
    fun onCanceled(routeOptions: RouteOptions, routerOrigin: RouterOrigin)
    fun onRoutesReady(routes: List<NavigationRoute>, routerOrigin: RouterOrigin)
}

// SDK v3
interface NavigationRouterCallback {
    fun onCanceled(routeOptions: RouteOptions, routerOrigin: String)  // RouterOrigin 改为 String
    fun onRoutesReady(routes: List<NavigationRoute>, routerOrigin: String)
}
```

#### NavigationOptions 配置变更
```kotlin
// SDK v2
NavigationOptions.Builder(context)
    .accessToken(token)
    .build()

// SDK v3
NavigationOptions.Builder(context)
    .build()  // accessToken 自动从资源文件获取
```

#### MapboxNavigationApp.setup 变更
```kotlin
// SDK v2
MapboxNavigationApp.setup(navigationOptions)

// SDK v3
MapboxNavigationApp.setup { navigationOptions }  // 需要 lambda
```

#### Route Line API 变更
```kotlin
// SDK v2
val options = MapboxRouteLineOptions.Builder(context)
    .withRouteLineResources(RouteLineResources.Builder().build())
    .build()
routeLineApi = MapboxRouteLineApi(options)
routeLineView = MapboxRouteLineView(options)

// SDK v3
val apiOptions = MapboxRouteLineApiOptions.Builder().build()
val viewOptions = MapboxRouteLineViewOptions.Builder(context).build()
routeLineApi = MapboxRouteLineApi(apiOptions)
routeLineView = MapboxRouteLineView(viewOptions)  // API 和 View 使用不同的 Options
```

## 已解决的问题

### 1. JDK 兼容性问题 ✅

**问题：** JDK 21 与 Gradle 8.5 + Android SDK 34 存在兼容性问题

**解决方案：**
- 安装并配置 JDK 17
- 在 `example/android/gradle.properties` 中配置：
  ```properties
  org.gradle.java.home=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
  org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m -XX:+HeapDumpOnOutOfMemoryError
  ```

### 2. Data Binding 生成代码错误 ✅

**问题：** 旧的布局文件 `components_navigation_activity.xml` 包含 SDK v2 UI 组件

**解决方案：**
- 删除 `android/src/main/res/layout/components_navigation_activity.xml`
- 使用新的 `navigation_activity.xml` 布局文件

## 编译警告（非阻塞）

以下警告不影响编译，但建议后续处理：

1. **Deprecated API 使用**
   - `getMapboxMap()` → 使用 `mapboxMap` 属性
   - `getStyle()` → 使用 `style` 属性
   - `loadStyleUri()` → 使用新的样式加载方法
   - `cameraForCoordinates()` → 使用新的相机 API

2. **未使用的参数**
   - TurnByTurn.kt 中的一些方法参数未使用

3. **版本警告**
   - Gradle 8.5.0 建议升级到 8.7.0+
   - Android Gradle Plugin 8.1.4 建议升级到 8.6.0+
   - Kotlin 1.9.22 建议升级到 2.1.0+

## MVP 功能状态

### ✅ 已实现
- 基础地图显示
- 路线规划和显示
- 导航启动/停止
- 位置跟踪
- 进度事件（距离、时间、到达等）
- 语音指令
- Banner 指令
- 离线路由检测
- 重新路由

### ⚠️ 临时禁用（等待 v3 适配）
- Free Drive 模式（需要重写）
- Embedded Navigation View（需要重写）
- Custom Info Panel（需要重写）
- 地图点击回调（需要重写）

### ❌ 未实现（非 MVP 范围）
- 历史记录回放（完整功能）
- 搜索功能
- 路线选择
- 地图样式选择器

## 下一步

### 1. ✅ 编译成功 - 已完成

### 2. 测试 MVP 功能
- 在真实设备或模拟器上运行应用
- 测试基础导航功能：
  * 路线规划
  * 导航启动/停止
  * 位置跟踪
  * 进度事件回调
  * 语音指令
  * 到达检测

### 3. 完善临时禁用的功能
- 重写 Free Drive 模式（使用 SDK v3 API）
- 重写 Embedded Navigation View（使用 SDK v3 API）
- 实现地图手势处理

### 4. 处理编译警告
- 更新 deprecated API 使用：
  * `getMapboxMap()` → `mapboxMap` 属性
  * `getStyle()` → `style` 属性
  * `loadStyleUri()` → 新的样式加载方法
  * `cameraForCoordinates()` → 新的相机 API
- 清理未使用的参数
- 考虑升级 Gradle、AGP 和 Kotlin 版本（可选）

### 5. 实现缺失的高级功能
- 历史记录回放（完整功能）
- 搜索功能
- 路线选择
- 地图样式选择器

## 参考文档

- [Mapbox Navigation SDK v3 Migration Guide](https://docs.mapbox.com/android/navigation/guides/migrate-to-v3/)
- [SDK v3 Breaking Changes](ANDROID_SDK_V3_MAJOR_CHANGES.md)
- [Migration Status](ANDROID_SDK_V3_MIGRATION_STATUS.md)
