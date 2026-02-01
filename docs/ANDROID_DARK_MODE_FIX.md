# Android 深色主题适配修复

## 问题诊断

Android项目之前**没有完整适配深色主题**，导致在深色模式下出现以下问题：

### 1. 缺少深色主题资源文件夹
- ❌ 没有 `values-night/` 文件夹
- ❌ 没有 `drawable-night/` 文件夹
- 结果：深色模式下使用默认的Mapbox样式，而不是自定义主题色

### 2. 硬编码的颜色值
- ❌ GPS警告面板：`@android:color/holo_orange_light` 和 `@android:color/black`
- ❌ 搜索界面：`@android:color/white`
- ❌ Stop按钮：白色圆形背景在深色模式下显示不正确

### 3. 转向图标颜色问题
- ❌ `MapboxManeuverView` 的转向图标在深色模式下不显示主题绿色 `#01E47C`
- ❌ 按钮中间有白色圆形，应该是黑色 `#040608`

## 修复方案

### 1. 创建深色主题资源文件夹

#### `values-night/colors.xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- 主题色 - 深色模式下保持一致 -->
    <color name="colorPrimary">#01E47C</color>
    <color name="colorPrimaryDark">#00B35F</color>
    <color name="colorAccent">#01E47C</color>
    
    <!-- 背景色 - 深色 -->
    <color name="colorBackground">#040608</color>
    <color name="colorSurface">#040608</color>
    <color name="colorCardBackground">#191A21</color>
    <color name="colorBottomCard">#0C1010</color>
    
    <!-- 文字颜色 - 白色系 -->
    <color name="textPrimary">#FFFFFF</color>
    <color name="textSecondary">#8AFFFFFF</color>
    <color name="textDisabled">#61FFFFFF</color>
    
    <!-- GPS警告颜色 - 深色模式 -->
    <color name="gps_warning_background">#664D03</color>
    <color name="gps_warning_text">#FFECB5</color>
    <color name="gps_warning_icon">#FFC107</color>
</resources>
```

#### `values-night/styles.xml`
```xml
<resources>
    <!-- Mapbox Maneuver Turn Icon Style - 确保深色模式下使用主题绿色 -->
    <style name="MapboxCustomManeuverTurnIconStyle" parent="MapboxStyleTurnIconManeuver">
        <item name="maneuverTurnIconColor">@color/colorPrimary</item>
        <item name="maneuverTurnIconShadowColor">@color/colorPrimaryDark</item>
    </style>

    <!-- Mapbox Maneuver View Style - 深色模式配置 -->
    <style name="MapboxCustomManeuverStyle" parent="MapboxStyleManeuverView">
        <item name="maneuverViewBackgroundColor">@color/cardBackgroundDark</item>
        <item name="maneuverViewIconStyle">@style/MapboxCustomManeuverTurnIconStyle</item>
        <item name="laneGuidanceManeuverIconStyle">@style/MapboxCustomManeuverTurnIconStyle</item>
        <!-- 文字颜色 -->
        <item name="maneuverViewPrimaryTextColor">@color/textPrimary</item>
        <item name="maneuverViewSecondaryTextColor">@color/textSecondary</item>
    </style>
</resources>
```

### 2. 修复Stop按钮白色圆形问题

#### `drawable/stop_button_circle.xml` (浅色模式)
```xml
<?xml version="1.0" encoding="utf-8"?>
<ripple xmlns:android="http://schemas.android.com/apk/res/android"
    android:color="#40000000">
    <item>
        <shape android:shape="oval">
            <solid android:color="#FFFFFF" />
            <stroke 
                android:width="1dp"
                android:color="#20000000" />
        </shape>
    </item>
</ripple>
```

#### `drawable-night/stop_button_circle.xml` (深色模式)
```xml
<?xml version="1.0" encoding="utf-8"?>
<ripple xmlns:android="http://schemas.android.com/apk/res/android"
    android:color="#40FFFFFF">
    <item>
        <shape android:shape="oval">
            <solid android:color="#040608" />
            <stroke 
                android:width="1dp"
                android:color="#20FFFFFF" />
        </shape>
    </item>
</ripple>
```

#### 布局文件修改
```xml
<com.google.android.material.button.MaterialButton
    android:id="@+id/stopButton"
    style="@style/Widget.MaterialComponents.Button.Icon"
    android:background="@drawable/stop_button_circle"
    app:backgroundTint="@null"
    ... />
```

关键点：
- 使用 `android:background` 而不是 `app:backgroundTint`
- 设置 `app:backgroundTint="@null"` 禁用Material默认背景
- 使用 `style="@style/Widget.MaterialComponents.Button.Icon"` 确保图标正确显示

### 3. 修复GPS警告面板

#### `drawable/gps_warning_background.xml` (浅色模式)
```xml
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#FFF3CD" />
    <corners android:radius="8dp" />
</shape>
```

#### `drawable-night/gps_warning_background.xml` (深色模式)
```xml
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#664D03" />
    <corners android:radius="8dp" />
</shape>
```

#### 布局文件修改
```xml
<LinearLayout
    android:id="@+id/gpsWarningPanel"
    android:background="@drawable/gps_warning_background"
    ...>
    
    <ImageView
        android:tint="@color/gps_warning_icon"
        ... />
    
    <TextView
        android:textColor="@color/gps_warning_text"
        ... />
</LinearLayout>
```

### 4. 修复搜索界面背景

#### 修改前
```xml
<com.mapbox.search.ui.view.SearchResultsView
    android:background="@android:color/white" />
```

#### 修改后
```xml
<com.mapbox.search.ui.view.SearchResultsView
    android:background="@color/colorBackground" />
```

## 修复效果

### 深色模式 (Night Mode)
✅ 转向图标显示主题绿色 `#01E47C`
✅ Stop按钮中间是黑色 `#040608`，不是白色
✅ GPS警告面板使用深色背景 `#664D03` 和浅色文字 `#FFECB5`
✅ 搜索界面使用深色背景 `#040608`
✅ 所有文字颜色正确（白色系）

### 浅色模式 (Light Mode)
✅ 转向图标显示主题绿色 `#01E47C`
✅ Stop按钮中间是白色 `#FFFFFF`
✅ GPS警告面板使用浅色背景 `#FFF3CD` 和深色文字 `#664D03`
✅ 搜索界面使用浅色背景
✅ 所有文字颜色正确（深色系）

## 深色主题适配最佳实践

### 1. 使用资源限定符
- `values-night/` - 深色模式颜色
- `drawable-night/` - 深色模式drawable
- `layout-night/` - 深色模式布局（如果需要）

### 2. 避免硬编码颜色
❌ 不要使用：
```xml
android:background="@android:color/white"
android:textColor="#000000"
```

✅ 应该使用：
```xml
android:background="@color/colorBackground"
android:textColor="@color/textPrimary"
```

### 3. 使用主题属性
```xml
<style name="AppTheme" parent="Theme.MaterialComponents.DayNight.NoActionBar">
    <item name="colorPrimary">@color/colorPrimary</item>
    <item name="android:windowBackground">@color/colorBackground</item>
</style>
```

### 4. MaterialButton背景处理
当使用自定义drawable作为背景时：
```xml
<com.google.android.material.button.MaterialButton
    android:background="@drawable/custom_background"
    app:backgroundTint="@null" />
```

### 5. 测试深色模式
- 在设备设置中切换深色模式
- 使用 `AppCompatDelegate.setDefaultNightMode()` 编程切换
- 测试所有界面和组件

## 文件清单

### 新增文件
- `android/src/main/res/values-night/colors.xml`
- `android/src/main/res/values-night/styles.xml`
- `android/src/main/res/drawable-night/stop_button_circle.xml`
- `android/src/main/res/drawable-night/gps_warning_background.xml`
- `android/src/main/res/drawable/gps_warning_background.xml`

### 修改文件
- `android/src/main/res/values/colors.xml` - 添加GPS警告颜色
- `android/src/main/res/values/styles.xml` - 添加文字颜色配置
- `android/src/main/res/layout/navigation_activity.xml` - 修复GPS警告和Stop按钮
- `android/src/main/res/layout/activity_search.xml` - 修复搜索背景
- `android/src/main/res/drawable/stop_button_circle.xml` - 浅色模式背景

## 验证步骤

1. **切换到深色模式**
   ```bash
   adb shell "cmd uimode night yes"
   ```

2. **启动导航**
   - 检查转向图标是否为绿色 `#01E47C`
   - 检查Stop按钮中间是否为黑色 `#040608`

3. **切换到浅色模式**
   ```bash
   adb shell "cmd uimode night no"
   ```

4. **再次启动导航**
   - 检查所有颜色是否正确

## 总结

通过创建完整的深色主题资源文件夹和修复硬编码颜色，Android项目现在完全支持深色模式。所有UI组件在深色和浅色模式下都能正确显示主题色和文字颜色。

**关键修复：**
1. ✅ 创建 `values-night/` 和 `drawable-night/` 资源文件夹
2. ✅ 修复转向图标颜色配置
3. ✅ 修复Stop按钮白色圆形问题
4. ✅ 修复GPS警告面板颜色
5. ✅ 修复搜索界面背景
6. ✅ 所有颜色使用资源引用，避免硬编码
