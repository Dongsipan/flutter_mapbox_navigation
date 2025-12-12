# 设计文档

## 概述

本设计文档描述了为 Flutter Mapbox Navigation 插件添加历史事件获取 API 的技术实现方案。该 API 允许开发者根据历史记录 ID 获取详细的导航事件数据，包括位置更新、路线分配和自定义事件等。

核心功能包括：
- 使用 Mapbox HistoryReader 解析历史文件
- 提取并序列化所有类型的 HistoryEvent
- 通过 Platform Channel 将数据传递给 Flutter 层
- 提供完善的错误处理和性能优化

## 架构

### 整体架构

系统采用分层架构，分为 Flutter 层和原生层（iOS/Android）。Flutter 层通过 Platform Channel 与原生层通信，原生层使用 Mapbox SDK 的 HistoryReader 解析历史文件并返回事件数据。

### 数据流

1. Flutter 应用调用 getNavigationHistoryEvents(historyId)
2. 请求通过 Platform Channel 发送到原生层
3. 原生层根据 historyId 查找对应的历史文件路径
4. 使用 HistoryReader 解析历史文件
5. 提取并分类所有 HistoryEvent
6. 将事件序列化为 JSON 格式
7. 通过 Platform Channel 返回给 Flutter 层
8. Flutter 层解析 JSON 为 Dart 对象

## 组件和接口

### Flutter 层组件

#### NavigationHistoryEvents 模型
包含历史记录 ID、事件列表、原始位置数据和初始路线信息。

#### HistoryEventData 模型
表示单个历史事件，包含事件类型和事件数据。

#### LocationData 模型
表示位置信息，包含经纬度、海拔、精度、速度、方向和时间戳。

#### Platform Interface 方法
定义 getNavigationHistoryEvents 方法接口。

### iOS 原生层组件

#### HistoryEventsParser 类
负责解析历史文件、提取事件和序列化数据。

#### 方法处理器
在 FlutterMapboxNavigationPlugin 中处理 getNavigationHistoryEvents 方法调用。

## 数据模型

### JSON 数据结构

完整响应包含 historyId、events 数组、rawLocations 数组和 initialRoute 对象。

每个事件包含 eventType 和 data 字段，不同类型的事件有不同的数据结构。



## 正确性属性

*属性是系统在所有有效执行中应该保持为真的特征或行为——本质上是关于系统应该做什么的形式化陈述。属性作为人类可读规范和机器可验证正确性保证之间的桥梁。*

### 属性 1: 完整事件提取
*对于任何*有效的历史文件，解析后返回的事件列表应包含文件中的所有事件，且事件数量应等于原始事件数量。
**验证: 需求 1.1, 1.2**

### 属性 2: 位置事件字段完整性
*对于任何* LocationUpdateHistoryEvent，序列化后的 JSON 应包含所有必需字段（latitude, longitude, altitude, horizontalAccuracy, verticalAccuracy, speed, course, timestamp）。
**验证: 需求 2.2**

### 属性 3: 路线事件信息完整性
*对于任何* RouteAssignmentHistoryEvent，序列化后的 JSON 应包含路线的关键信息（distance, duration, geometry）。
**验证: 需求 2.3**

### 属性 4: 自定义事件 JSON 解析
*对于任何* UserPushedHistoryEvent，其 properties 字符串应被成功解析为有效的 JSON 对象。
**验证: 需求 1.4, 2.4**

### 属性 5: 事件类型标识
*对于任何*返回的事件，JSON 数据应包含 eventType 字段，且该字段的值应为有效的事件类型标识符。
**验证: 需求 1.6**

### 属性 6: JSON 序列化往返一致性
*对于任何*事件数据，序列化为 JSON 后再反序列化应得到等价的数据结构。
**验证: 需求 2.1, 2.6**

### 属性 7: 原始位置数据提取
*对于任何*历史文件，解析后应提取 History 对象中的 rawLocations 数组，且数组长度应大于等于 2。
**验证: 需求 5.1, 5.5**

### 属性 8: 位置数据时间顺序
*对于任何*返回的位置数据数组，位置点应按时间戳升序排列。
**验证: 需求 5.3**

### 属性 9: 无效坐标过滤
*对于任何*包含无效坐标（纬度不在 -90 到 90 或经度不在 -180 到 180）的位置数据，系统应过滤或标记这些数据。
**验证: 需求 5.4**

### 属性 10: 跨平台数据结构一致性
*对于任何*历史记录，在 iOS 和 Android 平台上调用 API 返回的 JSON 数据结构应保持一致。
**验证: 需求 4.3, 4.5**

### 属性 11: 错误日志记录
*对于任何*错误情况（文件不存在、解析失败等），系统应记录包含错误类型和详细信息的日志。
**验证: 需求 3.5**

### 属性 12: 后台线程执行
*对于任何*历史文件解析操作，该操作应在后台线程执行，不应阻塞主线程。
**验证: 需求 6.1**

### 属性 13: 大文件解析性能
*对于任何*包含超过 1000 个事件的历史文件，解析操作应在 5 秒内完成。
**验证: 需求 6.2**

### 属性 14: 数据传输优化
*对于任何*序列化的事件数据，JSON 应只包含必要的字段，不包含冗余或未使用的字段。
**验证: 需求 6.3**

## 错误处理

### 错误类型

#### 1. HISTORY_NOT_FOUND
- 触发条件：传入的历史记录 ID 在数据库中不存在
- 错误码：HISTORY_NOT_FOUND
- 错误消息：History record with id {historyId} not found
- 处理方式：返回 FlutterError 给 Flutter 层

#### 2. FILE_NOT_FOUND
- 触发条件：历史文件路径无效或文件不存在
- 错误码：FILE_NOT_FOUND
- 错误消息：History file not found at path {filePath}
- 处理方式：返回 FlutterError 给 Flutter 层

#### 3. PARSE_ERROR
- 触发条件：HistoryReader 解析历史文件失败
- 错误码：PARSE_ERROR
- 错误消息：Failed to parse history file: {error details}
- 处理方式：记录详细错误日志，返回 FlutterError 给 Flutter 层

#### 4. READER_CREATION_FAILED
- 触发条件：无法创建 HistoryReader 实例
- 错误码：READER_CREATION_FAILED
- 错误消息：Failed to create HistoryReader for file {filePath}
- 处理方式：返回 FlutterError 给 Flutter 层

#### 5. SERIALIZATION_ERROR
- 触发条件：事件数据序列化为 JSON 失败
- 错误码：SERIALIZATION_ERROR
- 错误消息：Failed to serialize event data: {error details}
- 处理方式：记录错误日志，返回 FlutterError 给 Flutter 层

### 错误处理流程

1. 捕获所有异常并转换为 FlutterError
2. 记录详细的错误日志（包括堆栈跟踪）
3. 返回用户友好的错误消息
4. 确保资源正确清理（关闭文件句柄等）

## 测试策略

### 单元测试

#### Flutter 层测试
- 测试 NavigationHistoryEvents.fromMap 正确解析 JSON
- 测试 HistoryEventData.fromMap 正确解析不同类型的事件
- 测试 LocationData.fromMap 正确解析位置数据
- 测试错误情况下的异常处理

#### iOS 原生层测试
- 测试 HistoryEventsParser 正确解析历史文件
- 测试不同类型事件的提取和序列化
- 测试错误情况的处理
- 测试文件路径解析逻辑

### 属性测试

属性测试使用 Flutter 的 test 包和 iOS 的 XCTest 框架。每个属性测试应运行至少 100 次迭代。

#### 属性测试标记格式
每个属性测试必须使用以下格式标记：
```
Feature: history-events-api, Property {number}: {property_text}
```

### 集成测试

- 测试完整的 Flutter 到原生层的调用流程
- 测试真实历史文件的解析
- 测试跨平台一致性
- 测试性能指标（解析时间、内存使用）

### 性能测试

- 测试不同大小历史文件的解析时间
- 测试内存使用情况
- 测试并发调用的性能
- 测试缓存机制的效果

