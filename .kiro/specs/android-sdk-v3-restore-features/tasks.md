# Implementation Plan: Android SDK v3 恢复临时禁用的功能

## Overview

本实施计划将使用 Mapbox Navigation SDK v3 核心 API 重新实现在 MVP 迁移过程中临时禁用的功能。实施分为 3 个主要阶段，按优先级从高到低执行。

## Tasks

- [x] 1. 实现 Free Drive 模式
  - [x] 1.1 在 TurnByTurn.kt 中实现 startFreeDrive() 方法
    - 调用 MapboxNavigation.startTripSession() 而不设置路线
    - 发送 NAVIGATION_RUNNING 事件到 Flutter
    - 移除临时禁用的注释和日志
    - _Requirements: 1.1, 1.6_

  - [x] 1.2 验证位置更新功能
    - 确认 LocationObserver 持续接收位置更新
    - 确认 NavigationLocationProvider 正确更新
    - 确认地图显示用户位置和方向
    - _Requirements: 1.2, 1.3_

  - [x] 1.3 实现 Free Drive 停止逻辑
    - 在 finishNavigation() 中添加停止 trip session 的逻辑
    - 确保资源正确清理
    - 发送 NAVIGATION_CANCELLED 事件
    - _Requirements: 1.5_

  - [ ]* 1.4 编写 Free Drive 单元测试
    - 测试 startFreeDrive() 调用正确的 SDK 方法
    - 测试位置更新事件正确发送
    - 测试停止逻辑正确执行
    - _Requirements: 1.1-1.5_

- [x] 2. 实现路线预览和导航启动
  - [x] 2.1 在 TurnByTurn.kt 中实现 startNavigation() 方法
    - 检查 currentRoutes 是否为空
    - 调用 MapboxNavigation.setNavigationRoutes()
    - 根据 simulateRoute 选择 trip session 类型
    - 发送 NAVIGATION_RUNNING 事件
    - 移除临时禁用的注释和日志
    - _Requirements: 2.3, 2.4, 2.6_

  - [x] 2.2 实现路线绘制功能
    - 在 getRoute() 回调中使用 MapboxRouteLineApi
    - 调用 routeLineApi.setNavigationRoutes() 绘制路线
    - 使用 routeLineView.renderRouteDrawData() 渲染
    - _Requirements: 2.1, 2.5_

  - [x] 2.3 实现路线预览相机调整
    - 计算路线边界
    - 使用 cameraForCoordinateBounds() 调整相机
    - 添加合适的 EdgeInsets
    - _Requirements: 2.2_

  - [ ]* 2.4 编写导航启动单元测试
    - 测试 startNavigation() 正确设置路线
    - 测试模拟模式选择逻辑
    - 测试路线绘制功能
    - _Requirements: 2.1-2.6_

- [ ] 3. Checkpoint - 测试基础导航功能
  - 在真实设备上测试 Free Drive 模式
  - 测试路线构建和导航启动
  - 确认所有事件正确传递到 Flutter
  - 询问用户测试结果

- [x] 4. 实现地图点击回调
  - [x] 4.1 在 NavigationActivity.kt 中实现地图点击监听
    - 创建 OnMapClickListener 实现
    - 在点击时发送 ON_MAP_TAP 事件到 Flutter
    - 包含点击坐标信息
    - _Requirements: 4.1, 4.2_

  - [x] 4.2 添加条件注册逻辑
    - 根据 enableOnMapTapCallback 标志注册监听器
    - 在 onDestroy() 中注销监听器
    - _Requirements: 4.3, 4.4, 4.5, 4.6_

  - [ ]* 4.3 编写地图点击测试
    - 测试点击事件触发回调
    - 测试事件数据格式正确
    - 测试条件注册逻辑
    - _Requirements: 4.1-4.6_

- [x] 5. 实现长按设置目的地
  - [x] 5.1 在 NavigationActivity.kt 中实现长按监听
    - 创建 OnMapLongClickListener 实现
    - 获取当前位置和长按位置
    - 调用 requestRoutes() 构建路线
    - _Requirements: 5.1, 5.2_

  - [x] 5.2 添加条件注册逻辑
    - 根据 longPressDestinationEnabled 标志注册监听器
    - 在 onDestroy() 中注销监听器
    - 处理当前位置不可用的情况
    - _Requirements: 5.3, 5.4, 5.6_

  - [ ]* 5.3 编写长按功能测试
    - 测试长按事件触发路线构建
    - 测试路线参数正确
    - 测试条件注册逻辑
    - _Requirements: 5.1-5.6_

- [x] 6. 实现模拟导航支持
  - [x] 6.1 在 TurnByTurn.kt 中完善模拟导航逻辑
    - 确认 simulateRoute 标志正确传递
    - 在 startNavigation() 中根据标志选择模式
    - 配置 MapboxReplayer（如需要）
    - _Requirements: 7.1, 7.2, 7.3_

  - [x] 6.2 验证模拟导航功能
    - 测试模拟位置更新
    - 测试导航进度更新
    - 测试与真实导航的切换
    - _Requirements: 7.4, 7.5, 7.6_

  - [ ]* 6.3 编写模拟导航测试
    - 测试模式选择逻辑
    - 测试模拟位置更新
    - 测试回放速度控制
    - _Requirements: 7.1-7.6_

- [ ] 7. Checkpoint - 测试地图交互功能
  - 测试地图点击回调
  - 测试长按设置目的地
  - 测试模拟导航
  - 询问用户测试结果

- [ ] 8. 实现嵌入式导航视图（低优先级）
  - [x] 8.1 重写 EmbeddedNavigationMapView.kt
    - 移除 NavigationView 相关代码
    - 使用 MapView 替代
    - 初始化 MapboxNavigation
    - _Requirements: 3.1, 3.5_

  - [x] 8.2 实现视图生命周期管理
    - 在 init 中初始化组件
    - 在 dispose() 中清理资源
    - 注册和注销观察者
    - _Requirements: 3.4, 3.6_

  - [x] 8.3 实现地图交互
    - 添加手势监听器
    - 处理用户交互
    - 发送事件到 Flutter
    - _Requirements: 3.3_

  - [ ]* 8.4 编写嵌入式视图测试
    - 测试视图初始化
    - 测试生命周期管理
    - 测试事件处理
    - _Requirements: 3.1-3.6_

- [x] 9. 实现自定义信息面板（低优先级）
  - [x] 9.1 更新 NavigationActivity.kt 布局
    - 在 navigation_activity.xml 中添加信息面板
    - 包含距离、时间、结束按钮等元素
    - _Requirements: 6.4, 6.5_

  - [x] 9.2 实现信息面板更新逻辑
    - 在 RouteProgressObserver 中更新 UI
    - 格式化距离和时间显示
    - 处理结束按钮点击
    - _Requirements: 6.1, 6.2, 6.3_

  - [ ]* 9.3 编写信息面板测试
    - 测试面板显示和隐藏
    - 测试数据更新
    - 测试按钮点击
    - _Requirements: 6.1-6.6_

- [x] 10. 完善事件传递机制
  - [x] 10.1 审查所有事件发送点
    - 确认 ROUTE_BUILT 事件正确发送
    - 确认 NAVIGATION_RUNNING 事件正确发送
    - 确认 NAVIGATION_CANCELLED 事件正确发送
    - 确认 ROUTE_BUILD_FAILED 事件正确发送
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [x] 10.2 验证事件数据完整性
    - 检查事件格式符合 Flutter 层期望
    - 检查所有必需字段都包含
    - 检查数据类型正确
    - _Requirements: 8.5, 8.6_

  - [ ]* 10.3 编写事件传递测试
    - 测试所有事件类型
    - 测试事件数据格式
    - 测试事件发送时机
    - _Requirements: 8.1-8.6_

- [x] 11. 完善资源管理和生命周期
  - [x] 11.1 审查观察者注册和注销
    - 确认所有观察者在 onCreate/onAttached 中注册
    - 确认所有观察者在 onDestroy/onDetached 中注销
    - 添加异常处理
    - _Requirements: 9.1, 9.2, 9.5_

  - [x] 11.2 审查地图监听器管理
    - 确认监听器正确注册
    - 确认监听器正确注销
    - 避免内存泄漏
    - _Requirements: 9.3, 9.6_

  - [ ]* 11.3 编写生命周期测试
    - 测试初始化逻辑
    - 测试清理逻辑
    - 测试异常处理
    - _Requirements: 9.1-9.6_

- [ ] 12. Checkpoint - 完整功能测试
  - 测试所有恢复的功能
  - 运行所有单元测试
  - 运行集成测试
  - 询问用户测试结果

- [x] 13. 验证向后兼容性
  - [x] 13.1 测试 Flutter API 兼容性
    - 测试所有 MethodChannel 方法
    - 确认方法签名未改变
    - 确认返回值格式未改变
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [x] 13.2 测试事件格式兼容性
    - 确认所有事件格式与之前一致
    - 确认事件数据结构未改变
    - _Requirements: 10.5, 10.6_

  - [ ]* 13.3 编写兼容性测试
    - 测试 Flutter 到 Android 的调用
    - 测试 Android 到 Flutter 的事件
    - 测试数据序列化和反序列化
    - _Requirements: 10.1-10.6_

- [ ] 14. 性能测试和优化
  - [ ] 14.1 测试位置更新性能
    - 监控位置更新频率
    - 检查 CPU 使用率
    - 检查内存使用
    - _Performance_

  - [ ] 14.2 测试地图渲染性能
    - 监控帧率
    - 检查路线绘制性能
    - 优化相机动画
    - _Performance_

  - [ ] 14.3 测试电池消耗
    - 监控导航时的电池使用
    - 与 MVP 版本对比
    - 优化后台运行
    - _Performance_

- [x] 15. 文档更新
  - [x] 15.1 更新 ANDROID_SDK_V3_NEXT_STEPS.md
    - 标记已完成的任务
    - 更新状态说明
    - _Documentation_

  - [x] 15.2 创建功能恢复总结文档
    - 记录所有恢复的功能
    - 说明实现方式
    - 提供使用示例
    - _Documentation_

  - [x] 15.3 更新 API_DOCUMENTATION.md
    - 更新功能支持状态
    - 添加新的使用说明
    - _Documentation_

- [ ] 16. Final Checkpoint - 发布前确认
  - 确保所有功能正常工作
  - 确保所有测试通过
  - 确保文档完整
  - 询问用户是否准备好合并

## Notes

- 标记为 `*` 的任务是可选的测试任务，可以根据时间安排决定是否实施
- 每个 Checkpoint 都需要用户确认才能继续
- 优先实现高优先级功能（Free Drive、导航启动、事件传递）
- 低优先级功能（嵌入式视图、信息面板）可以在后续版本中实现
- 保持与 Flutter 层的 API 兼容性是最高优先级

## 预计时间

- 阶段 1-3（Free Drive + 导航启动）: 1-2 天
- 阶段 4-7（地图交互 + 模拟导航）: 1-2 天
- 阶段 8-9（嵌入式视图 + 信息面板）: 2-3 天（可选）
- 阶段 10-13（完善和测试）: 1-2 天
- 阶段 14-16（性能优化和文档）: 1 天
- **总计**: 4-10 天（取决于是否实现低优先级功能）

## 成功标准

- ✅ 所有临时禁用的功能都已恢复
- ✅ 所有功能测试通过
- ✅ 与 Flutter 层的集成正常工作
- ✅ 无内存泄漏或资源泄漏
- ✅ 性能不低于 MVP 版本
- ✅ 文档完整更新

---

**创建日期**: 2026-01-05
**状态**: 待实施
