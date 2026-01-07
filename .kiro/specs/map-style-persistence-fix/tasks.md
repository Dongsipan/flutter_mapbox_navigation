# Implementation Plan: Map Style Persistence Fix

## Overview

This implementation plan fixes the bug where user-selected map styles are saved but not applied to map activities. The fix involves modifying three activities (NavigationActivity, SearchActivity, NavigationReplayActivity) to read styles from StylePreferenceManager and adding a helper method to apply Light Preset settings.

## Tasks

- [x] 1. Add Light Preset helper method to StylePreferenceManager
  - Add `applyLightPresetToStyle()` method to apply Light Preset to loaded styles
  - Add `supportsLightPreset()` private method to check if a style supports Light Preset
  - Add proper error handling for Light Preset application failures
  - _Requirements: 5.1, 5.4_

- [x] 2. Update NavigationActivity to use saved map style
  - [x] 2.1 Modify `initializeMap()` to read style from StylePreferenceManager
    - Implement priority logic: Plugin override > User preference > Default
    - Replace hardcoded `FlutterMapboxNavigationPlugin.mapStyleUrlDay` with preference-based loading
    - _Requirements: 1.1, 1.2, 4.1, 4.3_

  - [x] 2.2 Apply Light Preset after style loads
    - Call `StylePreferenceManager.applyLightPresetToStyle()` in the style load callback
    - Handle styles that don't support Light Preset
    - _Requirements: 1.4, 5.1, 5.4_

  - [x] 2.3 Update MapStyleManager day/night style initialization
    - Ensure MapStyleManager uses saved preferences when plugin overrides are not set
    - _Requirements: 4.4_

- [x] 3. Update SearchActivity to use saved map style
  - [x] 3.1 Modify `setupMapView()` to load saved style
    - Add explicit style loading using StylePreferenceManager.getMapStyleUrl()
    - Replace implicit default style with user preference
    - _Requirements: 2.1, 2.2_

  - [x] 3.2 Apply Light Preset after style loads
    - Call `StylePreferenceManager.applyLightPresetToStyle()` in the style load callback
    - _Requirements: 2.4, 5.1, 5.4_

- [x] 4. Update NavigationReplayActivity to use saved map style
  - [x] 4.1 Replace UI mode style with saved preference
    - Replace `MapStyleSelectorActivity.getStyleForUiMode()` with `StylePreferenceManager.getMapStyleUrl()`
    - Update both initial style load and any style refresh logic
    - _Requirements: 3.1, 3.2_

  - [x] 4.2 Apply Light Preset after style loads
    - Call `StylePreferenceManager.applyLightPresetToStyle()` in the style load callback
    - _Requirements: 3.4, 5.1, 5.4_

- [x] 5. Add error handling and logging
  - Add try-catch blocks for style loading failures with fallback to default style
  - Add logging for style loading success/failure
  - Add logging for Light Preset application
  - _Requirements: All_

- [x] 6. Checkpoint - Manual testing
  - Test style persistence across all three activities
  - Test Light Preset application for compatible styles
  - Test backward compatibility with plugin overrides
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- All tasks involve modifying existing Kotlin files in the Android platform code
- No changes needed to Flutter/Dart code or iOS implementation
- StylePreferenceManager already has all the data access methods needed
- The fix maintains full backward compatibility with existing plugin options
- Light Preset is only applied to styles that support it (standard, standardSatellite, faded, monochrome)
