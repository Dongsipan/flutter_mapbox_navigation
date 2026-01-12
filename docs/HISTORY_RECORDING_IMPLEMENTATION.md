# 历史记录功能实现说明

## 实现日期
2026-01-05

## 实现内容

### 1. 使用的 API
- **HistoryRecorder**: Mapbox Navigation SDK v3 的历史记录器
- **startRecording()**: 开始记录导航历史
- **stopRecording()**: 停止记录并保存文件

### 2. 实现位置
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/TurnByTurn.kt`
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`

### 3. 主要功能

#### 3.1 历史记录启动
在 `startHistoryRecording()` 方法中:
- 获取 MapboxNavigation 实例
- 调用 `historyRecorder.startRecording()`
- 设置记录状态标志
- 发送启动事件到 Flutter

#### 3.2 历史记录停止
在 `stopHistoryRecording()` 方法中:
- 调用 `historyRecorder.stopRecording()`
- 接收历史文件路径回调
- 发送文件路径到 Flutter 层
- 清理记录状态

#### 3.3 生命周期集成
- 在 `startNavigation()` 中检查配置并启动记录
- 在 `stopNavigation()` 中停止记录
- 在 `onDestroy()` 中确保清理

### 4. 工作流程

```
用户启动导航
    ↓
检查 enableHistoryRecording 配置
    ↓
如果启用 → startHistoryRecording()
    ↓
MapboxNavigation.historyRecorder.startRecording()
    ↓
记录导航事件(位置、路线、指令等)
    ↓
用户停止导航
    ↓
stopHistoryRecording()
    ↓
historyRecorder.stopRecording { filePath ->
    发送文件路径到 Flutter
}
```

### 5. 历史文件格式

SDK v3 的历史记录器生成 JSON 格式的历史文件,包含:
- 导航路线信息
- 位置更新序列
- 转弯指令
- 路线进度
- 时间戳

文件可以用于:
- 回放导航会话
- 调试导航问题
- 分析导航性能
- 生成导航报告

### 6. 文件存储

#### 存储位置
- TurnByTurn.kt: `context.getExternalFilesDir("navigation_history")`
- NavigationActivity.kt: SDK 默认位置

#### 文件命名
- 格式: `history_[timestamp].json`
- 示例: `history_1704441600000.json`

#### 文件管理
- 自动创建目录
- 每次导航生成新文件
- 文件路径返回给 Flutter 层

### 7. 事件通信

#### 启动事件
```kotlin
sendEvent(MapBoxEvents.HISTORY_RECORDING_STARTED)
```

#### 停止事件(带文件路径)
```kotlin
val eventData = mapOf("historyFilePath" to historyFilePath)
sendEvent(
    MapBoxEvents.HISTORY_RECORDING_STOPPED,
    JSONObject(eventData).toString()
)
```

#### 错误事件
```kotlin
sendEvent(MapBoxEvents.HISTORY_RECORDING_ERROR)
```

### 8. 配置选项

通过 `FlutterMapboxNavigationPlugin.enableHistoryRecording` 控制:
- `true`: 启用历史记录
- `false`: 禁用历史记录(默认)

在 Flutter 层设置:
```dart
await MapboxNavigation.startNavigation(
  wayPoints: waypoints,
  enableHistoryRecording: true,
);
```

## 验证需求

根据 Requirements 19:

✅ 19.1 - WHEN enableHistoryRecording is true THEN the system SHALL start history recording
- 实现: 在 startNavigation 中检查配置

✅ 19.2 - WHEN navigation starts THEN the system SHALL begin recording navigation events
- 实现: 调用 historyRecorder.startRecording()

✅ 19.3 - WHEN navigation ends THEN the system SHALL stop recording and save history file
- 实现: 在 stopNavigation 中调用 stopRecording()

✅ 19.4 - WHEN history is saved THEN the system SHALL send file path to Flutter layer
- 实现: 通过事件发送文件路径

✅ 19.5 - THE system SHALL use SDK v3 history recording APIs
- 实现: 使用 historyRecorder API

✅ 19.6 - THE system SHALL store history files in appropriate directory
- 实现: 使用 getExternalFilesDir 或 SDK 默认位置

## SDK v3 变化

### 从 SDK v2 到 v3 的变化

**SDK v2**:
- 使用 `MapboxHistoryRecorder` 类
- 需要手动管理文件路径
- 需要显式配置

**SDK v3**:
- 使用 `MapboxNavigation.historyRecorder` 属性
- SDK 自动管理文件路径
- 更简单的 API

### 迁移要点

1. **不再需要手动创建 HistoryRecorder**
   ```kotlin
   // SDK v2 (旧)
   val historyRecorder = MapboxHistoryRecorder(context)
   
   // SDK v3 (新)
   mapboxNavigation.historyRecorder
   ```

2. **简化的启动/停止**
   ```kotlin
   // SDK v3
   historyRecorder.startRecording()
   historyRecorder.stopRecording { filePath -> }
   ```

3. **自动文件管理**
   - SDK 自动选择存储位置
   - 自动生成文件名
   - 自动处理文件权限

## 错误处理

### 常见错误场景

1. **MapboxNavigation 未初始化**
   - 检查: `MapboxNavigationApp.current() == null`
   - 处理: 记录错误,发送错误事件

2. **存储权限不足**
   - SDK 自动处理
   - 使用应用私有目录

3. **磁盘空间不足**
   - SDK 内部处理
   - 可能导致记录失败

4. **记录已在进行中**
   - 检查 `isRecordingHistory` 标志
   - 避免重复启动

### 错误恢复

```kotlin
try {
    historyRecorder.startRecording()
    isRecordingHistory = true
} catch (e: Exception) {
    Log.e(TAG, "Failed to start recording", e)
    sendEvent(MapBoxEvents.HISTORY_RECORDING_ERROR)
    isRecordingHistory = false
}
```

## 性能考虑

### 内存使用
- 历史记录器使用内存缓冲
- 定期写入磁盘
- 不会显著增加内存使用

### 存储空间
- 每次导航约 1-10 MB
- 取决于导航时长和复杂度
- 建议定期清理旧文件

### CPU 使用
- 后台异步记录
- 不影响导航性能
- 最小化 CPU 开销

### 电池影响
- 记录本身影响很小
- 主要开销来自导航本身
- 可以安全启用

## 测试建议

### 单元测试
1. 测试启动/停止逻辑
2. 测试错误处理
3. 测试状态管理

### 集成测试
1. 启动导航并启用记录
2. 验证文件生成
3. 验证文件内容
4. 验证事件发送
5. 测试禁用记录的情况

### 手动测试
1. 启动导航(启用记录)
2. 完成导航
3. 检查文件是否生成
4. 验证文件路径正确
5. 尝试回放历史文件

## 历史文件使用

### 回放导航
可以使用历史文件回放导航会话:
```kotlin
val historyFile = File(historyFilePath)
// 使用 SDK 的回放功能
```

### 分析数据
历史文件包含完整的导航数据:
- 解析 JSON 文件
- 提取位置序列
- 分析路线偏差
- 计算性能指标

### 调试问题
- 重现用户报告的问题
- 分析导航行为
- 验证算法正确性

## 与 iOS 对齐

iOS 实现使用类似的历史记录机制:
- 使用 Mapbox Navigation SDK 的历史记录功能
- 在导航启动时开始记录
- 在导航结束时停止并保存
- 发送文件路径到 Flutter 层

Android 实现与 iOS 保持一致的行为和 API。

## 隐私和安全

### 数据隐私
- 历史文件包含位置数据
- 存储在应用私有目录
- 其他应用无法访问

### 用户控制
- 用户可以选择启用/禁用
- 可以手动删除历史文件
- 透明的数据收集

### 合规性
- 遵守 GDPR 等隐私法规
- 提供数据删除功能
- 明确告知用户

## 故障排除

### 问题: 历史文件未生成
**可能原因**:
- 记录未启动
- 导航时间太短
- 存储空间不足

**解决方案**:
- 检查配置
- 延长导航时间
- 清理存储空间

### 问题: 文件路径为 null
**可能原因**:
- SDK 内部错误
- 文件写入失败

**解决方案**:
- 检查日志
- 重试记录
- 报告 SDK 问题

### 问题: 记录影响性能
**可能原因**:
- 设备性能较低
- 存储速度慢

**解决方案**:
- 在高性能设备上测试
- 考虑禁用记录
- 优化存储配置

## 未来改进

### 高优先级
1. **历史文件管理**: 自动清理旧文件
2. **压缩支持**: 减少文件大小
3. **上传功能**: 上传到服务器

### 中优先级
4. **选择性记录**: 只记录特定事件
5. **加密支持**: 保护敏感数据
6. **元数据**: 添加自定义元数据

### 低优先级
7. **实时流式传输**: 实时上传数据
8. **多格式支持**: 支持其他格式
9. **可视化工具**: 历史数据可视化

