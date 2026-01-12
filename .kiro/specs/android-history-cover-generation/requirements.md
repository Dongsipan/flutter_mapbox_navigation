# 需求文档

## 简介

本功能为 Android 平台实现导航历史记录的自动封面图生成功能，与 iOS 实现保持一致。当导航历史记录停止时，系统将自动生成一张封面图，显示完整的路线并根据速度应用渐变色。这为用户提供了导航历史的可视化预览。

## 术语表

- **History_Cover**: 历史封面，显示完整导航路线和速度渐变的静态地图快照图片
- **HistoryCoverGenerator**: 历史封面生成器，负责生成封面图的 Android 工具类
- **Snapshotter**: Mapbox Maps SDK 提供的静态地图快照组件
- **Speed_Gradient**: 速度渐变，根据速度值应用到路线的颜色渐变
- **GeoJsonSource**: Mapbox 地图的 GeoJSON 数据源，用于存储路线几何数据
- **LineLayer**: Mapbox 地图的线图层，用于渲染带渐变的路线
- **HistoryManager**: 历史管理器，管理导航历史记录和元数据的 Android 工具类
  - HistoryRecord 字段：id, historyFilePath, cover, startTime, endTime, distance, duration, startPointName, endPointName, navigationMode
- **NavigationHistoryManager**: 导航历史管理器，用于加载和解析历史文件的 Android 工具类

## 需求

### 需求 1

**用户故事:** 作为用户，我希望能看到导航历史的可视化预览，以便快速识别和选择记录。

#### 验收标准

1. WHEN 导航历史记录停止时 THEN 系统应生成封面图
2. WHEN 生成封面图时 THEN 系统应从历史文件中提取位置和速度数据
3. WHEN 封面图生成后 THEN 系统应使用 `{historyId}_cover.png` 命名模式保存
4. WHEN 封面图保存后 THEN 系统应将文件路径存储到历史记录元数据中
5. WHEN 封面生成失败时 THEN 系统应继续保存历史记录但不包含封面

### 需求 2

**用户故事:** 作为用户，我希望封面图显示完整路线，以便一眼看到整个行程。

#### 验收标准

1. WHEN 生成封面图时 THEN 系统应渲染从起点到终点的完整路线
2. WHEN 计算相机位置时 THEN 系统应将所有路线点包含在视口内
3. WHEN 设置相机边界时 THEN 系统应应用适当的边距（上：50px，左：30px，下：50px，右：30px）
4. WHEN 渲染路线时 THEN 系统应用绿色圆圈标记起点
5. WHEN 渲染路线时 THEN 系统应用红色圆圈标记终点

### 需求 3

**用户故事:** 作为用户，我希望封面图显示速度变化，以便了解行程特征。

#### 验收标准

1. WHEN 渲染路线时 THEN 系统应应用基于速度的颜色渐变
2. WHEN 速度低于 5 km/h 时 THEN 路线应显示为蓝色 (#2E7DFF)
3. WHEN 速度在 5-10 km/h 时 THEN 路线应显示为青色 (#00E5FF)
4. WHEN 速度在 10-15 km/h 时 THEN 路线应显示为绿色 (#00E676)
5. WHEN 速度在 15-20 km/h 时 THEN 路线应显示为黄绿色 (#C6FF00)
6. WHEN 速度在 20-25 km/h 时 THEN 路线应显示为黄色 (#FFD600)
7. WHEN 速度在 25-30 km/h 时 THEN 路线应显示为橙色 (#FF9100)
8. WHEN 速度超过 30 km/h 时 THEN 路线应显示为红色 (#FF1744)

### 需求 4

**用户故事:** 作为用户，我希望封面图匹配我偏好的地图样式，以便与导航体验保持一致。

#### 验收标准

1. WHEN 生成封面图时 THEN 系统应使用历史记录中的地图样式
2. WHEN 地图样式为 "standard"、"faded" 或 "monochrome" 时 THEN 系统应应用历史记录中的 light preset
3. WHEN 地图样式为 "faded" 时 THEN 系统应应用 "faded" 主题配置
4. WHEN 地图样式为 "monochrome" 时 THEN 系统应应用 "monochrome" 主题配置
5. WHEN 地图样式不支持 light preset 时 THEN 系统应使用基础样式而不配置 preset

### 需求 5

**用户故事:** 作为开发者，我希望封面生成是非阻塞的，以便不延迟历史记录保存操作。

#### 验收标准

1. WHEN 停止历史记录时 THEN 系统应立即捕获必要数据
2. WHEN 封面生成开始时 THEN 系统应异步执行
3. WHEN 封面生成完成时 THEN 系统应用封面路径更新历史记录
4. WHEN 封面生成失败时 THEN 系统应记录错误但不影响历史记录
5. WHEN 请求多个封面生成时 THEN 系统应独立执行而不相互干扰

### 需求 6

**用户故事:** 作为用户，我希望封面图有一致的尺寸，以便在列表和网格中正确显示。

#### 验收标准

1. WHEN 生成封面图时 THEN 系统应使用 720x405 像素尺寸（16:9 宽高比）
2. WHEN 生成封面图时 THEN 系统应使用设备的像素密度进行渲染
3. WHEN 保存封面图时 THEN 系统应使用 PNG 格式
4. WHEN 保存封面图时 THEN 系统应使用原子写入操作防止损坏
5. WHEN 封面文件已存在时 THEN 系统应用新图片覆盖

### 需求 7

**用户故事:** 作为用户，我希望路线清晰可见，以便轻松看到我走过的路径。

#### 验收标准

1. WHEN 渲染路线时 THEN 系统应使用 6 像素的线宽
2. WHEN 渲染路线时 THEN 系统应使用圆角线连接
3. WHEN 渲染路线时 THEN 系统应使用圆角线端点
4. WHEN 渲染起终点标记时 THEN 系统应使用 5 像素的半径
5. WHEN 路线少于 2 个点时 THEN 系统应跳过封面生成

### 需求 8

**用户故事:** 作为开发者，我希望有适当的错误处理，以便封面生成失败不会导致应用崩溃。

#### 验收标准

1. WHEN 无法读取历史文件时 THEN 系统应记录错误并返回 null
2. WHEN 位置数据提取失败时 THEN 系统应记录错误并返回 null
3. WHEN Snapshotter 初始化失败时 THEN 系统应记录错误并返回 null
4. WHEN 快照渲染失败时 THEN 系统应记录错误并返回 null
5. WHEN 文件写入失败时 THEN 系统应记录错误并返回 null

