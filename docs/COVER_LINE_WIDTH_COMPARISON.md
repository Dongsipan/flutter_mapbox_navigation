# 封面轨迹线宽度对比分析

## 问题描述
Android 和 iOS 封面中的轨迹线粗细不一致，即使设置了相同的数值，Android 的线条可能仍然比 iOS 粗。

## 技术原理

### Mapbox lineWidth 单位
根据 Mapbox 官方文档：
- **Android LineLayer 的 `lineWidth` 单位是像素（pixels）**，默认值为 1
- **不需要也不应该乘以 `displayMetrics.density`**
- 直接传入的数值就是像素宽度

### iOS 实现
- **绘制方式**: Core Graphics (`CGContext`)
- **线宽设置**: `ctx.setLineWidth(6)` - 单位是**点（points）**
- **像素比例**: `UIScreen.main.scale` (通常 2x 或 3x)
- **实际像素宽度**: 6 points × scale = 12-18 pixels

```swift
let size = CGSize(width: 720, height: 405)
let pixelRatio = CGFloat(UIScreen.main.scale)
ctx.setLineWidth(6)  // 6 points
```

### Android 实现
- **绘制方式**: Mapbox Maps SDK (`lineLayer`)
- **线宽设置**: `lineWidth(6.0)` - 单位是**像素（pixels）**
- **像素比例**: `context.resources.displayMetrics.density`
- **实际像素宽度**: 6.0 pixels（直接使用，不乘 density）

```kotlin
val pixelRatio = context.resources.displayMetrics.density
lineWidth(6.0)  // 6 pixels，不乘 density
```

## 关键要点

### ❌ 错误做法
```kotlin
// 不要这样做！lineWidth 已经是像素单位
val px = 6.0 * context.resources.displayMetrics.density
lineWidth(px)  // 错误：会导致线条过粗
```

### ✅ 正确做法
```kotlin
// lineWidth 直接使用像素值，与 iOS 保持一致
lineWidth(6.0)  // 正确：6 像素
```

## 为什么可能仍有差异

即使使用相同的像素值，Android 和 iOS 的视觉效果可能仍有细微差异，原因包括：

1. **不同的渲染引擎**
   - iOS: Core Graphics
   - Android: Mapbox 渲染引擎

2. **抗锯齿算法不同**
   - 不同平台的抗锯齿实现可能导致边缘模糊程度不同

3. **快照分辨率的细微差异**
   - 虽然都使用 pixelRatio，但实际渲染可能有平台差异

4. **屏幕密度的影响**
   - iOS: 固定的 2x 或 3x
   - Android: 更广泛的密度范围（1.0 - 4.0+）

## 调整历史

| 版本 | iOS 线宽 | Android 线宽 | 说明 |
|------|----------|--------------|------|
| 初始 | 6 points | 8.0 pixels | Android 太粗 |
| 调整1 | 6 points | 6.0 pixels | 理论上应该一致 |
| 调整2 | 6 points | 4.0 pixels | 如果仍然偏粗，尝试减小 |
| 当前 | 6 points | 6.0 pixels | 使用相同像素值（推荐） |

## 推荐设置

### 当前设置（推荐）
```kotlin
// Android - HistoryCoverGenerator.kt
private const val LINE_WIDTH = 6.0  // 像素单位，与 iOS 保持一致
```

```swift
// iOS - HistoryCoverGenerator.swift
ctx.setLineWidth(6)  // points（在 2x 设备上约等于 12 pixels）
```

### 如果需要微调

如果测试后发现 Android 的线条仍然偏粗，可以尝试：
- `5.5` - 轻微减小
- `5.0` - 中等减小
- `4.5` - 较大减小
- `4.0` - 显著减小

如果太细，可以增加到：
- `6.5` 或 `7.0`

## 测试建议

1. **在相同密度的设备上对比**
   - 例如：iPhone 14 Pro (3x) vs Pixel 6 Pro (3.5x)
   - 尽量选择密度接近的设备

2. **截图对比**
   - 生成相同历史记录的封面
   - 放大查看线条粗细
   - 测量实际像素宽度

3. **不同密度设备测试**
   - 低密度 (1.0x-1.5x)
   - 中密度 (2.0x-2.5x)
   - 高密度 (3.0x-3.5x)
   - 超高密度 (4.0x)

## 快速调整指南

如果需要调整 Android 的线宽，只需修改一个常量：

```kotlin
// android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/utilities/HistoryCoverGenerator.kt

// 调整此值（建议范围：4.0 - 7.0）
private const val LINE_WIDTH = 6.0
```

**调整步骤：**
1. 修改 `LINE_WIDTH` 常量
2. 重新编译 Android 应用
3. 生成封面并对比
4. 重复直到满意

## 结论

- **Android 的 `lineWidth` 单位是像素，不需要乘以 density**
- **理论上使用相同的像素值应该能达到相似的视觉效果**
- **如果仍有差异，通过微调 Android 的 `LINE_WIDTH` 常量来校准**
- **当前设置：Android 6.0 pixels，iOS 6 points**

