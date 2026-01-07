# Design Document

## Overview

This design addresses the bug where user-selected map styles are correctly saved to SharedPreferences but not applied when map-related activities (NavigationActivity, SearchActivity, NavigationReplayActivity) are launched. The root cause is that these activities use hardcoded style values or system UI mode instead of reading from StylePreferenceManager.

The solution involves modifying the map initialization logic in each activity to:
1. Read the saved style from StylePreferenceManager
2. Convert the style name to a Mapbox Style URI
3. Apply Light Preset settings for compatible styles
4. Maintain backward compatibility with existing plugin options

## Architecture

### Current Architecture Issues

1. **NavigationActivity**: Uses `FlutterMapboxNavigationPlugin.mapStyleUrlDay/Night` which are static values set at plugin initialization, not user preferences
2. **SearchActivity**: Doesn't load any custom style, uses default Mapbox style
3. **NavigationReplayActivity**: Uses `MapStyleSelectorActivity.getStyleForUiMode()` which returns style based on system dark mode, not user preference
4. **StylePreferenceManager**: Exists and works correctly for saving/loading, but is not used by the activities

### Proposed Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Activity Initialization                   │
│  (NavigationActivity, SearchActivity, NavigationReplayActivity)│
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              StylePreferenceManager.getMapStyleUrl()         │
│  - Reads saved style from SharedPreferences                  │
│  - Converts style name to Mapbox URI                         │
│  - Returns style URL string                                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  MapView.loadStyle(styleUrl)                 │
│  - Loads the style into the map                              │
│  - Applies Light Preset if supported                         │
└─────────────────────────────────────────────────────────────┘
```

### Backward Compatibility Layer

```
if (FlutterMapboxNavigationPlugin.mapStyleUrlDay != null) {
    // Use plugin override (backward compatibility)
    styleUrl = FlutterMapboxNavigationPlugin.mapStyleUrlDay
} else {
    // Use saved user preference (new behavior)
    styleUrl = StylePreferenceManager.getMapStyleUrl(context)
}
```

## Components and Interfaces

### Modified Components

#### 1. NavigationActivity.initializeMap()

**Current Implementation:**
```kotlin
val styleUrl = FlutterMapboxNavigationPlugin.mapStyleUrlDay ?: Style.MAPBOX_STREETS
binding.mapView.mapboxMap.loadStyle(styleUrl) { style ->
    // ...
}
```

**New Implementation:**
```kotlin
// Priority: Plugin override > User preference > Default
val styleUrl = when {
    FlutterMapboxNavigationPlugin.mapStyleUrlDay != null -> 
        FlutterMapboxNavigationPlugin.mapStyleUrlDay!!
    else -> StylePreferenceManager.getMapStyleUrl(this)
}

binding.mapView.mapboxMap.loadStyle(styleUrl) { style ->
    // Apply Light Preset if supported
    applyLightPresetIfSupported(style)
    // ... rest of initialization
}
```

#### 2. SearchActivity.setupMapView()

**Current Implementation:**
```kotlin
// No explicit style loading - uses default
```

**New Implementation:**
```kotlin
// Load user's preferred style
val styleUrl = StylePreferenceManager.getMapStyleUrl(this)

mapView.mapboxMap.loadStyle(styleUrl) { style ->
    // Apply Light Preset if supported
    applyLightPresetIfSupported(style)
}
```

#### 3. NavigationReplayActivity (onCreate)

**Current Implementation:**
```kotlin
val styleUri = MapStyleSelectorActivity.getStyleForUiMode(this)
binding.mapView.mapboxMap.loadStyle(styleUri)
```

**New Implementation:**
```kotlin
// Use saved user preference instead of UI mode
val styleUri = StylePreferenceManager.getMapStyleUrl(this)
binding.mapView.mapboxMap.loadStyle(styleUri) { style ->
    // Apply Light Preset if supported
    applyLightPresetIfSupported(style)
    // ... rest of initialization
}
```

### New Helper Methods

#### StylePreferenceManager Extension

Add a helper method to apply Light Preset settings:

```kotlin
/**
 * Apply Light Preset to a loaded style if the style supports it
 */
fun applyLightPresetToStyle(context: Context, style: Style) {
    val mapStyle = getMapStyle(context)
    val lightPreset = getLightPreset(context)
    
    // Only apply Light Preset to styles that support it
    if (supportsLightPreset(mapStyle)) {
        try {
            style.setStyleImportConfigProperty(
                "basemap",
                "lightPreset",
                Value.valueOf(lightPreset)
            )
            Log.d("StylePreferenceManager", "Applied Light Preset: $lightPreset to style: $mapStyle")
        } catch (e: Exception) {
            Log.e("StylePreferenceManager", "Failed to apply Light Preset: ${e.message}")
        }
    }
}

/**
 * Check if a style supports Light Preset
 */
private fun supportsLightPreset(styleName: String): Boolean {
    return styleName in listOf("standard", "standardSatellite", "faded", "monochrome")
}
```

## Data Models

### StylePreferenceManager Data

Existing data structure (no changes needed):

```kotlin
SharedPreferences: "mapbox_style_settings"
├── "map_style": String          // e.g., "standard", "dark", "satellite"
├── "light_preset": String       // e.g., "day", "night", "dawn", "dusk"
└── "light_preset_mode": String  // "manual" or "automatic"
```

### Style Name to URI Mapping

Existing mapping in StylePreferenceManager.getStyleUrl() (no changes needed):

```kotlin
"standard" -> Style.MAPBOX_STREETS
"standardSatellite" -> Style.SATELLITE_STREETS
"faded" -> "mapbox://styles/mapbox/light-v11"
"monochrome" -> "mapbox://styles/mapbox/dark-v11"
"light" -> Style.LIGHT
"dark" -> Style.DARK
"outdoors" -> Style.OUTDOORS
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Style Persistence Consistency

*For any* map-related activity (NavigationActivity, SearchActivity, NavigationReplayActivity), when the activity initializes its map view, the loaded style URL should match the style URL returned by StylePreferenceManager.getMapStyleUrl() unless a plugin override is set.

**Validates: Requirements 1.1, 2.1, 3.1**

### Property 2: Plugin Override Priority

*For any* map-related activity, when FlutterMapboxNavigationPlugin.mapStyleUrlDay is not null, the loaded style URL should equal FlutterMapboxNavigationPlugin.mapStyleUrlDay, regardless of saved preferences.

**Validates: Requirements 4.1, 4.2**

### Property 3: Default Style Fallback

*For any* map-related activity, when no saved style exists in SharedPreferences and no plugin override is set, the loaded style URL should equal the default style (Style.MAPBOX_STREETS).

**Validates: Requirements 1.2, 2.2, 3.2**

### Property 4: Light Preset Application

*For any* style that supports Light Preset (standard, standardSatellite, faded, monochrome), when the style is loaded, the Light Preset configuration should be applied with the value from StylePreferenceManager.getLightPreset().

**Validates: Requirements 1.4, 2.4, 3.4, 5.1**

### Property 5: Light Preset Exclusion

*For any* style that does not support Light Preset (light, dark, outdoors), when the style is loaded, no Light Preset configuration should be applied.

**Validates: Requirements 5.4**

## Error Handling

### Style Loading Failures

**Scenario**: Style URL is invalid or network error occurs during style loading

**Handling**:
```kotlin
binding.mapView.mapboxMap.loadStyle(styleUrl) { style ->
    // Success
    applyLightPresetIfSupported(style)
}.onError { error ->
    // Fallback to default style
    Log.e(TAG, "Failed to load style: $styleUrl, falling back to default")
    binding.mapView.mapboxMap.loadStyle(Style.MAPBOX_STREETS)
}
```

### Light Preset Application Failures

**Scenario**: Light Preset configuration fails (e.g., style doesn't support it despite being in the list)

**Handling**:
```kotlin
try {
    style.setStyleImportConfigProperty("basemap", "lightPreset", Value.valueOf(lightPreset))
} catch (e: Exception) {
    // Log error but continue - map will still work with default lighting
    Log.e(TAG, "Failed to apply Light Preset: ${e.message}")
}
```

### Missing SharedPreferences

**Scenario**: StylePreferenceManager returns null or empty string

**Handling**:
```kotlin
fun getMapStyleUrl(context: Context): String {
    val styleName = getMapStyle(context) // Returns DEFAULT_STYLE if null
    return getStyleUrl(styleName)
}
```

## Testing Strategy

### Unit Tests

1. **Test StylePreferenceManager.getMapStyleUrl()**
   - Verify correct URL returned for each style name
   - Verify default style returned when no preference saved
   - Verify style name to URI mapping is correct

2. **Test Light Preset Support Detection**
   - Verify supportsLightPreset() returns true for standard, standardSatellite, faded, monochrome
   - Verify supportsLightPreset() returns false for light, dark, outdoors

3. **Test Plugin Override Priority**
   - Verify plugin override takes precedence over saved preference
   - Verify saved preference used when plugin override is null

### Integration Tests

1. **Test NavigationActivity Style Loading**
   - Save a style preference
   - Launch NavigationActivity
   - Verify the correct style is loaded

2. **Test SearchActivity Style Loading**
   - Save a style preference
   - Launch SearchActivity
   - Verify the correct style is loaded

3. **Test NavigationReplayActivity Style Loading**
   - Save a style preference
   - Launch NavigationReplayActivity
   - Verify the correct style is loaded (not UI mode style)

4. **Test Light Preset Application**
   - Save a style that supports Light Preset
   - Save a Light Preset value
   - Launch any activity
   - Verify Light Preset is applied to the map

### Manual Testing

1. **End-to-End Style Persistence Test**
   - Open style picker
   - Select a style (e.g., "Dark")
   - Save the style
   - Open navigation → Verify dark style is applied
   - Open search → Verify dark style is applied
   - Open replay → Verify dark style is applied

2. **Light Preset Test**
   - Select "Standard" style
   - Set Light Preset to "night"
   - Save settings
   - Open any map activity → Verify night lighting is applied

3. **Backward Compatibility Test**
   - Set FlutterMapboxNavigationPlugin.mapStyleUrlDay in code
   - Launch navigation
   - Verify plugin override style is used, not saved preference
