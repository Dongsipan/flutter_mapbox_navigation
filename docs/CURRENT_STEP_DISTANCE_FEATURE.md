# Current Step Distance Remaining Feature

## Overview
Added `currentStepDistanceRemaining` field to `RouteProgressEvent` to provide the remaining distance from the user's current position to the end of the current step.

## Implementation

### iOS Side

**File:** `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/models/RouteProgressEvent.swift`

Added new property:
```swift
let currentStepDistanceRemaining: Double
```

Populated from RouteProgress:
```swift
// Get current step distance remaining from currentStepProgress
currentStepDistanceRemaining = progress.currentLegProgress.currentStepProgress.distanceRemaining
```

**Data Path:**
```
RouteProgress 
  → currentLegProgress 
    → currentStepProgress 
      → distanceRemaining
```

### Flutter Side

**File:** `lib/src/models/route_progress_event.dart`

Added new property:
```dart
double? currentStepDistanceRemaining;
```

JSON parsing:
```dart
currentStepDistanceRemaining =
    isNullOrZero(json['currentStepDistanceRemaining'] as num?)
        ? 0.0
        : (json['currentStepDistanceRemaining'] as num).toDouble();
```

## Usage

### Accessing Current Step Distance

```dart
// Listen to route progress events
MapBoxNavigation.instance.registerRouteEventListener((RouteEvent event) {
  if (event.eventType == MapBoxEvent.progress_change) {
    final progress = event.data as RouteProgressEvent;
    
    // Get current step distance remaining (in meters)
    final stepDistance = progress.currentStepDistanceRemaining;
    
    print('Current step distance remaining: ${stepDistance?.toStringAsFixed(1)} m');
    
    // Example: Show warning when approaching end of step
    if (stepDistance != null && stepDistance < 50) {
      print('Approaching end of current step!');
    }
  }
});
```

### Example JSON Response

```json
{
  "arrived": false,
  "distance": 2463.3588,
  "duration": 537.404,
  "distanceTraveled": 112.6682,
  "currentLegDistanceTraveled": 112.6682,
  "currentLegDistanceRemaining": 2463.3588,
  "currentStepInstruction": "Turn left onto Scott Street",
  "currentStepDistanceRemaining": 315.835,
  "legIndex": 0,
  "stepIndex": 1,
  "currentLeg": {
    "name": "Sanchez Street, 17th Street",
    "distance": 2576.027,
    "expectedTravelTime": 557.567,
    "steps": 9
  }
}
```

## Distance Hierarchy

Understanding the different distance values:

1. **`distance`** (Route level)
   - Total remaining distance for the entire route
   - From current position to final destination

2. **`currentLegDistanceRemaining`** (Leg level)
   - Remaining distance for the current leg
   - From current position to end of current leg (waypoint)

3. **`currentStepDistanceRemaining`** (Step level) ⭐ NEW
   - Remaining distance for the current step
   - From current position to end of current step (maneuver)
   - Most granular distance information

## Use Cases

1. **Precise Turn Warnings**
   - Alert users when they're close to the next maneuver
   - "In 50 meters, turn left"

2. **Step-by-Step Progress**
   - Show progress within each navigation instruction
   - Progress bar for current maneuver

3. **Voice Guidance Timing**
   - Trigger voice instructions at specific distances
   - "In 100 meters, turn right"

4. **UI Updates**
   - Update instruction cards based on step distance
   - Change visual emphasis as user approaches maneuver

## Platform Support

- ✅ **iOS**: Implemented via `RouteStepProgress.distanceRemaining`
- ✅ **Android**: Implemented via `RouteStepProgress.distanceRemaining`

## Related Documentation

- [iOS RouteProgress Documentation](https://docs.mapbox.com/ios/navigation/api/3.0.0/Classes/RouteProgress.html)
- [iOS RouteStepProgress Documentation](https://docs.mapbox.com/ios/navigation/api/3.0.0/Classes/RouteStepProgress.html)
- [Android RouteProgress Documentation](https://docs.mapbox.com/android/navigation/api/3.0.0/)

## Testing

To test the new field:

1. Start a navigation session
2. Listen to progress events
3. Verify `currentStepDistanceRemaining` is populated
4. Verify the value decreases as you move along the step
5. Verify it resets when moving to the next step

## Android Implementation

### File: `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/models/MapBoxRouteProgressEvent.kt`

Added new property:
```kotlin
private var currentStepDistanceRemaining: Float? = null
```

Populated from RouteProgress:
```kotlin
// Get current step distance remaining from currentStepProgress
currentStepDistanceRemaining = progress.currentLegProgress?.currentStepProgress?.distanceRemaining
```

Added to JSON serialization:
```kotlin
addProperty(json, "currentStepDistanceRemaining", currentStepDistanceRemaining)
```

**Data Path:**
```
RouteProgress 
  → currentLegProgress 
    → currentStepProgress 
      → distanceRemaining
```

## Status

✅ **iOS Implementation Complete**
✅ **Android Implementation Complete**
✅ **Flutter Model Updated**
✅ **Documentation Updated**
