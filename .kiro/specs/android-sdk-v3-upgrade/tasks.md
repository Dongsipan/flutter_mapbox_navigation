# Implementation Plan: Android Mapbox Navigation SDK v3 升级

## Overview

本实施计划将Flutter Mapbox Navigation插件的Android端从Mapbox Navigation SDK v2.16.0升级到v3.17.2。升级分为6个主要阶段，每个阶段都有明确的任务和验收标准。

## Tasks

- [x] 1. 准备和备份
  - 创建Git分支用于升级工作
  - 备份当前工作代码
  - 记录当前SDK版本和配置
  - _Requirements: 1.1, 11.1_

- [x] 2. 更新Gradle依赖配置
  - [x] 2.1 更新android/build.gradle
    - 更新Kotlin版本从1.7.10到1.9.22
    - 更新Android Gradle Plugin从7.4.2到8.1.4
    - 更新compileSdkVersion从33到34
    - 更新targetSdkVersion从33到34
    - 更新Java版本从1.8到17
    - _Requirements: 1.1, 9.1, 9.2, 9.3, 9.4_

  - [x] 2.2 更新Mapbox SDK依赖
    - 移除v2依赖（copilot:2.16.0, ui-app:2.16.0, ui-dropin:2.16.0）
    - 添加v3依赖（android:3.17.2, ui-dropin:3.17.2）
    - 更新其他相关依赖到兼容版本
    - _Requirements: 1.1, 1.5, 9.5_

  - [x] 2.3 更新example/android配置
    - 同步更新example项目的Gradle配置
    - 确保example项目使用相同的SDK版本
    - _Requirements: 1.1_

  - [x] 2.4 清理和同步
    - 运行flutter clean
    - 运行./gradlew clean
    - 同步Gradle依赖
    - _Requirements: 1.2_

- [x] 3. Checkpoint - 验证依赖更新
  - 确保Gradle同步成功，询问用户是否有问题

- [x] 4. 更新导入语句和包名（MVP 版本）
  - [~] 4.1 更新FlutterMapboxNavigationPlugin.kt
    - 部分更新导入语句从v2到v3
    - 临时禁用 Drop-in UI 相关代码
    - _Requirements: 2.1, 2.2, 5.1, 5.2_
    - _Note: 需要后续完善_

  - [x] 4.2 更新NavigationActivity.kt
    - ✅ 完全重写使用 SDK v3 核心 API
    - ✅ 实现基础导航功能（路线规划、导航、位置跟踪）
    - ✅ 实现观察者模式（位置、进度、到达、离线路由）
    - ✅ 实现 UI 更新和事件回调
    - _Requirements: 2.1, 3.1, 5.5_

  - [~] 4.3 更新NavigationReplayActivity.kt
    - 临时禁用部分 Drop-in UI 功能
    - _Requirements: 2.1, 4.1, 4.2_
    - _Note: 需要后续完善_

  - [~] 4.4 更新其他Activity文件
    - TurnByTurn.kt - 临时禁用 Drop-in UI 相关代码
    - EmbeddedNavigationMapView.kt - 临时禁用 NavigationView
    - CustomInfoPanelEndNavButtonBinder.kt - 临时禁用
    - _Requirements: 2.1, 7.1, 7.2_
    - _Note: 需要后续完善_

- [ ] 5. 更新事件监听和回调
  - [ ] 5.1 更新RouteProgressObserver
    - 使用v3的事件监听机制
    - 确保事件正确传递到Flutter层
    - _Requirements: 6.1, 6.5_

  - [ ] 5.2 更新ArrivalObserver
    - 使用v3的到达检测API
    - 更新事件序列化
    - _Requirements: 6.2_

  - [ ] 5.3 更新OffRouteObserver
    - 使用v3的路线偏离检测
    - _Requirements: 6.3_

  - [ ] 5.4 更新其他观察者
    - RouteRefreshObserver
    - VoiceInstructionsObserver
    - BannerInstructionsObserver
    - _Requirements: 6.4, 8.1_

- [ ] 6. 更新UI组件
  - [ ] 6.1 更新布局文件
    - 更新mapbox_activity_navigation.xml
    - 更新mapbox_activity_replay_view.xml
    - 使用v3的UI组件
    - _Requirements: 3.1, 3.2_

  - [ ] 6.2 更新ViewBinder
    - 使用v3的ViewBinder机制
    - 更新自定义UI绑定
    - _Requirements: 3.3_

  - [ ] 6.3 更新样式和主题
    - 更新styles.xml
    - 确保UI样式兼容v3
    - _Requirements: 3.4, 7.3_

- [x] 7. Checkpoint - 编译测试
  - ✅ 项目编译成功（Kotlin + Java）
  - ✅ 所有编译错误已修复
  - ✅ APK 构建成功

- [ ] 8. 更新历史记录功能
  - [ ] 8.1 更新HistoryManager.kt
    - 使用v3的History API
    - 更新历史记录录制逻辑
    - _Requirements: 4.1_

  - [ ] 8.2 更新NavigationHistoryManager.kt
    - 使用v3的HistoryReader
    - 更新历史文件读取逻辑
    - _Requirements: 4.2_

  - [ ] 8.3 测试历史文件兼容性
    - 测试v2历史文件是否可读
    - 如需要，实现格式转换
    - _Requirements: 4.5_

- [ ] 9. 更新地图样式和渲染
  - [ ] 9.1 更新MapStyleManager.kt
    - 使用v3的Style API
    - 更新样式切换逻辑
    - _Requirements: 7.1, 7.2_

  - [ ] 9.2 更新地图自定义
    - 使用v3的Layer和Source API
    - 更新地图元素自定义
    - _Requirements: 7.3, 7.4_

- [ ] 10. 更新语音指令
  - [ ] 10.1 更新语音播放
    - 使用v3的VoiceInstructionsPlayer
    - 更新语音自定义机制
    - _Requirements: 8.1, 8.2_

  - [ ] 10.2 更新语言和音量控制
    - 确保语言设置正常工作
    - 确保音量控制正常工作
    - _Requirements: 8.3, 8.4, 8.5_

- [ ] 11. 更新错误处理和日志
  - [ ] 11.1 更新错误处理
    - 使用v3的错误处理机制
    - 确保错误信息清晰
    - _Requirements: 13.1, 13.4_

  - [ ] 11.2 更新日志记录
    - 使用v3的日志系统
    - 添加调试信息
    - _Requirements: 13.2, 13.3_

- [ ] 12. Checkpoint - 功能测试
  - 确保所有基本功能正常工作，询问用户测试结果

- [ ] 13. 全面测试
  - [ ] 13.1 测试基本导航
    - 启动导航
    - 转弯指示
    - 语音播报
    - 到达目的地
    - _Requirements: 10.1_

  - [ ] 13.2 测试自由驾驶模式
    - 启动自由驾驶
    - 位置跟踪
    - 地图显示
    - _Requirements: 10.2_

  - [ ] 13.3 测试嵌入式导航视图
    - 嵌入式视图显示
    - 视图交互
    - 生命周期管理
    - _Requirements: 10.3_

  - [ ] 13.4 测试历史记录功能
    - 历史记录录制
    - 历史记录读取
    - 历史列表显示
    - _Requirements: 10.4_

  - [ ] 13.5 测试事件传递
    - 进度更新事件
    - 到达事件
    - 路线偏离事件
    - 所有事件正确传递到Flutter层
    - _Requirements: 10.5_

  - [ ] 13.6 测试地图样式
    - 样式切换
    - 日夜模式
    - 自定义样式
    - _Requirements: 7.5_

  - [ ] 13.7 运行自动化测试
    - 运行单元测试
    - 运行集成测试
    - 确保所有测试通过
    - _Requirements: 10.5_

- [ ] 14. 性能测试和优化
  - [ ] 14.1 内存使用测试
    - 使用Android Profiler监控内存
    - 检查内存泄漏
    - 优化内存使用
    - _Requirements: 12.4_

  - [ ] 14.2 电池消耗测试
    - 测试导航时的电池消耗
    - 与v2对比
    - _Requirements: 12.5_

  - [ ] 14.3 渲染性能测试
    - 测试地图渲染帧率
    - 测试UI响应速度
    - _Requirements: 12.1_

- [ ] 15. 文档更新
  - [ ] 15.1 更新README.md
    - 更新Android配置说明
    - 更新SDK版本要求
    - 添加v3特定说明
    - _Requirements: 14.1_

  - [ ] 15.2 更新API_DOCUMENTATION.md
    - 标注平台支持状态
    - 更新API说明
    - _Requirements: 14.2_

  - [ ] 15.3 创建迁移指南
    - 为用户提供升级指南
    - 说明breaking changes
    - _Requirements: 14.3_

  - [ ] 15.4 更新代码示例
    - 更新example应用
    - 添加v3特定示例
    - _Requirements: 14.4, 14.5_

- [ ] 16. 最终验证和发布准备
  - [ ] 16.1 完整回归测试
    - 测试所有功能
    - 确保无重大bug
    - _Requirements: 10.1-10.5_

  - [ ] 16.2 代码审查
    - 审查所有修改
    - 确保代码质量
    - _Requirements: 11.1_

  - [ ] 16.3 性能基准对比
    - 与v2进行性能对比
    - 确保性能不降低
    - _Requirements: 12.1-12.5_

  - [ ] 16.4 文档完整性检查
    - 确保所有文档已更新
    - 确保文档准确
    - _Requirements: 14.1-14.5_

  - [ ] 16.5 准备发布说明
    - 编写changelog
    - 说明主要变更
    - 提供升级指导
    - _Requirements: 14.3_

- [ ] 17. Final Checkpoint - 发布前确认
  - 确保所有测试通过，所有文档完整，询问用户是否准备好发布

## Notes

- 每个Checkpoint任务都需要用户确认才能继续
- 如果遇到问题，及时记录并寻求帮助
- 保持Git提交的原子性，便于回滚
- 定期备份工作进度
- 遇到breaking changes时，优先考虑向后兼容性

## 预计时间

- 阶段1-2（准备和依赖更新）: 2-3天
- 阶段3-6（API迁移和UI更新）: 5-7天
- 阶段7-11（功能更新和优化）: 3-5天
- 阶段12-17（测试和文档）: 3-5天
- **总计**: 2-3周

## 成功标准

- ✅ 项目编译成功
- ✅ 所有现有功能正常工作
- ✅ 所有测试通过
- ✅ 性能不低于v2
- ✅ 文档完整更新
- ✅ 无重大bug

---

**创建日期**: 2026-01-05
**最后更新**: 2026-01-05
**状态**: MVP 阶段完成 - 编译成功

## MVP 完成状态

### ✅ 已完成
- 依赖升级到 SDK v3.10.0
- NavigationActivity 完全重写（使用核心 API）
- 所有编译错误修复
- 基础导航功能实现
- 项目可以成功构建

### 🔄 进行中
- 功能测试（需要在真实设备上验证）

### ⏳ 待完成
- 完善临时禁用的功能
- 实现高级功能（历史记录、搜索等）
- 性能优化
- 文档更新

详见: [ANDROID_SDK_V3_MVP_SUCCESS.md](../../ANDROID_SDK_V3_MVP_SUCCESS.md)
