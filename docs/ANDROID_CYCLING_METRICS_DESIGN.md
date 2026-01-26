# Android 骑行导航指标设计 - 卡片网格布局

## 设计概述

基于专业骑行应用的 UI/UX 设计，采用卡片网格布局展示导航指标，提供清晰、专业的骑行导航体验。

## 设计灵感

参考专业骑行应用的指标展示方式，采用：
- 大字号时间显示（最重要的信息）
- 2x2 网格布局的次要指标
- 深色卡片背景 + 微妙边框
- 清晰的视觉层次

## 布局结构

```
┌─────────────────────────────────────────┐
│                                         │
│            6 min                        │  ← 时间（绿色，48sp）
│         Time remaining                  │
│                                         │
├──────────────────┬──────────────────────┤
│                  │                      │
│    1.2 km        │      1:29 pm        │  ← 距离 + ETA
│    Distance      │        ETA          │
│                  │                      │
├──────────────────┼──────────────────────┤
│                  │                      │
│    26.3          │       45%           │  ← 速度 + 进度
│    Speed         │     Progress        │
│                  │                      │
└──────────────────┴──────────────────────┘
```

## 指标说明

### 1. 时间剩余 (Time Remaining) - 顶部大卡片
- **字号**: 48sp
- **颜色**: 绿色 #01E47C
- **字体**: sans-serif-condensed (运动感)
- **位置**: 顶部居中，最显眼
- **原因**: 骑行时最关心的是还需要多久到达

### 2. 距离剩余 (Distance) - 左上卡片
- **字号**: 28sp
- **颜色**: 白色 #FFFFFF
- **格式**: 
  - ≥ 1000m: "X.X km"
  - < 1000m: "XXX m"

### 3. 预计到达时间 (ETA) - 右上卡片
- **字号**: 28sp
- **颜色**: 白色 #FFFFFF
- **格式**: "h:mm a" (例如: "1:29 pm")

### 4. 当前速度 (Speed) - 左下卡片
- **字号**: 28sp
- **颜色**: 白色 #FFFFFF
- **单位**: km/h
- **来源**: GPS location.speed * 3.6

### 5. 进度百分比 (Progress) - 右下卡片
- **字号**: 28sp
- **颜色**: 白色 #FFFFFF
- **格式**: "XX%"
- **计算**: (已行驶距离 / 总距离) * 100

## 卡片样式

### 指标卡片背景
```xml
<shape>
    <corners android:radius="16dp" />
    <solid android:color="#1A1C1E" />
    <stroke android:width="1dp" android:color="#20FFFFFF" />
</shape>
```

- **圆角**: 16dp (现代感)
- **背景**: #1A1C1E (深灰色)
- **边框**: 1dp 半透明白色 (#20FFFFFF)
- **间距**: 卡片间距 12dp

## 颜色系统

| 元素 | 颜色 | 用途 |
|------|------|------|
| 时间值 | #01E47C (绿色) | 最重要信息，主题色 |
| 其他值 | #FFFFFF (白色) | 清晰可见 |
| 标签 | #8AFFFFFF (半透明白) | 次要信息 |
| 卡片背景 | #1A1C1E | 深灰色 |
| 卡片边框 | #20FFFFFF | 微妙边框 |
| 容器背景 | #040608 | 深黑色 |

## 字体系统

- **数值**: sans-serif-condensed (运动感，紧凑)
- **标签**: sans-serif (标准)
- **大小**:
  - 时间: 48sp (超大)
  - 指标值: 28sp (大)
  - 标签: 12-14sp (小)

## 间距系统

```
卡片内边距:     16dp
卡片间距:       12dp
顶部卡片下边距: 12dp
容器内边距:     20dp
```

## 技术实现

### 文件结构
```
android/src/main/res/
├── layout/
│   ├── custom_trip_progress_view.xml  (自定义指标视图)
│   └── navigation_activity.xml        (主布局)
├── drawable/
│   └── metric_card_background.xml     (指标卡片背景)
```

### Kotlin 更新逻辑
```kotlin
private fun updateCustomTripProgressView(routeProgress: RouteProgress) {
    // 时间 - 绿色
    val minutes = (routeProgress.durationRemaining / 60).toInt()
    timeRemainingValue.text = "$minutes min"
    
    // 距离 - 白色
    val distanceText = if (distanceRemaining >= 1000) {
        String.format("%.1f km", distanceRemaining / 1000)
    } else {
        String.format("%.0f m", distanceRemaining)
    }
    
    // ETA - 白色
    val eta = System.currentTimeMillis() + (durationRemaining * 1000).toLong()
    etaValue.text = SimpleDateFormat("h:mm a").format(Date(eta))
    
    // 速度 - 白色 (km/h)
    val speedKmh = location.speed * 3.6f
    speedValue.text = String.format("%.1f", speedKmh)
    
    // 进度 - 白色
    val progressPercent = (distanceTraveled / totalDistance * 100).toInt()
    progressValue.text = "$progressPercent%"
}
```

## 设计优势

### ✅ 优点
1. **清晰的层次**: 时间最大 → 其他指标次之
2. **专业感**: 类似专业骑行应用的布局
3. **信息密度**: 5 个关键指标一目了然
4. **运动美学**: 紧凑字体 + 大字号数值
5. **易读性**: 高对比度，户外可见
6. **现代感**: 卡片布局 + 圆角 + 微妙边框

### 🎯 用户体验
- **快速扫视**: 大字号时间立即可见
- **完整信息**: 距离、ETA、速度、进度全覆盖
- **骑行优化**: 字体紧凑，信息密集但不拥挤
- **专业感**: 类似 Strava、Komoot 等专业应用

## 对比标准 TripProgressView

| 特性 | 标准 View | 自定义卡片 |
|------|-----------|------------|
| 布局 | 横向单行 | 网格布局 |
| 时间显示 | 小字 | 48sp 大字 |
| 信息密度 | 3 项 | 5 项 |
| 视觉层次 | 平等 | 明确（时间最大）|
| 速度显示 | 无 | 有 |
| 进度显示 | 无 | 有 (%) |
| 专业感 | 一般 | 高 |

## 可扩展性

未来可添加的指标（如果有数据）：
- 心率 (Heart Rate)
- 踏频 (Cadence)
- 爬升 (Climb)
- 平均速度 (Avg Speed)
- 卡路里 (Calories)

只需在网格中添加新卡片即可。

## 可访问性

- ✅ 大字号数值 (28sp+)
- ✅ 高对比度 (7:1+)
- ✅ 清晰标签
- ✅ 支持 TalkBack

---

**设计日期**: 2026-01-26  
**版本**: v1.0  
**设计工具**: UI/UX PRO MAX  
**设计师**: Kiro AI Assistant
