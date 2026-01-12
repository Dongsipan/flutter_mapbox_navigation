# 实现计划：Android 历史封面生成

## 概述

本实现计划将为 Android 平台添加导航历史封面自动生成功能，与 iOS 实现保持一致。实现将创建 HistoryCoverGenerator 工具类，使用 Mapbox Snapshotter API 生成带速度渐变的路线封面图。

## 任务

- [x] 1. 创建 HistoryCoverGenerator 核心类
  - 创建 `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/utilities/HistoryCoverGenerator.kt`
  - 实现单例模式
  - 定义常量（封面尺寸、线宽、标记半径等）
  - 定义 HistoryCoverCallback 接口
  - _需求: 1.1, 6.1, 7.1, 7.4_

- [x] 2. 实现位置数据提取功能
  - [x] 2.1 实现 extractLocationData() 方法
    - 从历史事件中提取位置点、速度和累计距离
    - 使用反射获取位置字段（与 NavigationReplayActivity 相同逻辑）
    - 过滤无效坐标（0, 0）
    - 过滤过近的点（< 0.5米）
    - 计算累计距离
    - 返回 Triple<List<Point>, List<Double>, List<Double>>
    - _需求: 1.2, 7.5_
  
  - [ ]* 2.2 编写位置数据提取的单元测试
    - 测试有效数据提取
    - 测试无效坐标过滤
    - 测试过近点过滤
    - 测试累计距离计算
    - **属性 1: 位置数据提取完整性**
    - **验证: 需求 1.2**

- [x] 3. 实现速度颜色映射
  - [x] 3.1 实现 getColorForSpeed() 方法
    - 根据速度范围返回对应颜色（7个区间）
    - 使用 when 表达式实现
    - 颜色值与 iOS 和 NavigationReplayActivity 保持一致
    - _需求: 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_
  
  - [ ]* 3.2 编写速度颜色映射的单元测试
    - 测试所有速度范围返回正确颜色
    - 测试边界值
    - 测试极端值
    - **属性 7: 速度颜色映射一致性**
    - **验证: 需求 3.2-3.8**

- [x] 4. 实现地图样式配置
  - [x] 4.1 实现 getStyleUri() 方法
    - 将地图样式字符串映射到 Mapbox StyleURI
    - 支持 standard, standardSatellite, light, dark, outdoors 等
    - 默认使用 MAPBOX_STREETS
    - _需求: 4.1_
  
  - [x] 4.2 实现 applyStyleConfig() 方法
    - 应用 light preset 配置（如果样式支持）
    - 应用 theme 配置（faded, monochrome）
    - 处理不支持 light preset 的样式
    - _需求: 4.2, 4.3, 4.4, 4.5_
  
  - [ ]* 4.3 编写地图样式配置的单元测试
    - 测试所有样式映射正确
    - 测试 light preset 应用
    - 测试 theme 配置
    - **属性 9: 地图样式应用一致性**
    - **验证: 需求 4.1**

- [x] 5. 实现 Snapshotter 配置和渲染
  - [x] 5.1 实现 generateHistoryCover() 主方法
    - 接收参数：context, filePath, historyId, mapStyle, lightPreset, callback
    - 使用协程异步执行
    - 调用 NavigationHistoryManager.loadReplayEvents() 加载历史文件
    - 调用 extractLocationData() 提取数据
    - 检查点数是否足够（>= 2）
    - 构建 LineString 几何对象
    - 创建 MapSnapshotOptions（720x405, 设备像素密度）
    - 创建 Snapshotter 并设置样式 URI
    - 使用 cameraForGeometry() 自动计算相机位置
    - _需求: 1.1, 1.2, 5.1, 5.2, 6.1, 6.2_
  
  - [x] 5.2 实现 SnapshotStyleListener 样式加载处理
    - 实现 onDidFinishLoadingStyle() 回调
    - 添加 route-source（开启 lineMetrics(true)）
    - 添加 route-layer（配置 lineGradient）
    - 添加起终点数据源和图层
    - 调用 applyStyleConfig() 应用样式配置
    - 调用 snapshotter.start() 开始生成快照
    - _需求: 2.1, 2.4, 2.5, 3.1, 4.2, 4.3, 4.4_
  
  - [x] 5.3 实现 lineGradient 表达式构建
    - 使用 interpolate + lineProgress 构建渐变
    - 根据速度数据计算渐变停止点
    - 确保进度值在 [0.0, 1.0] 范围内
    - 限制渐变节点数量（最多20个）
    - _需求: 3.1, 7.1, 7.2, 7.3_

- [x] 6. 实现快照生成和资源管理
  - [x] 6.1 实现快照生成回调处理
    - 在 snapshotter.start() 回调中处理 Bitmap 结果
    - 处理生成失败的情况
    - 调用 saveSnapshot() 保存图片
    - 调用 snapshotter.destroy() 释放资源
    - _需求: 1.3, 6.3, 6.5_
  
  - [x] 6.2 实现 saveSnapshot() 方法
    - 将 Bitmap 转换为 PNG 格式
    - 生成文件路径：{historyDir}/{historyId}_cover.png
    - 使用原子写入操作保存文件
    - 处理文件已存在的情况（覆盖）
    - 返回文件路径或 null
    - _需求: 1.3, 6.3, 6.5_
  
  - [x] 6.3 实现 updateHistoryRecord() 方法
    - 调用 HistoryManager.updateHistoryCover()
    - 更新历史记录的 cover 字段
    - 通过回调返回成功结果
    - _需求: 1.4, 5.3_
  
  - [ ]* 6.4 编写文件保存的单元测试
    - 测试文件命名正确
    - 测试文件格式为 PNG
    - 测试文件覆盖
    - **属性 3: 文件命名一致性**
    - **属性 11: 文件格式一致性**
    - **验证: 需求 1.3, 6.3**

- [x] 7. 实现错误处理
  - [x] 7.1 添加 try-catch 块处理所有异常
    - 文件读取错误
    - 数据提取错误
    - Snapshotter 初始化错误
    - 快照渲染错误
    - 文件写入错误
    - _需求: 8.1, 8.2, 8.3, 8.4, 8.5_
  
  - [x] 7.2 添加详细的日志输出
    - 记录关键步骤的执行状态
    - 记录错误详情
    - 使用 Log.d, Log.w, Log.e 区分日志级别
    - _需求: 1.5, 5.4_
  
  - [ ]* 7.3 编写错误处理的单元测试
    - 测试各种错误情况的处理
    - 测试错误不影响历史记录保存
    - **验证: 需求 1.5, 8.1-8.5**

- [x] 8. 集成到历史记录停止流程
  - [x] 8.1 在 TurnByTurn 或 NavigationActivity 中调用封面生成
    - 在 stopHistoryRecording() 方法中添加调用
    - 立即捕获必要数据（historyId, filePath, mapStyle, lightPreset）
    - 异步调用 HistoryCoverGenerator.generateHistoryCover()
    - 实现 HistoryCoverCallback 处理结果
    - 添加必要的 coroutine 导入
    - 修复 Mapbox v11 API 兼容性问题
    - _需求: 1.1, 5.1, 5.2_
  
  - [x] 8.2 确保封面生成不阻塞历史记录保存
    - 先保存历史记录（不包含 cover）
    - 然后异步生成封面
    - 封面生成完成后更新历史记录
    - _需求: 5.2, 5.3_
  
  - [x] 8.3 修复 Mapbox v11 API 兼容性
    - 修复 snapshotter.start() 回调签名（接受 bitmap 和 error 两个参数）
    - 修复 cameraForGeometry() 调用（改用 cameraForCoordinates()）
    - 添加 error 参数处理逻辑
    - 验证编译通过

- [ ] 9. 测试和验证
  - [ ] 9.1 功能测试
    - 测试生成小型历史文件的封面（< 100点）
    - 测试生成中型历史文件的封面（100-500点）
    - 测试生成大型历史文件的封面（> 500点）
    - 验证封面图显示完整路线
    - 验证速度渐变颜色正确
    - 验证起终点标记位置正确
    - _需求: 1.1, 2.1, 3.1_
  
  - [ ] 9.2 样式测试
    - 测试不同地图样式的封面生成
    - 测试 light preset 应用（standard, faded, monochrome）
    - 测试 theme 配置（faded, monochrome）
    - 验证封面样式与历史记录一致
    - _需求: 4.1, 4.2, 4.3, 4.4_
  
  - [ ] 9.3 错误处理测试
    - 测试无效历史文件的处理
    - 测试轨迹点不足的处理
    - 测试文件写入失败的处理
    - 验证错误不影响历史记录保存
    - _需求: 1.5, 7.5, 8.1-8.5_
  
  - [ ] 9.4 性能测试
    - 测试封面生成时间（应 < 10秒）
    - 测试内存使用（应 < 100MB 增量）
    - 测试并发生成多个封面
    - _需求: 5.5_

- [ ] 10. 最终检查点
  - 确保所有测试通过
  - 确认代码无编译错误和警告
  - 验证封面生成流畅，不阻塞 UI
  - 确认内存使用合理
  - 验证与 iOS 实现的一致性
  - 询问用户是否有问题

## 注意事项

- 使用官方推荐的 Snapshotter API 方式
- 参考提供的官方示例代码结构
- 必须在 GeoJsonSource 中开启 lineMetrics(true) 才能支持渐变
- 使用 cameraForGeometry() 自动计算最佳相机位置
- 复用 NavigationReplayActivity 的位置数据提取和速度颜色映射逻辑
- 使用 Kotlin 协程实现异步执行
- 确保在主线程中操作 Snapshotter
- 注意资源释放（调用 snapshotter.destroy()）
- 遵循 Kotlin 代码规范和最佳实践
- 保持与 iOS 实现的一致性（颜色、尺寸、样式等）
