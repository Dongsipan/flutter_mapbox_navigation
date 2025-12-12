import 'package:flutter/services.dart';
import 'package:flutter_mapbox_navigation/src/flutter_mapbox_navigation_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final platform = MethodChannelFlutterMapboxNavigation();
  const channel = MethodChannel('flutter_mapbox_navigation');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '42';
    });
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  group('getNavigationHistoryEvents', () {
    test('should throw ArgumentError when historyId is empty', () async {
      expect(
        () => platform.getNavigationHistoryEvents(''),
        throwsArgumentError,
      );
    });

    test('should call method channel with correct parameters', () async {
      String? calledMethod;
      Map<dynamic, dynamic>? calledArguments;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        calledMethod = methodCall.method;
        calledArguments = methodCall.arguments as Map<dynamic, dynamic>?;

        // Return mock data
        return {
          'historyId': 'test-id',
          'events': [],
          'rawLocations': [],
          'initialRoute': null,
        };
      });

      await platform.getNavigationHistoryEvents('test-id');

      expect(calledMethod, 'getNavigationHistoryEvents');
      expect(calledArguments?['historyId'], 'test-id');
    });

    test('should parse response correctly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return <String, dynamic>{
          'historyId': 'test-id',
          'events': <Map<String, dynamic>>[
            <String, dynamic>{
              'eventType': 'location_update',
              'data': <String, dynamic>{
                'latitude': 37.7749,
                'longitude': -122.4194,
                'altitude': 10.0,
                'horizontalAccuracy': 5.0,
                'verticalAccuracy': 3.0,
                'speed': 15.0,
                'course': 90.0,
                'timestamp': 1234567890.0,
              },
            },
          ],
          'rawLocations': <Map<String, dynamic>>[
            <String, dynamic>{
              'latitude': 37.7749,
              'longitude': -122.4194,
              'altitude': 10.0,
              'horizontalAccuracy': 5.0,
              'verticalAccuracy': 3.0,
              'speed': 15.0,
              'course': 90.0,
              'timestamp': 1234567890.0,
            },
          ],
          'initialRoute': null,
        };
      });

      final result = await platform.getNavigationHistoryEvents('test-id');

      expect(result.historyId, 'test-id');
      expect(result.events.length, 1);
      expect(result.rawLocations.length, 1);
      expect(result.events[0].eventType, 'location_update');
    });

    test('should throw exception when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return null;
      });

      expect(
        () => platform.getNavigationHistoryEvents('test-id'),
        throwsException,
      );
    });

    test('should handle PlatformException correctly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'HISTORY_NOT_FOUND',
          message: 'History record not found',
        );
      });

      expect(
        () => platform.getNavigationHistoryEvents('test-id'),
        throwsException,
      );
    });
  });
}
