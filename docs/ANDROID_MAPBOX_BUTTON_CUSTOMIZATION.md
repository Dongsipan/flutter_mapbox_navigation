# Android Mapbox Button Customization

## Overview
This document describes the implementation of custom styling for Mapbox official button components in the Android navigation UI.

## Affected Components
- `MapboxSoundButton` - Voice instructions toggle
- `MapboxRouteOverviewButton` - Route overview camera mode
- `MapboxRecenterButton` - Recenter camera to following mode

## Design Requirements
- Background: `#040608` (deep black, matching theme) with **circular shape** (24dp corner radius)
- Icon color: White (`#FFFFFF`)
- Text color: White (`#FFFFFF`) - for expanded button labels
- Consistent with cycling navigation theme

## Implementation Details

### 1. Layout Configuration
**File**: `android/src/main/res/layout/navigation_activity.xml`

The buttons are declared without custom backgrounds in XML, allowing programmatic styling:

```xml
<com.mapbox.navigation.ui.components.voice.view.MapboxSoundButton
    android:id="@+id/soundButton"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:layout_marginTop="8dp"
    android:layout_marginEnd="16dp"
    android:visibility="invisible"
    app:layout_constraintEnd_toEndOf="parent"
    app:layout_constraintTop_toBottomOf="@id/maneuverView" />
```

### 2. Programmatic Styling
**File**: `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`

The `customizeMapboxButtons()` function applies custom styling:

```kotlin
private fun customizeMapboxButtons() {
    try {
        val darkBackground = android.graphics.Color.parseColor("#040608")
        val whiteColor = android.graphics.Color.WHITE
        
        // Helper function to recursively find and style child views
        fun styleChildViews(view: View, iconColor: Int, textColor: Int) {
            when (view) {
                is android.widget.ImageView -> {
                    view.setColorFilter(iconColor, android.graphics.PorterDuff.Mode.SRC_IN)
                }
                is android.widget.TextView -> {
                    view.setTextColor(textColor)
                }
                is android.view.ViewGroup -> {
                    for (i in 0 until view.childCount) {
                        styleChildViews(view.getChildAt(i), iconColor, textColor)
                    }
                }
            }
        }
        
        // Create rounded background drawable (circular)
        val cornerRadius = 24f
        val roundedBackground = android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            setColor(darkBackground)
            setCornerRadius(cornerRadius)
        }
        
        // Apply to each button
        binding.soundButton?.let { button ->
            button.background = roundedBackground
            styleChildViews(button, whiteColor, whiteColor)
        }
        
        // ... similar for routeOverview and recenter buttons
    } catch (e: Exception) {
        android.util.Log.e(TAG, "❌ Failed to customize Mapbox buttons: ${e.message}", e)
    }
}
```

### 3. Technical Approach

#### Circular Background
Uses `GradientDrawable` with corner radius:
```kotlin
val roundedBackground = android.graphics.drawable.GradientDrawable().apply {
    shape = android.graphics.drawable.GradientDrawable.RECTANGLE
    setColor(darkBackground)
    setCornerRadius(24f) // Creates circular appearance
}
button.background = roundedBackground
```

#### Icon & Text Color
Since these buttons are `ConstraintLayout` subclasses containing child views:
1. Recursively traverse the view hierarchy
2. Find all `ImageView` instances → apply white color filter
3. Find all `TextView` instances → set white text color
4. This ensures both collapsed (icon only) and expanded (icon + text) states are styled correctly

This approach works because:
- Mapbox buttons use standard Android `ImageView` for icons
- Mapbox buttons use standard Android `TextView` for labels (when expanded)
- Color filters and text colors are applied at runtime after view inflation
- Circular shape is maintained through `GradientDrawable` corner radius

### 4. Execution Timing
The function is called in `setupUI()` after view binding is complete:

```kotlin
private fun setupUI() {
    // ... other UI setup ...
    
    // Customize Mapbox button styles - circular bg + white icons/text
    customizeMapboxButtons()
    
    // ... rest of setup ...
}
```

## Visual Result
- **Collapsed state**: Circular button with white icon on dark background
- **Expanded state**: Rounded button with white icon + white text label on dark background
- **Consistency**: All three buttons maintain the same visual style

## Testing
Build verification:
```bash
cd example/android
./gradlew assembleDebug
```

Expected result: Build succeeds with no errors.

## Logging
The implementation includes detailed logging:
- `✓ Colored ImageView in [parent class]` - Icon successfully colored
- `✓ Colored TextView in [parent class]` - Text successfully colored
- `✓ Customized [button]: circular bg + white icon/text` - Button fully customized
- `🎨 All Mapbox buttons customized: circular #040608 background + white icons/text` - Success
- `❌ Failed to customize Mapbox buttons: [error]` - Error occurred

## Fallback Behavior
If styling fails (e.g., SDK structure changes):
- Background shape will still be applied
- Icons/text may retain default colors
- Error is logged but doesn't crash the app

## References
- Mapbox Navigation SDK v3.9.2 Documentation
- Official Mapbox button components: `MapboxSoundButton`, `MapboxRouteOverviewButton`, `MapboxRecenterButton`
- Android `GradientDrawable` for circular backgrounds
- Android View hierarchy traversal for custom styling

## Related Files
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/activity/NavigationActivity.kt`
- `android/src/main/res/layout/navigation_activity.xml`
- `android/src/main/res/values/colors.xml`
