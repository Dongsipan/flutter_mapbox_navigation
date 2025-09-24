import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

void main() {
  group('MapboxSearch', () {
    const MethodChannel channel = MethodChannel('flutter_mapbox_navigation/search');

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('showSearchView should handle valid waypoint data', () async {
      // Mock the platform method call
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'showSearchView') {
          // Return mock waypoint data in the format that iOS returns
          return [
            {
              'name': '当前位置',
              'latitude': 39.9042,
              'longitude': 116.4074,
              'isSilent': false,
              'address': '北京市东城区'
            },
            {
              'name': '天安门',
              'latitude': 39.9163,
              'longitude': 116.3972,
              'isSilent': false,
              'address': '北京市东城区天安门广场'
            }
          ];
        }
        return null;
      });

      // Call the method
      final result = await MapboxSearch.showSearchView();

      // Verify the result
      expect(result, isNotNull);
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result!.length, equals(2));
      
      // Check first waypoint (origin)
      expect(result[0]['name'], equals('当前位置'));
      expect(result[0]['latitude'], equals(39.9042));
      expect(result[0]['longitude'], equals(116.4074));
      
      // Check second waypoint (destination)
      expect(result[1]['name'], equals('天安门'));
      expect(result[1]['latitude'], equals(39.9163));
      expect(result[1]['longitude'], equals(116.3972));
    });

    test('showSearchView should handle null result', () async {
      // Mock the platform method call to return null
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'showSearchView') {
          return null;
        }
        return null;
      });

      // Call the method
      final result = await MapboxSearch.showSearchView();

      // Verify the result
      expect(result, isNull);
    });

    test('showSearchView should handle empty list', () async {
      // Mock the platform method call to return empty list
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'showSearchView') {
          return [];
        }
        return null;
      });

      // Call the method
      final result = await MapboxSearch.showSearchView();

      // Verify the result
      expect(result, isNull);
    });

    test('showSearchView should handle platform exception', () async {
      // Mock the platform method call to throw an exception
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'showSearchView') {
          throw PlatformException(
            code: 'SEARCH_ERROR',
            message: 'Search failed',
            details: null,
          );
        }
        return null;
      });

      // Call the method and expect an exception
      expect(
        () async => await MapboxSearch.showSearchView(),
        throwsA(isA<MapboxSearchException>()),
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });
}
