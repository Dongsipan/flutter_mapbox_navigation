# Flutter Mapbox Navigation - API Documentation

## Table of Contents

- [Navigation History Events API](#navigation-history-events-api)
  - [Overview](#overview)
  - [Data Models](#data-models)
  - [API Methods](#api-methods)
  - [Usage Examples](#usage-examples)
  - [Error Handling](#error-handling)
  - [Platform Support](#platform-support)

## Navigation History Events API

### Overview

The Navigation History Events API provides detailed access to navigation session data recorded by the Mapbox Navigation SDK. This API allows you to retrieve comprehensive event information including location updates, route assignments, and custom user events from past navigation sessions.

**Key Features:**
- Extract all events from a navigation history session
- Access detailed location data with timestamps
- Retrieve route assignment information
- Parse custom user-pushed events
- Get raw location trajectory for visualization
- Cross-platform support (iOS and Android)

### Data Models

#### NavigationHistoryEvents

The main container for all history event data.

```dart
class NavigationHistoryEvents {
  final String historyId;                    // Unique identifier for the history record
  final List<HistoryEventData> events;       // List of all events in chronological order
  final List<LocationData> rawLocations;     // Raw location trajectory points
  final Map<String, dynamic>? initialRoute;  // Initial route information (optional)
}
```

#### HistoryEventData

Represents a single event in the navigation history.

```dart
class HistoryEventData {
  final String eventType;  // Type of event: 'location_update', 'route_assignment', 'user_pushed', 'unknown'
  final dynamic data;      // Event-specific data (type varies by eventType)
}
```

**Event Types:**

| Event Type | Description | Data Type |
|------------|-------------|-----------|
| `location_update` | GPS location update during navigation | `LocationData` |
| `route_assignment` | Route was assigned or changed | `Map<String, dynamic>` |
| `user_pushed` | Custom event pushed by the application | `Map<String, dynamic>` |
| `unknown` | Unrecognized event type | `Map<String, dynamic>` |

#### LocationData

Detailed location information from GPS updates.

```dart
class LocationData {
  final double latitude;              // Latitude in degrees (-90 to 90)
  final double longitude;             // Longitude in degrees (-180 to 180)
  final double? altitude;             // Altitude in meters (optional)
  final double? horizontalAccuracy;   // Horizontal accuracy in meters (optional)
  final double? verticalAccuracy;     // Vertical accuracy in meters (optional)
  final double? speed;                // Speed in meters per second (optional)
  final double? course;               // Direction of travel in degrees (0-360) (optional)
  final DateTime timestamp;           // Time when location was recorded
}
```

### API Methods

#### getNavigationHistoryEvents

Retrieves detailed event data for a specific navigation history record.

**Signature:**
```dart
Future<NavigationHistoryEvents> getNavigationHistoryEvents({
  required String historyId,
})
```

**Parameters:**
- `historyId` (required): The unique identifier of the navigation history record

**Returns:**
- `NavigationHistoryEvents`: Event data containing all events, raw locations, and initial route

**Throws:**
- `PlatformException` with code:
  - `HISTORY_NOT_FOUND`: History record with the given ID doesn't exist
  - `FILE_NOT_FOUND`: History file is missing or inaccessible
  - `PARSE_ERROR`: Failed to parse the history file
  - `READER_CREATION_FAILED`: Failed to create history reader
  - `SERIALIZATION_ERROR`: Failed to serialize event data

**Example:**
```dart
try {
  final events = await MapBoxNavigation.instance.getNavigationHistoryEvents(
    historyId: 'abc123',
  );
  
  print('Found ${events.events.length} events');
} catch (e) {
  print('Error loading history events: $e');
}
```

### Usage Examples

#### Basic Usage - Get All Events

```dart
// Get the history list first
List<NavigationHistory> historyList = 
    await MapBoxNavigation.instance.getNavigationHistoryList();

if (historyList.isNotEmpty) {
  // Get events for the first history record
  try {
    NavigationHistoryEvents events = 
        await MapBoxNavigation.instance.getNavigationHistoryEvents(
      historyId: historyList.first.id,
    );
    
    print('History ID: ${events.historyId}');
    print('Total Events: ${events.events.length}');
    print('Raw Locations: ${events.rawLocations.length}');
  } catch (e) {
    print('Error: $e');
  }
}
```

#### Processing Location Updates

```dart
try {
  NavigationHistoryEvents events = 
      await MapBoxNavigation.instance.getNavigationHistoryEvents(
    historyId: historyId,
  );
  
  // Filter and process location update events
  for (var event in events.events) {
    if (event.eventType == 'location_update') {
      LocationData location = event.data as LocationData;
      
      print('Location: ${location.latitude}, ${location.longitude}');
      print('Speed: ${location.speed ?? 0} m/s');
      print('Accuracy: ${location.horizontalAccuracy ?? 0} meters');
      print('Time: ${location.timestamp}');
      
      // Use location data for visualization, analysis, etc.
    }
  }
} catch (e) {
  print('Error: $e');
}
```

#### Analyzing Route Information

```dart
try {
  NavigationHistoryEvents events = 
      await MapBoxNavigation.instance.getNavigationHistoryEvents(
    historyId: historyId,
  );
  
  // Check for route assignment events
  for (var event in events.events) {
    if (event.eventType == 'route_assignment') {
      Map<String, dynamic> routeData = event.data as Map<String, dynamic>;
      
      print('Route Distance: ${routeData['distance']} meters');
      print('Route Duration: ${routeData['duration']} seconds');
      
      // Access route geometry if available
      if (routeData.containsKey('geometry')) {
        print('Route Geometry: ${routeData['geometry']}');
      }
    }
  }
  
  // Access initial route information
  if (events.initialRoute != null) {
    print('Initial Route Distance: ${events.initialRoute!['distance']}');
    print('Initial Route Duration: ${events.initialRoute!['duration']}');
  }
} catch (e) {
  print('Error: $e');
}
```

#### Processing Custom Events

```dart
try {
  NavigationHistoryEvents events = 
      await MapBoxNavigation.instance.getNavigationHistoryEvents(
    historyId: historyId,
  );
  
  // Process user-pushed custom events
  for (var event in events.events) {
    if (event.eventType == 'user_pushed') {
      Map<String, dynamic> customData = event.data as Map<String, dynamic>;
      
      // Access custom properties
      print('Custom Event Type: ${customData['type']}');
      print('Custom Properties: ${customData['properties']}');
      
      // Handle specific custom event types
      if (customData['type'] == 'speed_limit_exceeded') {
        print('Speed limit exceeded at: ${customData['properties']['timestamp']}');
      }
    }
  }
} catch (e) {
  print('Error: $e');
}
```

#### Visualizing Raw Location Trajectory

```dart
try {
  NavigationHistoryEvents events = 
      await MapBoxNavigation.instance.getNavigationHistoryEvents(
    historyId: historyId,
  );
  
  // Use raw locations for map visualization
  List<LatLng> trajectoryPoints = events.rawLocations.map((location) {
    return LatLng(location.latitude, location.longitude);
  }).toList();
  
  // Draw polyline on map
  Polyline trajectory = Polyline(
    polylineId: PolylineId('history_trajectory'),
    points: trajectoryPoints,
    color: Colors.blue,
    width: 5,
  );
  
  // Calculate speed-based colors
  List<Color> speedColors = events.rawLocations.map((location) {
    double speed = location.speed ?? 0;
    if (speed < 5) return Colors.red;      // Slow
    if (speed < 15) return Colors.yellow;  // Medium
    return Colors.green;                   // Fast
  }).toList();
} catch (e) {
  print('Error: $e');
}
```

#### Statistical Analysis

```dart
try {
  NavigationHistoryEvents events = 
      await MapBoxNavigation.instance.getNavigationHistoryEvents(
    historyId: historyId,
  );
  
  // Calculate statistics from location data
  List<double> speeds = [];
  double totalDistance = 0;
  
  for (int i = 0; i < events.rawLocations.length; i++) {
    LocationData location = events.rawLocations[i];
    
    if (location.speed != null) {
      speeds.add(location.speed!);
    }
    
    // Calculate distance between consecutive points
    if (i > 0) {
      LocationData prevLocation = events.rawLocations[i - 1];
      double distance = _calculateDistance(
        prevLocation.latitude, prevLocation.longitude,
        location.latitude, location.longitude,
      );
      totalDistance += distance;
    }
  }
  
  // Calculate average speed
  double avgSpeed = speeds.isEmpty ? 0 : 
      speeds.reduce((a, b) => a + b) / speeds.length;
  
  // Calculate max speed
  double maxSpeed = speeds.isEmpty ? 0 : speeds.reduce((a, b) => a > b ? a : b);
  
  print('Total Distance: ${totalDistance.toStringAsFixed(2)} meters');
  print('Average Speed: ${avgSpeed.toStringAsFixed(2)} m/s');
  print('Max Speed: ${maxSpeed.toStringAsFixed(2)} m/s');
  print('Duration: ${events.rawLocations.last.timestamp.difference(
      events.rawLocations.first.timestamp).inSeconds} seconds');
} catch (e) {
  print('Error: $e');
}

// Helper function to calculate distance between two coordinates
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371000; // meters
  double dLat = _toRadians(lat2 - lat1);
  double dLon = _toRadians(lon2 - lon1);
  
  double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _toRadians(double degrees) => degrees * pi / 180;
```

#### Complete Example - History Event Viewer

```dart
import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

class HistoryEventViewer extends StatefulWidget {
  final String historyId;
  
  const HistoryEventViewer({required this.historyId, Key? key}) : super(key: key);
  
  @override
  State<HistoryEventViewer> createState() => _HistoryEventViewerState();
}

class _HistoryEventViewerState extends State<HistoryEventViewer> {
  NavigationHistoryEvents? _events;
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadEvents();
  }
  
  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final events = await MapBoxNavigation.instance.getNavigationHistoryEvents(
        historyId: widget.historyId,
      );
      
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Error: $_errorMessage'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvents,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_events == null) {
      return Center(child: Text('No events found'));
    }
    
    return ListView(
      children: [
        // Summary Card
        Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('History Summary', 
                    style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 8),
                Text('Total Events: ${_events!.events.length}'),
                Text('Location Points: ${_events!.rawLocations.length}'),
                if (_events!.initialRoute != null)
                  Text('Initial Route Distance: ${_events!.initialRoute!['distance']} m'),
              ],
            ),
          ),
        ),
        
        // Events List
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Events', style: Theme.of(context).textTheme.titleMedium),
        ),
        ..._events!.events.map((event) => _buildEventCard(event)).toList(),
      ],
    );
  }
  
  Widget _buildEventCard(HistoryEventData event) {
    IconData icon;
    Color color;
    String title;
    String subtitle;
    
    switch (event.eventType) {
      case 'location_update':
        icon = Icons.location_on;
        color = Colors.blue;
        title = 'Location Update';
        final location = event.data as LocationData;
        subtitle = '${location.latitude.toStringAsFixed(4)}, '
                  '${location.longitude.toStringAsFixed(4)}';
        break;
      case 'route_assignment':
        icon = Icons.route;
        color = Colors.green;
        title = 'Route Assignment';
        subtitle = 'Route assigned';
        break;
      case 'user_pushed':
        icon = Icons.push_pin;
        color = Colors.orange;
        title = 'Custom Event';
        subtitle = 'User-pushed event';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        title = 'Unknown Event';
        subtitle = event.eventType;
    }
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
```

### Error Handling

The API uses standard Flutter `PlatformException` for error reporting. Always wrap API calls in try-catch blocks:

```dart
try {
  final events = await MapBoxNavigation.instance.getNavigationHistoryEvents(
    historyId: historyId,
  );
  // Process events
} on PlatformException catch (e) {
  switch (e.code) {
    case 'HISTORY_NOT_FOUND':
      print('History record not found');
      break;
    case 'FILE_NOT_FOUND':
      print('History file is missing');
      break;
    case 'PARSE_ERROR':
      print('Failed to parse history file: ${e.message}');
      break;
    case 'READER_CREATION_FAILED':
      print('Failed to create history reader');
      break;
    case 'SERIALIZATION_ERROR':
      print('Failed to serialize event data');
      break;
    default:
      print('Unknown error: ${e.code} - ${e.message}');
  }
} catch (e) {
  print('Unexpected error: $e');
}
```

### Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| iOS | ✅ Supported | Requires Mapbox Navigation SDK v2.0+ |
| Android | ✅ Supported | Requires Mapbox Navigation SDK v2.0+ |
| Web | ❌ Not Supported | History recording not available on web |
| macOS | ❌ Not Supported | Not implemented |
| Windows | ❌ Not Supported | Not implemented |
| Linux | ❌ Not Supported | Not implemented |

### Performance Considerations

- **Large Files**: History files with 1000+ events are parsed in under 5 seconds
- **Background Processing**: Parsing is performed on background threads to avoid blocking the UI
- **Memory Usage**: Raw location data is loaded into memory; consider pagination for very large histories
- **Caching**: Consider caching parsed events if you need to access them multiple times

### Best Practices

1. **Check for null**: Always check if the returned `NavigationHistoryEvents` is null
2. **Error handling**: Wrap API calls in try-catch blocks
3. **Type checking**: Use `is` operator to check event data types before casting
4. **Memory management**: Process events in batches for large histories
5. **UI updates**: Use `setState` or state management to update UI with event data
6. **Validation**: Validate location coordinates before using them for visualization

### Related APIs

- `getNavigationHistoryList()` - Get list of all navigation history records
- `startHistoryReplay()` - Replay a navigation session
- `generateHistoryCover()` - Generate cover image for history
- `deleteNavigationHistory()` - Delete a history record
- `clearAllNavigationHistory()` - Clear all history records
