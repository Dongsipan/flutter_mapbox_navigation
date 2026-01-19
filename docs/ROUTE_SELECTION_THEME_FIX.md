# 路线选择面板主题修复

## 问题描述
路线选择面板（Select a Route）的样式不符合深色主题要求：
- 底部卡片背景为白色
- 路线名称（Fastest Route）使用蓝色而非主题色
- 按钮样式与样式选择器页面不一致
- 卡片没有顶部圆角

## 修复内容

### 1. 颜色资源更新 (colors.xml)

添加了底部卡片专用背景色：
```xml
<!-- 底部卡片背景色 - 更深的颜色 -->
<color name="colorBottomCard">#0C1010</color>
```

### 2. 创建自定义背景 (bottom_card_background.xml)

创建了只有顶部圆角的背景drawable：
```xml
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="@color/colorBottomCard" />
    <corners
        android:topLeftRadius="16dp"
        android:topRightRadius="16dp"
        android:bottomLeftRadius="0dp"
        android:bottomRightRadius="0dp" />
</shape>
```

### 3. 布局文件更新 (navigation_activity.xml)

#### 主要改动：

**底部卡片背景**
```xml
<!-- 修改前 -->
android:background="@android:color/white"

<!-- 修改后 -->
android:background="@drawable/bottom_card_background"  <!-- #0C1010 + 顶部圆角 -->
```

**标题文字颜色**
```xml
<!-- 修改前 -->
android:textColor="@android:color/black"

<!-- 修改后 -->
android:textColor="@color/textPrimary"  <!-- 白色 -->
```

**按钮样式**
```xml
<!-- 修改前 -->
<Button
    android:background="@android:color/holo_blue_dark"
    android:textColor="@android:color/white" />

<!-- 修改后 -->
<com.google.android.material.button.MaterialButton
    app:cornerRadius="8dp"
    app:backgroundTint="@color/colorPrimary"
    android:textSize="16sp" />
```

### 4. Kotlin 代码更新 (NavigationActivity.kt)

#### 路线名称颜色

```kotlin
// 修改前
setTextColor(if (index == selectedRouteIndex) 
    android.graphics.Color.BLUE 
else 
    android.graphics.Color.BLACK)

// 修改后
setTextColor(
    if (index == selectedRouteIndex) 
        resources.getColor(R.color.colorPrimary, null)  // 主题绿色
    else 
        resources.getColor(R.color.textPrimary, null)   // 白色
)
```

#### 距离和时间文字颜色

```kotlin
// 修改前
setTextColor(android.graphics.Color.GRAY)

// 修改后
setTextColor(resources.getColor(R.color.textSecondary, null))  // 半透明白色
```

## 最终效果

### 颜色配置

| 元素 | 颜色 | 说明 |
|------|------|------|
| 底部卡片背景 | `#0C1010` | 更深的深色 |
| 卡片圆角 | 16dp (仅顶部) | border-radius: 16px 16px 0px 0px |
| 标题文字 | `#FFFFFF` | 白色 |
| 选中路线名称 | `#01E47C` | 主题绿色 |
| 未选中路线名称 | `#FFFFFF` | 白色 |
| 距离/时间文字 | `#FFFFFF` (54% 透明度) | 半透明白色 |
| 按钮背景 | `#01E47C` | 主题绿色 |
| 按钮圆角 | 8dp | 与样式选择器一致 |

### 视觉检查清单

- [x] 底部卡片背景为 #0C1010
- [x] 卡片只有顶部有 16dp 圆角
- [x] 标题 "Select a Route" 为白色
- [x] 选中的路线名称（Fastest Route）为主题绿色
- [x] 未选中的路线名称为白色
- [x] 距离和时间文字为半透明白色
- [x] 按钮使用 Material Button
- [x] 按钮背景为主题绿色
- [x] 按钮圆角为 8dp

## 相关文件

### 新建文件
- `android/src/main/res/drawable/bottom_card_background.xml`

### 修改文件
- `android/src/main/res/values/colors.xml`
- `android/src/main/res/layout/navigation_activity.xml`
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`

## 设计规范

### 底部卡片层级
```
页面背景 (#040608)
  └─ 底部卡片 (#0C1010) - 比页面背景稍亮
      └─ 按钮 (#01E47C) - 主题色
```

### 圆角规范
- 底部卡片：16dp (仅顶部)
- 按钮：8dp (四周)
- 与样式选择器页面保持一致

### 文字颜色规范
- 标题：白色 (#FFFFFF)
- 选中项：主题色 (#01E47C)
- 未选中项：白色 (#FFFFFF)
- 辅助信息：半透明白色 (#FFFFFF 54%)

## 测试建议

1. 启动导航并显示路线选择面板
2. 检查底部卡片背景是否为 #0C1010
3. 检查卡片顶部是否有 16dp 圆角
4. 检查卡片底部是否没有圆角（贴合屏幕底部）
5. 点击不同路线，检查选中状态的颜色变化
6. 检查按钮的圆角是否为 8dp
7. 检查按钮背景是否为主题绿色

## 注意事项

1. **圆角实现**：使用自定义 drawable 而不是 MaterialCardView，以实现只有顶部圆角的效果
2. **颜色层级**：底部卡片 (#0C1010) 比页面背景 (#040608) 稍亮，提供视觉层次
3. **按钮一致性**：使用 MaterialButton 并设置 8dp 圆角，与样式选择器页面保持一致
4. **文字对比度**：确保所有文字在深色背景上清晰可读

## 更新日期

2024-01-19
