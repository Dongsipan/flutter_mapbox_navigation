# Requirements Document - Android 导航功能与 iOS 对齐

## Introduction

本规格文档定义了在 Android 平台实现完整的转弯导航功能的需求,目标是实现与 iOS 实现的功能对齐。重点是提供完整的导航体验,包括适当的模拟支持、路线预览、主动引导以及所有导航模式(驾驶、步行、骑行),使用 Mapbox Navigation SDK v3。

## Glossary

- **Turn-by-Turn Navigation**: Step-by-step navigation guidance with voice instructions and visual cues
- **Simulation Mode**: Navigation replay using simulated location updates for testing without actual movement
- **Active Guidance**: Real-time navigation with live location tracking and route following
- **Free Drive Mode**: Location tracking without a destination or route
- **Route Preview**: Visual display of the calculated route before starting navigation
- **NavigationActivity**: Full-screen Android Activity for turn-by-turn navigation
- **MapboxNavigation**: Core navigation engine from Mapbox SDK v3
- **Trip Session**: Navigation session lifecycle management in SDK v3
- **Route Line**: Visual representation of the route on the map
- **Vanishing Route Line**: Route line that progressively disappears as you travel
- **Camera Tracking**: Automatic camera following of user location during navigation

## Requirements

### Requirement 1: Turn-by-Turn Navigation Activity

**User Story:** As a user, I want to start turn-by-turn navigation in a full-screen activity, so that I can follow directions to my destination with a clear, focused interface.

#### Acceptance Criteria

1. WHEN user calls startNavigation() THEN the system SHALL launch NavigationActivity in full-screen mode
2. WHEN NavigationActivity launches THEN the system SHALL display the map with the calculated route
3. WHEN NavigationActivity is active THEN the system SHALL show navigation UI elements (instructions, ETA, distance)
4. WHEN user dismisses NavigationActivity THEN the system SHALL stop navigation and clean up resources
5. THE system SHALL use Mapbox SDK v3 NavigationView or equivalent components
6. THE system SHALL support both portrait and landscape orientations

### Requirement 2: Simulation Mode Support

**User Story:** As a developer, I want to test navigation with simulated location updates, so that I can verify navigation functionality without physically traveling the route.

#### Acceptance Criteria

1. WHEN simulateRoute parameter is true THEN the system SHALL use startReplayTripSession()
2. WHEN simulateRoute parameter is false THEN the system SHALL use startTripSession() for real navigation
3. WHEN simulation is active THEN the system SHALL generate location updates along the route
4. WHEN simulation is active THEN the system SHALL trigger all navigation events as if traveling
5. THE system SHALL support configurable simulation speed
6. THE system SHALL provide smooth animated movement during simulation

### Requirement 3: Real Navigation Support

**User Story:** As a user, I want to navigate using my actual GPS location, so that I can receive accurate turn-by-turn directions while driving, walking, or cycling.

#### Acceptance Criteria

1. WHEN simulateRoute is false THEN the system SHALL use device GPS for location updates
2. WHEN real navigation is active THEN the system SHALL track actual user movement
3. WHEN user deviates from route THEN the system SHALL detect off-route condition
4. WHEN off-route is detected THEN the system SHALL automatically recalculate the route
5. THE system SHALL request and handle location permissions properly
6. THE system SHALL handle GPS signal loss gracefully

### Requirement 4: Navigation Modes

**User Story:** As a user, I want to choose different navigation modes (driving, walking, cycling), so that I get route options appropriate for my mode of transportation.

#### Acceptance Criteria

1. WHEN mode is "driving" THEN the system SHALL use PROFILE_DRIVING_TRAFFIC
2. WHEN mode is "walking" THEN the system SHALL use PROFILE_WALKING
3. WHEN mode is "cycling" THEN the system SHALL use PROFILE_CYCLING
4. WHEN calculating routes THEN the system SHALL apply mode-specific routing preferences
5. THE system SHALL support switching modes between route calculations
6. THE system SHALL use appropriate map styles for each mode

### Requirement 5: Route Calculation and Display

**User Story:** As a user, I want to see my calculated route on the map before starting navigation, so that I can review the path and estimated time.

#### Acceptance Criteria

1. WHEN waypoints are provided THEN the system SHALL calculate routes using RouteOptions
2. WHEN routes are calculated THEN the system SHALL draw the route line on the map
3. WHEN multiple routes are available THEN the system SHALL display alternative routes
4. WHEN route is displayed THEN the system SHALL adjust camera to show the full route
5. THE system SHALL use MapboxRouteLineApi and MapboxRouteLineView for route rendering
6. THE system SHALL support route line customization (color, width, opacity)

### Requirement 6: Voice Instructions

**User Story:** As a user, I want to hear voice instructions during navigation, so that I can keep my eyes on the road while receiving guidance.

#### Acceptance Criteria

1. WHEN navigation is active THEN the system SHALL play voice instructions at appropriate times
2. WHEN voiceInstructionsEnabled is true THEN the system SHALL enable voice guidance
3. WHEN voiceInstructionsEnabled is false THEN the system SHALL mute voice guidance
4. WHEN language is specified THEN the system SHALL use that language for voice instructions
5. THE system SHALL support imperial and metric units for voice instructions
6. THE system SHALL use VoiceInstructionsObserver to receive voice instruction events

### Requirement 7: Banner Instructions

**User Story:** As a user, I want to see visual turn instructions on screen, so that I have clear visual guidance for upcoming maneuvers.

#### Acceptance Criteria

1. WHEN navigation is active THEN the system SHALL display banner instructions
2. WHEN bannerInstructionsEnabled is true THEN the system SHALL show instruction banners
3. WHEN bannerInstructionsEnabled is false THEN the system SHALL hide instruction banners
4. WHEN approaching a maneuver THEN the system SHALL update the banner with current instruction
5. THE system SHALL use BannerInstructionsObserver to receive banner updates
6. THE system SHALL display maneuver icons and distance information

### Requirement 8: Route Progress Tracking

**User Story:** As a user, I want to see my progress along the route, so that I know how far I've traveled and how much remains.

#### Acceptance Criteria

1. WHEN navigation is active THEN the system SHALL track route progress continuously
2. WHEN progress updates THEN the system SHALL send progress events to Flutter layer
3. WHEN progress updates THEN the system SHALL update distance remaining
4. WHEN progress updates THEN the system SHALL update duration remaining (ETA)
5. THE system SHALL use RouteProgressObserver for progress tracking
6. THE system SHALL include current leg and step information in progress events

### Requirement 9: Arrival Detection

**User Story:** As a user, I want to be notified when I arrive at my destination, so that I know navigation is complete.

#### Acceptance Criteria

1. WHEN user reaches final destination THEN the system SHALL trigger arrival event
2. WHEN user reaches waypoint THEN the system SHALL trigger waypoint arrival event
3. WHEN arrival is detected THEN the system SHALL send ON_ARRIVAL event to Flutter
4. WHEN multi-leg route THEN the system SHALL continue to next leg after waypoint arrival
5. THE system SHALL use ArrivalObserver for arrival detection
6. THE system SHALL support configurable arrival threshold distance

### Requirement 10: Camera and Map Control

**User Story:** As a user, I want the map camera to follow my location during navigation, so that I always see my current position and upcoming route.

#### Acceptance Criteria

1. WHEN navigation starts THEN the system SHALL enable camera tracking
2. WHEN user is moving THEN the system SHALL update camera position smoothly
3. WHEN user manually moves map THEN the system SHALL temporarily disable auto-tracking
4. WHEN user taps recenter button THEN the system SHALL re-enable camera tracking
5. THE system SHALL support configurable camera zoom, tilt, and bearing
6. THE system SHALL use appropriate camera animations for smooth transitions

### Requirement 11: Map Style Support

**User Story:** As a user, I want to choose different map styles, so that I can customize the map appearance to my preference.

#### Acceptance Criteria

1. WHEN mapStyleUrlDay is provided THEN the system SHALL use it for day mode
2. WHEN mapStyleUrlNight is provided THEN the system SHALL use it for night mode
3. WHEN no custom style is provided THEN the system SHALL use default Mapbox styles
4. WHEN time of day changes THEN the system SHALL automatically switch between day/night styles
5. THE system SHALL support all standard Mapbox style URLs
6. THE system SHALL support custom style URLs

### Requirement 12: Event Communication

**User Story:** As a developer, I want all navigation events to be sent to the Flutter layer, so that the Flutter app can respond to navigation state changes.

#### Acceptance Criteria

1. WHEN route is built THEN the system SHALL send ROUTE_BUILT event
2. WHEN navigation starts THEN the system SHALL send NAVIGATION_RUNNING event
3. WHEN navigation is cancelled THEN the system SHALL send NAVIGATION_CANCELLED event
4. WHEN user goes off route THEN the system SHALL send USER_OFF_ROUTE event
5. WHEN route is recalculated THEN the system SHALL send REROUTE_ALONG event
6. THE system SHALL serialize all events to JSON and send via EventChannel

### Requirement 13: Lifecycle Management

**User Story:** As a developer, I want proper lifecycle management, so that navigation resources are correctly initialized and cleaned up.

#### Acceptance Criteria

1. WHEN NavigationActivity is created THEN the system SHALL initialize MapboxNavigation
2. WHEN NavigationActivity is destroyed THEN the system SHALL unregister all observers
3. WHEN navigation ends THEN the system SHALL stop trip session
4. WHEN navigation ends THEN the system SHALL clear routes and reset state
5. THE system SHALL use MapboxNavigationApp for lifecycle management
6. THE system SHALL prevent memory leaks and resource leaks

### Requirement 14: Error Handling

**User Story:** As a user, I want clear error messages when navigation fails, so that I understand what went wrong and can take appropriate action.

#### Acceptance Criteria

1. WHEN route calculation fails THEN the system SHALL send ROUTE_BUILD_FAILED event
2. WHEN navigation initialization fails THEN the system SHALL send error event with details
3. WHEN location permission is denied THEN the system SHALL notify user appropriately
4. WHEN GPS signal is lost THEN the system SHALL show appropriate warning
5. THE system SHALL log all errors for debugging
6. THE system SHALL handle all exceptions gracefully without crashing

### Requirement 15: Alternative Routes

**User Story:** As a user, I want to see alternative route options, so that I can choose the best route for my needs.

#### Acceptance Criteria

1. WHEN alternatives parameter is true THEN the system SHALL request alternative routes
2. WHEN multiple routes are available THEN the system SHALL display all routes on map
3. WHEN user selects a route THEN the system SHALL use that route for navigation
4. WHEN displaying alternatives THEN the system SHALL highlight the primary route
5. THE system SHALL show route comparison information (distance, duration)
6. THE system SHALL support up to 3 alternative routes

### Requirement 16: Vanishing Route Line

**User Story:** As a user, I want the route line to disappear behind me as I travel, so that I can clearly see the remaining route ahead.

#### Acceptance Criteria

1. WHEN navigation is active THEN the system SHALL enable vanishing route line
2. WHEN user travels along route THEN the system SHALL progressively hide traveled portion
3. WHEN route line vanishes THEN the system SHALL maintain smooth visual transition
4. THE system SHALL use routeLineTracksTraversal or equivalent feature
5. THE system SHALL support customization of vanishing route line appearance
6. THE system SHALL handle route line updates efficiently

### Requirement 17: Multi-Waypoint Support

**User Story:** As a user, I want to navigate through multiple waypoints, so that I can make stops along my route.

#### Acceptance Criteria

1. WHEN multiple waypoints are provided THEN the system SHALL create multi-leg route
2. WHEN reaching a waypoint THEN the system SHALL continue to next leg automatically
3. WHEN waypoint is marked as silent THEN the system SHALL not separate legs
4. WHEN adding waypoints during navigation THEN the system SHALL recalculate route
5. THE system SHALL support waypoint reordering and optimization
6. THE system SHALL track progress for each leg separately

### Requirement 18: Free Drive Mode

**User Story:** As a user, I want to use free drive mode without a destination, so that I can track my location and see the map while exploring.

#### Acceptance Criteria

1. WHEN startFreeDrive() is called THEN the system SHALL start trip session without routes
2. WHEN free drive is active THEN the system SHALL track and display user location
3. WHEN free drive is active THEN the system SHALL send location update events
4. WHEN free drive is active THEN the system SHALL not provide turn instructions
5. THE system SHALL use MapboxNavigation.startTripSession() without setting routes
6. THE system SHALL support stopping free drive mode cleanly

### Requirement 19: History Recording Integration

**User Story:** As a developer, I want navigation history to be recorded, so that I can replay and analyze navigation sessions later.

#### Acceptance Criteria

1. WHEN enableHistoryRecording is true THEN the system SHALL start history recording
2. WHEN navigation starts THEN the system SHALL begin recording navigation events
3. WHEN navigation ends THEN the system SHALL stop recording and save history file
4. WHEN history is saved THEN the system SHALL send file path to Flutter layer
5. THE system SHALL use SDK v3 history recording APIs
6. THE system SHALL store history files in appropriate directory

### Requirement 20: iOS Feature Parity

**User Story:** As a developer, I want Android navigation to match iOS functionality, so that users have a consistent experience across platforms.

#### Acceptance Criteria

1. THE Android implementation SHALL support all navigation modes supported by iOS
2. THE Android implementation SHALL support simulation mode like iOS
3. THE Android implementation SHALL send the same event types as iOS
4. THE Android implementation SHALL support the same configuration options as iOS
5. THE Android implementation SHALL handle lifecycle similarly to iOS
6. THE Android implementation SHALL provide equivalent error handling to iOS

## Priority

### High Priority (Must Have)
- Requirement 1: Turn-by-Turn Navigation Activity
- Requirement 2: Simulation Mode Support
- Requirement 3: Real Navigation Support
- Requirement 4: Navigation Modes
- Requirement 5: Route Calculation and Display
- Requirement 8: Route Progress Tracking
- Requirement 12: Event Communication
- Requirement 13: Lifecycle Management

### Medium Priority (Should Have)
- Requirement 6: Voice Instructions
- Requirement 7: Banner Instructions
- Requirement 9: Arrival Detection
- Requirement 10: Camera and Map Control
- Requirement 11: Map Style Support
- Requirement 14: Error Handling
- Requirement 17: Multi-Waypoint Support

### Low Priority (Nice to Have)
- Requirement 15: Alternative Routes
- Requirement 16: Vanishing Route Line
- Requirement 18: Free Drive Mode
- Requirement 19: History Recording Integration

## Technical Constraints

1. Must use Mapbox Navigation SDK v3.17.2 or higher
2. Must maintain compatibility with existing Flutter API
3. Must support Android API 21+ (Android 5.0 Lollipop)
4. Must use Kotlin 1.9.22 or higher
5. Must follow Android best practices for Activity lifecycle
6. Must handle permissions properly (location, notifications)
7. Must be memory efficient and avoid leaks

## Success Criteria

- ✅ All navigation modes work correctly (driving, walking, cycling)
- ✅ Simulation mode provides smooth, realistic navigation experience
- ✅ Real navigation tracks GPS accurately and handles off-route scenarios
- ✅ All navigation events are sent to Flutter layer correctly
- ✅ Voice and banner instructions work properly
- ✅ Camera tracking follows user smoothly during navigation
- ✅ Navigation can be started, paused, and stopped cleanly
- ✅ No memory leaks or crashes during extended navigation sessions
- ✅ Feature parity with iOS implementation achieved

## References

- [Mapbox Navigation Android SDK v3 Documentation](https://docs.mapbox.com/android/navigation/guides/)
- [Turn-by-Turn Navigation Example](https://docs.mapbox.com/android/navigation/examples/turn-by-turn-experience/)
- [iOS NavigationFactory Implementation](ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/NavigationFactory.swift)
- [Current Android TurnByTurn Implementation](android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/TurnByTurn.kt)

---

**Created**: 2026-01-05
**Status**: Draft - Awaiting Review
