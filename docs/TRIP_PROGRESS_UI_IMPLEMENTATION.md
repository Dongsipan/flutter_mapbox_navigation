# 行程进度 UI 组件实现说明

## 实现日期
2026-01-05

## 实现内容

### 1. 集成的组件
- **MapboxTripProgressApi**: 用于获取格式化的行程进度数据
- **TripProgressUpdateFormatter**: 用于格式化进度信息
- **改进的 UI 布局**: 显示距离、时间和 ETA

### 2. 实现位置
- Kotlin 代码: `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
- 布局文件: `android/src/main/res/layout/navigation_activity.xml`

### 3. UI 组件结构

#### 3.1 布局改进
行程进度面板现在包含三列信息:
- **距离列**: 标签 + 剩余距离
- **时间列**: 标签 + 剩余时间
- **ETA 列**: 标签 + 预计到达时间

#### 3.2 视觉布局
```
┌─────────────────────────────────────┐
│  Distance    Time        ETA        │
│   5.2 km    12 min     14:35        │
└─────────────────────────────────────┘
```

### 4. 主要功能

#### 4.1 初始化
在 `initializeTripProgressApi()` 方法中:
- 创建 MapboxTripProgressApi 实例
- 使用 TripProgressUpdateFormatter 配置格式化器
- 支持本地化和单位设置

#### 4.2 进度更新
在 `updateNavigationUI()` 方法中:
- 使用 TripProgressApi 获取格式化的进度数据
- 更新距离剩余显示
- 更新时间剩余显示
- 计算并更新 ETA

#### 4.3 数据格式化

**距离格式化** (由 TripProgressApi 处理):
- 自动选择合适的单位 (km/m, mi/ft)
- 根据语言设置本地化
- 示例: "5.2 km", "3.2 mi"

**时间格式化** (由 TripProgressApi 处理):
- 自动选择合适的格式 (小时/分钟)
- 根据语言设置本地化
- 示例: "12 min", "1h 25min"

**ETA 格式化** (自定义实现):
- 计算当前时间 + 剩余时间
- 格式: "HH:MM" (24小时制)
- 示例: "14:35", "09:15"

#### 4.4 错误处理
提供回退机制 `updateNavigationUIFallback()`:
- 当 TripProgressApi 失败时使用
- 手动格式化距离和时间
- 确保 UI 始终有数据显示

### 5. 数据流

```
RouteProgress (SDK)
    ↓
routeProgressObserver
    ↓
updateNavigationUI()
    ↓
TripProgressApi.getTripProgress()
    ↓
更新 UI 组件:
  - distanceRemainingText
  - durationRemainingText
  - etaText
```

### 6. 实时更新

- 进度信息在 `routeProgressObserver` 中持续更新
- 更新频率由 SDK 控制(通常每秒多次)
- UI 更新在主线程进行
- 使用格式化的字符串直接显示

### 7. 本地化支持

TripProgressUpdateFormatter 支持:
- 多语言文本
- 不同的单位系统(公制/英制)
- 日期和时间格式
- 数字格式

配置示例:
```kotlin
TripProgressUpdateFormatter.Builder(context)
    .distanceRemainingFormatter(/* custom formatter */)
    .timeRemainingFormatter(/* custom formatter */)
    .build()
```

## 验证需求

根据 Requirements 8:

✅ 8.1 - WHEN navigation is active THEN the system SHALL track route progress continuously
- 实现: 在 routeProgressObserver 中持续跟踪

✅ 8.2 - WHEN progress updates THEN the system SHALL send progress events to Flutter layer
- 实现: 已在 routeProgressObserver 中发送事件

✅ 8.3 - WHEN progress updates THEN the system SHALL update distance remaining
- 实现: 使用 TripProgressApi 更新距离

✅ 8.4 - WHEN progress updates THEN the system SHALL update duration remaining (ETA)
- 实现: 更新时间剩余和 ETA

✅ 8.5 - THE system SHALL use RouteProgressObserver for progress tracking
- 实现: 已注册 routeProgressObserver

✅ 8.6 - THE system SHALL include current leg and step information in progress events
- 实现: RouteProgress 包含完整信息

## UI 特性

### 视觉设计
- **三列布局**: 均匀分布,易于阅读
- **标签 + 数值**: 清晰的信息层次
- **标签样式**: 12sp, 灰色
- **数值样式**: 18sp, 粗体, 黑色
- **白色背景**: 与地图形成对比

### 响应式设计
- 使用 layout_weight 均匀分配空间
- 文本居中对齐
- 适配不同屏幕宽度

### 信息优先级
1. **距离**: 最重要,用户最关心
2. **时间**: 次重要,规划行程
3. **ETA**: 辅助信息,到达时间

## 性能考虑

### 更新频率
- SDK 控制更新频率(高效)
- UI 更新轻量级(只更新文本)
- 不会造成性能问题

### 内存使用
- TripProgressApi 是轻量级对象
- 格式化器复用,不重复创建
- 字符串对象及时回收

### 电池优化
- 不执行额外的计算
- 依赖 SDK 的优化机制
- UI 更新不触发重绘整个视图

## 测试建议

### 单元测试
1. 测试 formatETA 函数的准确性
2. 测试回退机制的正确性
3. 测试边界情况(0距离,0时间)

### 集成测试
1. 启动导航并验证进度显示
2. 测试长距离路线的格式化
3. 测试短距离路线的格式化
4. 测试 ETA 计算的准确性
5. 测试单位切换(公制/英制)

### 手动测试
1. 启动模拟导航,观察进度更新
2. 验证距离递减正确
3. 验证时间递减正确
4. 验证 ETA 随时间推移更新
5. 测试不同语言的显示

## 已知限制

1. **ETA 格式**: 固定为 24 小时制
2. **时区**: 使用设备本地时区
3. **精度**: 依赖 SDK 的计算精度
4. **自定义格式**: 当前使用默认格式化器

## 后续改进建议

### 高优先级
1. **12/24 小时制切换**: 根据系统设置
2. **进度条**: 添加视觉进度指示
3. **动画效果**: 数值变化时的动画

### 中优先级
4. **自定义格式化器**: 支持更多格式选项
5. **多路段信息**: 显示当前路段进度
6. **速度显示**: 添加当前速度信息

### 低优先级
7. **历史数据**: 显示平均速度等统计
8. **预测准确性**: 基于交通状况调整
9. **主题支持**: 深色/浅色主题

## 自定义格式化器示例

### 自定义距离格式化
```kotlin
val distanceFormatter = object : DistanceRemainingFormatter {
    override fun format(distance: Double): String {
        return if (distance >= 1000) {
            "%.1f km away".format(distance / 1000)
        } else {
            "%d m away".format(distance.toInt())
        }
    }
}

val formatter = TripProgressUpdateFormatter.Builder(this)
    .distanceRemainingFormatter(distanceFormatter)
    .build()
```

### 自定义时间格式化
```kotlin
val timeFormatter = object : TimeRemainingFormatter {
    override fun format(duration: Double): String {
        val hours = (duration / 3600).toInt()
        val minutes = ((duration % 3600) / 60).toInt()
        return when {
            hours > 0 -> "$hours hr $minutes min"
            minutes > 0 -> "$minutes min"
            else -> "< 1 min"
        }
    }
}
```

## 与 iOS 对齐

iOS 实现使用类似的进度显示:
- 显示距离、时间和 ETA
- 使用 Mapbox Navigation SDK 的格式化器
- 实时更新进度信息

Android 实现提供了相同的功能和用户体验。

## 可访问性

当前实现:
- TextView 自动支持 TalkBack
- 标签提供上下文信息
- 数值清晰易读

建议改进:
- 添加内容描述
- 支持大字体模式
- 提供语音播报选项

## 国际化

支持的本地化:
- 距离单位(公制/英制)
- 时间格式
- 数字格式
- 文本方向(LTR/RTL)

配置方式:
- 通过 TripProgressUpdateFormatter
- 根据系统语言设置
- 支持运行时切换

## 数据准确性

### 距离计算
- 基于 GPS 位置和路线几何
- 考虑路线曲线
- 实时更新

### 时间估算
- 基于历史交通数据
- 考虑当前速度
- 动态调整

### ETA 计算
- 当前时间 + 剩余时间
- 考虑时区
- 精确到分钟

