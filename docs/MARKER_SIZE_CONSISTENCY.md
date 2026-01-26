# 起点和终点标记大小一致性

## 修改总结

确保封面和回放页面中的起点/终点圆点大小保持一致。

## 当前设置

### iOS

**封面生成 (HistoryCoverGenerator.swift)**
```swift
// 起点和终点圆点半径
let r: CGFloat = 6  // points
```

**回放页面 (HistoryReplayViewController.swift)**
```swift
// 起点和终点圆点半径
startLayer.circleRadius = .constant(6.0)
endLayer.circleRadius = .constant(6.0)
```

✅ **一致**: 都使用半径 `6`

### Android

**封面生成 (HistoryCoverGenerator.kt)**
```kotlin
// 起点和终点圆点半径
private const val MARKER_RADIUS = 6.0  // pixels
circleRadius(MARKER_RADIUS)
```

**回放页面 (NavigationReplayActivity.kt)**
```kotlin
// 起点和终点圆点半径
circleRadius(6.0)
```

✅ **一致**: 都使用半径 `6.0`

## 修改历史

| 位置 | 修改前 | 修改后 |
|------|--------|--------|
| iOS 封面 | 半径 5 | 半径 6 |
| iOS 回放 | 半径 6.0 | 半径 6.0（无变化）|
| Android 封面 | 半径 6.0 | 半径 6.0（无变化）|
| Android 回放 | 半径 6.0 | 半径 6.0（无变化）|

## 视觉效果

- **起点标记**: 绿色圆点 (#00E676)，半径 6
- **终点标记**: 红色圆点 (#FF5252)，半径 6
- **封面和回放页面**: 完全一致的视觉效果

## 注意事项

1. **单位一致性**
   - iOS: 使用 `points`（逻辑单位）
   - Android: 使用 `pixels`（物理单位）
   - 数值相同（6）应该产生相似的视觉效果

2. **颜色一致性**
   - 起点: `#00E676` (绿色)
   - 终点: `#FF5252` (红色)
   - 所有平台和页面都使用相同的颜色

3. **如需调整**
   - 修改常量即可：
     - iOS 封面: `let r: CGFloat = 6`
     - iOS 回放: `circleRadius = .constant(6.0)`
     - Android 封面: `MARKER_RADIUS = 6.0`
     - Android 回放: `circleRadius(6.0)`
