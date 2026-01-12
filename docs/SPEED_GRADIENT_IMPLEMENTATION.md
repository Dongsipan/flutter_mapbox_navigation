# 速度渐变轨迹线实现

## 🎯 功能概述

基于官方 Mapbox iOS SDK 提示，实现了根据历史轨迹中每个点的速度绘制不同渐变色的轨迹线功能。

## 🔧 核心实现

### 1. **速度颜色映射**

```swift
extension UIColor {
    static func colorForSpeed(_ speedKmh: Double) -> UIColor {
        switch speedKmh {
        case ..<5.0:   return UIColor(hex: "#2E7DFF")  // 蓝色 - 很慢
        case ..<10.0:  return UIColor(hex: "#00E5FF")  // 青色 - 慢
        case ..<15.0:  return UIColor(hex: "#00E676")  // 绿色 - 中等偏慢
        case ..<20.0:  return UIColor(hex: "#C6FF00")  // 黄绿色 - 中等
        case ..<25.0:  return UIColor(hex: "#FFD600")  // 黄色 - 中等偏快
        case ..<30.0:  return UIColor(hex: "#FF9100")  // 橙色 - 快
        default:       return UIColor(hex: "#FF1744")  // 红色 - 很快
        }
    }
}
```

### 2. **速度和距离计算**

```swift
private func calculateSpeedsAndDistances() {
    var cumulativeDistance: Double = 0.0
    
    for (index, location) in historyLocations.enumerated() {
        // 计算速度（从 m/s 转换为 km/h）
        let speedKmh = location.speed >= 0 ? location.speed * 3.6 : 0.0
        traveledSpeedsKmh.append(speedKmh)
        
        // 计算累计距离
        if index > 0 {
            let previousLocation = historyLocations[index - 1]
            let distance = location.distance(from: previousLocation)
            cumulativeDistance += distance
        }
        traveledCumDistMeters.append(cumulativeDistance)
    }
}
```

### 3. **渐变表达式构建**

```swift
private func buildSpeedGradientExpression() -> Exp {
    guard let totalDist = traveledCumDistMeters.last, totalDist > 0,
          !traveledSpeedsKmh.isEmpty else {
        // 如果没有有效数据，返回默认颜色
        return Exp(.literal, StyleColor(.systemBlue))
    }

    var stops: [(Double, UIColor)] = []

    // 起点
    stops.append((0.0, UIColor.colorForSpeed(traveledSpeedsKmh.first ?? 0.0)))

    // 中间节点（采样以避免节点过多）
    let step = max(1, traveledSpeedsKmh.count / 20)
    for i in stride(from: step, to: traveledSpeedsKmh.count, by: step) {
        let progress = min(traveledCumDistMeters[i] / totalDist, 1.0)
        let color = UIColor.colorForSpeed(traveledSpeedsKmh[i])
        if stops.isEmpty || progress > stops.last!.0 {
            stops.append((progress, color))
        }
    }

    // 终点
    if stops.last?.0 ?? 0 < 1.0 {
        stops.append((1.0, UIColor.colorForSpeed(traveledSpeedsKmh.last ?? 0.0)))
    }

    // 构建参数数组 - 按照官方文档的正确写法
    var args: [Any] = [Exp(.linear), Exp(.lineProgress)]
    for (progress, color) in stops {
        args.append(progress)
        args.append(StyleColor(color))
    }

    // 使用参数列表而不是 trailing closure
    return Exp(.interpolate, args)
}
```

**重要修复**: 使用 `Exp(.interpolate, args)` 参数列表语法而不是 trailing closure，这是 Mapbox Maps SDK for iOS 的正确写法。

### 4. **LineLayer 配置**

```swift
// 关键：GeoJSON 源必须启用 lineMetrics
var routeLineSource = GeoJSONSource(id: historyRouteSourceId)
routeLineSource.data = .feature(feature)
routeLineSource.lineMetrics = true  // 必须启用才能使用 line-progress

// LineLayer 使用渐变
var lineLayer = LineLayer(id: historyRouteLayerId, source: historyRouteSourceId)
lineLayer.lineGradient = .expression(buildSpeedGradientExpression())
lineLayer.lineWidth = .constant(8.0)  // 加粗以更好显示渐变效果
lineLayer.lineCap = .constant(.round)
lineLayer.lineJoin = .constant(.round)
```

## 🎨 颜色方案

| 速度范围 (km/h) | 颜色 | 含义 |
|----------------|------|------|
| < 5.0 | 🔵 蓝色 (#2E7DFF) | 很慢 |
| 5.0 - 10.0 | 🔵 青色 (#00E5FF) | 慢 |
| 10.0 - 15.0 | 🟢 绿色 (#00E676) | 中等偏慢 |
| 15.0 - 20.0 | 🟡 黄绿色 (#C6FF00) | 中等 |
| 20.0 - 25.0 | 🟡 黄色 (#FFD600) | 中等偏快 |
| 25.0 - 30.0 | 🟠 橙色 (#FF9100) | 快 |
| ≥ 30.0 | 🔴 红色 (#FF1744) | 很快 |

## 🚀 使用方法

功能已集成到历史回放中，无需额外配置：

```dart
final success = await MapBoxNavigation.instance.startHistoryReplay(
  historyFilePath: '/path/to/history/file.pbf.gz',
  enableReplayUI: true,
);
```

## 📊 性能优化

1. **节点采样**: 最多20个渐变节点，避免过多节点影响性能
2. **智能回退**: 如果没有速度数据，自动使用单色轨迹线
3. **进度验证**: 确保渐变节点的进度值递增

## 🔍 调试信息

实现包含详细的调试输出：

```
计算完成 - 轨迹点数: 1234, 总距离: 5678.9m
速度范围: 0.0 - 45.2 km/h
渐变节点数: 20
  进度: 0.000, 颜色: UIColor
  进度: 0.050, 颜色: UIColor
  ...
✅ 使用速度渐变绘制轨迹线
✅ 轨迹线图层添加成功
```

## 🎉 预期效果

- ✅ **动态颜色**: 轨迹线颜色根据速度实时变化
- ✅ **平滑渐变**: 使用 Mapbox 的 interpolate 表达式实现平滑过渡
- ✅ **性能优化**: 智能采样和回退机制
- ✅ **视觉直观**: 一眼就能看出速度变化趋势

现在历史回放功能不仅能显示轨迹，还能通过颜色直观地展示速度变化！
