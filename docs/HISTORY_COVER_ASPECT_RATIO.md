# 历史封面比例调整（隐藏水印版）

## 问题背景

Flutter应用中历史封面有两种不同的显示比例需求：
1. **2.2:1** - 较宽的列表卡片比例
2. **1.91:1** - 社交媒体标准比例

同时，Mapbox地图底部有水印，需要在显示时隐藏。

## 解决方案

生成**更高的封面**（约1.69:1），在底部包含水印区域。显示时使用`Alignment.topCenter`从顶部对齐，自动裁剪底部水印。

### 比例设计

```
生成比例: 1.69:1 (720x426)
├─ 顶部区域 (720x327) ─ 对应 2.2:1 显示区域
├─ 中间区域 (720x377) ─ 对应 1.91:1 显示区域  
└─ 底部区域 (约100px) ─ 水印区域，会被裁剪
```

### 工作原理

| 生成尺寸 | 显示比例 | 显示尺寸 | 效果 |
|---------|---------|---------|------|
| 720x426 | 2.2:1 | 720x327 | 裁剪底部99px（包含水印） |
| 720x426 | 1.91:1 | 720x377 | 裁剪底部49px（包含水印） |

## 实现细节

### iOS修改

**文件**: `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/HistoryCoverGenerator.swift`

```swift
// 尺寸设置
let size = CGSize(width: 720, height: 426) // 约1.69:1

// 边距设置（关键！）
let padding = UIEdgeInsets(
    top: 50,      // 适中的上边距
    left: 50,     // 左右边距保持
    bottom: 110,  // 大幅增加！确保轨迹不会延伸到裁剪区域
    right: 50     // 左右边距保持
)
```

### Android修改

**文件**: `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/utilities/HistoryCoverGenerator.kt`

```kotlin
// 尺寸设置
private const val COVER_WIDTH = 720f
private const val COVER_HEIGHT = 426f  // 约1.69:1

// 边距设置（关键！）
val padding = EdgeInsets(
    50.0,   // top - 适中的上边距
    50.0,   // left - 保持
    110.0,  // bottom - 大幅增加！确保轨迹不会延伸到裁剪区域
    50.0    // right - 保持
)
```

## 边距设计说明

### 为什么这样设计边距？

```
┌─────────────────────────────────────────┐
│  top: 50                                │ ← 适中的上边距
│ ┌─────────────────────────────────────┐ │
│ │                                     │ │
│ │        轨迹主要显示区域              │ │ ← 2.2:1 显示范围
│ │        (有效高度约267px)             │ │   (327px - 50上 - 10安全)
│ ├─────────────────────────────────────┤ │
│ │        轨迹延伸区域                  │ │ ← 1.91:1 显示范围
│ │        (额外50px)                   │ │   (377px - 50上 - 10安全)
│ └─────────────────────────────────────┘ │
│  bottom: 110 (大幅增加！)               │ ← 确保轨迹不进入此区域
│ ┌─────────────────────────────────────┐ │
│ │     裁剪区域 (99px for 2.2:1)       │ │ ← 会被裁剪
│ │     包含 Mapbox 水印                │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
  left:50                         right:50
```

### 边距调整原理

1. **上边距 (50)**
   - 适中的上边距
   - 确保轨迹不会太靠近顶部
   - 在所有显示比例下都有良好的视觉效果

2. **底部边距 (110) - 关键！**
   - 2.2:1 会裁剪底部 99px
   - 底部padding设为110px，留11px安全边距
   - 确保轨迹完全在可见区域内
   - 水印区域(底部110px)会被完全裁剪

3. **左右边距 (50)**
   - 确保轨迹左右完整
   - 适配2.2:1的宽屏比例
   - 在1.91:1显示时也有足够空间

## Flutter显示处理

### 2.2:1 显示（列表卡片）
```dart
AspectRatio(
  aspectRatio: 2.2 / 1,
  child: Image.file(
    File(history.cover!),
    width: double.infinity,
    fit: BoxFit.cover,
    alignment: Alignment.topCenter,  // 关键：从顶部对齐
    errorBuilder: (context, error, stackTrace) {
      return _buildDefaultCover();
    },
  ),
)
```

**效果**: 显示顶部720x327区域，裁剪底部99px（包含水印）

### 1.91:1 显示（社交媒体）
```dart
AspectRatio(
  aspectRatio: 1.91,
  child: ClipRRect(
    borderRadius: BorderRadius.zero,
    child: Image.file(
      File(coverImagePath!),
      width: double.infinity,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,  // 关键：从顶部对齐
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholderCover();
      },
    ),
  ),
)
```

**效果**: 显示顶部720x377区域，裁剪底部49px（包含水印）

## 优势

1. ✅ **水印隐藏** - 在所有显示场景下，底部水印都被裁剪
2. ✅ **轨迹完整** - 轨迹在可见区域内完整显示
3. ✅ **适配性强** - 一个封面适配多种显示场景
4. ✅ **自然裁剪** - 使用topCenter对齐，自动裁剪底部

## 裁剪计算

### 2.2:1 显示
```
生成高度: 426px
显示高度: 720 / 2.2 = 327px
裁剪高度: 426 - 327 = 99px (底部)
```

### 1.91:1 显示
```
生成高度: 426px
显示高度: 720 / 1.91 = 377px
裁剪高度: 426 - 377 = 49px (底部)
```

## 测试验证

### 验证要点

1. ✅ 生成的封面尺寸为 720x426
2. ✅ 在2.2:1容器中，水印被完全裁剪（裁剪99px）
3. ✅ 在1.91:1容器中，水印被完全裁剪（裁剪49px）
4. ✅ 轨迹的起点和终点都在可见区域内
5. ✅ 轨迹不会太靠近顶部边缘

### 测试代码

```dart
// 测试场景1: 2.2:1 列表卡片
Container(
  width: 300,
  child: AspectRatio(
    aspectRatio: 2.2,
    child: Image.file(
      File(coverPath),
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,  // 必须
    ),
  ),
)

// 测试场景2: 1.91:1 详情页
Container(
  width: 400,
  child: AspectRatio(
    aspectRatio: 1.91,
    child: Image.file(
      File(coverPath),
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,  // 必须
    ),
  ),
)
```

## 关键注意事项

### ⚠️ 必须使用 topCenter 对齐

```dart
// ✅ 正确 - 从顶部对齐，裁剪底部水印
alignment: Alignment.topCenter

// ❌ 错误 - 居中对齐，水印可能可见
alignment: Alignment.center

// ❌ 错误 - 底部对齐，轨迹被裁剪
alignment: Alignment.bottomCenter
```

### 水印位置

Mapbox水印通常在底部左侧或右侧，高度约20-30px。我们的设计裁剪了底部49-99px，足以隐藏水印。

## 相关文件

### iOS
- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/HistoryCoverGenerator.swift`

### Android
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/utilities/HistoryCoverGenerator.kt`

## 视觉效果对比

### 生成的封面 (720x426)
```
┌─────────────────────────────────┐
│                                 │
│         轨迹完整显示             │ ← 可见区域
│                                 │
├─────────────────────────────────┤
│      Mapbox 水印                │ ← 会被裁剪
└─────────────────────────────────┘
```

### 2.2:1 显示 (720x327)
```
┌─────────────────────────────────┐
│                                 │
│         轨迹完整显示             │
│                                 │
└─────────────────────────────────┘
(底部99px被裁剪，包含水印)
```

### 1.91:1 显示 (720x377)
```
┌─────────────────────────────────┐
│                                 │
│         轨迹完整显示             │
│                                 │
│                                 │
└─────────────────────────────────┘
(底部49px被裁剪，包含水印)
```
