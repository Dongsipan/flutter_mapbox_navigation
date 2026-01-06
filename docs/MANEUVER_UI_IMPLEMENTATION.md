# 转弯指令 UI 组件实现说明

## 实现日期
2026-01-05

## 实现内容

### 1. 集成的组件
- **MapboxManeuverApi**: 用于获取转弯指令数据
- **改进的 UI 布局**: 包含图标、距离、指令文本和下一个转弯预览

### 2. 实现位置
- Kotlin 代码: `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
- 布局文件: `android/src/main/res/layout/navigation_activity.xml`

### 3. UI 组件结构

#### 3.1 布局改进
新的转弯指令面板包含:
- **转弯图标** (ImageView): 48x48dp,显示转弯类型图标
- **距离信息** (TextView): 显示到转弯点的距离
- **转弯指令文本** (TextView): 显示主要转弯指令
- **下一个转弯预览** (LinearLayout): 显示下一个转弯的图标和文本

#### 3.2 视觉层次
```
┌─────────────────────────────────────┐
│ [图标]  距离: In 500 m              │
│         转弯指令: Turn left onto... │
│         [小图标] Then turn right    │
└─────────────────────────────────────┘
```

### 4. 主要功能

#### 4.1 初始化
在 `initializeManeuverApi()` 方法中:
- 创建 MapboxManeuverApi 实例
- 使用默认的 ManeuverOptions 配置

#### 4.2 转弯指令更新
在 `updateManeuverUI()` 方法中:
- 使用 ManeuverApi 获取转弯数据
- 更新转弯指令文本
- 计算并显示距离信息
- 根据转弯类型显示相应图标
- 显示下一个转弯预览(如果有)

#### 4.3 图标映射
`getManeuverIconResource()` 方法:
- 将转弯类型和修饰符映射到 Android 系统图标
- 支持的转弯类型:
  - turn (left/right/slight/sharp)
  - arrive/depart
  - merge/fork
  - roundabout/rotary
  - continue

#### 4.4 距离格式化
- 距离 >= 1000m: 显示为 "X.X km"
- 距离 < 1000m: 显示为 "X m"
- 格式: "In [distance]"

### 5. 数据流

```
BannerInstructions (SDK)
    ↓
bannerInstructionObserver
    ↓
updateManeuverUI()
    ↓
ManeuverApi.getManeuver()
    ↓
更新 UI 组件:
  - maneuverIcon
  - maneuverDistance
  - maneuverText
  - nextManeuverIcon
  - nextManeuverText
```

### 6. 错误处理

- 使用 `fold()` 处理 ManeuverApi 返回的 Result
- 捕获所有异常并记录日志
- 失败时不影响导航继续进行
- 仍然发送事件到 Flutter 层

### 7. 配置支持

- 通过 `FlutterMapboxNavigationPlugin.bannerInstructionsEnabled` 控制
- 当禁用时不更新 UI,但仍发送事件

## 验证需求

根据 Requirements 7:

✅ 7.1 - WHEN navigation is active THEN the system SHALL display banner instructions
- 实现: 在 bannerInstructionObserver 中显示面板

✅ 7.2 - WHEN bannerInstructionsEnabled is true THEN the system SHALL show instruction banners
- 实现: 检查配置标志

✅ 7.3 - WHEN bannerInstructionsEnabled is false THEN the system SHALL hide instruction banners
- 实现: 配置为 false 时不调用 updateManeuverUI

✅ 7.4 - WHEN approaching a maneuver THEN the system SHALL update the banner with current instruction
- 实现: 在 bannerInstructionObserver 中自动更新

✅ 7.5 - THE system SHALL use BannerInstructionsObserver to receive banner updates
- 实现: 已注册 bannerInstructionObserver

✅ 7.6 - THE system SHALL display maneuver icons and distance information
- 实现: 显示图标、距离和指令文本

## UI 特性

### 视觉设计
- **白色背景**: 清晰可读
- **阴影效果**: elevation="8dp" 提供深度感
- **图标大小**: 主图标 48dp,次图标 24dp
- **文字层次**: 
  - 距离: 14sp, 灰色
  - 主指令: 16sp, 粗体, 黑色
  - 次指令: 12sp, 灰色

### 响应式布局
- 使用 ConstraintLayout 确保适配不同屏幕
- 图标和文本自适应内容
- 下一个转弯预览可选显示

### 动画效果
- 面板显示/隐藏使用 visibility 切换
- 可以添加淡入淡出动画(未实现)

## 测试建议

### 单元测试
1. 测试 getManeuverIconResource 的映射逻辑
2. 测试距离格式化函数
3. 测试 ManeuverApi 初始化

### 集成测试
1. 启动导航并验证指令显示
2. 测试不同转弯类型的图标显示
3. 测试距离更新的准确性
4. 测试下一个转弯预览的显示/隐藏
5. 测试禁用横幅指令后的行为

### 手动测试
1. 启动模拟导航,观察指令面板
2. 验证图标与转弯类型匹配
3. 验证距离信息准确更新
4. 验证下一个转弯预览正确显示
5. 测试复杂路线的指令切换

## 已知限制

1. **图标资源**: 当前使用 Android 系统图标,不够美观
2. **图标方向**: 图标不会根据转弯方向旋转
3. **动画效果**: 没有实现平滑的过渡动画
4. **自定义样式**: 颜色和字体大小硬编码

## 后续改进建议

### 高优先级
1. **自定义图标**: 使用 Mapbox 官方转弯图标
2. **图标旋转**: 根据转弯角度旋转图标
3. **动画效果**: 添加淡入淡出和滑动动画

### 中优先级
4. **样式配置**: 支持自定义颜色和字体
5. **多语言支持**: 确保所有语言正确显示
6. **可访问性**: 添加 TalkBack 支持

### 低优先级
7. **车道指引**: 显示车道选择指示
8. **路牌信息**: 显示路牌和出口编号
9. **交通标志**: 显示限速等交通标志

## 自定义图标实现指南

### 步骤 1: 准备图标资源
将 Mapbox 转弯图标放入 `res/drawable/` 目录:
- `ic_turn_left.xml`
- `ic_turn_right.xml`
- `ic_turn_slight_left.xml`
- 等等...

### 步骤 2: 更新映射函数
```kotlin
private fun getManeuverIconResource(type: String?, modifier: String?): Int {
    return when (type) {
        "turn" -> when (modifier) {
            "left" -> R.drawable.ic_turn_left
            "right" -> R.drawable.ic_turn_right
            "slight left" -> R.drawable.ic_turn_slight_left
            "slight right" -> R.drawable.ic_turn_slight_right
            "sharp left" -> R.drawable.ic_turn_sharp_left
            "sharp right" -> R.drawable.ic_turn_sharp_right
            else -> R.drawable.ic_turn_straight
        }
        "arrive" -> R.drawable.ic_arrive
        "depart" -> R.drawable.ic_depart
        // ... 其他类型
        else -> R.drawable.ic_turn_straight
    }
}
```

### 步骤 3: 添加图标旋转
```kotlin
// 根据转弯角度旋转图标
val rotation = getRotationForModifier(modifier)
binding.maneuverIcon.rotation = rotation
```

## 与 iOS 对齐

iOS 实现使用类似的 UI 结构:
- 显示转弯图标、距离和指令文本
- 支持下一个转弯预览
- 使用 Mapbox Navigation SDK 的 ManeuverView

Android 实现提供了相同的功能和用户体验。

## 性能考虑

- ManeuverApi 调用是轻量级的
- UI 更新在主线程进行,但不会阻塞
- 图标资源使用系统缓存
- 距离计算简单高效

## 可访问性

当前实现:
- ImageView 有 contentDescription
- TextView 自动支持 TalkBack

建议改进:
- 添加完整的语义描述
- 支持大字体模式
- 提供高对比度主题

