# Android SDK v3 后续工作计划

## 日期
2026-01-05

## 当前状态
✅ MVP 完成 - 基础导航功能可用
⚠️ 需要完善和优化

## 优先级任务

### 🔥 高优先级 (本周)

#### 1. 修复 NavigationActivity 中的 Deprecated API
**文件:** `NavigationActivity.kt`
**问题:**
- `getMapboxMap()` → 使用 `mapboxMap` 属性
- `getStyle()` → 使用 `style` 属性  
- `loadStyleUri()` → 使用新的样式加载方法
- `cameraForCoordinates()` → 使用新的相机 API
- `getSerializableExtra()` → 使用类型安全的方法

**影响:** 低 (仅警告,不影响功能)
**工作量:** 1-2 小时

#### 2. 测试和验证位置更新
**目标:** 确认位置服务修复是否有效
**测试项:**
- 位置更新事件
- 相机跟随
- 导航进度数据

**影响:** 高 (核心功能)
**工作量:** 1 小时测试


### ⚡ 中优先级 (下周)

#### 3. 修复其他文件的 Deprecated API
**文件:**
- `NavigationReplayActivity.kt` - 12 处警告
- `PluginUtilities.kt` - 3 处警告

**工作量:** 2-3 小时

#### 4. 完善临时禁用的功能
**需要重写的功能:**
- Free Drive 模式
- Embedded Navigation View
- Custom Info Panel
- 地图点击回调

**工作量:** 1-2 天

### 📋 低优先级 (未来)

#### 5. 实现缺失的高级功能
**功能列表:**
- 历史记录回放 (完整功能)
- 搜索功能
- 路线选择
- 地图样式选择器

**工作量:** 1-2 周

#### 6. 性能优化
- 内存使用优化
- 电池消耗优化
- 渲染性能优化

**工作量:** 3-5 天

## 建议的执行顺序

### 第一步: 快速修复 (今天)
1. 修复 NavigationActivity 的 deprecated API
2. 重新测试位置更新

### 第二步: 完善功能 (本周)
3. 修复其他文件的 deprecated API
4. 重写 Free Drive 模式

### 第三步: 高级功能 (下周+)
5. 实现历史记录功能
6. 实现搜索功能
7. 性能优化

## 详细任务清单

### Task 1: 修复 NavigationActivity Deprecated API

#### 1.1 修复 getMapboxMap()
```kotlin
// 旧代码
binding.mapView.getMapboxMap().loadStyleUri(styleUrl)

// 新代码
binding.mapView.mapboxMap.loadStyle(styleUrl)
```

#### 1.2 修复 getStyle()
```kotlin
// 旧代码
binding.mapView.getMapboxMap().getStyle()?.let { style ->

// 新代码
binding.mapView.mapboxMap.style?.let { style ->
```

#### 1.3 修复 cameraForCoordinates()
```kotlin
// 旧代码
val cameraOptions = binding.mapView.getMapboxMap().cameraForCoordinates(
    routePoints,
    EdgeInsets(100.0, 100.0, 100.0, 100.0)
)

// 新代码
val cameraOptions = binding.mapView.mapboxMap.cameraForCoordinateBounds(
    CoordinateBounds(routePoints, false),
    EdgeInsets(100.0, 100.0, 100.0, 100.0)
)
```

## 相关文档
- [ANDROID_SDK_V3_MVP_SUCCESS.md](ANDROID_SDK_V3_MVP_SUCCESS.md)
- [ANDROID_SDK_V3_TESTING_STATUS.md](ANDROID_SDK_V3_TESTING_STATUS.md)
- [.kiro/specs/android-sdk-v3-upgrade/tasks.md](.kiro/specs/android-sdk-v3-upgrade/tasks.md)
