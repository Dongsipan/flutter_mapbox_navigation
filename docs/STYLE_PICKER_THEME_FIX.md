# 样式选择器主题修复

## 问题描述
样式选择器页面的颜色配置不符合深色主题要求：
- 页面背景色为浅灰色 (#F5F5F5)
- 卡片背景色为浅蓝色和白色
- 下拉框文字颜色为深色，在深色背景上不可见

## 修复内容

### 1. 颜色资源更新 (colors.xml)

添加了卡片背景色：
```xml
<!-- 卡片背景色 - 稍亮的深色 -->
<color name="colorCardBackground">#191A21</color>
```

### 2. 布局文件更新 (activity_style_picker.xml)

#### 主要改动：

**页面背景**
```xml
<!-- 修改前 -->
android:background="#F5F5F5"

<!-- 修改后 -->
android:background="@color/colorBackground"  <!-- #040608 -->
```

**说明卡片**
```xml
<!-- 修改前 -->
app:cardBackgroundColor="#E3F2FD"
android:textColor="#0D47A1"
android:textColor="#1565C0"
android:tint="#1976D2"

<!-- 修改后 -->
app:cardBackgroundColor="@color/colorCardBackground"  <!-- #191A21 -->
android:textColor="@color/textPrimary"  <!-- 白色 -->
android:textColor="@color/textSecondary"  <!-- 半透明白色 -->
android:tint="@color/colorPrimary"  <!-- #01E47C -->
```

**所有卡片背景**
```xml
<!-- 修改前 -->
app:cardCornerRadius="12dp"
app:cardElevation="2dp"
<!-- 没有明确设置背景色，使用默认白色 -->

<!-- 修改后 -->
app:cardBackgroundColor="@color/colorCardBackground"  <!-- #191A21 -->
app:cardCornerRadius="12dp"
app:cardElevation="2dp"
```

**文字颜色**
```xml
<!-- 修改前 -->
android:textColor="#666666"
android:textColor="#999999"
android:textColor="#212121"
android:textColor="#757575"

<!-- 修改后 -->
android:textColor="@color/textPrimary"  <!-- 主文字：白色 -->
android:textColor="@color/textSecondary"  <!-- 次要文字：半透明白色 -->
```

**底部按钮栏**
```xml
<!-- 修改前 -->
android:background="@android:color/white"

<!-- 修改后 -->
app:cardBackgroundColor="@color/colorBackground"
android:background="@color/colorBackground"
android:textColor="@color/textSecondary"  <!-- 取消按钮 -->
app:backgroundTint="@color/colorPrimary"  <!-- 应用按钮 -->
```

### 3. Kotlin 代码更新 (StylePickerActivity.kt)

#### 自定义 Spinner 样式

创建了两个自定义布局文件来设置 Spinner 的文字颜色：

**spinner_item_white.xml** - Spinner 选中项样式
```xml
<TextView
    android:textColor="@color/textPrimary"
    android:padding="16dp" />
```

**spinner_dropdown_item_white.xml** - Spinner 下拉列表项样式
```xml
<TextView
    android:textColor="@color/textPrimary"
    android:background="@color/colorCardBackground"
    android:padding="16dp" />
```

#### 代码修改

```kotlin
// 修改前
val styleAdapter = ArrayAdapter.createFromResource(
    this,
    R.array.map_styles,
    android.R.layout.simple_spinner_item
)
styleAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)

// 修改后
val styleAdapter = ArrayAdapter.createFromResource(
    this,
    R.array.map_styles,
    R.layout.spinner_item_white
)
styleAdapter.setDropDownViewResource(R.layout.spinner_dropdown_item_white)

// 在 onItemSelected 中设置文字颜色
override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
    (view as? TextView)?.setTextColor(resources.getColor(R.color.textPrimary, null))
    selectedStyle = getStyleValue(position)
    updateLightPresetVisibility()
}
```

### 4. iOS 主题颜色更新 (ThemeColors.swift)

统一卡片背景色：
```swift
// 修改前
static let appCardBackground = UIColor(hex: "#1A1C1E")

// 修改后
static let appCardBackground = UIColor(hex: "#191A21")
```

## 最终效果

### 颜色配置

| 元素 | 颜色 | 说明 |
|------|------|------|
| 页面背景 | `#040608` | 深色背景 |
| 卡片背景 | `#191A21` | 稍亮的深色 |
| 主文字 | `#FFFFFF` | 白色 |
| 次要文字 | `#FFFFFF` (54% 透明度) | 半透明白色 |
| 图标 | `#01E47C` | 绿色主题色 |
| 应用按钮 | `#01E47C` | 绿色主题色 |
| 取消按钮边框 | `#FFFFFF` (54% 透明度) | 半透明白色 |

### 视觉检查清单

- [x] 页面背景为深色 (#040608)
- [x] 所有卡片背景为 #191A21
- [x] 所有文字为白色或半透明白色
- [x] 图标为绿色主题色
- [x] Spinner 选中项文字为白色
- [x] Spinner 下拉列表背景为卡片色
- [x] Spinner 下拉列表文字为白色
- [x] 应用按钮为绿色背景
- [x] 取消按钮为透明背景带边框

## 相关文件

### 新建文件
- `android/src/main/res/layout/spinner_item_white.xml`
- `android/src/main/res/layout/spinner_dropdown_item_white.xml`

### 修改文件
- `android/src/main/res/values/colors.xml`
- `android/src/main/res/layout/activity_style_picker.xml`
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/StylePickerActivity.kt`
- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/ThemeColors.swift`

## 测试建议

1. 打开样式选择器页面
2. 检查页面背景是否为深色
3. 检查所有卡片背景是否为 #191A21
4. 检查所有文字是否清晰可读
5. 点击 Spinner，检查下拉列表的背景和文字颜色
6. 检查按钮的颜色和文字

## 注意事项

1. **Spinner 文字颜色**：需要同时在布局文件和代码中设置
2. **下拉列表背景**：使用卡片背景色而不是页面背景色，以提供更好的对比度
3. **Material 组件**：使用 Material 组件的属性（如 `app:backgroundTint`）而不是 `android:background`
4. **颜色一致性**：确保 Android 和 iOS 使用相同的卡片背景色

## 更新日期

2024-01-19
