# 实现计划：历史轨迹静态渐变显示

## 概述

本实现计划将 NavigationReplayActivity 从动画回放模式重构为静态轨迹渐变显示模式。重构将移除所有动画和回放相关代码，简化为直接加载、解析和绘制速度渐变轨迹。

## 任务

- [x] 1. 移除不需要的组件和代码 ✅ **已完成**
  - ✅ 移除 MapboxReplayer、ReplayLocationEngine 相关代码
  - ✅ 移除 LocationObserver 和 NavigationLocationProvider
  - ✅ 移除 NavigationCamera 和 ViewportDataSource
  - ✅ 移除相机跟随逻辑（shouldUpdateCamera 方法）
  - ✅ 移除全览/跟随模式切换逻辑（switchToFollowingMode、switchToOverviewMode、updateOverviewButtonState 方法）
  - ✅ 移除路线绘制组件引用
  - ✅ 移除回放统计相关代码和注释
  - ✅ 移除 colorForSpeedExpr() 未使用的方法
  - ✅ 移除 preDrawCompleteRoute() 旧方法
  - ✅ 简化导入语句
  - ✅ 隐藏全览按钮（routeOverview.visibility = View.GONE）
  - _需求: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 2. 重构历史文件加载逻辑 ✅ **已完成**
  - [x] 2.1 简化 handleReplayFile() 方法 ✅
    - ✅ 移除回放引擎初始化代码
    - ✅ 移除回放倍速计算逻辑（recommendReplaySpeed 函数）
    - ✅ 移除 startReplayTripSession() 调用
    - ✅ 移除 dumpOnly 逻辑
    - ✅ 移除路线提取代码
    - ✅ 只保留历史事件加载逻辑
    - ✅ 调用 extractLocationData() 和 drawCompleteRoute()
    - _需求: 3.1, 3.2_
  
  - [x] 2.2 实现位置数据提取函数 ✅
    - ✅ 创建 extractLocationData() 方法
    - ✅ 遍历所有历史事件，提取位置和速度
    - ✅ 使用反射获取位置字段（latitude, longitude, speed）
    - ✅ 过滤无效坐标（0, 0）和过近的点（< 0.5米）
    - ✅ 计算累计距离
    - ✅ 填充三个列表：traveledPoints, traveledSpeedsKmh, traveledCumDistMeters
    - _需求: 1.2, 3.5_

- [x] 3. 实现轨迹绘制功能 ✅ **已完成**
  - [x] 3.1 更新图层初始化逻辑 ✅
    - ✅ 确保 GeoJsonSource 开启 lineMetrics(true)
    - ✅ 设置 LineLayer 的初始属性（lineWidth: 8.0, lineJoin: ROUND）
    - ✅ 确保图层添加在正确位置（location indicator 下方）
    - _需求: 1.3, 6.1_
  
  - [x] 3.2 实现 drawCompleteRoute() 方法 ✅
    - ✅ 检查轨迹点数量（至少2个点）
    - ✅ 构建 LineString 几何对象
    - ✅ 更新 GeoJsonSource 的 feature
    - ✅ 设置起点和终点标记
    - ✅ 调用 adjustCameraToShowRoute()
    - ✅ 调用 buildSpeedGradientExpression()
    - ✅ 应用渐变到 LineLayer
    - _需求: 1.1, 1.5_

- [x] 4. 实现速度渐变逻辑 ✅ **已完成**
  - [x] 4.1 实现 getColorForSpeed() 方法 ✅
    - ✅ 根据速度范围返回对应颜色代码
    - ✅ 使用 when 表达式实现分段映射（7个速度区间）
    - ✅ 颜色映射：<5km/h 蓝色, <10 青色, <15 绿色, <20 黄绿, <25 黄色, <30 橙色, ≥30 红色
    - _需求: 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8_
  
  - [x] 4.2 实现 buildSpeedGradientExpression() 方法 ✅
    - ✅ 检查数据有效性（点数、速度数、距离数）
    - ✅ 计算总距离
    - ✅ 采样渐变节点（最多20个）
    - ✅ 根据累计距离计算每个节点的进度值（0-1）
    - ✅ 确保进度值严格递增
    - ✅ 使用 interpolate + lineProgress 构建表达式
    - ✅ 为每个节点添加 stop（进度值 + 颜色）
    - _需求: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 5. 实现相机全览功能 ✅ **已完成**
  - [x] 5.1 实现 adjustCameraToShowRoute() 方法 ✅
    - ✅ 计算所有轨迹点的边界（minLat, maxLat, minLng, maxLng）
    - ✅ 添加 30% 边距
    - ✅ 计算中心点
    - ✅ 调用 calculateOverviewZoom() 计算缩放级别
    - ✅ 使用 setCamera() 设置相机位置
    - _需求: 4.1, 4.2, 4.3_
  
  - [x] 5.2 实现 calculateOverviewZoom() 方法 ✅
    - ✅ 根据轨迹范围（latDiff, lonDiff）计算合适的缩放级别
    - ✅ 使用分段逻辑返回合理的缩放值（10-17）
    - _需求: 4.3, 4.5_

- [x] 6. 简化 UI 组件 ✅ **已完成**
  - [x] 6.1 隐藏不需要的控件 ✅
    - ✅ 隐藏全览按钮（routeOverview.visibility = View.GONE）
    - ✅ 确认比例尺已隐藏（scalebar.enabled = false）
    - _需求: 5.5, 5.6_
  
  - [x] 6.2 移除相关事件监听器 ✅
    - ✅ 移除全览按钮的点击监听器（已在 Task 1 中移除）
    - ✅ 移除手势处理器（NavigationBasicGesturesHandler）
    - _需求: 7.5_

- [x] 7. 更新 onCreate() 和 initNavigation() ✅ **已完成**
  - [x] 7.1 简化 onCreate() 方法 ✅
    - ✅ 移除 MapboxNavigationApp.setup() 调用
    - ✅ 移除 requireMapboxNavigation 委托
    - ✅ 在样式加载完成后调用 initTravelLineLayer()
    - ✅ 在样式加载完成后调用 adjustMapComponentsForStatusBar()
    - ✅ 在样式加载完成后调用 handleReplayFile()
    - _需求: 3.1_
  
  - [x] 7.2 简化 initNavigation() 方法 ✅
    - ✅ 方法已重命名为 initTravelLineLayer()
    - ✅ 只保留图层初始化逻辑
    - ✅ 移除 NavigationCamera 和 ViewportDataSource 初始化
    - ✅ 移除 location component 配置
    - ✅ 移除全览按钮相关代码
    - _需求: 7.1, 7.2, 7.3, 7.4_

- [x] 8. 清理和优化 ✅ **已完成**
  - [x] 8.1 移除未使用的导入 ✅
    - ✅ 移除 MapboxNavigation 相关导入
    - ✅ 移除 LocationObserver 相关导入
    - ✅ 移除 NavigationCamera 相关导入
    - ✅ 移除 ReplayStats 相关导入
    - ✅ 保留必要的导入（ReplayEventBase, Point, LineString, Feature, etc.）
    - _需求: 7.7_
  
  - [x] 8.2 移除未使用的属性 ✅
    - ✅ 移除 navigationLocationProvider
    - ✅ 移除 isLocationInitialized
    - ✅ 移除 isOverviewMode
    - ✅ 移除 lastCameraUpdateTime
    - ✅ 移除 navigationCamera 和 viewportDataSource
    - ✅ 移除 lastPointTimeMs, travelLastUpdateAt, gradientLastUpdateAt
    - ✅ 移除 startPointAdded, endPointCoord
    - ✅ 保留必要的属性（traveledPoints, traveledSpeedsKmh, traveledCumDistMeters）
    - _需求: 7.3, 7.4, 7.5_
  
  - [x] 8.3 移除未使用的方法 ✅
    - ✅ 移除 locationObserver 对象
    - ✅ 移除 mapboxNavigation 委托
    - ✅ 移除 shouldUpdateCamera()
    - ✅ 移除 switchToFollowingMode()
    - ✅ 移除 switchToOverviewMode()
    - ✅ 移除 updateOverviewButtonState()
    - ✅ 移除 colorForSpeedExpr()
    - ✅ 移除 preDrawCompleteRoute()
    - _需求: 7.3, 7.4, 7.5_

- [ ] 9. 测试和验证
  - [ ] 9.1 功能测试
    - 测试加载小型历史文件（< 100点）
    - 测试加载中型历史文件（100-500点）
    - 测试加载大型历史文件（> 500点）
    - 验证轨迹颜色渐变正确
    - 验证起终点标记位置正确
    - 验证相机全览显示完整轨迹
    - _需求: 1.1, 2.1, 4.1_
  
  - [ ] 9.2 UI 测试
    - 验证标题栏显示正确
    - 验证返回按钮功能正常
    - 验证罗盘位置正确
    - 验证全览按钮已隐藏
    - 验证比例尺已隐藏
    - _需求: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_
  
  - [ ] 9.3 错误处理测试
    - 测试空文件路径的处理
    - 测试不存在的文件的处理
    - 测试无效历史文件的处理
    - 测试轨迹点不足的处理
    - _需求: 8.1, 8.2, 8.3, 8.4_

- [ ] 10. 最终检查点
  - 确保所有测试通过
  - 确认代码无编译错误和警告
  - 验证页面加载流畅，无卡顿
  - 确认内存使用合理
  - 询问用户是否有问题

## 注意事项

- 每个任务完成后进行编译检查，确保无错误
- 保留必要的日志输出，便于调试
- 注意处理边界情况（空数据、单点数据等）
- 确保资源正确释放（地图视图、监听器等）
- 遵循 Kotlin 代码规范和最佳实践
