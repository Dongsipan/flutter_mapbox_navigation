# Requirements Document

## Introduction

This feature addresses a critical bug where user-selected map styles are saved correctly but not applied when opening map-related interfaces (navigation, search, replay). The style picker correctly displays the previously selected value, but the actual map views use hardcoded default styles instead of the user's saved preferences.

## Glossary

- **StylePreferenceManager**: Android utility class that manages saving and retrieving map style preferences from SharedPreferences
- **NavigationActivity**: Activity that displays turn-by-turn navigation with a map view
- **SearchActivity**: Activity that provides map-based location search functionality
- **NavigationReplayActivity**: Activity that replays recorded navigation history on a map
- **MapStyleManager**: Utility class that manages map style switching and day/night modes
- **MapStyleSelectorActivity**: Utility class that provides style selection based on UI mode
- **Map_Style**: User's selected map style (standard, satellite, light, dark, etc.)
- **Light_Preset**: Light preset setting for styles that support it (day, night, dawn, dusk)
- **Style_URL**: Mapbox style URI string used to load map styles

## Requirements

### Requirement 1: Apply Saved Map Style in Navigation

**User Story:** As a user, I want my selected map style to be applied when I start navigation, so that the map appearance matches my preferences.

#### Acceptance Criteria

1. WHEN NavigationActivity initializes the map, THE System SHALL load the map style from StylePreferenceManager
2. WHEN no saved style exists, THE System SHALL use the default style (standard)
3. WHEN the saved style is loaded, THE System SHALL apply it to the map view before displaying routes
4. WHEN Light Preset is configured for the style, THE System SHALL apply the Light Preset setting

### Requirement 2: Apply Saved Map Style in Search

**User Story:** As a user, I want my selected map style to be applied when I open the search interface, so that the map appearance is consistent across all features.

#### Acceptance Criteria

1. WHEN SearchActivity initializes the map, THE System SHALL load the map style from StylePreferenceManager
2. WHEN no saved style exists, THE System SHALL use the default style (standard)
3. WHEN the saved style is loaded, THE System SHALL apply it to the map view
4. WHEN Light Preset is configured for the style, THE System SHALL apply the Light Preset setting

### Requirement 3: Apply Saved Map Style in History Replay

**User Story:** As a user, I want my selected map style to be applied when I replay navigation history, so that the map appearance matches my preferences.

#### Acceptance Criteria

1. WHEN NavigationReplayActivity initializes the map, THE System SHALL load the map style from StylePreferenceManager instead of using UI mode
2. WHEN no saved style exists, THE System SHALL use the default style (standard)
3. WHEN the saved style is loaded, THE System SHALL apply it to the map view before loading replay data
4. WHEN Light Preset is configured for the style, THE System SHALL apply the Light Preset setting

### Requirement 4: Maintain Backward Compatibility

**User Story:** As a developer, I want the system to maintain backward compatibility with existing code, so that other features continue to work without modification.

#### Acceptance Criteria

1. WHEN FlutterMapboxNavigationPlugin.mapStyleUrlDay is set, THE System SHALL use it as an override for the saved style
2. WHEN FlutterMapboxNavigationPlugin.mapStyleUrlNight is set, THE System SHALL use it as an override for the saved style
3. WHEN neither override is set, THE System SHALL use the saved style from StylePreferenceManager
4. THE MapStyleManager SHALL continue to support day/night mode switching

### Requirement 5: Handle Light Preset Configuration

**User Story:** As a user, I want Light Preset settings to be applied correctly for styles that support them, so that the map lighting matches my preferences.

#### Acceptance Criteria

1. WHEN a style supports Light Preset (standard, standardSatellite, faded, monochrome), THE System SHALL apply the saved Light Preset value
2. WHEN Light Preset mode is "automatic", THE System SHALL adjust Light Preset based on time of day
3. WHEN Light Preset mode is "manual", THE System SHALL use the saved Light Preset value
4. WHEN a style does not support Light Preset, THE System SHALL load the style without Light Preset configuration
