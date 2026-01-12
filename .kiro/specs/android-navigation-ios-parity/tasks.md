# Implementation Plan: Android 导航功能与 iOS 对齐
## 概述

本实现计划旨在完善 Android 平台的导航功能,实现与 iOS 的功能对齐。当前 NavigationActivity 已实现基础导航功能,包括路线计算、导航启动、位置跟踪和基本事件通信。需要补充的功能包括:语音指令播放、转弯箭头显示、UI 组件完善、历史记录集成等。

## 当前实现状态

### ✅ 已完成
- NavigationActivity 基础架构
- MapboxNavigationApp 生命周期管理  
- 路线计算和显示 (MapboxRouteLineApi/View)
- NavigationCamera 相机跟踪
- 消失路线线 (Vanishing Route Line)
- 基础观察者 (LocationObserver, RouteProgressObserver, etc.)
- 模拟导航支持 (startReplayTripSession)
- 自由驾驶模式
- 基础事件通信到 Flutter

### 🚧 需要完善
- 语音指令播放
- 转弯箭头显示
- 转弯指令面板 UI
- 行程进度 UI
- 历史记录集成
- 错误处理完善
- 多航点支持验证
- 替代路线选择

## 任务列表

- [x] 1. 实现语音指令播放功能
  - 集成 MapboxSpeechApi 和 MapboxVoiceInstructionsPlayer
  - 实现语音指令的播放和停止
  - 支持语音指令的启用/禁用配置
  - 处理语音播放错误和回退
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [x] 2. 实现转弯箭头显示
  - 集成 MapboxRouteArrowApi 和 MapboxRouteArrowView
  - 在即将转弯时显示转弯箭头
  - 根据导航进度更新箭头位置
  - 在转弯完成后隐藏箭头
  - _Requirements: 7.4, 10.1_

- [x] 3. 完善转弯指令 UI 组件
  - 实现 MapboxManeuverApi 集成
  - 显示转弯图标和距离信息
  - 更新当前指令文本
  - 显示下一个转弯预览
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [x] 4. 实现行程进度 UI 组件
  - 集成 MapboxTripProgressApi
  - 显示剩余距离和时间
  - 显示预计到达时间 (ETA)
  - 实时更新进度信息
  - _Requirements: 8.1, 8.3, 8.4_

- [x] 5. 完善历史记录功能
  - 验证 TurnByTurn.kt 中的历史记录启动/停止逻辑
  - 实现 SDK v3 的历史记录 API 集成
  - 保存历史文件到正确的目录
  - 发送历史文件路径到 Flutter 层
  - _Requirements: 19.1, 19.2, 19.3, 19.4, 19.5, 19.6_

- [x] 6. 实现替代路线选择功能
  - 在地图上显示多条路线
  - 高亮显示主路线
  - 支持用户点击选择路线
  - 显示路线对比信息 (距离、时间)
  - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6_

- [x] 7. 完善错误处理
  - 改进路线计算失败的错误消息
  - 添加 GPS 信号丢失的用户提示
  - 处理位置权限被拒绝的情况
  - 添加网络连接失败的重试逻辑
  - 确保所有异常都被捕获并记录
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6_

- [x] 8. 验证和完善多航点支持
  - 测试多航点路线创建
  - 验证航点到达事件触发
  - 确保自动推进到下一路段
  - 支持静默航点 (不分隔路段)
  - _Requirements: 17.1, 17.2, 17.3, 17.4, 17.5, 17.6_

- [x] 9. 完善相机控制功能
  - 实现重新居中按钮
  - 处理用户手动移动地图后的状态
  - 支持相机配置 (zoom, tilt, bearing)
  - 优化相机动画过渡
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

- [x] 10. 验证地图样式切换
  - 测试日间/夜间样式切换
  - 验证自定义样式 URL 支持
  - 确保样式切换不影响导航状态
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_

- [x] 11. Checkpoint - 功能验证
  - 运行所有导航模式测试 (driving, walking, cycling)
  - 验证模拟导航和真实导航
  - 测试所有事件是否正确发送到 Flutter
  - 检查内存泄漏和资源清理
  - 确保与 iOS 功能对齐

- [x]* 12. 编写单元测试
  - 测试导航模式映射
  - 测试模拟模式选择
  - 测试事件序列化
  - 测试错误处理逻辑
  - _Requirements: 所有需求_

- [x]* 13. 编写属性测试
  - [x]* 13.1 Property 1: 导航模式映射正确性
    - **Property 1: 导航模式映射正确性**
    - **Validates: Requirements 4.1, 4.2, 4.3**
  
  - [x]* 13.2 Property 2: 模拟模式选择正确性
    - **Property 2: 模拟模式选择正确性**
    - **Validates: Requirements 2.1, 2.2**
  
  - [x]* 13.3 Property 5: 路线计算和显示
    - **Property 5: 路线计算和显示**
    - **Validates: Requirements 5.1, 5.2**
  
  - [x]* 13.4 Property 10: 路线进度持续跟踪
    - **Property 10: 路线进度持续跟踪**
    - **Validates: Requirements 8.1, 8.3, 8.4**
  
  - [x]* 13.5 Property 11: 进度事件通信
    - **Property 11: 进度事件通信**
    - **Validates: Requirements 8.2**
  
  - [x]* 13.6 Property 12: 到达检测
    - **Property 12: 到达检测**
    - **Validates: Requirements 9.1**
  
  - [x]* 13.7 Property 17: 导航事件发送
    - **Property 17: 导航事件发送**
    - **Validates: Requirements 12.1, 12.2, 12.3, 12.4, 12.5**

- [x] 14. Final Checkpoint - 完整测试
  - 端到端测试所有导航场景
  - 性能测试和内存泄漏检查
  - 与 iOS 实现对比验证
  - 确保所有需求都已实现

## 注意事项

- 任务标记 `*` 的为可选任务,可以跳过以加快 MVP 开发
- 每个任务都引用了具体的需求编号以便追溯
- Checkpoint 任务确保增量验证
- 属性测试验证通用正确性属性
- 单元测试验证特定示例和边缘情况

## 实现优先级

### 高优先级 (必须完成)
- 任务 1: 语音指令播放
- 任务 3: 转弯指令 UI
- 任务 4: 行程进度 UI
- 任务 7: 错误处理
- 任务 11: 功能验证

### 中优先级 (应该完成)
- 任务 2: 转弯箭头
- 任务 5: 历史记录
- 任务 8: 多航点支持
- 任务 9: 相机控制
- 任务 10: 地图样式

### 低优先级 (可以延后)
- 任务 6: 替代路线选择
- 任务 12: 单元测试
- 任务 13: 属性测试

---

**创建日期**: 2026-01-05
**状态**: 待审核
