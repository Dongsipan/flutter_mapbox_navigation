# Android端实现路线图

## 总览

本文档提供Flutter Mapbox Navigation插件Android端功能补齐的完整路线图，包括SDK升级和功能实现计划。

## 📋 相关文档

1. **功能对比分析**: `ANDROID_IOS_FEATURE_COMPARISON.md` - iOS和Android功能差异详细对比
2. **SDK升级需求**: `.kiro/specs/android-sdk-v3-upgrade/requirements.md` - SDK升级的详细需求
3. **SDK升级指南**: `ANDROID_SDK_V3_UPGRADE_GUIDE.md` - 实际升级步骤和代码示例

## 🎯 总体目标

将Android端功能补齐到与iOS端相同的水平，提供完整的导航、搜索、历史记录等功能。

## 📊 当前状态

### ✅ 已完成功能
- 核心导航功能
- 自由驾驶模式
- 嵌入式导航视图
- 基础历史记录管理
- 基础地图样式选择

### ⚠️ 部分完成功能
- 历史记录回放（有空实现，需要补全）
- 地图样式选择器（功能简单，需要增强）

### ❌ 缺失功能
- 搜索功能（完全缺失）
- 历史记录事件解析（完全缺失）
- 历史记录封面生成（完全缺失）
- 路由选择（完全缺失）

## 🚀 实施阶段

### 阶段0：SDK升级 ⚠️ **前置条件**

**时间**: 2-3周  
**优先级**: 🔴 最高  
**状态**: 待开始

#### 目标
将Mapbox Navigation SDK从v2.16.0升级到v3.17.2

#### 任务清单
- [ ] 1.1 更新Gradle依赖配置
  - [ ] 更新Kotlin版本到1.9.22
  - [ ] 更新Android Gradle Plugin到8.1.4
  - [ ] 更新compileSdkVersion到34
  - [ ] 更新targetSdkVersion到34
  - [ ] 添加v3 SDK依赖
  - [ ] 移除v2 SDK依赖

- [ ] 1.2 迁移核心API
  - [ ] 更新MapboxNavigation初始化
  - [ ] 更新NavigationOptions配置
  - [ ] 迁移事件监听器
  - [ ] 更新位置服务API

- [ ] 1.3 迁移UI组件
  - [ ] 更新NavigationActivity
  - [ ] 迁移Drop-in UI组件
  - [ ] 更新自定义UI绑定
  - [ ] 更新布局文件

- [ ] 1.4 迁移历史记录API
  - [ ] 更新HistoryRecorder使用
  - [ ] 更新HistoryReader使用
  - [ ] 测试历史文件兼容性

- [ ] 1.5 测试和验证
  - [ ] 测试基本导航功能
  - [ ] 测试自由驾驶模式
  - [ ] 测试嵌入式视图
  - [ ] 测试历史记录功能
  - [ ] 性能测试

- [ ] 1.6 文档更新
  - [ ] 更新README配置说明
  - [ ] 更新API文档
  - [ ] 创建迁移指南

#### 交付物
- ✅ 升级后的Android项目（编译通过）
- ✅ 所有现有功能正常工作
- ✅ 升级文档和迁移指南
- ✅ 测试报告

#### 风险
- Breaking changes可能导致大量代码修改
- 可能与其他依赖产生冲突
- 需要全面测试以确保稳定性

---

### 阶段1：历史记录功能完善

**时间**: 2-3周  
**优先级**: 🔴 高  
**状态**: 待开始  
**前置条件**: 阶段0完成

#### 目标
实现完整的历史记录事件解析和回放功能

#### 任务清单

##### 1.1 历史记录事件解析器
- [ ] 创建 `HistoryEventsParser.kt`
- [ ] 实现历史文件读取
- [ ] 实现事件类型解析
  - [ ] location_update事件
  - [ ] route_assignment事件
  - [ ] user_pushed事件
- [ ] 实现原始位置轨迹提取
- [ ] 添加单元测试

##### 1.2 getNavigationHistoryEvents方法
- [ ] 在FlutterMapboxNavigationPlugin中添加方法处理
- [ ] 实现参数验证
- [ ] 调用HistoryEventsParser
- [ ] 序列化结果为Flutter可用格式
- [ ] 实现错误处理
- [ ] 添加集成测试

##### 1.3 历史记录回放完善
- [ ] 完善NavigationReplayActivity
- [ ] 实现回放控制UI
  - [ ] 播放/暂停按钮
  - [ ] 速度控制
  - [ ] 进度条
- [ ] 实现轨迹动画
- [ ] 实现速度梯度可视化
- [ ] 实现回放控制方法
  - [ ] startHistoryReplay
  - [ ] stopHistoryReplay
  - [ ] pauseHistoryReplay
  - [ ] resumeHistoryReplay
  - [ ] setHistoryReplaySpeed

##### 1.4 历史记录封面生成
- [ ] 创建 `HistoryCoverGenerator.kt`
- [ ] 实现轨迹数据提取
- [ ] 集成Mapbox Static API
- [ ] 实现速度梯度颜色编码
- [ ] 实现图片下载和保存
- [ ] 更新数据库记录
- [ ] 在FlutterMapboxNavigationPlugin中添加方法

#### 交付物
- ✅ HistoryEventsParser工具类
- ✅ 完整的历史回放功能
- ✅ 历史封面生成功能
- ✅ 单元测试和集成测试
- ✅ API文档更新

---

### 阶段2：搜索功能实现

**时间**: 1-2周  
**优先级**: 🔴 高  
**状态**: 待开始  
**前置条件**: 阶段0完成

#### 目标
实现完整的Mapbox搜索功能

#### 任务清单

##### 2.1 集成Mapbox Search SDK
- [ ] 添加Search SDK依赖
- [ ] 配置Search SDK
- [ ] 创建SearchController

##### 2.2 创建SearchActivity
- [ ] 设计搜索UI界面
- [ ] 实现搜索输入框
- [ ] 实现搜索结果列表
- [ ] 实现地图预览

##### 2.3 实现搜索方法
- [ ] showSearchView() - 显示搜索UI
- [ ] searchPlaces() - 地点搜索
- [ ] searchPointsOfInterest() - POI搜索
- [ ] getSearchSuggestions() - 自动完成
- [ ] reverseGeocode() - 反向地理编码
- [ ] searchByCategory() - 类别搜索
- [ ] searchInBoundingBox() - 边界框搜索

##### 2.4 Flutter集成
- [ ] 在FlutterMapboxNavigationPlugin中添加搜索方法
- [ ] 创建搜索方法通道
- [ ] 实现结果序列化
- [ ] 添加错误处理

##### 2.5 测试
- [ ] 单元测试
- [ ] UI测试
- [ ] 集成测试

#### 交付物
- ✅ SearchActivity和相关UI
- ✅ 完整的搜索API实现
- ✅ Flutter方法通道集成
- ✅ 测试套件
- ✅ 使用文档

---

### 阶段3：增强功能实现

**时间**: 2-3周  
**优先级**: 🟡 中  
**状态**: 待开始  
**前置条件**: 阶段0完成

#### 目标
实现路由选择和增强地图样式选择器

#### 任务清单

##### 3.1 路由选择功能
- [ ] 创建RouteSelectionActivity
- [ ] 实现多路线显示
- [ ] 实现路线对比UI
  - [ ] 距离对比
  - [ ] 时间对比
  - [ ] 交通状况对比
- [ ] 实现路线选择接口
- [ ] 集成到导航流程

##### 3.2 地图样式选择器增强
- [ ] 增强MapStyleSelectorActivity
- [ ] 添加Light Preset支持
  - [ ] Dawn（黎明）
  - [ ] Day（白天）
  - [ ] Dusk（黄昏）
  - [ ] Night（夜晚）
- [ ] 实现样式持久化存储
- [ ] 实现自动光照调整
- [ ] 改进UI界面

##### 3.3 Flutter集成
- [ ] 添加路由选择方法
- [ ] 添加样式选择器方法
- [ ] 更新方法通道

#### 交付物
- ✅ RouteSelectionActivity
- ✅ 增强的StyleSelectorActivity
- ✅ Flutter API集成
- ✅ 文档更新

---

### 阶段4：测试、优化和文档

**时间**: 1周  
**优先级**: 🟡 中  
**状态**: 待开始  
**前置条件**: 阶段1-3完成

#### 目标
全面测试、性能优化和文档完善

#### 任务清单

##### 4.1 端到端测试
- [ ] 创建完整的测试场景
- [ ] 测试所有功能集成
- [ ] 测试错误处理
- [ ] 测试边界情况

##### 4.2 性能优化
- [ ] 内存使用优化
- [ ] 电池消耗优化
- [ ] 渲染性能优化
- [ ] 网络请求优化

##### 4.3 文档更新
- [ ] 更新README.md
- [ ] 更新API_DOCUMENTATION.md
- [ ] 创建Android特定文档
- [ ] 更新代码示例
- [ ] 创建故障排除指南

##### 4.4 示例应用
- [ ] 更新example应用
- [ ] 添加所有新功能演示
- [ ] 添加使用说明

#### 交付物
- ✅ 完整的测试套件
- ✅ 性能优化报告
- ✅ 完整的文档
- ✅ 更新的示例应用

---

## 📈 进度跟踪

### 总体进度
- [ ] 阶段0: SDK升级 (0%)
- [ ] 阶段1: 历史记录功能 (0%)
- [ ] 阶段2: 搜索功能 (0%)
- [ ] 阶段3: 增强功能 (0%)
- [ ] 阶段4: 测试和文档 (0%)

### 里程碑
- [ ] M1: SDK升级完成 (预计: 第3周)
- [ ] M2: 历史记录功能完成 (预计: 第6周)
- [ ] M3: 搜索功能完成 (预计: 第8周)
- [ ] M4: 所有功能完成 (预计: 第11周)
- [ ] M5: 发布准备就绪 (预计: 第12周)

## 🎓 学习资源

### Mapbox官方文档
- [Android Navigation SDK v3](https://docs.mapbox.com/android/navigation/guides/)
- [v2到v3迁移指南](https://docs.mapbox.com/android/navigation/guides/migration-from-v2/)
- [Android Maps SDK](https://docs.mapbox.com/android/maps/guides/)
- [Android Search SDK](https://docs.mapbox.com/android/search/guides/)

### 示例代码
- [Mapbox Navigation Android Examples](https://github.com/mapbox/mapbox-navigation-android-examples)
- [iOS实现参考](ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/)

### Flutter集成
- [Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [Method Channel](https://api.flutter.dev/flutter/services/MethodChannel-class.html)

## ⚠️ 风险和缓解措施

### 风险1: SDK升级复杂度高
- **影响**: 可能导致大量代码重写
- **缓解**: 
  - 仔细阅读迁移指南
  - 分步骤进行，每步都测试
  - 保持Git分支以便回滚

### 风险2: API不兼容
- **影响**: v3 API可能无法实现某些v2功能
- **缓解**:
  - 提前研究v3 API文档
  - 寻找替代方案
  - 必要时联系Mapbox支持

### 风险3: 性能问题
- **影响**: 新SDK可能有性能问题
- **缓解**:
  - 进行性能基准测试
  - 使用Android Profiler监控
  - 优化关键路径

### 风险4: 时间估算不准
- **影响**: 项目延期
- **缓解**:
  - 预留缓冲时间
  - 定期评估进度
  - 及时调整计划

## 📞 支持和协作

### 团队协作
- 定期进度同步会议
- 代码审查流程
- 问题跟踪和解决

### 外部支持
- Mapbox技术支持
- Flutter社区
- GitHub Issues

## 🎉 成功标准

项目成功的标准：
1. ✅ Android端功能与iOS端完全对等
2. ✅ 所有测试通过（单元测试、集成测试、端到端测试）
3. ✅ 性能指标达标（内存、电池、渲染）
4. ✅ 文档完整且准确
5. ✅ 示例应用展示所有功能
6. ✅ 无重大bug
7. ✅ 用户反馈积极

---

**创建日期**: 2026-01-05  
**最后更新**: 2026-01-05  
**维护者**: Flutter Mapbox Navigation Team  
**状态**: 规划中
