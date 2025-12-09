[![Pub][pub_badge]][pub] [![BuyMeACoffee][buy_me_a_coffee_badge]][buy_me_a_coffee]

# flutter_mapbox_navigation

A comprehensive Flutter plugin for Mapbox Navigation SDK that brings professional-grade navigation capabilities to your Flutter applications. Build immersive navigation experiences with advanced features including turn-by-turn guidance, route selection, integrated search, navigation history recording and replay, automatic route cover generation with speed gradients, and real-time traffic updates.

## Features

### Core Navigation
* **Full-fledged turn-by-turn navigation UI** - Production-ready navigation interface that drops seamlessly into your Flutter app
* **[Professional map styles](https://www.mapbox.com/maps/)** - Beautifully designed maps for daytime and nighttime driving
* **Multi-modal routing** - Worldwide driving, cycling, and walking directions powered by [open data](https://www.mapbox.com/about/open/)
* **Smart traffic handling** - Traffic avoidance and proactive rerouting in [over 55 countries](https://docs.mapbox.com/help/how-mapbox-works/directions/#traffic-data)
* **Natural voice guidance** - Turn instructions powered by [Amazon Polly](https://aws.amazon.com/polly/) (no configuration needed)
* **Global language support** - [20+ languages](https://docs.mapbox.com/ios/navigation/overview/localization-and-internationalization/) for international audiences

### Advanced Features
* **📍 Navigation History Recording** - Automatically record complete navigation sessions with route data, timestamps, and metadata
* **🎬 History Replay** - Replay past navigation sessions with animated trajectory visualization and speed-based color gradients
* **🖼️ Automatic Cover Generation** - Generate beautiful route cover images from navigation history using Mapbox's static map API
* **🔄 Smart Path Resolution** - Intelligent file path handling for iOS sandbox changes
* **📊 Detailed Analytics** - Track distance, duration, start/end points, and navigation modes
* **🚀 Route Selection** - Choose from multiple route options before starting navigation
* **🔍 Integrated Search** - Powerful place search and geocoding capabilities powered by Mapbox Search API
* **🌈 Speed Gradient Visualization** - Color-coded trajectory lines based on speed during history replay
* **🎛️ Simulation Controls** - Easy-to-use simulation mode toggle for development and testing
* **🎨 Map Style Picker** - Interactive UI for selecting map styles with automatic persistence and Light Preset support
* **🌓 Light Preset Control** - Dynamic time-of-day lighting (dawn, day, dusk, night) for supported map styles
* **🔄 Automatic Light Adjustment** - Optional automatic light preset switching based on time of day

## IOS Configuration

1. Go to your [Mapbox account dashboard](https://account.mapbox.com/) and create an access token that has the `DOWNLOADS:READ` scope. **PLEASE NOTE: This is not the same as your production Mapbox API token. Make sure to keep it private and do not insert it into any Info.plist file.** Create a file named `.netrc` in your home directory if it doesn’t already exist, then add the following lines to the end of the file:
   ```
   machine api.mapbox.com
     login mapbox
     password PRIVATE_MAPBOX_API_TOKEN
   ```
   where _PRIVATE_MAPBOX_API_TOKEN_ is your Mapbox API token with the `DOWNLOADS:READ` scope.
   
1. Mapbox APIs and vector tiles require a Mapbox account and API access token. In the project editor, select the application target, then go to the Info tab. Under the “Custom iOS Target Properties” section, set `MBXAccessToken` to your access token. You can obtain an access token from the [Mapbox account page](https://account.mapbox.com/access-tokens/).

1. In order for the SDK to track the user’s location as they move along the route, set `NSLocationWhenInUseUsageDescription` to:
   > Shows your location on the map and helps improve OpenStreetMap.

1. Users expect the SDK to continue to track the user’s location and deliver audible instructions even while a different application is visible or the device is locked. Go to the Capabilities tab. Under the Background Modes section, enable “Audio, AirPlay, and Picture in Picture” and “Location updates”. (Alternatively, add the `audio` and `location` values to the `UIBackgroundModes` array in the Info tab.)


## Android Configuration

1. Mapbox APIs and vector tiles require a Mapbox account and API access token. Add a new resource file called `mapbox_access_token.xml` with it's full path being `<YOUR_FLUTTER_APP_ROOT>/android/app/src/main/res/values/mapbox_access_token.xml`. Then add a string resource with name "mapbox_access_token" and your token as it's value as shown below. You can obtain an access token from the [Mapbox account page](https://account.mapbox.com/access-tokens/).
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools">
    <string name="mapbox_access_token" translatable="false" tools:ignore="UnusedResources">ADD_MAPBOX_ACCESS_TOKEN_HERE</string>
</resources>
```

2. Add the following permissions to the app level Android Manifest
```xml
<manifest>
    ...
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    ...
</manifest>
```

3. Add the MapBox Downloads token with the ```downloads:read``` scope to your gradle.properties file in Android folder to enable downloading the MapBox binaries from the repository. To secure this token from getting checked into source control, you can add it to the gradle.properties of your GRADLE_HOME which is usually at $USER_HOME/.gradle for Mac. This token can be retrieved from your [MapBox Dashboard](https://account.mapbox.com/access-tokens/). You can review the [Token Guide](https://docs.mapbox.com/accounts/guides/tokens/) to learn more about download tokens
```text
MAPBOX_DOWNLOADS_TOKEN=sk.XXXXXXXXXXXXXXX
```

After adding the above, your gradle.properties file may look something like this:
```text
org.gradle.jvmargs=-Xmx1536M
android.useAndroidX=true
android.enableJetifier=true
MAPBOX_DOWNLOADS_TOKEN=sk.epe9nE9peAcmwNzKVNqSbFfp2794YtnNepe9nE9peAcmwNzKVNqSbFfp2794YtnN.-HrbMMQmLdHwYb8r
```

4. Update `MainActivity.kt` to extends `FlutterFragmentActivity` vs `FlutterActivity`. Otherwise you'll get `Caused by: java.lang.IllegalStateException: Please ensure that the hosting Context is a valid ViewModelStoreOwner`.
```kotlin
//import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
}
```

5. Add `implementation platform("org.jetbrains.kotlin:kotlin-bom:1.8.0")` to `android/app/build.gradle`

## Usage

#### Set Default Route Options (Optional)
```dart
    MapBoxNavigation.instance.setDefaultOptions(MapBoxOptions(
                     initialLatitude: 36.1175275,
                     initialLongitude: -115.1839524,
                     zoom: 13.0,
                     tilt: 0.0,
                     bearing: 0.0,
                     enableRefresh: false,
                     alternatives: true,
                     voiceInstructionsEnabled: true,
                     bannerInstructionsEnabled: true,
                     allowsUTurnAtWayPoints: true,
                     mode: MapBoxNavigationMode.drivingWithTraffic,
                     mapStyleUrlDay: "https://url_to_day_style",
                     mapStyleUrlNight: "https://url_to_night_style",
                     units: VoiceUnits.imperial,
                     simulateRoute: true,
                     language: "en"))
```

#### Listen for Events

```dart
  MapBoxNavigation.instance.registerRouteEventListener(_onRouteEvent);
  Future<void> _onRouteEvent(e) async {

        _distanceRemaining = await _directions.distanceRemaining;
        _durationRemaining = await _directions.durationRemaining;
    
        switch (e.eventType) {
          case MapBoxEvent.progress_change:
            var progressEvent = e.data as RouteProgressEvent;
            _arrived = progressEvent.arrived;
            if (progressEvent.currentStepInstruction != null)
              _instruction = progressEvent.currentStepInstruction;
            break;
          case MapBoxEvent.route_building:
          case MapBoxEvent.route_built:
            _routeBuilt = true;
            break;
          case MapBoxEvent.route_build_failed:
            _routeBuilt = false;
            break;
          case MapBoxEvent.navigation_running:
            _isNavigating = true;
            break;
          case MapBoxEvent.on_arrival:
            _arrived = true;
            if (!_isMultipleStop) {
              await Future.delayed(Duration(seconds: 3));
              await _controller.finishNavigation();
            } else {}
            break;
          case MapBoxEvent.navigation_finished:
          case MapBoxEvent.navigation_cancelled:
            _routeBuilt = false;
            _isNavigating = false;
            break;
          default:
            break;
        }
        //refresh UI
        setState(() {});
      }
```

#### Begin Navigating

```dart

    final cityhall = WayPoint(name: "City Hall", latitude: 42.886448, longitude: -78.878372);
    final downtown = WayPoint(name: "Downtown Buffalo", latitude: 42.8866177, longitude: -78.8814924);

    var wayPoints = List<WayPoint>();
    wayPoints.add(cityHall);
    wayPoints.add(downtown);
    
    await MapBoxNavigation.instance.startNavigation(wayPoints: wayPoints);
```

#### Screenshots
![Navigation View](screenshots/screenshot1.png?raw=true "iOS View") | ![Android View](screenshots/screenshot2.png?raw=true "Android View")
|:---:|:---:|
| iOS View | Android View |



## Embedding Navigation View


#### Declare Controller
```dart
      MapBoxNavigationViewController _controller;
```

#### Add Navigation View to Widget Tree
```dart
            Container(
                color: Colors.grey,
                child: MapBoxNavigationView(
                    options: _options,
                    onRouteEvent: _onRouteEvent,
                    onCreated:
                        (MapBoxNavigationViewController controller) async {
                      _controller = controller;
                    }),
              ),
```
#### Build Route

```dart
        var wayPoints = List<WayPoint>();
                            wayPoints.add(_origin);
                            wayPoints.add(_stop1);
                            wayPoints.add(_stop2);
                            wayPoints.add(_stop3);
                            wayPoints.add(_stop4);
                            wayPoints.add(_origin);
                            _controller.buildRoute(wayPoints: wayPoints);
```

#### Start Navigation

```dart
    _controller.startNavigation();
```

### Additional IOS Configuration
Add the following to your `info.plist` file

```xml
    <dict>
        ...
        <key>io.flutter.embedded_views_preview</key>
        <true/>
        ...
    </dict>
```

### Embedding Navigation Screenshots
![Navigation View](screenshots/screenshot3.png?raw=true "Embedded iOS View") | ![Navigation View](screenshots/screenshot4.png?raw=true "Embedded Android View")
|:---:|:---:|
| Embedded iOS View | Embedded Android View |

## Advanced Usage

### Navigation History Management

The plugin automatically records navigation sessions and provides APIs to manage and replay them.

#### Get Navigation History List

```dart
// Get all navigation history records
List<NavigationHistory> historyList = await MapBoxNavigation.instance.getNavigationHistoryList();

for (var history in historyList) {
  print('ID: ${history.id}');
  print('Start Time: ${history.startTime}');
  print('End Time: ${history.endTime}');
  print('Distance: ${history.distance} meters');
  print('Duration: ${history.duration} seconds');
  print('Start Point: ${history.startPointName}');
  print('End Point: ${history.endPointName}');
  print('Cover Image: ${history.cover}');
  print('History File: ${history.historyFilePath}');
}
```

#### Replay Navigation History

```dart
// Replay a navigation session with UI
await MapBoxNavigation.instance.startHistoryReplay(
  historyFilePath: history.historyFilePath,
  enableReplayUI: true, // Show replay UI with speed gradient visualization
);

// Replay without UI (programmatic only)
await MapBoxNavigation.instance.startHistoryReplay(
  historyFilePath: history.historyFilePath,
  enableReplayUI: false,
);
```

#### Generate History Cover Image

```dart
// Manually generate a cover image for a history record
String? coverPath = await MapBoxNavigation.instance.generateHistoryCover(
  historyFilePath: history.historyFilePath,
  historyId: history.id,
);

if (coverPath != null) {
  print('Cover generated at: $coverPath');
}
```

#### Delete Navigation History

```dart
// Delete a specific history record
bool success = await MapBoxNavigation.instance.deleteNavigationHistory(historyId);

// Clear all history records
bool cleared = await MapBoxNavigation.instance.clearAllNavigationHistory();
```

### Integrated Search

The plugin provides comprehensive search capabilities powered by Mapbox Search API.

#### Show Search View (Full UI)

```dart
// Open the full search UI with autocomplete
List<Map<String, dynamic>>? wayPoints = await MapboxSearch.showSearchView();

if (wayPoints != null && wayPoints.length >= 2) {
  // wayPoints contains origin and destination
  var origin = WayPoint(
    name: wayPoints[0]['name'],
    latitude: wayPoints[0]['latitude'],
    longitude: wayPoints[0]['longitude'],
  );
  
  var destination = WayPoint(
    name: wayPoints[1]['name'],
    latitude: wayPoints[1]['latitude'],
    longitude: wayPoints[1]['longitude'],
  );
  
  await MapBoxNavigation.instance.startNavigation(
    wayPoints: [origin, destination],
  );
}
```

#### Search Places

```dart
// Search for places with options
var results = await MapboxSearch.searchPlaces(
  MapboxSearchOptions(
    query: 'coffee shop',
    proximity: MapboxCoordinate(latitude: 37.7749, longitude: -122.4194),
    limit: 10,
    categories: [MapboxSearchCategories.cafe],
  ),
);

for (var result in results) {
  print('${result.name} - ${result.address}');
  print('Distance: ${result.distance} meters');
}
```

#### Search Nearby Points of Interest

```dart
// Search for nearby POIs
var nearbyResults = await MapboxSearch.searchPointsOfInterest(
  coordinate: MapboxCoordinate(latitude: 37.7749, longitude: -122.4194),
  radius: 1000.0, // 1km radius
  categories: [MapboxSearchCategories.restaurant, MapboxSearchCategories.cafe],
  limit: 20,
);
```

#### Get Search Suggestions (Autocomplete)

```dart
// Get search suggestions as user types
var suggestions = await MapboxSearch.getSearchSuggestions(
  query: 'star',
  proximity: MapboxCoordinate(latitude: 37.7749, longitude: -122.4194),
  limit: 5,
);

for (var suggestion in suggestions) {
  print('${suggestion.name} - ${suggestion.address}');
}
```

#### Reverse Geocoding

```dart
// Get address from coordinates
var results = await MapboxSearch.reverseGeocode(
  MapboxCoordinate(latitude: 37.7749, longitude: -122.4194),
);

if (results.isNotEmpty) {
  print('Address: ${results.first.address}');
}
```

#### Search by Category

```dart
// Search for specific category
var restaurants = await MapboxSearch.searchByCategory(
  query: 'italian',
  category: MapboxSearchCategories.restaurant,
  proximity: MapboxCoordinate(latitude: 37.7749, longitude: -122.4194),
  limit: 10,
);
```

#### Search in Bounding Box

```dart
// Search within a specific area
var results = await MapboxSearch.searchInBoundingBox(
  query: 'hotel',
  boundingBox: MapboxBoundingBox(
    southwest: MapboxCoordinate(latitude: 37.7, longitude: -122.5),
    northeast: MapboxCoordinate(latitude: 37.8, longitude: -122.4),
  ),
  limit: 15,
);
```

#### Available Search Categories

```dart
// Common categories available in MapboxSearchCategories:
MapboxSearchCategories.restaurant
MapboxSearchCategories.hotel
MapboxSearchCategories.gasStation
MapboxSearchCategories.hospital
MapboxSearchCategories.pharmacy
MapboxSearchCategories.bank
MapboxSearchCategories.atm
MapboxSearchCategories.school
MapboxSearchCategories.university
MapboxSearchCategories.shopping
MapboxSearchCategories.supermarket
MapboxSearchCategories.parking
MapboxSearchCategories.airport
MapboxSearchCategories.trainStation
MapboxSearchCategories.busStation
MapboxSearchCategories.museum
MapboxSearchCategories.park
MapboxSearchCategories.gym
MapboxSearchCategories.cinema
MapboxSearchCategories.cafe
```

### Map Style Picker

The plugin provides an interactive UI for selecting map styles with automatic persistence.

#### Show Style Picker

```dart
// Open the style picker UI
// User selections are automatically saved and applied to all future navigation
bool saved = await MapboxStylePicker.show();

if (saved) {
  print('Style saved! All future navigation will use the selected style.');
}

// Start navigation - automatically uses the saved style
await MapBoxNavigation.instance.startNavigation(
  wayPoints: wayPoints,
  // No need to pass style parameters - automatically applied
);
```

#### Get Current Style Settings

```dart
// Retrieve the currently saved style configuration
Map<String, dynamic> settings = await MapboxStylePicker.getStoredStyle();

print('Map Style: ${settings['mapStyle']}'); // e.g., 'standard', 'dark', 'outdoors'
print('Light Preset: ${settings['lightPreset']}'); // e.g., 'day', 'night', 'dawn', 'dusk'
print('Light Mode: ${settings['lightPresetMode']}'); // 'manual' or 'automatic'
```

#### Clear Saved Style

```dart
// Reset to default style (standard + day)
bool cleared = await MapboxStylePicker.clearStoredStyle();
```

#### Available Map Styles

The following map styles are available:

- **Standard** - Default Mapbox style (supports Light Preset)
- **Standard Satellite** - Satellite imagery with labels (supports Light Preset)
- **Faded** - Subtle, faded theme (supports Light Preset)
- **Monochrome** - Single-color theme (supports Light Preset)
- **Light** - Light theme
- **Dark** - Dark theme
- **Outdoors** - Optimized for outdoor activities

#### Light Preset Options

For styles that support Light Preset (Standard, Standard Satellite, Faded, Monochrome):

- **Dawn** - Early morning lighting
- **Day** - Daytime lighting (default)
- **Dusk** - Evening lighting
- **Night** - Nighttime lighting

#### Automatic Light Adjustment

When enabled, the Light Preset automatically adjusts based on the time of day:
- Dawn: 5:00 AM - 7:00 AM
- Day: 7:00 AM - 6:00 PM
- Dusk: 6:00 PM - 8:00 PM
- Night: 8:00 PM - 5:00 AM

### Free Drive Mode

Start navigation without a destination for passive navigation.

```dart
// Start free drive mode
await MapBoxNavigation.instance.startFreeDrive(
  options: MapBoxOptions(
    mode: MapBoxNavigationMode.drivingWithTraffic,
    simulateRoute: false,
  ),
);
```

### Add Waypoints During Navigation

```dart
// Add additional stops during active navigation
await MapBoxNavigation.instance.addWayPoints(
  wayPoints: [
    WayPoint(name: "Gas Station", latitude: 42.888, longitude: -78.880),
    WayPoint(name: "Restaurant", latitude: 42.890, longitude: -78.882),
  ],
);
```

### Get Navigation Metrics

```dart
// Get remaining distance in meters
double? distance = await MapBoxNavigation.instance.getDistanceRemaining();

// Get remaining duration in seconds
double? duration = await MapBoxNavigation.instance.getDurationRemaining();
```

## To Do
* [DONE] Android Implementation
* [DONE] Add more settings like Navigation Mode (driving, walking, etc)
* [DONE] Stream Events like relevant navigation notifications, metrics, current location, etc. 
* [DONE] Embeddable Navigation View
* [DONE] Navigation History Recording and Replay
* [DONE] Integrated Search with Mapbox Search API
* [DONE] Map Style Picker with Light Preset Support
* Offline Routing

<!-- Links -->
[pub_badge]: https://img.shields.io/pub/v/flutter_mapbox_navigation.svg
[pub]: https://pub.dev/packages/flutter_mapbox_navigation
[buy_me_a_coffee]: https://www.buymeacoffee.com/eopeter
[buy_me_a_coffee_badge]: https://img.buymeacoffee.com/button-api/?text=Donate&emoji=&slug=eopeter&button_colour=29b6f6&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=FFDD00