# Android SDK v3 依赖更新完成报告

## 日期
2026-01-05

## 完成的任务

### 1. 准备和备份 ✅
- 创建了 Git 分支 `feature/android-sdk-v3-upgrade`
- 记录了当前配置状态

### 2. 更新Gradle依赖配置 ✅

#### 2.1 更新 android/build.gradle ✅
- ✅ 更新 Kotlin 版本：1.7.10 → 1.9.22
- ✅ 更新 Android Gradle Plugin：7.4.2 → 8.1.4
- ✅ 更新 compileSdkVersion：33 → 34
- ✅ 更新 targetSdkVersion：33 → 34
- ✅ 更新 Java 版本：1.8 → 17
- ✅ 移除了 buildscript 中的仓库声明（避免与 settings.gradle 冲突）

#### 2.2 更新 Mapbox SDK 依赖 ✅
**移除的 v2 依赖：**
- ❌ `com.mapbox.navigation:copilot:2.16.0`
- ❌ `com.mapbox.navigation:ui-app:2.16.0`
- ❌ `com.mapbox.navigation:ui-dropin:2.16.0` (v3 中已移除)

**添加的 v3 依赖：**
- ✅ `com.mapbox.navigationcore:android:3.10.0`
- ✅ `com.mapbox.navigationcore:copilot:3.10.0`
- ✅ `com.mapbox.navigationcore:ui-maps:3.10.0`
- ✅ `com.mapbox.navigationcore:voice:3.10.0`
- ✅ `com.mapbox.navigationcore:tripdata:3.10.0`
- ✅ `com.mapbox.navigationcore:ui-components:3.10.0` (替代 ui-dropin)
- ✅ `com.mapbox.maps:android:11.4.0`

#### 2.3 更新 example/android 配置 ✅
- ✅ 更新 `example/android/build.gradle`
  - 移除了 `allprojects` 块中的仓库声明冲突
  - 恢复了 `allprojects` 块以支持 Flutter 插件的仓库
- ✅ 更新 `example/android/settings.gradle`
  - 移除了 `dependencyResolutionManagement`（避免与 Flutter 插件冲突）
  - 添加了 Mapbox Maven 仓库配置注释
- ✅ 更新 `example/android/app/build.gradle`
  - 同步了 Java 版本到 17

#### 2.4 清理和同步 ✅
- ✅ 运行了 `./gradlew clean`
- ✅ Gradle 依赖同步成功

## 关键问题和解决方案

### 问题 1: ui-dropin 模块在 v3 中不存在
**错误信息：**
```
Could not find com.mapbox.navigationcore:ui-dropin:3.7.1
```

**原因：**
Mapbox Navigation SDK v3 移除了 `ui-dropin` 模块，改用新的模块组合。

**解决方案：**
使用以下模块替代：
- `ui-components` - UI 组件
- `ui-maps` - 地图 UI
- `tripdata` - 行程数据
- `voice` - 语音指令
- `copilot` - 辅助功能

### 问题 2: Flutter embedding 依赖找不到
**错误信息：**
```
Could not find io.flutter:flutter_embedding_debug:1.0.0-...
```

**原因：**
`settings.gradle` 中的 `dependencyResolutionManagement` 使用 `PREFER_SETTINGS` 模式，忽略了 Flutter 插件添加的仓库。

**解决方案：**
1. 移除 `settings.gradle` 中的 `dependencyResolutionManagement`
2. 在 `example/android/build.gradle` 中恢复 `allprojects` 块
3. 在 `allprojects` 块中配置所有必要的仓库（包括 Mapbox Maven）

### 问题 3: 仓库配置冲突
**错误信息：**
```
Build was configured to prefer settings repositories over project repositories but repository 'maven' was added by build file 'build.gradle'
```

**原因：**
多个地方声明了仓库，导致 Gradle 配置冲突。

**解决方案：**
1. 从 `android/build.gradle` 的 `buildscript` 和 `rootProject.allprojects` 中移除仓库声明
2. 将所有仓库配置集中到 `example/android/build.gradle` 的 `allprojects` 块中
3. 这样可以与 Flutter 插件添加的仓库兼容

## 当前状态

### ✅ 依赖配置完成
- 所有 Gradle 依赖已更新到 v3
- 仓库配置已正确设置
- Gradle 同步成功

### ⚠️ 编译错误（预期中）
项目现在可以正确解析依赖，但出现编译错误，因为代码还在使用 v2 的 API：

```
e: NavigationActivity.kt:445:29 Cannot access class 'NavigationView'. Check your module classpath for missing or conflicting dependencies
e: NavigationActivity.kt:445:44 Unresolved reference: api
e: NavigationActivity.kt:455:17 'onCanceled' overrides nothing
e: NavigationActivity.kt:527:36 Object is not abstract and does not implement abstract member public abstract fun onNewRawLocation(rawLocation: Location): Unit
...
```

这些错误是正常的，因为：
1. `NavigationView` 在 v3 中被重命名为 `MapboxNavigationView`
2. 许多 API 接口发生了变化
3. 事件监听器的签名发生了变化

## 下一步

### 任务 3: Checkpoint - 验证依赖更新 ✅
依赖更新已成功完成，可以继续下一步。

### 任务 4: 更新导入语句和包名
需要更新以下文件的导入语句和 API 调用：
1. `FlutterMapboxNavigationPlugin.kt`
2. `NavigationActivity.kt`
3. `NavigationReplayActivity.kt`
4. 其他使用 Mapbox API 的文件

主要变更：
- `com.mapbox.navigation.ui.app` → `com.mapbox.navigationcore.ui.maps`
- `com.mapbox.navigation.ui.dropin` → `com.mapbox.navigationcore.ui.components`
- `NavigationView` → `MapboxNavigationView`
- 更新事件监听器接口

## 参考文档
- [Mapbox Navigation SDK v3 安装指南](https://docs.mapbox.com/android/navigation/guides/install/)
- [v2 到 v3 迁移指南](https://docs.mapbox.com/android/navigation/guides/migration-from-v2/)
- [v3 API 文档](https://docs.mapbox.com/android/navigation/api/coreframework/3.17.2/)

## 配置文件变更总结

### android/build.gradle
- 移除了所有仓库声明
- 更新了 Mapbox SDK 依赖到 v3
- 更新了 Kotlin 和 Java 版本

### example/android/build.gradle
- 恢复了 `allprojects` 块
- 添加了 Mapbox Maven 仓库配置

### example/android/settings.gradle
- 移除了 `dependencyResolutionManagement`
- 保留了 `pluginManagement` 配置

### example/android/app/build.gradle
- 更新了 Java 版本到 17

## 总结

✅ **依赖更新阶段已成功完成！**

所有 Gradle 配置已正确更新，项目可以正确解析 Mapbox Navigation SDK v3 的依赖。下一步需要更新代码以使用 v3 的 API。

---

**完成时间**: 2026-01-05
**下一任务**: 4. 更新导入语句和包名
