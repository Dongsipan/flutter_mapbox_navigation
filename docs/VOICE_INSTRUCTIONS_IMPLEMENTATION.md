# 语音指令播放功能实现说明

## 实现日期
2026-01-05

## 实现内容

### 1. 集成的组件
- **MapboxSpeechApi**: 用于生成语音播报内容
- **MapboxVoiceInstructionsPlayer**: 用于播放语音指令

### 2. 实现位置
文件: `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`

### 3. 主要功能

#### 3.1 初始化
在 `initializeVoiceInstructions()` 方法中:
- 创建 MapboxSpeechApi 实例,使用访问令牌和导航语言
- 创建 MapboxVoiceInstructionsPlayer 实例

#### 3.2 语音播放
在 `VoiceInstructionsObserverImpl` 内部类中:
- 接收来自 SDK 的语音指令
- 使用 SpeechApi 生成语音播报
- 使用 VoiceInstructionsPlayer 播放语音
- 处理错误情况,使用回退方案(文本转语音)

#### 3.3 配置支持
- 支持通过 `FlutterMapboxNavigationPlugin.voiceInstructionsEnabled` 启用/禁用语音
- 支持通过 `FlutterMapboxNavigationPlugin.navigationLanguage` 设置语音语言
- 支持通过 `FlutterMapboxNavigationPlugin.navigationVoiceUnits` 设置单位(公制/英制)

#### 3.4 生命周期管理
在 `onDestroy()` 方法中:
- 调用 `voiceInstructionsPlayer.shutdown()` 释放播放器资源
- 调用 `speechApi.cancel()` 取消待处理的语音请求

### 4. 错误处理
- 捕获语音生成和播放过程中的异常
- 当 SpeechApi 出错时,自动使用回退方案(TTS)
- 记录所有错误日志以便调试

### 5. 事件通信
- 语音指令仍然通过 `MapBoxEvents.SPEECH_ANNOUNCEMENT` 发送到 Flutter 层
- Flutter 层可以接收到语音文本内容

## 验证需求

根据 Requirements 6:

✅ 6.1 - WHEN navigation is active THEN the system SHALL play voice instructions at appropriate times
- 实现: 在 voiceInstructionObserver 中接收指令并播放

✅ 6.2 - WHEN voiceInstructionsEnabled is true THEN the system SHALL enable voice guidance
- 实现: 检查 FlutterMapboxNavigationPlugin.voiceInstructionsEnabled

✅ 6.3 - WHEN voiceInstructionsEnabled is false THEN the system SHALL mute voice guidance
- 实现: 当配置为 false 时不调用播放方法

✅ 6.4 - WHEN language is specified THEN the system SHALL use that language for voice instructions
- 实现: 使用 FlutterMapboxNavigationPlugin.navigationLanguage 初始化

✅ 6.5 - THE system SHALL support imperial and metric units for voice instructions
- 实现: 通过 applyLanguageAndVoiceUnitOptions 在路线请求时设置

✅ 6.6 - THE system SHALL use VoiceInstructionsObserver to receive voice instruction events
- 实现: 已注册 voiceInstructionObserver

## 测试建议

### 单元测试
1. 测试语音指令启用/禁用逻辑
2. 测试语音 API 错误处理
3. 测试资源清理

### 集成测试
1. 启动导航并验证语音播放
2. 测试不同语言的语音指令
3. 测试公制/英制单位切换
4. 测试禁用语音后不播放

### 手动测试
1. 启动模拟导航,听取语音指令
2. 切换语言设置,验证语音语言
3. 测试网络不佳时的回退方案

## 已知限制

1. 语音音量控制目前依赖系统音量设置
2. 没有实现自定义语音速率调整
3. 没有实现语音指令的暂停/恢复功能

## 后续改进建议

1. 添加音量控制 UI
2. 支持自定义语音速率
3. 添加语音指令历史记录
4. 支持多种 TTS 引擎选择

