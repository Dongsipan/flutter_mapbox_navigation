import 'dart:math';

import 'package:flutter_mapbox_navigation/src/models/history_event_data.dart';
import 'package:flutter_mapbox_navigation/src/models/location_data.dart';
import 'package:flutter_mapbox_navigation/src/models/navigation_history_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigationHistoryEvents Data Models', () {
    group('LocationData', () {
      test('should create LocationData with valid coordinates', () {
        final location = LocationData(
          latitude: 39.9042,
          longitude: 116.4074,
          altitude: 50.0,
          horizontalAccuracy: 5.0,
          verticalAccuracy: 3.0,
          speed: 10.5,
          course: 180.0,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );

        expect(location.latitude, equals(39.9042));
        expect(location.longitude, equals(116.4074));
        expect(location.altitude, equals(50.0));
      });

      test('should throw error for invalid latitude', () {
        expect(
          () => LocationData(
            latitude: 91.0, // Invalid
            longitude: 116.4074,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
          throwsArgumentError,
        );
      });

      test('should throw error for invalid longitude', () {
        expect(
          () => LocationData(
            latitude: 39.9042,
            longitude: 181.0, // Invalid
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
          throwsArgumentError,
        );
      });

      test('should parse LocationData from Map', () {
        final map = {
          'latitude': 39.9042,
          'longitude': 116.4074,
          'altitude': 50.0,
          'horizontalAccuracy': 5.0,
          'verticalAccuracy': 3.0,
          'speed': 10.5,
          'course': 180.0,
          'timestamp': 1234567890,
        };

        final location = LocationData.fromMap(map);

        expect(location.latitude, equals(39.9042));
        expect(location.longitude, equals(116.4074));
        expect(location.altitude, equals(50.0));
        expect(location.timestamp, equals(1234567890));
      });
    });

    group('HistoryEventData', () {
      test('should create HistoryEventData', () {
        final event = HistoryEventData(
          eventType: 'locationUpdate',
          data: {'latitude': 39.9042, 'longitude': 116.4074},
        );

        expect(event.eventType, equals('locationUpdate'));
        expect(event.data['latitude'], equals(39.9042));
      });

      test('should parse HistoryEventData from Map', () {
        final map = {
          'eventType': 'routeAssignment',
          'data': {'distance': 1000.0, 'duration': 300},
        };

        final event = HistoryEventData.fromMap(map);

        expect(event.eventType, equals('routeAssignment'));
        expect(event.data['distance'], equals(1000.0));
      });
    });

    group('NavigationHistoryEvents', () {
      test('should create NavigationHistoryEvents', () {
        final events = NavigationHistoryEvents(
          historyId: 'test-123',
          events: [],
          rawLocations: [],
        );

        expect(events.historyId, equals('test-123'));
        expect(events.events, isEmpty);
        expect(events.rawLocations, isEmpty);
      });

      test('should parse NavigationHistoryEvents from Map', () {
        final map = {
          'historyId': 'test-456',
          'events': [
            {
              'eventType': 'locationUpdate',
              'data': {'latitude': 39.9042, 'longitude': 116.4074},
            },
          ],
          'rawLocations': [
            {
              'latitude': 39.9042,
              'longitude': 116.4074,
              'timestamp': 1234567890,
            },
          ],
          'initialRoute': {'distance': 5000.0},
        };

        final historyEvents = NavigationHistoryEvents.fromMap(map);

        expect(historyEvents.historyId, equals('test-456'));
        expect(historyEvents.events.length, equals(1));
        expect(historyEvents.rawLocations.length, equals(1));
        expect(historyEvents.initialRoute?['distance'], equals(5000.0));
      });
    });

    group('Property Tests', () {
      // **Feature: history-events-api, Property 6: JSON 序列化往返一致性**
      // **Validates: Requirements 2.1, 2.6**
      test(
          'Property 6: LocationData JSON round-trip consistency - for any LocationData, serializing to JSON and deserializing should produce equivalent data',
          () {
        final random = Random(42); // Fixed seed for reproducibility

        // Run 100 iterations as specified in the design document
        for (var i = 0; i < 100; i++) {
          // Generate random valid LocationData
          final originalLocation = LocationData(
            latitude: (random.nextDouble() * 180) - 90, // -90 to 90
            longitude: (random.nextDouble() * 360) - 180, // -180 to 180
            altitude: random.nextBool() ? random.nextDouble() * 1000 : null,
            horizontalAccuracy:
                random.nextBool() ? random.nextDouble() * 100 : null,
            verticalAccuracy:
                random.nextBool() ? random.nextDouble() * 100 : null,
            speed: random.nextBool() ? random.nextDouble() * 50 : null,
            course: random.nextBool() ? random.nextDouble() * 360 : null,
            timestamp:
                DateTime.now().millisecondsSinceEpoch + random.nextInt(1000000),
          );

          // Serialize to Map
          final map = originalLocation.toMap();

          // Deserialize from Map
          final deserializedLocation = LocationData.fromMap(map);

          // Verify equivalence
          expect(
              deserializedLocation.latitude, equals(originalLocation.latitude));
          expect(deserializedLocation.longitude,
              equals(originalLocation.longitude));
          expect(
              deserializedLocation.altitude, equals(originalLocation.altitude));
          expect(
            deserializedLocation.horizontalAccuracy,
            equals(originalLocation.horizontalAccuracy),
          );
          expect(
            deserializedLocation.verticalAccuracy,
            equals(originalLocation.verticalAccuracy),
          );
          expect(deserializedLocation.speed, equals(originalLocation.speed));
          expect(deserializedLocation.course, equals(originalLocation.course));
          expect(deserializedLocation.timestamp,
              equals(originalLocation.timestamp));
        }
      });

      test(
          'Property 6: HistoryEventData JSON round-trip consistency - for any HistoryEventData, serializing to JSON and deserializing should produce equivalent data',
          () {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          // Generate random event types
          final eventTypes = [
            'locationUpdate',
            'routeAssignment',
            'userPushed',
            'unknown',
          ];
          final eventType = eventTypes[random.nextInt(eventTypes.length)];

          // Generate random data
          final data = <String, dynamic>{
            'field1': random.nextDouble(),
            'field2': random.nextInt(1000),
            'field3': 'test_${random.nextInt(100)}',
          };

          final originalEvent = HistoryEventData(
            eventType: eventType,
            data: data,
          );

          // Serialize to Map
          final map = originalEvent.toMap();

          // Deserialize from Map
          final deserializedEvent = HistoryEventData.fromMap(map);

          // Verify equivalence
          expect(deserializedEvent.eventType, equals(originalEvent.eventType));
          expect(deserializedEvent.data['field1'],
              equals(originalEvent.data['field1']));
          expect(deserializedEvent.data['field2'],
              equals(originalEvent.data['field2']));
          expect(deserializedEvent.data['field3'],
              equals(originalEvent.data['field3']));
        }
      });

      test(
          'Property 6: NavigationHistoryEvents JSON round-trip consistency - for any NavigationHistoryEvents, serializing to JSON and deserializing should produce equivalent data',
          () {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          // Generate random number of events and locations
          final numEvents = random.nextInt(10) + 1;
          final numLocations = random.nextInt(20) + 2; // At least 2 locations

          final events = List.generate(
            numEvents,
            (index) => HistoryEventData(
              eventType: 'locationUpdate',
              data: {'index': index, 'value': random.nextDouble()},
            ),
          );

          final rawLocations = List.generate(
            numLocations,
            (index) => LocationData(
              latitude: (random.nextDouble() * 180) - 90,
              longitude: (random.nextDouble() * 360) - 180,
              timestamp: DateTime.now().millisecondsSinceEpoch + index * 1000,
            ),
          );

          final initialRoute = random.nextBool()
              ? <String, dynamic>{
                  'distance': random.nextDouble() * 10000,
                  'duration': random.nextInt(3600),
                }
              : null;

          final originalHistoryEvents = NavigationHistoryEvents(
            historyId: 'test-${random.nextInt(10000)}',
            events: events,
            rawLocations: rawLocations,
            initialRoute: initialRoute,
          );

          // Serialize to Map
          final map = originalHistoryEvents.toMap();

          // Deserialize from Map
          final deserializedHistoryEvents =
              NavigationHistoryEvents.fromMap(map);

          // Verify equivalence
          expect(
            deserializedHistoryEvents.historyId,
            equals(originalHistoryEvents.historyId),
          );
          expect(
            deserializedHistoryEvents.events.length,
            equals(originalHistoryEvents.events.length),
          );
          expect(
            deserializedHistoryEvents.rawLocations.length,
            equals(originalHistoryEvents.rawLocations.length),
          );

          // Verify events
          for (var j = 0; j < numEvents; j++) {
            expect(
              deserializedHistoryEvents.events[j].eventType,
              equals(originalHistoryEvents.events[j].eventType),
            );
            expect(
              deserializedHistoryEvents.events[j].data['index'],
              equals(originalHistoryEvents.events[j].data['index']),
            );
          }

          // Verify locations
          for (var j = 0; j < numLocations; j++) {
            expect(
              deserializedHistoryEvents.rawLocations[j].latitude,
              equals(originalHistoryEvents.rawLocations[j].latitude),
            );
            expect(
              deserializedHistoryEvents.rawLocations[j].longitude,
              equals(originalHistoryEvents.rawLocations[j].longitude),
            );
          }

          // Verify initialRoute
          if (initialRoute != null) {
            expect(
              deserializedHistoryEvents.initialRoute?['distance'],
              equals(originalHistoryEvents.initialRoute?['distance']),
            );
          }
        }
      });
    });

    group('Property 4 & 5: Event Type Handling', () {
      // **Feature: history-events-api, Property 4: 自定义事件 JSON 解析**
      // **Validates: Requirements 1.4, 2.4**
      test(
          'Property 4: Custom event JSON parsing - for any UserPushedHistoryEvent, its properties string should be successfully parsed as valid JSON',
          () {
        final random = Random(42);

        // Run 100 iterations as specified in the design document
        for (var i = 0; i < 100; i++) {
          // Generate random valid JSON properties
          final properties = <String, dynamic>{
            'property_0': 'value_${random.nextInt(1000)}',
            'property_1': random.nextDouble() * 1000,
            'property_2': random.nextBool(),
          };

          // Create a user pushed event with properties
          final eventData = {
            'eventType': 'userPushed',
            'data': {
              'type': 'test_event',
              'properties': properties,
            },
          };

          // Parse the event
          final event = HistoryEventData.fromMap(eventData);

          // Verify the event structure
          expect(event.eventType, equals('userPushed'),
              reason: 'Iteration $i: eventType should be userPushed');

          // Verify the data contains type and properties
          expect(event.data['type'], equals('test_event'),
              reason: 'Iteration $i: type should match');

          // Verify properties were parsed correctly
          final parsedProperties =
              event.data['properties'] as Map<String, dynamic>;
          expect(parsedProperties, isNotNull,
              reason: 'Iteration $i: properties should be present');
          expect(parsedProperties.length, equals(properties.length),
              reason: 'Iteration $i: properties count should match');

          // Verify each property
          expect(
              parsedProperties['property_0'], equals(properties['property_0']),
              reason: 'Iteration $i: property_0 should match');
          expect(
              parsedProperties['property_1'], equals(properties['property_1']),
              reason: 'Iteration $i: property_1 should match');
          expect(
              parsedProperties['property_2'], equals(properties['property_2']),
              reason: 'Iteration $i: property_2 should match');
        }
      });

      // **Feature: history-events-api, Property 5: 事件类型标识**
      // **Validates: Requirements 1.6**
      test(
          'Property 5: Event type identification - for any returned event, the JSON data should contain an eventType field with a valid event type identifier',
          () {
        final random = Random(42);

        // Valid event types
        final validEventTypes = [
          'locationUpdate',
          'routeAssignment',
          'userPushed',
          'unknown',
        ];

        // Run 100 iterations as specified in the design document
        for (var i = 0; i < 100; i++) {
          // Test each event type
          for (final expectedType in validEventTypes) {
            // Create event data based on type
            Map<String, dynamic> eventData;

            switch (expectedType) {
              case 'locationUpdate':
                eventData = {
                  'eventType': expectedType,
                  'data': {
                    'latitude': (random.nextDouble() * 180) - 90,
                    'longitude': (random.nextDouble() * 360) - 180,
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                  },
                };
                break;
              case 'routeAssignment':
                eventData = {
                  'eventType': expectedType,
                  'data': {
                    'distance': random.nextDouble() * 10000,
                    'duration': random.nextInt(3600),
                  },
                };
                break;
              case 'userPushed':
                eventData = {
                  'eventType': expectedType,
                  'data': {
                    'type': 'test_event',
                    'properties': {'key': 'value'},
                  },
                };
                break;
              case 'unknown':
                eventData = {
                  'eventType': expectedType,
                  'data': {
                    'type': 'UnknownEventType',
                  },
                };
                break;
              default:
                throw Exception('Unexpected event type: $expectedType');
            }

            // Parse the event
            final event = HistoryEventData.fromMap(eventData);

            // Verify eventType field exists
            expect(event.eventType, isNotNull,
                reason:
                    'Iteration $i, type $expectedType: eventType field should be present');

            // Verify eventType is valid
            expect(validEventTypes.contains(event.eventType), isTrue,
                reason:
                    'Iteration $i, type $expectedType: eventType should be one of the valid types');

            // Verify eventType matches expected
            expect(event.eventType, equals(expectedType),
                reason: 'Iteration $i: eventType should be $expectedType');

            // Verify data field exists
            expect(event.data, isNotNull,
                reason:
                    'Iteration $i, type $expectedType: data field should be present');

            // Verify data is a Map
            expect(event.data, isA<Map<String, dynamic>>(),
                reason:
                    'Iteration $i, type $expectedType: data should be a Map');
          }
        }
      });
    });
  });
}
