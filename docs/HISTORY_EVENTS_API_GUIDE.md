# Navigation History Events API - Quick Start Guide

## What's New

The Navigation History Events API is a powerful new feature that allows you to access detailed event data from recorded navigation sessions. This enables advanced analytics, visualization, and debugging capabilities for your navigation application.

## Key Features

✅ **Detailed Event Access** - Get all events from a navigation session including location updates, route changes, and custom events

✅ **Raw Location Data** - Access the complete GPS trajectory for visualization and analysis

✅ **Event Types** - Support for location updates, route assignments, custom user events, and more

✅ **Cross-Platform** - Consistent API and data structures on both iOS and Android

✅ **Performance Optimized** - Background thread processing for large history files

✅ **Type-Safe** - Strongly typed Dart models for all event data

## Quick Start

### 1. Get Navigation History List

First, retrieve the list of available navigation history records:

```dart
List<NavigationHistory> historyList = 
    await MapBoxNavigation.instance.getNavigationHistoryList();
```

### 2. Get Detailed Events

Then, fetch detailed events for a specific history record:

```dart
try {
  NavigationHistoryEvents events = 
      await MapBoxNavigation.instance.getNavigationHistoryEvents(
    historyId: historyList.first.id,
  );
  
  // Events loaded successfully
} catch (e) {
  print('Error: $e');
}
```

### 3. Process Events

Access and process the event data:

```dart
try {
  NavigationHistoryEvents events = 
      await MapBoxNavigation.instance.getNavigationHistoryEvents(
    historyId: historyList.first.id,
  );
  
  // Get summary information
  print('Total Events: ${events.events.length}');
  print('Location Points: ${events.rawLocations.length}');
  
  // Process location updates
  for (var event in events.events) {
    if (event.eventType == 'location_update') {
      LocationData location = event.data as LocationData;
      print('${location.latitude}, ${location.longitude}');
    }
  }
} catch (e) {
  print('Error: $e');
}
```

## Common Use Cases

### 1. Trajectory Visualization

Draw the navigation path on a map:

```dart
List<LatLng> points = events.rawLocations.map((loc) {
  return LatLng(loc.latitude, loc.longitude);
}).toList();

// Use points to draw a polyline on your map
```

### 2. Speed Analysis

Calculate average and maximum speeds:

```dart
List<double> speeds = events.rawLocations
    .where((loc) => loc.speed != null)
    .map((loc) => loc.speed!)
    .toList();

double avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
double maxSpeed = speeds.reduce((a, b) => a > b ? a : b);
```

### 3. Route Statistics

Get detailed route information:

```dart
if (events.initialRoute != null) {
  double distance = events.initialRoute!['distance'];
  double duration = events.initialRoute!['duration'];
  print('Route: ${distance}m in ${duration}s');
}
```

### 4. Custom Event Processing

Handle application-specific events:

```dart
for (var event in events.events) {
  if (event.eventType == 'user_pushed') {
    Map<String, dynamic> customData = event.data;
    // Process your custom event data
  }
}
```

## Data Models

### NavigationHistoryEvents

Main container for all event data:

```dart
class NavigationHistoryEvents {
  final String historyId;
  final List<HistoryEventData> events;
  final List<LocationData> rawLocations;
  final Map<String, dynamic>? initialRoute;
}
```

### HistoryEventData

Individual event with type and data:

```dart
class HistoryEventData {
  final String eventType;  // 'location_update', 'route_assignment', etc.
  final dynamic data;      // Type varies by eventType
}
```

### LocationData

GPS location information:

```dart
class LocationData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? course;
  final DateTime timestamp;
  // ... more fields
}
```

## Event Types

| Type | Description | Data Type |
|------|-------------|-----------|
| `location_update` | GPS location update | `LocationData` |
| `route_assignment` | Route assigned/changed | `Map<String, dynamic>` |
| `user_pushed` | Custom user event | `Map<String, dynamic>` |
| `unknown` | Unrecognized event | `Map<String, dynamic>` |

## Error Handling

Always wrap API calls in try-catch:

```dart
try {
  final events = await MapBoxNavigation.instance.getNavigationHistoryEvents(
    historyId: historyId,
  );
} on PlatformException catch (e) {
  switch (e.code) {
    case 'HISTORY_NOT_FOUND':
      // Handle missing history
      break;
    case 'FILE_NOT_FOUND':
      // Handle missing file
      break;
    case 'PARSE_ERROR':
      // Handle parse error
      break;
  }
}
```

## Performance Tips

1. **Large Files**: Files with 1000+ events parse in under 5 seconds
2. **Background Processing**: Parsing happens on background threads
3. **Memory**: Consider pagination for very large histories
4. **Caching**: Cache parsed events if accessing multiple times

## Example Application

Check out the updated `history_test_page.dart` in the example app for a complete working implementation that demonstrates:

- Loading history events
- Displaying event details in a dialog
- Processing different event types
- Error handling
- UI integration

## Documentation

For complete API documentation with detailed examples, see:
- `API_DOCUMENTATION.md` - Comprehensive API reference
- `README.md` - Updated with History Events API section
- `CHANGELOG.md` - Version 0.2.5 release notes

## Migration Guide

If you're already using the navigation history features, no changes are required. The new API is additive and doesn't affect existing functionality.

To start using the new API:

1. Update to version 0.2.5 or later
2. Import the necessary models (already exported in the main package)
3. Call `getNavigationHistoryEvents()` with a history ID
4. Process the returned event data

## Support

For issues, questions, or feature requests:
- GitHub Issues: [flutter_mapbox_navigation](https://github.com/eopeter/flutter_mapbox_navigation/issues)
- Documentation: See `API_DOCUMENTATION.md` for detailed examples

## What's Next

Future enhancements planned:
- Event filtering and querying
- Streaming API for large files
- Additional event types
- Enhanced analytics helpers
- Export to common formats (GPX, KML)

---

**Happy Navigating! 🗺️**
