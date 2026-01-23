# Android 导航返回键确认功能 - 实现任务

## 1. 添加字符串资源 (String Resources)

### 1.1 添加中文字符串资源
**需求**: FR-2.2, FR-2.3, FR-2.4, FR-2.6
**描述**: 在 `android/src/main/res/values/strings.xml` 中添加退出导航确认对话框的字符串资源
**详情**:
- 添加对话框标题: `exit_navigation_title`
- 添加对话框消息: `exit_navigation_message`
- 添加确认按钮文本: `exit_navigation_confirm`
- 添加取消按钮文本: `exit_navigation_cancel`

### 1.2 添加英文字符串资源
**需求**: FR-2.6, NFR-3.1
**描述**: 创建 `android/src/main/res/values-en/strings.xml` 文件并添加英文版本的字符串资源
**详情**:
- 创建 values-en 目录（如果不存在）
- 添加英文版本的对话框字符串
- 确保与中文版本的 key 保持一致

## 2. 添加对话框样式资源 (Dialog Theme)

### 2.1 添加对话框主题样式
**需求**: FR-2.5, NFR-3.3
**描述**: 在 `android/src/main/res/values/styles.xml` 中添加 AlertDialog 主题样式
**详情**:
- 创建 `AlertDialogTheme` 样式，继承自 Material Components
- 配置主题色、文字颜色、背景色
- 配置按钮样式（PositiveButtonStyle, NegativeButtonStyle）
- 使用现有的颜色资源（colorPrimary, textPrimary, colorSurface 等）

### 2.2 添加夜间主题样式（可选）
**需求**: FR-2.5, NFR-3.3
**描述**: 如果需要显式的夜间主题，创建 `android/src/main/res/values-night/styles.xml` 并添加夜间版本的对话框样式
**详情**:
- 由于项目已使用 DayNight 主题，此步骤可能不需要
- 如果需要，配置夜间模式下的对话框颜色

## 3. 实现返回键处理逻辑 (Back Press Handling)

### 3.1 添加成员变量
**需求**: FR-1.1, FR-1.2
**描述**: 在 `NavigationActivity.kt` 中添加必要的成员变量
**详情**:
- 添加 `backPressedCallback: OnBackPressedCallback` 变量
- 添加 `isExitDialogShowing: Boolean` 标志位（防止重复显示）

### 3.2 实现 setupBackPressedHandler 方法
**需求**: FR-1.1, FR-1.2, NFR-2.2
**描述**: 创建 `setupBackPressedHandler()` 方法，初始化 OnBackPressedCallback
**详情**:
- 创建 OnBackPressedCallback 实例
- 在回调中调用 `handleBackPress()` 方法
- 使用 `onBackPressedDispatcher.addCallback()` 注册回调
- 在 `onCreate()` 方法中调用此方法

### 3.3 实现 handleBackPress 方法
**需求**: FR-1.3, FR-4.1, FR-4.2, FR-4.3
**描述**: 创建 `handleBackPress()` 方法，根据导航状态决定是否显示确认对话框
**详情**:
- 检查 `isNavigationInProgress` 状态
- 如果为 true，调用 `showExitConfirmationDialog()`
- 如果为 false，直接调用 `finish()`
- 添加日志记录

### 3.4 实现 showExitConfirmationDialog 方法
**需求**: FR-2.1, FR-2.2, FR-2.3, FR-2.4, FR-2.5, NFR-1.1
**描述**: 创建 `showExitConfirmationDialog()` 方法，显示退出确认对话框
**详情**:
- 检查 `isExitDialogShowing` 标志位，防止重复显示
- 检查 Activity 状态（isFinishing, isDestroyed）
- 使用 AlertDialog.Builder 创建对话框
- 设置标题、消息、按钮（使用字符串资源）
- 应用 AlertDialogTheme 样式
- 确认按钮点击时调用 `stopNavigation()`
- 取消按钮点击时关闭对话框
- 设置 onDismissListener 重置 `isExitDialogShowing` 标志
- 添加 try-catch 错误处理

### 3.5 重写 onBackPressed 方法（兼容性）
**需求**: NFR-2.1
**描述**: 重写 `onBackPressed()` 方法以支持 Android 13 以下版本
**详情**:
- 添加 @Deprecated 注解
- 检查 Android 版本（Build.VERSION.SDK_INT < TIRAMISU）
- 对于旧版本，调用 `handleBackPress()`
- 对于新版本，调用 `super.onBackPressed()`

### 3.6 清理资源
**需求**: NFR-4.2
**描述**: 在 `onDestroy()` 方法中清理 OnBackPressedCallback
**详情**:
- 调用 `backPressedCallback.remove()` 移除回调
- 添加日志记录

## 4. 验证和测试 (Verification)

### 4.1 验证 stopNavigation 方法
**需求**: FR-3.1, FR-3.2, FR-3.3
**描述**: 确认现有的 `stopNavigation()` 方法正确实现了所有必要的清理逻辑
**详情**:
- 检查是否停止历史记录
- 检查是否停止 trip session
- 检查是否清理路线
- 检查是否发送 NAVIGATION_CANCELLED 事件
- 检查是否调用 finish()
- 无需修改，仅验证

### 4.2 手动测试基本场景
**需求**: 7.1, 8.1
**描述**: 执行手动测试验证基本功能
**详情**:
- 测试导航中按返回键显示对话框
- 测试点击取消按钮继续导航
- 测试点击确认按钮退出导航
- 测试未开始导航时按返回键直接退出
- 测试对话框主题在日间/夜间模式下的显示

### 4.3 测试边界场景
**需求**: 8.2, 8.3
**描述**: 测试边界和异常场景
**详情**:
- 测试快速连续按返回键（验证防重复显示）
- 测试对话框显示时旋转屏幕
- 测试对话框显示时应用进入后台

## 5. 文档和日志 (Documentation)

### 5.1 添加代码注释
**需求**: NFR-4.3
**描述**: 为新增的方法和逻辑添加清晰的代码注释
**详情**:
- 为每个新方法添加 KDoc 注释
- 说明方法的目的、参数、返回值
- 添加关键逻辑的行内注释

### 5.2 验证日志记录
**需求**: NFR-4.2
**描述**: 确保所有关键操作都有适当的日志记录
**详情**:
- 返回键按下事件
- 对话框显示/关闭
- 用户选择（确认/取消）
- 错误情况

## 任务依赖关系

```
1.1, 1.2 (字符串资源) → 3.4 (显示对话框)
2.1, 2.2 (样式资源) → 3.4 (显示对话框)
3.1 (成员变量) → 3.2, 3.3, 3.4 (实现方法)
3.2 (初始化) → 3.3, 3.4 (处理逻辑)
3.3 (处理逻辑) → 3.4 (显示对话框)
3.1-3.6 (实现) → 4.1-4.3 (测试)
4.1-4.3 (测试) → 5.1-5.2 (文档)
```

## 实现优先级

**P0 - 必须实现**:
- 1.1, 1.2: 字符串资源
- 2.1: 对话框样式
- 3.1-3.5: 返回键处理逻辑
- 4.1: 验证 stopNavigation

**P1 - 应该实现**:
- 3.6: 资源清理
- 4.2: 基本场景测试
- 5.1, 5.2: 文档和日志

**P2 - 可以实现**:
- 2.2: 夜间主题样式（如果需要）
- 4.3: 边界场景测试

## 预期结果

完成所有任务后，应该实现以下功能：
1. ✅ 导航进行中按返回键显示确认对话框
2. ✅ 对话框包含清晰的标题、消息和按钮
3. ✅ 点击取消按钮关闭对话框，继续导航
4. ✅ 点击确认按钮调用 stopNavigation()，退出导航
5. ✅ 未开始导航时按返回键直接退出
6. ✅ 对话框支持中英文国际化
7. ✅ 对话框支持日间/夜间主题自动切换
8. ✅ 兼容 Android 5.0+ 所有版本
9. ✅ 防止快速连续按键导致的重复对话框
10. ✅ 正确触发 MapBoxEvent.navigation_cancelled 事件
