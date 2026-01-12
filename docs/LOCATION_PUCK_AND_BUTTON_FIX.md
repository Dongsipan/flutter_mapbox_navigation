# 位置 Puck 和按钮修复

## 问题描述

1. **用户位置 puck 不显示** - 导航中没有展示用户位置的 puck
2. **语音按钮图标不显示** - SoundButton 的图标没有展示
3. **按钮点击无响应** - 点击按钮没有响应

## 修复内容

### 1. 添加 NavigationLocationProvider (官方示例模式)

根据官方示例，需要使用 `NavigationLocationProvider` 来提供位置更新给 Maps SDK，以便更新地图上的用户位置指示器。

```kotlin
// 添加导入
import com.mapbox.maps.plugin.LocationPuck2D
import com.mapbox.maps.ImageHolder
import com.mapbox.navigation.ui.maps.location.NavigationLocationProvider
import com.mapbox.navigation.voice.model.SpeechVolume

// 添加变量
private val navigationLocationProvider = NavigationLocationProvider()
```

### 2. 初始化 Location Puck (在 initializeNavigation 中)

官方示例在 `initNavigation()` 中初始化 location puck：

```kotlin
private fun initializeNavigation() {
    // ... 其他初始化代码 ...
    
    // Initialize location puck (官方示例模式)
    binding.mapView.location.apply {
        setLocationProvider(navigationLocationProvider)
        this.locationPuck = LocationPuck2D(
            bearingImage = ImageHolder.from(
                com.mapbox.navigation.ui.maps.R.drawable.mapbox_navigation_puck_icon
            )
        )
        puckBearingEnabled = true
        enabled = true
    }
}
```

### 3. 更新 locationObserver 使用 navigationLocationProvider.changePosition()

```kotlin
private val locationObserver = object : LocationObserver {
    var firstLocationUpdateReceived = false
    
    override fun onNewLocationMatcherResult(locationMatcherResult: LocationMatcherResult) {
        val enhancedLocation = locationMatcherResult.enhancedLocation
        
        // 更新位置 puck 的位置 (官方示例模式)
        navigationLocationProvider.changePosition(
            location = enhancedLocation,
            keyPoints = locationMatcherResult.keyPoints,
        )
        
        // ... 其他代码 ...
    }
}
```

### 4. 添加 SoundButton 点击事件和静音状态

```kotlin
// 添加静音状态变量
private var isVoiceInstructionsMuted = false
    set(value) {
        field = value
        if (value) {
            binding.soundButton?.muteAndExtend(1500L)
            voiceInstructionsPlayer.volume(SpeechVolume(0f))
        } else {
            binding.soundButton?.unmuteAndExtend(1500L)
            voiceInstructionsPlayer.volume(SpeechVolume(1f))
        }
    }

// 在 setupUI 中添加点击事件
binding.soundButton?.setOnClickListener {
    isVoiceInstructionsMuted = !isVoiceInstructionsMuted
}

// 设置初始状态
binding.soundButton?.unmute()
```

### 5. 添加 RouteOverview 按钮点击事件

```kotlin
binding.routeOverview?.setOnClickListener {
    navigationCamera.requestNavigationCameraToOverview()
    binding.recenter?.showTextAndExtend(1500L)
}
```

### 6. 更新 Recenter 按钮点击事件

```kotlin
binding.recenter?.setOnClickListener {
    navigationCamera.requestNavigationCameraToFollowing()
    binding.routeOverview?.showTextAndExtend(1500L)
}
```

### 7. 更新相机状态观察者

```kotlin
navigationCamera.registerNavigationCameraStateChangeObserver { navigationCameraState ->
    // 根据相机状态显示/隐藏 recenter 按钮 (官方示例模式)
    when (navigationCameraState) {
        NavigationCameraState.TRANSITION_TO_FOLLOWING,
        NavigationCameraState.FOLLOWING -> binding.recenter?.visibility = View.INVISIBLE
        NavigationCameraState.TRANSITION_TO_OVERVIEW,
        NavigationCameraState.OVERVIEW,
        NavigationCameraState.IDLE -> binding.recenter?.visibility = View.VISIBLE
    }
}
```

## 关键差异

| 功能 | 之前 | 之后 (官方模式) |
|------|------|----------------|
| 位置提供者 | 直接使用 location component | NavigationLocationProvider |
| Puck 初始化 | loadStyle 回调中 | initializeNavigation 中 |
| 位置更新 | 只更新 viewportDataSource | navigationLocationProvider.changePosition() |
| SoundButton | 无点击事件 | isVoiceInstructionsMuted 状态切换 |
| RouteOverview | 无点击事件 | 切换到概览模式 |
| Recenter | 简单调用 | 带动画效果 |

## 编译状态

✅ **无编译错误**

## 测试建议

1. 验证用户位置 puck 是否正确显示
2. 验证 puck 是否跟随位置更新移动
3. 验证 SoundButton 点击是否切换静音状态
4. 验证 RouteOverview 按钮是否切换到概览模式
5. 验证 Recenter 按钮是否切换到跟随模式
6. 验证按钮图标是否正确显示

## 参考

- [官方 Turn-by-Turn 示例](https://docs.mapbox.com/android/navigation/examples/turn-by-turn-experience/)
- [NavigationLocationProvider 文档](https://docs.mapbox.com/android/navigation/api/ui-maps/)
