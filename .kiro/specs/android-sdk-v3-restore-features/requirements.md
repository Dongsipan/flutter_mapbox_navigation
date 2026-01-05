# Requirements Document - Android SDK v3 恢复临时禁用的功能

## Introduction

在 Android Mapbox Navigation SDK v3 MVP 迁移过程中，由于 Drop-in UI 组件被完全移除，我们临时禁用了一些高级功能。本规格文档定义了使用 SDK v3 核心 API 重新实现这些功能的需求。

## Glossary

- **Free Drive Mode**: 自由驾驶模式，不需要设定目的地的导航模式
- **Embedded Navigation View**: 嵌入式导航视图，可以嵌入到 Flutter 应用中的导航组件
- **Custom Info Panel**: 自定义信息面板，用于显示导航信息和控制按钮
- **Map Tap Callback**: 地图点击回调，当用户点击地图时触发的事件
- **TurnByTurn**: 转弯导航类，处理导航逻辑和事件
- **Drop-in UI**: Mapbox v2 提供的即插即用 UI 组件（v3 已移除）
- **Core API**: Mapbox Navigation SDK v3 的核心 API

## Requirements

### Requirement 1: Free Drive 模式

**User Story:** 作为用户，我希望能够启动自由驾驶模式，这样我可以在不设定目的地的情况下使用导航功能进行位置跟踪。

#### Acceptance Criteria

1. WHEN 用户调用 startFreeDrive() THEN 系统应启动 trip session 而不设置路线
2. WHEN Free Drive 模式激活 THEN 系统应持续更新用户位置
3. WHEN Free Drive 模式激活 THEN 系统应在地图上显示用户位置和方向
4. WHEN Free Drive 模式激活 THEN 系统应发送位置更新事件到 Flutter 层
5. WHEN 用户停止 Free Drive THEN 系统应停止 trip session 并清理资源
6. THE 系统应使用 MapboxNavigation.startTripSession() 而不是已移除的 NavigationView API

### Requirement 2: 路线预览和导航启动

**User Story:** 作为用户，我希望在开始导航前能够预览路线，并能够顺利启动导航。

#### Acceptance Criteria

1. WHEN 路线构建完成 THEN 系统应在地图上绘制路线
2. WHEN 显示路线预览 THEN 系统应调整相机以显示完整路线
3. WHEN 用户启动导航 THEN 系统应设置导航路线并启动 trip session
4. WHEN 导航启动 THEN 系统应根据 simulateRoute 设置选择真实导航或模拟导航
5. THE 系统应使用 MapboxRouteLineApi 和 MapboxRouteLineView 绘制路线
6. THE 系统应使用 MapboxNavigation.setNavigationRoutes() 设置路线

### Requirement 3: 嵌入式导航视图

**User Story:** 作为开发者，我希望能够在 Flutter 应用中嵌入导航视图，这样用户可以在应用内使用导航功能。

#### Acceptance Criteria

1. WHEN 创建嵌入式视图 THEN 系统应初始化 MapView 和 MapboxNavigation
2. WHEN 嵌入式视图显示 THEN 系统应正确显示地图和导航元素
3. WHEN 用户与嵌入式视图交互 THEN 系统应响应手势和点击事件
4. WHEN 嵌入式视图销毁 THEN 系统应正确清理资源和注销监听器
5. THE 系统应使用 MapView 和核心 API 替代已移除的 NavigationView
6. THE 系统应支持自定义地图样式和 UI 配置

### Requirement 4: 地图点击回调

**User Story:** 作为用户，我希望能够点击地图上的位置，这样我可以设置目的地或查看位置信息。

#### Acceptance Criteria

1. WHEN 用户点击地图 THEN 系统应触发 onMapTap 事件
2. WHEN onMapTap 事件触发 THEN 系统应将点击坐标发送到 Flutter 层
3. WHEN enableOnMapTapCallback 为 true THEN 系统应注册地图点击监听器
4. WHEN enableOnMapTapCallback 为 false THEN 系统应不注册地图点击监听器
5. THE 系统应使用 MapView.gestures.addOnMapClickListener() 实现点击监听
6. THE 系统应在视图销毁时注销点击监听器

### Requirement 5: 长按设置目的地

**User Story:** 作为用户，我希望能够长按地图设置目的地，这样我可以快速规划路线。

#### Acceptance Criteria

1. WHEN 用户长按地图 THEN 系统应触发 onMapLongClick 事件
2. WHEN onMapLongClick 事件触发 THEN 系统应使用当前位置和长按位置构建路线
3. WHEN longPressDestinationEnabled 为 true THEN 系统应注册长按监听器
4. WHEN longPressDestinationEnabled 为 false THEN 系统应不注册长按监听器
5. THE 系统应使用 MapView.gestures.addOnMapLongClickListener() 实现长按监听
6. THE 系统应自动请求从当前位置到长按位置的路线

### Requirement 6: 自定义信息面板

**User Story:** 作为用户，我希望看到导航信息面板，这样我可以了解导航状态并控制导航。

#### Acceptance Criteria

1. WHEN 导航启动 THEN 系统应显示信息面板
2. WHEN 导航进行中 THEN 系统应更新面板上的距离和时间信息
3. WHEN 用户点击结束导航按钮 THEN 系统应停止导航并隐藏面板
4. THE 系统应使用自定义 View 替代已移除的 Drop-in UI 组件
5. THE 系统应在布局文件中定义信息面板 UI
6. THE 系统应通过 ViewBinding 访问和更新面板元素

### Requirement 7: 模拟导航支持

**User Story:** 作为开发者，我希望能够启用模拟导航，这样我可以在没有真实移动的情况下测试导航功能。

#### Acceptance Criteria

1. WHEN simulateRoute 为 true THEN 系统应使用 startReplayTripSession()
2. WHEN simulateRoute 为 false THEN 系统应使用 startTripSession()
3. WHEN 模拟导航启动 THEN 系统应使用 MapboxReplayer 播放路线
4. WHEN 模拟导航进行中 THEN 系统应发送模拟的位置更新
5. THE 系统应支持调整模拟速度
6. THE 系统应在真实导航和模拟导航之间正确切换

### Requirement 8: 事件传递完整性

**User Story:** 作为开发者，我希望所有导航事件都能正确传递到 Flutter 层，这样 Flutter 应用可以响应导航状态变化。

#### Acceptance Criteria

1. WHEN 路线构建完成 THEN 系统应发送 ROUTE_BUILT 事件
2. WHEN 导航启动 THEN 系统应发送 NAVIGATION_RUNNING 事件
3. WHEN 导航取消 THEN 系统应发送 NAVIGATION_CANCELLED 事件
4. WHEN 路线构建失败 THEN 系统应发送 ROUTE_BUILD_FAILED 事件
5. THE 系统应确保所有事件都通过 EventChannel 正确发送
6. THE 系统应在 TurnByTurn 类中正确处理所有事件

### Requirement 9: 资源管理和生命周期

**User Story:** 作为开发者，我希望系统能够正确管理资源和生命周期，这样可以避免内存泄漏和崩溃。

#### Acceptance Criteria

1. WHEN Activity 创建 THEN 系统应初始化 MapboxNavigation 和观察者
2. WHEN Activity 销毁 THEN 系统应注销所有观察者并清理资源
3. WHEN 导航停止 THEN 系统应停止 trip session 并清理路线
4. THE 系统应使用 MapboxNavigationApp 管理导航生命周期
5. THE 系统应在适当的生命周期回调中注册和注销观察者
6. THE 系统应避免内存泄漏和资源泄漏

### Requirement 10: 向后兼容性

**User Story:** 作为开发者，我希望新实现能够保持与现有 Flutter API 的兼容性，这样不需要修改 Flutter 层代码。

#### Acceptance Criteria

1. WHEN Flutter 调用 startFreeDrive() THEN Android 应正确响应
2. WHEN Flutter 调用 startNavigation() THEN Android 应正确响应
3. WHEN Flutter 调用 buildRoute() THEN Android 应正确响应
4. WHEN Flutter 调用 clearRoute() THEN Android 应正确响应
5. THE 系统应保持所有现有的 MethodChannel 方法签名
6. THE 系统应保持所有现有的事件格式和结构

## 优先级

### 高优先级（本周）
- Requirement 1: Free Drive 模式
- Requirement 2: 路线预览和导航启动
- Requirement 8: 事件传递完整性

### 中优先级（下周）
- Requirement 4: 地图点击回调
- Requirement 5: 长按设置目的地
- Requirement 7: 模拟导航支持

### 低优先级（未来）
- Requirement 3: 嵌入式导航视图
- Requirement 6: 自定义信息面板

## 技术约束

1. 必须使用 Mapbox Navigation SDK v3 核心 API
2. 不能使用已移除的 Drop-in UI 组件
3. 必须保持与 Flutter 层的 API 兼容性
4. 必须支持 Android API 21+
5. 必须使用 Kotlin 1.9.22+

## 成功标准

- ✅ 所有临时禁用的功能都已重新实现
- ✅ 所有功能测试通过
- ✅ 与 Flutter 层的集成正常工作
- ✅ 无内存泄漏或资源泄漏
- ✅ 代码符合 Android 和 Kotlin 最佳实践

---

**创建日期**: 2026-01-05
**状态**: 待实施
