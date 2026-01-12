# 设计文档

## 概述

本设计文档描述了 Android 平台导航历史封面自动生成功能的实现方案，与 iOS 实现保持一致。该功能在导航历史记录停止时自动生成封面图，显示完整的路线并根据速度应用渐变色，为用户提供可视化的历史预览。

核心功能包括：
- 创建 HistoryCoverGenerator 工具类
- 使用 Mapbox Snapshotter API 生成静态地图快照
- 从历史文件中提取位置和速度数据
- 应用速度渐变到路线渲染
- 支持地图样式和 light preset 配置
- 异步非阻塞生成
- 自动更新历史记录元数据

## 架构

### 整体架构

**新增组件：**
- `HistoryCoverGenerator`: 单例工具类，负责封面生成的核心逻辑
- `HistoryCoverCallback`: 回调接口，用于异步返回生成结果

**修改组件：**
- `HistoryManager`: 添加 `updateHistoryCover()` 方法，支持更新封面路径
- `HistoryRecord`: 添加 `cover` 字段，存储封面文件路径
- `TurnByTurn` 或 `NavigationActivity`: 在停止历史记录时调用封面生成

**依赖关系：**
```
TurnByTurn/NavigationActivity
    ↓ (调用)
HistoryCoverGenerator
    ↓ (使用)
NavigationHistoryManager (加载历史文件)
Mapbox Snapshotter (生成快照)
    ↓ (更新)
HistoryManager (保存封面路径)
```

### 数据流

1. 用户停止导航历史记录
2. 系统立即捕获必要数据（historyId, filePath, mapStyle, lightPreset）
3. 异步启动封面生成任务
4. 使用 NavigationHistoryManager 加载历史文件
5. 从历史事件中提取位置点和速度数据
6. 过滤过近的点（< 0.5米）
7. 构建 LineString 几何对象
8. 创建 MapSnapshotOptions（720x405, 设备像素密度）
9. 创建 Snapshotter 并设置样式 URI
10. 设置 SnapshotStyleListener 等待样式加载
11. 样式加载完成后：
    - 添加 route-source（开启 lineMetrics）
    - 添加 route-layer（配置 lineGradient）
    - 添加起终点数据源和图层
    - 应用 light preset 和 theme 配置（如果适用）
    - 设置相机位置（cameraForGeometry）
12. 调用 snapshotter.start() 生成快照
13. 保存为 PNG 文件
14. 使用 HistoryManager 更新历史记录的 cover 字段
15. 通过回调返回结果
16. 销毁 Snapshotter 释放资源

## 组件和接口

### HistoryCoverGenerator

**职责：**
- 管理封面生成的完整流程
- 加载和解析历史文件
- 配置和使用 Mapbox Snapshotter
- 绘制速度渐变路线
- 保存封面图片
- 更新历史记录元数据

**关键属性：**
```kotlin
object HistoryCoverGenerator {
    private const val TAG = "HistoryCoverGenerator"
    private const val COVER_WIDTH = 720
    private const val COVER_HEIGHT = 405  // 16:9 aspect ratio
    private const val LINE_WIDTH = 6f
    private const val MARKER_RADIUS = 5f
    private const val MIN_POINT_DISTANCE = 0.5  // meters
}
```

**关键方法：**
```kotlin
// 生成封面的主入口方法
fun generateHistoryCover(
    context: Context,
    filePath: String,
    historyId: String,
    mapStyle: String?,
    lightPreset: String?,
    callback: HistoryCoverCallback
)

// 从历史文件提取位置和速度数据
private fun extractLocationData(
    events: List<ReplayEventBase>
): Triple<List<Point>, List<Double>, List<Double>>

// 根据速度获取颜色
private fun getColorForSpeed(speedKmh: Double): Int

// 构建速度渐变表达式
private fun buildSpeedGradientExpression(
    points: List<Point>,
    speeds: List<Double>,
    cumDistances: List<Double>
): Expression

// 获取地图样式 URI
private fun getStyleUri(mapStyle: String?): String

// 应用样式配置（light preset 和 theme）
private fun applyStyleConfig(
    snapshotter: Snapshotter,
    mapStyle: String,
    lightPreset: String
)

// 保存快照到文件
private fun saveSnapshot(
    bitmap: Bitmap,
    historyId: String,
    context: Context
): String?
 
// 更新历史记录的封面路径
private fun updateHistoryRecord(
    context: Context,
    historyId: String,
    coverPath: String
)
```

### HistoryCoverCallback

**接口定义：**
```kotlin
interface HistoryCoverCallback {
    fun onSuccess(coverPath: String)
    fun onFailure(error: String)
}
```

### 地图图层结构

封面生成使用 Snapshotter 的 SnapshotStyleListener，在样式加载完成后动态添加数据源和图层。

**数据源（Sources）：**
1. `route-source`: GeoJsonSource，存储轨迹 LineString
   - 必须开启 `lineMetrics(true)` 支持渐变
2. `start-point-source`: GeoJsonSource，存储起点坐标
3. `end-point-source`: GeoJsonSource，存储终点坐标

**图层（Layers）：**
1. `route-layer`: LineLayer，显示速度渐变轨迹
   - lineWidth: 8.0
   - lineCap: LineCap.ROUND
   - lineJoin: LineJoin.ROUND
   - lineGradient: 使用 interpolate + lineProgress 实现渐变
2. `start-point-layer`: CircleLayer，显示起点标记（绿色）
3. `end-point-layer`: CircleLayer，显示终点标记（红色）

## 数据模型

### 位置数据结构

从历史事件中提取的数据：
```kotlin
data class LocationData(
    val points: List<Point>,           // 位置点列表
    val speedsKmh: List<Double>,       // 速度列表（km/h）
    val cumDistMeters: List<Double>    // 累计距离列表（米）
)
```

### 速度颜色映射

与 iOS 和 NavigationReplayActivity 保持一致：

| 速度范围 (km/h) | 颜色代码 | 颜色名称 | 场景描述 |
|----------------|---------|---------|---------|
| < 5.0 | #2E7DFF | 蓝色 | 慢速/停车 |
| 5.0 - 10.0 | #00E5FF | 青色 | 休闲骑行 |
| 10.0 - 15.0 | #00E676 | 绿色 | 正常骑行 |
| 15.0 - 20.0 | #C6FF00 | 黄绿色 | 快速骑行 |
| 20.0 - 25.0 | #FFD600 | 黄色 | 高速骑行 |
| 25.0 - 30.0 | #FF9100 | 橙色 | 冲刺速度 |
| >= 30.0 | #FF1744 | 红色 | 极速/下坡 |

### 地图样式映射

```kotlin
private fun getStyleUri(mapStyle: String?): String {
    return when (mapStyle) {
        "standard", "faded", "monochrome" -> Style.STANDARD
        "standardSatellite" -> Style.SATELLITE_STREETS
        "light" -> Style.LIGHT
        "dark" -> Style.DARK
        "outdoors" -> Style.OUTDOORS
        else -> Style.MAPBOX_STREETS
    }
}
```

### Light Preset 支持

支持 light preset 的样式：
- standard
- standardSatellite
- faded
- monochrome

Theme 配置：
- faded → "faded"
- monochrome → "monochrome"
- standard → "default"


## 正确性属性

*属性是系统在所有有效执行中应该保持为真的特征或行为——本质上是关于系统应该做什么的形式化陈述。属性作为人类可读规范和机器可验证正确性保证之间的桥梁。*

### 属性 1: 位置数据提取完整性
*对于任何*有效的历史文件，提取的位置点数量应等于文件中包含有效位置信息的事件数量（过滤掉无效坐标和过近的点后）。
**验证: 需求 1.2**

### 属性 2: 速度数据一致性
*对于任何*提取的位置点，应包含对应的速度值，且速度值应为非负数。
**验证: 需求 1.2**

### 属性 3: 文件命名一致性
*对于任何*historyId，生成的封面文件名应遵循 `{historyId}_cover.png` 模式。
**验证: 需求 1.3**

### 属性 4: 元数据更新一致性
*对于任何*成功生成的封面，其文件路径应被存储到对应的历史记录的 cover 字段中。
**验证: 需求 1.4**

### 属性 5: 轨迹边界包含性
*对于任何*轨迹点集合，计算的相机边界应包含所有轨迹点。
**验证: 需求 2.2**

### 属性 6: 起终点标记正确性
*对于任何*包含至少2个点的轨迹，起点标记应位于第一个点（绿色），终点标记应位于最后一个点（红色）。
**验证: 需求 2.4, 2.5**

### 属性 7: 速度颜色映射一致性
*对于任何*速度值，getColorForSpeed() 函数应返回一致的颜色值（相同输入产生相同输出）。
**验证: 需求 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8**

### 属性 8: 渐变应用完整性
*对于任何*有速度数据的轨迹，应用速度渐变后的路线应包含所有速度区间的颜色。
**验证: 需求 3.1**

### 属性 9: 地图样式应用一致性
*对于任何*地图样式，生成的封面应使用该样式对应的 StyleURI。
**验证: 需求 4.1**

### 属性 10: 封面路径更新幂等性
*对于任何*历史记录，多次使用相同的封面路径调用 updateHistoryCover() 应产生相同的结果。
**验证: 需求 5.3**

### 属性 11: 文件格式一致性
*对于任何*保存的封面文件，其格式应为 PNG。
**验证: 需求 6.3**

### 属性 12: 并发安全性
*对于任何*多个并发的封面生成请求，每个请求应独立执行，不相互干扰。
**验证: 需求 5.5**

## 错误处理

### 错误类型

#### 1. FILE_READ_ERROR
- 触发条件：无法读取历史文件或文件不存在
- 错误消息：无法读取历史文件: {filePath}
- 处理方式：记录错误日志，通过回调返回 null，不影响历史记录保存

#### 2. DATA_EXTRACTION_ERROR
- 触发条件：从历史事件中提取位置数据失败
- 错误消息：位置数据提取失败: {error details}
- 处理方式：记录错误日志，通过回调返回 null

#### 3. INSUFFICIENT_POINTS
- 触发条件：提取的位置点少于 2 个
- 错误消息：轨迹点不足，无法生成封面
- 处理方式：记录警告日志，通过回调返回 null

#### 4. SNAPSHOTTER_INIT_ERROR
- 触发条件：Snapshotter 初始化失败
- 错误消息：Snapshotter 初始化失败
- 处理方式：记录错误日志，通过回调返回 null

#### 5. SNAPSHOT_RENDER_ERROR
- 触发条件：快照渲染失败
- 错误消息：快照渲染失败: {error details}
- 处理方式：记录错误日志，通过回调返回 null

#### 6. FILE_WRITE_ERROR
- 触发条件：无法写入封面文件
- 错误消息：封面保存失败: {error details}
- 处理方式：记录错误日志，通过回调返回 null

### 错误处理流程

1. 所有错误都应被捕获并记录详细日志
2. 错误不应导致应用崩溃
3. 错误应通过回调接口返回给调用者
4. 封面生成失败不应影响历史记录的保存
5. 确保资源正确释放（Snapshotter、文件句柄等）

## 测试策略

### 单元测试

#### 位置数据提取测试
- 测试从不同类型的历史事件中正确提取位置和速度
- 测试过滤无效坐标（0, 0）
- 测试过滤过近的位置点（< 0.5米）
- 测试累计距离计算的正确性

#### 速度颜色映射测试
- 测试 getColorForSpeed() 对所有速度范围返回正确颜色
- 测试边界值（5.0, 10.0, 15.0 等）
- 测试极端值（负数、超大值）

#### 文件命名测试
- 测试不同 historyId 生成正确的文件名
- 测试特殊字符处理

#### 地图样式映射测试
- 测试所有支持的地图样式返回正确的 StyleURI
- 测试未知样式的降级处理

### 集成测试

- 测试完整的生成流程：加载→提取→渲染→保存→更新
- 测试使用真实历史文件的端到端场景
- 测试不同大小的历史文件（小、中、大）
- 测试不同地图样式的封面生成
- 测试 light preset 和 theme 配置的应用

### 性能测试

- 测试加载大型历史文件（>1000点）的时间应 < 5秒
- 测试封面生成总时间应 < 10秒
- 测试内存使用应合理（< 100MB 增量）
- 测试并发生成多个封面的性能

### 手动测试检查清单

- [ ] 封面图显示完整路线
- [ ] 速度渐变颜色正确且平滑
- [ ] 起点（绿色）和终点（红色）标记位置正确
- [ ] 封面图尺寸为 720x405 像素
- [ ] 封面图格式为 PNG
- [ ] 封面图文件名正确
- [ ] 历史记录的 cover 字段已更新
- [ ] 地图样式与历史记录一致
- [ ] Light preset 应用正确（如果适用）
- [ ] 封面生成不阻塞 UI
- [ ] 封面生成失败不影响历史记录保存
- [ ] 删除历史记录时封面文件也被删除
