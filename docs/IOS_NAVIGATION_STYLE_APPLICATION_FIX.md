# iOS Navigation Style Application Fix

## Problem

User-selected map styles from the Style Picker were not being applied to the actual navigation interface. The navigation always used the default "standard" style regardless of user preferences.

## Root Cause

In `NavigationFactory.swift`, the `startNavigation()` method was creating `CustomDayStyle` and `CustomNightStyle` instances using the default `init()` constructor, which doesn't accept any parameters:

```swift
// ❌ Before: Using default initializer (no parameters)
styles: [CustomDayStyle(), CustomNightStyle()]
```

However, both `CustomDayStyle` and `CustomNightStyle` have parameterized initializers that accept:
- `mapStyle: String?` - The map style (e.g., "standard", "satellite", "dark")
- `lightPreset: String?` - The light preset (e.g., "day", "night", "dusk", "dawn")
- `lightPresetMode: LightPresetMode` - The mode (manual or automatic)

When using the default `init()`, these values were set to `nil` and `.manual`, causing the styles to always use the default configuration.

## Solution

Updated the `startNavigation()` method to pass the stored style parameters to the custom style initializers:

```swift
// ✅ After: Passing user-configured style parameters
let dayStyle = CustomDayStyle(
    mapStyle: self._mapStyle,
    lightPreset: self._lightPreset,
    lightPresetMode: self._lightPresetMode
)
let nightStyle = CustomNightStyle(
    mapStyle: self._mapStyle,
    lightPreset: self._lightPreset,
    lightPresetMode: self._lightPresetMode
)

let navigationOptions = NavigationOptions(
    mapboxNavigation: mapboxNavigation,
    voiceController: mapboxNavigationProvider!.routeVoiceController,
    eventsManager: mapboxNavigation.eventsManager(),
    styles: [dayStyle, nightStyle]
)
```

## How It Works

### 1. Style Settings Storage

When the user selects a style in the Style Picker:
- Settings are saved to `UserDefaults` via `StylePickerHandler.saveStyleSettings()`
- Keys: `mapbox_map_style`, `mapbox_light_preset`, `mapbox_light_preset_mode`

### 2. Style Settings Loading

When `NavigationFactory` is initialized:
- `loadStoredStyleSettings()` is called in `init()`
- Settings are loaded from `UserDefaults` into instance variables:
  - `_mapStyle`
  - `_lightPreset`
  - `_lightPresetMode`

### 3. Style Application

When navigation starts:
- `startNavigation()` creates custom style instances with the loaded parameters
- The custom styles apply the user's preferences in their `init()` methods:
  - Convert `mapStyle` string to `StyleURI` URL
  - Store `lightPreset` and `lightPresetMode` for later use
  - Set `mapStyleURL` and `previewMapStyleURL`

### 4. Runtime Style Updates

The custom styles also post notifications when applied:
```swift
NotificationCenter.default.post(
    name: NSNotification.Name("CustomStyleDidApply"),
    object: nil,
    userInfo: [
        "mapStyle": customMapStyle as Any,
        "lightPreset": customLightPreset as Any,
        "lightPresetMode": customLightPresetMode.rawValue
    ]
)
```

This allows other components (like the map view) to react to style changes.

## Supported Map Styles

The following map styles are supported:

| Style String | Mapbox StyleURI |
|-------------|----------------|
| `standard` | `.standard` |
| `faded` | `.standard` (variant) |
| `monochrome` | `.standard` (variant) |
| `standardSatellite` | `.standardSatellite` |
| `light` | `.light` |
| `dark` | `.dark` |
| `outdoors` | `.outdoors` |

## Supported Light Presets

| Preset | Description |
|--------|-------------|
| `day` | Bright daylight appearance |
| `night` | Dark nighttime appearance |
| `dusk` | Twilight appearance |
| `dawn` | Early morning appearance |

## Light Preset Modes

| Mode | Behavior |
|------|----------|
| `manual` | Uses the fixed preset selected by the user |
| `automatic` | Automatically adjusts based on real sunrise/sunset times |

## Testing

To verify the fix:

1. **Open Style Picker**
   - Launch the app
   - Navigate to Style Picker

2. **Select a Style**
   - Choose a map style (e.g., "Satellite")
   - Choose a light preset (e.g., "Night")
   - Save settings

3. **Start Navigation**
   - Create a route
   - Start navigation
   - Verify the map uses the selected style

4. **Check Console Logs**
   ```
   🔄 重新加载样式设置...
   ✅ NavigationFactory: 已加载存储的地图样式: standardSatellite
   ✅ NavigationFactory: 已加载存储的 Light Preset: night
   🎨 创建导航样式: mapStyle=standardSatellite, lightPreset=night, mode=manual
   🔵 CustomDayStyle.init() 开始: mapStyle=standardSatellite, lightPreset=night, mode=manual
   ✅ CustomDayStyle 初始化完成
   ✅ 导航控制器已创建，样式参数已传递
   ```

## Files Modified

- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/NavigationFactory.swift`
  - Updated `startNavigation()` method to pass style parameters to custom styles

## Related Files

- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/styles/Day.swift`
  - Contains `CustomDayStyle` with parameterized initializer
  
- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/styles/Night.swift`
  - Contains `CustomNightStyle` with parameterized initializer

- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/StylePickerHandler.swift`
  - Handles saving/loading style settings to/from UserDefaults

- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/StylePickerViewController.swift`
  - UI for selecting map styles and light presets

## Benefits

✅ User-selected styles are now properly applied to navigation
✅ Consistent style experience across Style Picker preview and actual navigation
✅ Supports all Mapbox map styles and light presets
✅ Supports both manual and automatic light preset modes
✅ Settings persist across app sessions via UserDefaults

## Date

January 31, 2026
