# Light Preset 功能优化建议

## 📊 当前实现 vs 官方推荐

### 当前实现（基于固定时间段）

```swift
func getLightPresetForRealTime() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<7: return "dawn"
    case 7..<18: return "day"
    case 18..<20: return "dusk"
    default: return "night"
    }
}
```

**缺点**：
- ❌ 固定时间段，不考虑季节变化
- ❌ 不考虑地理位置（北京的日出时间和其他城市不同）
- ❌ 不够精确

### 🌟 官方推荐方案

根据官方文档，Mapbox Navigation SDK 内置了根据日出日落自动调整的功能：

> Active style is set based on the sunrise and sunset at your current location.

## ✅ 优化方案

### 方案 1：使用 NavigationViewController 的内置功能（最简单）

如果你使用的是 `NavigationViewController`，它已经内置了自动调整功能：

```swift
// 在创建 NavigationViewController 后
self._navigationViewController = NavigationViewController(
    navigationRoutes: navigationRoutes,
    navigationOptions: navigationOptions
)

// 对于真实时间模式，检查是否有 styleManager
if _lightPresetMode == .realTime {
    // NavigationViewController 内部的 StyleManager 会自动根据日出日落调整
    // 无需手动设置 - 这是最简单的方式！
    print("✅ 使用 NavigationViewController 内置的自动调整功能")
} else if _lightPresetMode == .manual {
    // 手动模式：应用用户选择的 preset
    // 需要在样式加载后手动设置
}
```

**优点**：
- ✅ 零代码 - SDK 自动处理
- ✅ 基于真实日出日落时间
- ✅ 考虑地理位置

**缺点**：
- ⚠️ 仅适用于 NavigationViewController
- ⚠️ 不适用于普通的 MapView

### 方案 2：保持当前的简单实现（推荐用于非导航场景）

对于不使用 NavigationViewController 的场景（如 EmbeddedNavigationView 或独立 MapView），当前的实现已经足够好：

```swift
func getLightPresetForRealTime() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    
    switch hour {
    case 5..<7:   return "dawn"   // 黎明
    case 7..<18:  return "day"    // 白天
    case 18..<20: return "dusk"   // 黄昏
    default:      return "night"  // 夜晚
    }
}
```

**理由**：
- ✅ 简单直接，无需第三方库
- ✅ 对大多数用户来说已经足够精确
- ✅ 性能好，无需复杂计算
- ✅ 可读性强

### 方案 3：集成日出日落计算库（最精确，但复杂）

如果需要最精确的日出日落时间，可以集成第三方库：

```swift
// 使用 Solar 库（需要添加依赖）
import Solar

func getLightPresetBasedOnSun(location: CLLocationCoordinate2D) -> String {
    let solar = Solar(coordinate: location)
    let now = Date()
    
    guard let sunrise = solar?.sunrise,
          let sunset = solar?.sunset else {
        // 如果无法获取日出日落，使用固定时间段
        return getLightPresetForRealTime()
    }
    
    let calendar = Calendar.current
    let dawn = calendar.date(byAdding: .minute, value: -30, to: sunrise) ?? sunrise
    let dusk = calendar.date(byAdding: .minute, value: 30, to: sunset) ?? sunset
    
    if now < dawn {
        return "night"
    } else if now < sunrise {
        return "dawn"
    } else if now < sunset {
        return "day"
    } else if now < dusk {
        return "dusk"
    } else {
        return "night"
    }
}
```

**优点**：
- ✅ 最精确
- ✅ 考虑地理位置
- ✅ 考虑季节变化

**缺点**：
- ❌ 需要添加第三方依赖
- ❌ 需要位置权限
- ❌ 代码复杂度增加
- ❌ 如果位置不可用，需要降级处理

## 🎯 推荐方案

### 对于导航场景（NavigationViewController）

**直接使用官方内置功能** - 无需编写任何代码：

```swift
// 真实时间模式：什么都不做，让 SDK 自动处理！
case .realTime:
    // NavigationViewController 会自动根据日出日落调整样式
    // 我们只需要不手动覆盖它
    print("✅ Light Preset 模式：真实时间（SDK 自动处理）")
```

### 对于非导航场景（普通 MapView）

**保持当前的简单实现**：

```swift
case .realTime:
    let preset = self.getLightPresetForRealTime()  // 基于固定时间段
    self.applyLightPreset(preset, to: mapView)
    print("✅ Light Preset 模式：真实时间 (\(preset))")
```

## 📝 简化建议

### 当前代码可以这样简化：

```swift
// NavigationFactory.swift - applyStoredMapStyle 方法

func applyStoredMapStyle(to navigationViewController: NavigationViewController) {
    Task { @MainActor in
        guard let navigationMapView = navigationViewController.navigationMapView else {
            print("⚠️ 无法获取 navigationMapView")
            return
        }
        
        let mapView = navigationMapView.mapView
        
        if _mapStyle != nil {
            mapView.mapboxMap.style.uri = getCurrentStyleURI()
            print("✅ 已应用地图样式: \(_mapStyle ?? "standard")")
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // 简化：只处理手动和演示模式，真实时间让 SDK 自动处理
            switch self._lightPresetMode {
            case .manual:
                // 手动模式：应用用户选择的 preset
                if let preset = self._lightPreset {
                    self.applyLightPreset(preset, to: mapView)
                    print("✅ Light Preset 模式：手动 (\(preset))")
                }
                
            case .realTime:
                // 真实时间模式：让 NavigationViewController 的 StyleManager 自动处理
                // 如果是普通 MapView，使用简单的时间段判断
                if navigationViewController is NavigationViewController {
                    print("✅ Light Preset 模式：真实时间（SDK 自动处理）")
                } else {
                    let preset = self.getLightPresetForRealTime()
                    self.applyLightPreset(preset, to: mapView)
                    print("✅ Light Preset 模式：真实时间 (\(preset))")
                }
                
            case .demo:
                // 演示模式：启动循环
                self.startDemoMode(mapView: mapView)
                print("✅ Light Preset 模式：演示（5秒循环）")
            }
        }
    }
}
```

## 🔍 进一步优化建议

### 1. 移除不必要的复杂度

如果 NavigationViewController 已经自动处理了真实时间模式，我们可以：

```swift
case .realTime:
    // 对于 NavigationViewController，什么都不做
    // 对于普通 MapView，使用简单判断
    let isNavigationView = navigationViewController is NavigationViewController
    
    if isNavigationView {
        // SDK 自动处理，无需手动设置
        print("✅ 使用 SDK 自动时间调整")
    } else {
        // 简单的时间段判断（对大多数场景已足够）
        let preset = getLightPresetForRealTime()
        applyLightPreset(preset, to: mapView)
    }
```

### 2. 添加配置选项

可以添加一个配置来选择精确度：

```swift
enum RealTimeAccuracy {
    case simple      // 基于固定时间段（当前实现）
    case precise     // 基于真实日出日落（需要第三方库）
    case automatic   // 使用 SDK 自动调整（NavigationViewController）
}
```

## 📊 最终建议

### 对于你的项目

**保持当前的实现**，因为：

1. ✅ **简单直接** - 无需添加依赖
2. ✅ **足够精确** - 对大多数用户来说已经很好
3. ✅ **性能好** - 无需复杂计算
4. ✅ **可维护** - 代码清晰易懂

### 可选优化

如果未来想要更精确，可以：

1. 在 NavigationViewController 中，检查是否有 `styleManager` 或类似属性
2. 如果有，在真实时间模式下让 SDK 自动处理
3. 如果没有，保持当前的简单实现

### 示例优化代码

```swift
// 简化版本 - 保持当前逻辑，只是更清晰
func applyLightPresetForMode(_ mode: LightPresetMode, to mapView: MapView) {
    switch mode {
    case .manual:
        applyManualPreset(to: mapView)
        
    case .realTime:
        applyRealTimePreset(to: mapView)
        
    case .demo:
        startDemoMode(mapView: mapView)
    }
}

private func applyRealTimePreset(to mapView: MapView) {
    let preset = getLightPresetForRealTime()
    applyLightPreset(preset, to: mapView)
    print("✅ 真实时间模式: \(preset) (基于本地时间)")
}
```

## 🎉 总结

**回答你的问题**：

1. **可以简化吗？** 
   - 当前代码已经相对简单了
   - 如果使用 NavigationViewController，可以让 SDK 自动处理真实时间模式
   - 但你的简单实现对大多数场景已经足够好

2. **需要更精确吗？**
   - 如果用户对精确度要求不高：**保持当前实现**
   - 如果需要最精确：可以集成日出日落计算库
   - 如果使用导航视图：可以依赖 SDK 的自动调整

3. **推荐做法**：
   - ✅ 保持当前的简单实现
   - ✅ 在文档中说明这是"近似值"
   - ✅ 如果用户反馈需要更精确，再考虑优化

**你的当前实现已经很好了！** 👍

---

**优化日期**: 2024-11-17  
**结论**: 保持当前实现，无需复杂化
