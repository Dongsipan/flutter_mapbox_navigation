# 设计文档

## 概述

本设计文档描述了 NavigationReplayActivity 的重构方案，将其从动画回放模式改为静态轨迹渐变显示模式。重构后的页面将一次性加载并显示完整的历史轨迹，轨迹颜色根据速度呈现渐变效果，无需播放动画。

核心功能包括：
- 使用 NavigationHistoryManager 加载历史文件
- 从历史事件中提取位置点和速度数据
- 使用 GeoJsonSource (lineMetrics: true) + LineLayer (lineGradient) 绘制速度渐变轨迹
- 自动调整相机到全览模式显示完整轨迹
- 简化的 UI 设计（移除不必要的控件）

## 架构

### 整体架构变更

**移除的组件：**
- MapboxReplayer 回放引擎（不再需要动画播放）
- ReplayLocationEngine（不再需要位置回放）
- LocationObserver（不再需要监听位置更新）
- NavigationLocationProvider（不再需要位置提供者）
- Location Puck（不再需要显示当前位置标记）
- NavigationCamera 和 ViewportDataSource（不再需要相机跟随）
- 相机智能跟随逻辑（shouldUpdateCamera 等）
- 全览/跟随模式切换逻辑
- 路线绘制组件（RouteLineAPI、RouteLineView 等）
- 回放统计组件（ReplayStatsCalculator、ReplayStatsBottomSheet）

**保留的组件：**
- NavigationHistoryManager（加载历史文件）
- GeoJsonSource + LineLayer（绘制轨迹）
- 标题栏组件（返回按钮、标题文本）
- 地图样式管理（MapStyleManager、StylePreferenceManager）
- 状态栏样式管理（StatusBarStyleManager）

### 数据流

1. 用户打开历史回放页面，传入历史文件路径
2. 使用 NavigationHistoryManager.loadReplayEvents() 加载历史事件
3. 遍历所有事件，提取位置点（经纬度）和速度数据
4. 计算累计距离，用于后续渐变计算
5. 构建 LineString 几何对象
6. 更新 GeoJsonSource 的数据
7. 根据速度和距离构建 lineGradient 表达式
8. 应用渐变到 LineLayer
9. 计算轨迹边界并调整相机到全览模式
10. 绘制起点（绿色）和终点（红色）标记

## 组件和接口

### 核心类：NavigationReplayActivity

**职责：**
- 管理页面生命周期
- 加载和解析历史文件
- 绘制速度渐变轨迹
- 管理地图样式和 UI 组件

**关键属性：**
```kotlin
private lateinit var binding: MapboxActivityReplayViewBinding
private val traveledPoints = mutableListOf<Point>()
private val traveledSpeedsKmh = mutableListOf<Double>()
private val traveledCumDistMeters = mutableListOf<Double>()
```

**关键方法：**
- `onCreate()`: 初始化页面和地图
- `initTravelLineLayer()`: 初始化轨迹图层
- `handleReplayFile()`: 加载并处理历史文件
- `extractLocationData()`: 从历史事件中提取位置和速度数据
- `drawCompleteRoute()`: 绘制完整轨迹
- `buildSpeedGradientExpression()`: 构建速度渐变表达式
- `adjustCameraToShowRoute()`: 调整相机到全览模式
- `getColorForSpeed()`: 根据速度获取颜色

### 地图图层结构

**数据源（Sources）：**
1. `replay-travel-line-source`: GeoJsonSource，存储轨迹 LineString
   - 必须开启 `lineMetrics(true)`
2. `replay-start-source`: GeoJsonSource，存储起点坐标
3. `replay-end-source`: GeoJsonSource，存储终点坐标

**图层（Layers）：**
1. `replay-travel-line-layer`: LineLayer，显示速度渐变轨迹
   - lineWidth: 8.0
   - lineJoin: LineJoin.ROUND
   - lineGradient: 动态计算的渐变表达式
2. `replay-start-layer`: CircleLayer，显示起点标记（绿色）
   - circleColor: #00E676
   - circleRadius: 6.0
3. `replay-end-layer`: CircleLayer，显示终点标记（红色）
   - circleColor: #FF5252
   - circleRadius: 6.0

**图层顺序：**
所有轨迹相关图层应添加在 `mapbox-location-indicator-layer` 下方（如果存在），确保不遮挡其他地图元素。

## 数据模型

### 位置数据结构

从历史事件中提取的位置数据包含：
- `Point`: Mapbox GeoJSON Point 对象（经度、纬度）
- `speedKmh`: Double，速度（km/h）
- `cumDistMeters`: Double，从起点到当前点的累计距离（米）

### 速度颜色映射

根据速度值映射到不同颜色（适合骑行场景）：

| 速度范围 (km/h) | 颜色代码 | 颜色名称 | 场景描述 |
|----------------|---------|---------|---------|
| < 5.0 | #2E7DFF | 蓝色 | 慢速/停车 |
| 5.0 - 10.0 | #00E5FF | 青色 | 休闲骑行 |
| 10.0 - 15.0 | #00E676 | 绿色 | 正常骑行 |
| 15.0 - 20.0 | #C6FF00 | 黄绿色 | 快速骑行 |
| 20.0 - 25.0 | #FFD600 | 黄色 | 高速骑行 |
| 25.0 - 30.0 | #FF9100 | 橙色 | 冲刺速度 |
| >= 30.0 | #FF1744 | 红色 | 极速/下坡 |


## 正确性属性

*属性是系统在所有有效执行中应该保持为真的特征或行为——本质上是关于系统应该做什么的形式化陈述。属性作为人类可读规范和机器可验证正确性保证之间的桥梁。*

### 属性 1: 完整位置数据提取
*对于任何*有效的历史文件，从事件中提取的位置点数量应等于文件中包含位置信息的事件数量。
**验证: 需求 1.2**

### 属性 2: 速度数据完整性
*对于任何*提取的位置点，应包含对应的速度值，且速度值应为非负数。
**验证: 需求 2.1**

### 属性 3: 累计距离单调递增
*对于任何*轨迹点序列，累计距离数组应严格单调递增（后一个点的累计距离大于前一个点）。
**验证: 需求 6.2**

### 属性 4: LineString 几何有效性
*对于任何*位置点列表（至少2个点），构建的 LineString 应为有效的 GeoJSON 几何对象。
**验证: 需求 1.3**

### 属性 5: 渐变进度值范围
*对于任何*渐变节点，其进度值应在 [0.0, 1.0] 范围内。
**验证: 需求 6.2**

### 属性 6: 渐变进度值严格递增
*对于任何*渐变节点序列，进度值应严格递增（后一个节点的进度值大于前一个节点）。
**验证: 需求 6.4**

### 属性 7: 速度颜色映射一致性
*对于任何*速度值，getColorForSpeed() 函数应返回一致的颜色代码（相同输入产生相同输出）。
**验证: 需求 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8**

### 属性 8: 起终点标记正确性
*对于任何*包含至少2个点的轨迹，起点标记应位于第一个点，终点标记应位于最后一个点。
**验证: 需求 1.5**

### 属性 9: 相机边界包含完整轨迹
*对于任何*轨迹点集合，计算的相机边界应包含所有轨迹点。
**验证: 需求 4.1, 4.2**

### 属性 10: 缩放级别合理性
*对于任何*轨迹范围，计算的缩放级别应在 [10.0, 17.0] 范围内。
**验证: 需求 4.3, 4.5**

### 属性 11: 轨迹点过滤有效性
*对于任何*相邻两个位置点，如果距离小于 0.5 米，后一个点应被过滤掉。
**验证: 需求 3.5**

### 属性 12: 渐变节点采样合理性
*对于任何*轨迹，渐变节点数量应不超过 20 个（起点和终点除外）。
**验证: 需求 6.3**

## 错误处理

### 错误类型

#### 1. FILE_PATH_EMPTY
- 触发条件：Intent 中未提供历史文件路径
- 错误码：无（直接记录警告日志）
- 错误消息：未提供回放文件路径
- 处理方式：记录警告日志，不执行后续操作

#### 2. FILE_LOAD_FAILED
- 触发条件：NavigationHistoryManager.loadReplayEvents() 返回空列表
- 错误码：无
- 错误消息：未能加载回放事件
- 处理方式：记录警告日志，不绘制轨迹

#### 3. INSUFFICIENT_POINTS
- 触发条件：提取的位置点少于 2 个
- 错误码：无
- 错误消息：轨迹点不足，无法绘制
- 处理方式：记录警告日志，不绘制轨迹

#### 4. PARSE_ERROR
- 触发条件：解析历史事件中的位置数据失败
- 错误码：无
- 错误消息：解析位置数据失败: {error details}
- 处理方式：记录错误日志，跳过该事件，继续处理下一个

#### 5. STYLE_NOT_LOADED
- 触发条件：尝试操作地图样式时样式未加载
- 错误码：无
- 错误消息：样式未加载，无法绘制路线
- 处理方式：记录警告日志，等待样式加载完成后重试

### 错误处理流程

1. 捕获所有异常并记录详细日志
2. 对于非致命错误，跳过当前操作继续执行
3. 对于致命错误，记录日志并优雅降级
4. 确保资源正确释放（地图视图、监听器等）


## 测试策略

### 单元测试

#### 位置数据提取测试
- 测试从不同类型的历史事件中正确提取位置和速度
- 测试过滤过近的位置点（< 0.5米）
- 测试累计距离计算的正确性
- 测试处理无效坐标（0, 0）的情况

#### 速度颜色映射测试
- 测试 getColorForSpeed() 对所有速度范围返回正确颜色
- 测试边界值（5.0, 10.0, 15.0 等）
- 测试极端值（负数、超大值）

#### 渐变表达式构建测试
- 测试 buildSpeedGradientExpression() 生成有效的 Expression
- 测试渐变节点进度值严格递增
- 测试渐变节点数量不超过限制
- 测试处理空数据或单点数据的情况

#### 相机计算测试
- 测试 calculateOverviewZoom() 对不同范围返回合理缩放级别
- 测试边界计算包含所有轨迹点
- 测试边距计算（30%）的正确性

### 集成测试

- 测试完整的加载→解析→绘制→显示流程
- 测试使用真实历史文件的端到端场景
- 测试不同大小的历史文件（小、中、大）
- 测试地图样式切换后轨迹仍正确显示
- 测试页面旋转后轨迹和相机状态保持

### 性能测试

- 测试加载大型历史文件（>1000点）的时间应 < 3秒
- 测试渐变表达式构建时间应 < 100ms
- 测试内存使用应合理（< 50MB 增量）
- 测试页面启动到显示轨迹的总时间应 < 5秒

### 手动测试检查清单

- [ ] 轨迹颜色渐变平滑，无明显色块
- [ ] 起点（绿色）和终点（红色）标记位置正确
- [ ] 相机自动调整到全览模式，轨迹完全可见
- [ ] 标题栏显示正确，返回按钮可用
- [ ] 罗盘位置正确，不被标题栏遮挡
- [ ] 比例尺已隐藏
- [ ] 全览按钮已隐藏
- [ ] 地图样式与用户偏好一致
- [ ] 状态栏文字颜色与地图样式匹配
- [ ] 页面加载流畅，无卡顿

