# 设计文档 - Android导航返回键确认功能

## 概述

本设计文档描述了在Android NavigationActivity中实现返回键拦截和退出确认对话框的技术方案。该功能旨在防止用户通过实体返回键意外退出导航，确保正确触发取消事件并清理导航资源。

设计目标：
- 在导航进行中拦截返回键，显示确认对话框
- 确保用户确认后正确调用stopNavigation()方法
- 保证MapBoxEvent.navigation_cancelled事件正确触发
- 在非导航状态下允许直接返回
- 遵循Android 13+的返回手势规范
- 支持主题适配和国际化

## 架构

### 整体架构

```
NavigationActivity
    ├── OnBackPressedDispatcher (Android 13+)
    │   └── OnBackPressedCallback
    │       ├── 检查导航状态 (isNavigationInProgress)
    │       ├── 显示确认对话框 (AlertDialog)
    │       └── 处理用户选择
    │           ├── 确认 → stopNavigation()
    │           └── 取消 → 继续导航
    └── onBackPressed() (兼容旧版本)
        └── 相同逻辑
```

### 状态流转

```
用户按返回键
    ↓
检查 isNavigationInProgress
    ↓
├─ true (导航中)
│   ↓
│   显示确认对话框
│   ↓
│   ├─ 用户点击"确认"
│   │   ↓
│   │   调用 stopNavigation()
│   │   ↓
│   │   触发 MapBoxEvent.navigation_cancelled
│   │   ↓
│   │   清理资源
│   │   ↓
│   │   finish()
│   │
│   └─ 用户点击"取消"
│       ↓
│       关闭对话框
│       ↓
│       继续导航
│
└─ false (未导航)
    ↓
    直接 finish()
```

## 组件和接口

### 1. OnBackPressedCallback

使用Android Jetpack的OnBackPressedDispatcher API处理返回键事件。

#### 实现方式

```kotlin
class NavigationActivity : AppCompatActivity() {
    
    private lateinit var backPressedCallback: OnBackPressedCallback
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 初始化返回键回调
        setupBackPressedHandler()
    }
    
    private fun setupBackPressedHandler() {
        backPressedCallback = object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                handleBackPress()
            }
        }
        
        // 注册回调到OnBackPressedDispatcher
        onBackPressedDispatcher.addCallback(this, backPressedCallback)
    }
    
    private fun handleBackPress() {
        if (isNavigationInProgress) {
            showExitConfirmationDialog()
        } else {
            finish()
        }
    }
}
```

### 2. 确认对话框

使用Material Design的AlertDialog显示退出确认。

#### 对话框规格

```kotlin
private fun showExitConfirmationDialog() {
    AlertDialog.Builder(this, R.style.AlertDialogTheme)
        .setTitle(R.string.exit_navigation_title)
        .setMessage(R.string.exit_navigation_message)
        .setPositiveButton(R.string.exit_navigation_confirm) { dialog, _ ->
            dialog.dismiss()
            stopNavigation()
        }
        .setNegativeButton(R.string.exit_navigation_cancel) { dialog, _ ->
            dialog.dismiss()
        }
        .setCancelable(true)
        .show()
}
```

#### 对话框样式

支持日间/夜间主题自动切换：

```xml
<!-- res/values/styles.xml -->
<style name="AlertDialogTheme" parent="Theme.MaterialComponents.Light.Dialog.Alert">
    <item name="colorPrimary">@color/mapboxBlue</item>
    <item name="android:textColorPrimary">@color/primaryTextColor</item>
    <item name="android:background">@color/dialogBackground</item>
</style>

<!-- res/values-night/styles.xml -->
<style name="AlertDialogTheme" parent="Theme.MaterialComponents.Dialog.Alert">
    <item name="colorPrimary">@color/mapboxBlue</item>
    <item name="android:textColorPrimary">@color/primaryTextColorNight</item>
    <item name="android:background">@color/dialogBackgroundNight</item>
</style>
```

### 3. 导航状态管理

利用现有的`isNavigationInProgress`标志位判断导航状态。

#### 状态定义

```kotlin
// 现有代码中已定义
private var isNavigationInProgress = false
```

#### 状态更新时机

- 开始导航时设置为`true`（在`startNavigation()`中）
- 停止导航时设置为`false`（在`stopNavigation()`中）
- 到达目的地时设置为`false`（在`arrivalObserver`中）

### 4. 兼容性处理

为Android 13以下版本提供兼容支持。

#### 重写onBackPressed()

```kotlin
@Deprecated("Deprecated in Java")
override fun onBackPressed() {
    // 对于Android 13以下版本，手动调用handleBackPress
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
        handleBackPress()
    } else {
        super.onBackPressed()
    }
}
```

## 数据模型

### DialogState

```kotlin
sealed class DialogState {
    object Hidden : DialogState()
    object Showing : DialogState()
}
```

### BackPressAction

```kotlin
sealed class BackPressAction {
    object DirectExit : BackPressAction()
    object ShowConfirmation : BackPressAction()
}
```

## 正确性属性

*属性是一个特征或行为，应该在系统的所有有效执行中保持为真——本质上是关于系统应该做什么的形式化陈述。*

### 属性 1: 导航中拦截返回键

*对于任何*导航进行中的状态（isNavigationInProgress == true），当用户按下返回键时，系统应该拦截该事件并显示确认对话框，而不是直接退出Activity

**验证: 需求 FR-1.3, 3.1**

### 属性 2: 对话框包含必需元素

*对于任何*显示的确认对话框，对话框应该包含标题、消息文本、确认按钮和取消按钮这四个元素

**验证: 需求 FR-2.2, FR-2.3, FR-2.4**

### 属性 3: 取消按钮继续导航

*对于任何*显示的确认对话框，当用户点击取消按钮时，对话框应该关闭，并且导航状态保持不变（isNavigationInProgress仍为true）

**验证: 需求 3.1, 7.1**

### 属性 4: 确认按钮调用stopNavigation

*对于任何*显示的确认对话框，当用户点击确认按钮时，系统应该调用stopNavigation()方法

**验证: 需求 FR-3.1, 3.2, 7.1**

### 属性 5: stopNavigation触发取消事件

*对于任何*通过确认对话框触发的stopNavigation()调用，系统应该发送MapBoxEvent.navigation_cancelled事件到Flutter层

**验证: 需求 FR-3.2, 3.2, 7.1**

### 属性 6: 未导航时直接退出

*对于任何*未开始导航的状态（isNavigationInProgress == false），当用户按下返回键时，系统应该直接调用finish()退出Activity，不显示确认对话框

**验证: 需求 FR-4.1, FR-4.2, FR-4.3, 3.3, 7.1**

### 属性 7: 对话框支持主题切换

*对于任何*显示的确认对话框，对话框的样式应该根据当前系统主题（日间/夜间）自动调整颜色和背景

**验证: 需求 FR-2.5, NFR-3.3, 7.2**

### 属性 8: 对话框文本国际化

*对于任何*显示的确认对话框，对话框中的所有文本（标题、消息、按钮）应该从字符串资源文件中读取，支持多语言

**验证: 需求 FR-2.6, 7.2**

### 属性 9: 对话框响应时间

*对于任何*返回键按下事件，从按下到对话框显示的时间应该小于200毫秒

**验证: 需求 NFR-1.1**

### 属性 10: 退出处理时间

*对于任何*确认退出操作，从点击确认按钮到Activity关闭的时间应该小于500毫秒

**验证: 需求 NFR-1.2**

### 属性 11: Android 13+兼容性

*对于任何*运行在Android 13及以上版本的设备，系统应该使用OnBackPressedCallback处理返回键事件

**验证: 需求 NFR-2.2**

### 属性 12: 旧版本兼容性

*对于任何*运行在Android 13以下版本的设备，系统应该通过重写onBackPressed()方法处理返回键事件

**验证: 需求 NFR-2.1**

### 属性 13: 对话框防重复显示

*对于任何*已经显示的确认对话框，在对话框关闭前，连续按下返回键不应该创建新的对话框实例

**验证: 需求 8.3**

### 属性 14: 资源正确清理

*对于任何*通过确认对话框退出的导航，系统应该正确清理所有导航资源（历史记录、语音播报、路线等）

**验证: 需求 FR-3.3, 3.2**

## 错误处理

### 错误类型和处理策略

#### 1. 对话框创建失败
- **场景**: Activity已销毁或Context无效
- **处理**: 捕获异常，记录日志，直接调用finish()
- **恢复**: 不影响应用稳定性

```kotlin
private fun showExitConfirmationDialog() {
    try {
        if (isFinishing || isDestroyed) {
            Log.w(TAG, "Activity is finishing or destroyed, cannot show dialog")
            return
        }
        
        AlertDialog.Builder(this, R.style.AlertDialogTheme)
            // ... 对话框配置
            .show()
    } catch (e: Exception) {
        Log.e(TAG, "Failed to show exit confirmation dialog", e)
        finish()
    }
}
```

#### 2. stopNavigation调用失败
- **场景**: MapboxNavigation实例为null或已释放
- **处理**: 记录错误日志，发送取消事件，强制finish()
- **恢复**: 确保Activity正常关闭

```kotlin
private fun stopNavigation() {
    try {
        val mapboxNavigation = MapboxNavigationApp.current()
        if (mapboxNavigation == null) {
            Log.w(TAG, "MapboxNavigation is null when stopping navigation")
            sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
            finish()
            return
        }
        
        // 正常停止流程
        // ...
    } catch (e: Exception) {
        Log.e(TAG, "Error stopping navigation", e)
        sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        finish()
    }
}
```

#### 3. 对话框显示时Activity生命周期变化
- **场景**: 对话框显示时屏幕旋转或应用进入后台
- **处理**: 使用DialogFragment替代AlertDialog（可选优化）
- **恢复**: 对话框自动重建或关闭

#### 4. 快速连续按返回键
- **场景**: 用户快速多次按下返回键
- **处理**: 使用标志位防止重复显示对话框
- **恢复**: 只显示一个对话框实例

```kotlin
private var isExitDialogShowing = false

private fun showExitConfirmationDialog() {
    if (isExitDialogShowing) {
        Log.d(TAG, "Exit dialog is already showing")
        return
    }
    
    isExitDialogShowing = true
    
    AlertDialog.Builder(this, R.style.AlertDialogTheme)
        // ... 对话框配置
        .setOnDismissListener {
            isExitDialogShowing = false
        }
        .show()
}
```

### 错误日志

所有错误都应该记录到Android日志系统：
```kotlin
Log.e("NavigationActivity", "Error message", exception)
```

## 测试策略

### 单元测试

使用JUnit和Mockito进行单元测试：

1. **返回键处理逻辑测试**
   - 测试isNavigationInProgress为true时的行为
   - 测试isNavigationInProgress为false时的行为
   - 测试对话框显示逻辑

2. **状态管理测试**
   - 测试isExitDialogShowing标志位
   - 测试导航状态变化

### 属性测试

使用Kotest Property Testing进行属性测试：

1. **属性 1-14的实现**
   - 每个属性至少运行100次迭代
   - 使用随机生成的导航状态
   - 标记格式: `// Feature: android-back-button-confirmation, Property X: [属性描述]`

### UI测试

使用Espresso进行UI测试：

1. **对话框显示测试**
   - 验证对话框在导航中按返回键时显示
   - 验证对话框包含所有必需元素
   - 验证对话框主题正确

2. **交互测试**
   - 测试点击取消按钮的行为
   - 测试点击确认按钮的行为
   - 测试对话框外部点击的行为

3. **生命周期测试**
   - 测试屏幕旋转时对话框状态
   - 测试应用进入后台时对话框状态

### 集成测试

1. **端到端流程测试**
   - 启动导航 → 按返回键 → 显示对话框 → 点击取消 → 导航继续
   - 启动导航 → 按返回键 → 显示对话框 → 点击确认 → 导航停止
   - 未开始导航 → 按返回键 → 直接退出

2. **事件触发测试**
   - 验证MapBoxEvent.navigation_cancelled事件正确发送到Flutter层
   - 验证事件时序正确

## 实现细节

### 依赖配置

无需添加新的依赖，使用现有的AndroidX库：

```gradle
dependencies {
    // 已有依赖
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.9.0'
}
```

### 字符串资源

在`res/values/strings.xml`中添加：

```xml
<resources>
    <!-- 退出导航确认对话框 -->
    <string name="exit_navigation_title">退出导航？</string>
    <string name="exit_navigation_message">导航将被取消，确定要退出吗？</string>
    <string name="exit_navigation_confirm">退出</string>
    <string name="exit_navigation_cancel">取消</string>
</resources>
```

在`res/values-en/strings.xml`中添加英文版本：

```xml
<resources>
    <!-- Exit navigation confirmation dialog -->
    <string name="exit_navigation_title">Exit Navigation?</string>
    <string name="exit_navigation_message">Navigation will be cancelled. Are you sure you want to exit?</string>
    <string name="exit_navigation_confirm">Exit</string>
    <string name="exit_navigation_cancel">Cancel</string>
</resources>
```

### 样式资源

在`res/values/styles.xml`中添加：

```xml
<style name="AlertDialogTheme" parent="Theme.MaterialComponents.Light.Dialog.Alert">
    <item name="colorPrimary">@color/mapboxBlue</item>
    <item name="colorAccent">@color/mapboxBlue</item>
    <item name="android:textColorPrimary">@color/primaryTextColor</item>
    <item name="android:background">@color/dialogBackground</item>
    <item name="buttonBarPositiveButtonStyle">@style/PositiveButtonStyle</item>
    <item name="buttonBarNegativeButtonStyle">@style/NegativeButtonStyle</item>
</style>

<style name="PositiveButtonStyle" parent="Widget.MaterialComponents.Button.TextButton.Dialog">
    <item name="android:textColor">@color/mapboxBlue</item>
</style>

<style name="NegativeButtonStyle" parent="Widget.MaterialComponents.Button.TextButton.Dialog">
    <item name="android:textColor">@color/secondaryTextColor</item>
</style>
```

在`res/values-night/styles.xml`中添加夜间主题：

```xml
<style name="AlertDialogTheme" parent="Theme.MaterialComponents.Dialog.Alert">
    <item name="colorPrimary">@color/mapboxBlue</item>
    <item name="colorAccent">@color/mapboxBlue</item>
    <item name="android:textColorPrimary">@color/primaryTextColorNight</item>
    <item name="android:background">@color/dialogBackgroundNight</item>
    <item name="buttonBarPositiveButtonStyle">@style/PositiveButtonStyle</item>
    <item name="buttonBarNegativeButtonStyle">@style/NegativeButtonStyleNight</item>
</style>

<style name="NegativeButtonStyleNight" parent="Widget.MaterialComponents.Button.TextButton.Dialog">
    <item name="android:textColor">@color/secondaryTextColorNight</item>
</style>
```

### 颜色资源

在`res/values/colors.xml`中添加（如果不存在）：

```xml
<resources>
    <color name="dialogBackground">#FFFFFF</color>
    <color name="primaryTextColor">#000000</color>
    <color name="secondaryTextColor">#757575</color>
</resources>
```

在`res/values-night/colors.xml`中添加：

```xml
<resources>
    <color name="dialogBackgroundNight">#1E1E1E</color>
    <color name="primaryTextColorNight">#FFFFFF</color>
    <color name="secondaryTextColorNight">#B0B0B0</color>
</resources>
```

### 完整实现代码

在`NavigationActivity.kt`中添加以下代码：

```kotlin
class NavigationActivity : AppCompatActivity() {
    
    // 添加成员变量
    private lateinit var backPressedCallback: OnBackPressedCallback
    private var isExitDialogShowing = false
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // ... 现有初始化代码
        
        // 设置返回键处理
        setupBackPressedHandler()
    }
    
    /**
     * 设置返回键处理器
     * 使用OnBackPressedDispatcher API（Android 13+推荐）
     */
    private fun setupBackPressedHandler() {
        backPressedCallback = object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                handleBackPress()
            }
        }
        
        onBackPressedDispatcher.addCallback(this, backPressedCallback)
        
        Log.d(TAG, "Back pressed handler initialized")
    }
    
    /**
     * 处理返回键按下事件
     * 根据导航状态决定是否显示确认对话框
     */
    private fun handleBackPress() {
        Log.d(TAG, "Back pressed, isNavigationInProgress=$isNavigationInProgress")
        
        if (isNavigationInProgress) {
            // 导航进行中，显示确认对话框
            showExitConfirmationDialog()
        } else {
            // 未开始导航或已结束，直接退出
            Log.d(TAG, "Navigation not in progress, finishing activity")
            finish()
        }
    }
    
    /**
     * 显示退出确认对话框
     * 防止重复显示，支持主题切换
     */
    private fun showExitConfirmationDialog() {
        // 防止重复显示
        if (isExitDialogShowing) {
            Log.d(TAG, "Exit dialog is already showing, ignoring")
            return
        }
        
        // 检查Activity状态
        if (isFinishing || isDestroyed) {
            Log.w(TAG, "Activity is finishing or destroyed, cannot show dialog")
            return
        }
        
        try {
            isExitDialogShowing = true
            
            AlertDialog.Builder(this, R.style.AlertDialogTheme)
                .setTitle(R.string.exit_navigation_title)
                .setMessage(R.string.exit_navigation_message)
                .setPositiveButton(R.string.exit_navigation_confirm) { dialog, _ ->
                    Log.d(TAG, "User confirmed exit navigation")
                    dialog.dismiss()
                    stopNavigation()
                }
                .setNegativeButton(R.string.exit_navigation_cancel) { dialog, _ ->
                    Log.d(TAG, "User cancelled exit navigation")
                    dialog.dismiss()
                }
                .setCancelable(true)
                .setOnDismissListener {
                    isExitDialogShowing = false
                    Log.d(TAG, "Exit dialog dismissed")
                }
                .show()
            
            Log.d(TAG, "Exit confirmation dialog shown")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show exit confirmation dialog", e)
            isExitDialogShowing = false
            finish()
        }
    }
    
    /**
     * 兼容Android 13以下版本
     * 重写onBackPressed方法
     */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            Log.d(TAG, "Using legacy onBackPressed for Android < 13")
            handleBackPress()
        } else {
            super.onBackPressed()
        }
    }
    
    // ... 现有的stopNavigation()方法保持不变
}
```

## 性能考虑

### 对话框创建优化

- 使用AlertDialog.Builder避免重复创建
- 对话框样式预加载
- 避免在对话框中执行耗时操作

### 内存管理

- 对话框及时dismiss释放资源
- 使用弱引用避免内存泄漏
- Activity销毁时清理回调

```kotlin
override fun onDestroy() {
    super.onDestroy()
    
    // 移除返回键回调
    backPressedCallback.remove()
    
    Log.d(TAG, "Back pressed callback removed")
}
```

### 响应时间优化

- 对话框使用轻量级布局
- 避免复杂的主题计算
- 预加载字符串资源

## 安全考虑

### 状态一致性

- 确保isNavigationInProgress状态准确
- 防止状态竞争条件
- 使用同步机制保护关键状态

### 资源清理

- 确保stopNavigation()正确执行
- 防止资源泄漏
- 处理异常情况

## 可访问性

- 对话框支持TalkBack屏幕阅读器
- 按钮文本清晰易懂
- 支持键盘导航
- 确保足够的触摸目标大小

## 设计决策

### 决策 1: 使用OnBackPressedDispatcher而非onBackPressed

**理由**:
- OnBackPressedDispatcher是Android官方推荐的新API
- 更好地支持Android 13+的预测性返回手势
- 提供更灵活的回调管理机制
- 向后兼容，同时保留onBackPressed()作为fallback

**权衡**:
- 需要维护两套代码（新旧API）
- 增加少量代码复杂度
- 但获得更好的用户体验和未来兼容性

### 决策 2: 使用AlertDialog而非自定义Dialog

**理由**:
- AlertDialog是Android标准组件，用户熟悉
- 自动支持主题切换
- 代码简洁，易于维护
- 符合Material Design规范

**权衡**:
- 自定义程度有限
- 但满足当前需求，且实现成本低

### 决策 3: 不修改stopNavigation()方法

**理由**:
- stopNavigation()已经正确实现了所有清理逻辑
- 避免引入新的bug
- 保持代码稳定性
- 符合单一职责原则

**权衡**:
- 无明显权衡，这是最佳实践

### 决策 4: 使用标志位防止重复显示对话框

**理由**:
- 简单有效的解决方案
- 避免用户快速按键导致的问题
- 性能开销极小

**权衡**:
- 需要正确管理标志位生命周期
- 但实现简单，风险可控

### 决策 5: 支持国际化

**理由**:
- 项目已有中英文支持
- 提升用户体验
- 符合国际化最佳实践

**权衡**:
- 需要维护多语言资源文件
- 但工作量小，价值高

## 未来扩展

### 可选功能

1. **记住用户选择**
   - 添加"不再提示"选项
   - 使用SharedPreferences保存用户偏好

2. **自定义对话框样式**
   - 支持插件配置对话框样式
   - 允许自定义按钮文本

3. **DialogFragment实现**
   - 使用DialogFragment替代AlertDialog
   - 更好地处理生命周期变化

4. **动画效果**
   - 添加对话框进入/退出动画
   - 提升视觉体验

### 维护建议

1. 定期测试不同Android版本的兼容性
2. 关注Android新版本的返回手势变化
3. 收集用户反馈，优化对话框文案
4. 监控崩溃日志，及时修复问题
