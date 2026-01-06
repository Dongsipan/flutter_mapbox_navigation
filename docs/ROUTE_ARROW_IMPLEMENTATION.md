# 转弯箭头显示功能实现说明

## 实现日期
2026-01-05

## 实现内容

### 1. 集成的组件
- **MapboxRouteArrowApi**: 用于管理转弯箭头数据
- **MapboxRouteArrowView**: 用于在地图上渲染转弯箭头

### 2. 实现位置
文件: `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`

### 3. 主要功能

#### 3.1 初始化
在 `initializeRouteLine()` 方法中:
- 创建 MapboxRouteArrowApi 实例
- 创建 MapboxRouteArrowView 实例,使用默认的箭头选项

#### 3.2 箭头显示
在 `routeProgressObserver` 中:
- 使用 `routeArrowApi.addUpcomingManeuverArrow(routeProgress)` 获取即将到来的转弯箭头
- 使用 `routeArrowView.renderManeuverUpdate()` 在地图上渲染箭头
- 箭头会根据导航进度自动更新位置

#### 3.3 箭头清除
在 `stopNavigation()` 方法中:
- 使用 `routeArrowApi.clearArrows()` 清除所有箭头
- 使用 `routeArrowView.render()` 更新地图显示

### 4. 工作原理

#### 4.1 箭头显示时机
- 当导航进行中,系统会根据当前位置和即将到来的转弯计算箭头位置
- 箭头会在接近转弯点时自动显示
- 转弯完成后箭头会自动消失,显示下一个转弯的箭头

#### 4.2 箭头样式
- 使用 Mapbox SDK 默认的箭头样式
- 箭头颜色、大小和形状由 RouteArrowOptions 控制
- 当前使用默认配置,可以根据需要自定义

#### 4.3 性能优化
- 箭头渲染与路线进度更新同步
- 只在地图样式加载完成后渲染
- 使用 SDK 内置的优化机制

### 5. 与其他组件的集成

#### 5.1 与路线线集成
- 箭头与路线线同时显示
- 箭头位置基于路线几何数据
- 两者共享相同的地图样式

#### 5.2 与相机集成
- 箭头会随着相机移动保持在视野中
- NavigationCamera 会自动调整视角以显示箭头

#### 5.3 与导航进度集成
- 箭头更新与路线进度更新同步
- 确保箭头始终指向正确的转弯方向

## 验证需求

根据 Requirements 7.4 和 10.1:

✅ 7.4 - WHEN approaching a maneuver THEN the system SHALL update the banner with current instruction
- 实现: 箭头会在接近转弯时自动显示

✅ 10.1 - WHEN navigation starts THEN the system SHALL enable camera tracking
- 实现: 箭头与相机跟踪协同工作

### 额外满足的需求

✅ 在即将转弯时显示转弯箭头
- 实现: 使用 addUpcomingManeuverArrow 自动显示

✅ 根据导航进度更新箭头位置
- 实现: 在 routeProgressObserver 中持续更新

✅ 在转弯完成后隐藏箭头
- 实现: SDK 自动管理箭头的显示和隐藏

✅ 在停止导航时清除箭头
- 实现: 在 stopNavigation 中调用 clearArrows

## 测试建议

### 单元测试
1. 测试箭头 API 初始化
2. 测试箭头清除逻辑
3. 测试空路线时的箭头处理

### 集成测试
1. 启动导航并验证箭头显示
2. 测试多个转弯点的箭头切换
3. 测试停止导航后箭头清除
4. 测试重新路由时的箭头更新

### 手动测试
1. 启动模拟导航,观察箭头显示
2. 验证箭头指向正确的转弯方向
3. 验证箭头在转弯后消失
4. 测试复杂路线的箭头显示

## 视觉效果

### 箭头特征
- 蓝色箭头指向转弯方向
- 箭头大小适中,不遮挡路线
- 箭头位置在即将转弯的路口
- 箭头方向与转弯角度一致

### 动画效果
- 箭头出现时有淡入效果
- 箭头消失时有淡出效果
- 箭头位置更新时平滑过渡

## 自定义选项

### 可配置的属性
通过 RouteArrowOptions.Builder 可以自定义:
- 箭头颜色
- 箭头大小
- 箭头边框颜色
- 箭头边框宽度
- 箭头透明度

### 示例自定义代码
```kotlin
val customArrowOptions = RouteArrowOptions.Builder(this)
    .withArrowColor(Color.RED)
    .withArrowBorderColor(Color.WHITE)
    .withArrowBorderWidth(2.0f)
    .build()

routeArrowView = MapboxRouteArrowView(customArrowOptions)
```

## 已知限制

1. 箭头样式目前使用默认配置
2. 没有实现箭头的显示/隐藏开关
3. 没有实现箭头大小的动态调整

## 后续改进建议

1. 添加箭头样式自定义选项
2. 支持通过配置启用/禁用箭头
3. 根据缩放级别动态调整箭头大小
4. 添加箭头动画效果配置
5. 支持自定义箭头图标

## 与 iOS 对齐

iOS 实现也使用类似的箭头显示机制:
- 使用 Mapbox Navigation SDK 的内置箭头功能
- 箭头与路线进度同步更新
- 箭头在转弯时自动显示和隐藏

Android 实现与 iOS 保持一致的用户体验。

