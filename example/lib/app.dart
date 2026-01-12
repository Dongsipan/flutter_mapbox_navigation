import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

class SampleNavigationApp extends StatefulWidget {
  const SampleNavigationApp({super.key});

  @override
  State<SampleNavigationApp> createState() => _SampleNavigationAppState();
}

class _SampleNavigationAppState extends State<SampleNavigationApp> {
  String? _platformVersion;
  String? _instruction;
  final _origin = WayPoint(
      name: "Way Point 1",
      latitude: 38.9111117447887,
      longitude: -77.04012393951416,
      isSilent: true);
  final _stop1 = WayPoint(
      name: "Way Point 2",
      latitude: 38.91113678979344,
      longitude: -77.03847169876099,
      isSilent: true);
  final _stop2 = WayPoint(
      name: "Way Point 3",
      latitude: 38.91040213277608,
      longitude: -77.03848242759705,
      isSilent: false);
  final _stop3 = WayPoint(
      name: "Way Point 4",
      latitude: 38.909650771013034,
      longitude: -77.03850388526917,
      isSilent: true);
  final _destination = WayPoint(
      name: "Way Point 5",
      latitude: 38.90894949285854,
      longitude: -77.03651905059814,
      isSilent: false);

  final _home = WayPoint(
      name: "Home",
      latitude: 37.77440680146262,
      longitude: -122.43539772352648,
      isSilent: false);

  final _store = WayPoint(
      name: "Store",
      latitude: 37.76556957793795,
      longitude: -122.42409811526268,
      isSilent: false);

  bool _isMultipleStop = false;
  double? _distanceRemaining, _durationRemaining;
  MapBoxNavigationViewController? _controller;
  bool _routeBuilt = false;
  bool _isNavigating = false;
  bool _inFreeDrive = false;
  late MapBoxOptions _navigationOption;
  bool _enableHistoryRecording = false; // 历史记录开关

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initialize() async {
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    _navigationOption = MapBoxNavigation.instance.getDefaultOptions();
    _navigationOption.simulateRoute = true;
    _navigationOption.language = "en";
    //_navigationOption.initialLatitude = 36.1175275;
    //_navigationOption.initialLongitude = -115.1839524;
    MapBoxNavigation.instance.registerRouteEventListener(_onEmbeddedRouteEvent);

    // Standalone logging listener (prints all navigation events)
    await MapBoxNavigation.instance.registerRouteEventListener((RouteEvent e) {
      final ts = DateTime.now().toIso8601String();
      debugPrint('[$ts] [RouteEvent] type=${e.eventType} raw=${e.data}');

      if (e.eventType == MapBoxEvent.progress_change) {
        final p = e.data as RouteProgressEvent;
        // 基础进度
        debugPrint('[$ts] [Progress] arrived=${p.arrived}');
        debugPrint('[$ts] [Progress] distance=${p.distance}m, duration=${p.duration}s');
        debugPrint('[$ts] [Progress] distanceTraveled=${p.distanceTraveled}m');
        debugPrint('[$ts] [Progress] legDistanceTraveled=${p.currentLegDistanceTraveled}m, legDistanceRemaining=${p.currentLegDistanceRemaining}m');
        debugPrint('[$ts] [Progress] legIndex=${p.legIndex}, stepIndex=${p.stepIndex}');
        debugPrint('[$ts] [Progress] instruction=${p.currentStepInstruction}');

        // 当前 Leg 概览
        final leg = p.currentLeg;
        if (leg != null) {
          debugPrint('[$ts] [Leg] name=${leg.name}, distance=${leg.distance}m, eta=${leg.expectedTravelTime}s');
          debugPrint('[$ts] [Leg] steps=${leg.steps?.length ?? 0}');
          if ((leg.steps?.isNotEmpty ?? false)) {
            final s0 = leg.steps!.first;
            debugPrint('[$ts] [Leg.step0] name=${s0.name}, distance=${s0.distance}m, eta=${s0.expectedTravelTime}s');
            debugPrint('[$ts] [Leg.step0] instructions=${s0.instructions}');
          }
        }

        // 其他 Leg 信息
        debugPrint('[$ts] [Leg.prior] exists=${p.priorLeg != null}');
        debugPrint('[$ts] [Leg.remaining] count=${p.remainingLegs?.length ?? 0}');

        // currentVisualInstruction 详细日志
        final v = p.currentVisualInstruction;
        if (v != null) {
          debugPrint('[$ts] [VIS] text=${v.text}');
          debugPrint('[$ts] [VIS] secondary=${v.secondaryText}');
          debugPrint('[$ts] [VIS] type=${v.maneuverType}, dir=${v.maneuverDirection}');
          debugPrint('[$ts] [VIS] distanceAlongStep=${v.distanceAlongStep}');
        } else {
          debugPrint('[$ts] [VIS] null');
        }

        // 以字符串(JSON)形式输出 RouteProgressEvent（摘要字段）
        final progressJson = jsonEncode({
          'arrived': p.arrived,
          'distance': p.distance,
          'duration': p.duration,
          'distanceTraveled': p.distanceTraveled,
          'currentLegDistanceTraveled': p.currentLegDistanceTraveled,
          'currentLegDistanceRemaining': p.currentLegDistanceRemaining,
          'currentStepInstruction': p.currentStepInstruction,
          'legIndex': p.legIndex,
          'stepIndex': p.stepIndex,
          'currentLeg': p.currentLeg == null
              ? null
              : {
                  'name': p.currentLeg!.name,
                  'distance': p.currentLeg!.distance,
                  'expectedTravelTime': p.currentLeg!.expectedTravelTime,
                  'steps': p.currentLeg!.steps?.length,
                },
          'priorLegExists': p.priorLeg != null,
          'remainingLegsCount': p.remainingLegs?.length ?? 0,
          'currentVisualInstruction': p.currentVisualInstruction == null
              ? null
              : {
                  'text': p.currentVisualInstruction!.text,
                  'secondaryText': p.currentVisualInstruction!.secondaryText,
                  'maneuverType': p.currentVisualInstruction!.maneuverType,
                  'maneuverDirection': p.currentVisualInstruction!.maneuverDirection,
                  'distanceAlongStep': p.currentVisualInstruction!.distanceAlongStep,
                },
        });
        debugPrint('[$ts] [Progress.json] $progressJson');
      }
    });

    String? platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await MapBoxNavigation.instance.getPlatformVersion();
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(
                      height: 10,
                    ),
                    Text('Running on: $_platformVersion\n'),
                    Container(
                      color: Colors.grey,
                      width: double.infinity,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: (Text(
                          "Full Screen Navigation",
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        )),
                      ),
                    ),
                    // 历史记录开关
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '启用导航历史记录',
                            style: TextStyle(fontSize: 16),
                          ),
                          Switch(
                            value: _enableHistoryRecording,
                            onChanged: (value) {
                              setState(() {
                                _enableHistoryRecording = value;
                                _navigationOption.enableHistoryRecording =
                                    value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          child: const Text("Start A to B"),
                          onPressed: () async {
                            var wayPoints = <WayPoint>[];
                            wayPoints.add(_home);
                            wayPoints.add(_store);
                            var opt = MapBoxOptions.from(_navigationOption);
                            opt.simulateRoute = true;
                            opt.voiceInstructionsEnabled = true;
                            opt.bannerInstructionsEnabled = true;
                            opt.units = VoiceUnits.metric;
                            opt.language = "de-DE";
                            opt.enableHistoryRecording =
                                _enableHistoryRecording; // 使用历史记录设置
                            await MapBoxNavigation.instance.startNavigation(
                                wayPoints: wayPoints, options: opt);
                          },
                        ),
                        ElevatedButton(
                          child: const Text("Start Multi Stop"),
                          onPressed: () async {
                            _isMultipleStop = true;
                            var wayPoints = <WayPoint>[];
                            wayPoints.add(_origin);
                            wayPoints.add(_stop1);
                            wayPoints.add(_stop2);
                            wayPoints.add(_stop3);
                            wayPoints.add(_destination);

                            MapBoxNavigation.instance.startNavigation(
                                wayPoints: wayPoints,
                                options: MapBoxOptions(
                                    mode: MapBoxNavigationMode.driving,
                                    simulateRoute: true,
                                    language: "en",
                                    allowsUTurnAtWayPoints: true,
                                    units: VoiceUnits.metric,
                                    enableHistoryRecording:
                                        _enableHistoryRecording)); // 使用历史记录设置
                            //after 10 seconds add a new stop
                            await Future.delayed(const Duration(seconds: 10));
                            var stop = WayPoint(
                                name: "Gas Station",
                                latitude: 38.911176544398,
                                longitude: -77.04014366543564,
                                isSilent: false);
                            MapBoxNavigation.instance
                                .addWayPoints(wayPoints: [stop]);
                          },
                        ),
                        ElevatedButton(
                          child: const Text("Free Drive"),
                          onPressed: () async {
                            await MapBoxNavigation.instance.startFreeDrive();
                          },
                        ),
                      ],
                    ),
                    Container(
                      color: Colors.grey,
                      width: double.infinity,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: (Text(
                          "Embedded Navigation",
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        )),
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _isNavigating
                              ? null
                              : () {
                                  if (_routeBuilt) {
                                    _controller?.clearRoute();
                                  } else {
                                    var wayPoints = <WayPoint>[];
                                    wayPoints.add(_home);
                                    wayPoints.add(_store);
                                    _isMultipleStop = wayPoints.length > 2;
                                    _controller?.buildRoute(
                                        wayPoints: wayPoints,
                                        options: _navigationOption);
                                  }
                                },
                          child: Text(_routeBuilt && !_isNavigating
                              ? "Clear Route"
                              : "Build Route"),
                        ),
                        ElevatedButton(
                          onPressed: _routeBuilt && !_isNavigating
                              ? () {
                                  _controller?.startNavigation();
                                }
                              : null,
                          child: const Text('Start '),
                        ),
                        ElevatedButton(
                          onPressed: _isNavigating
                              ? () {
                                  _controller?.finishNavigation();
                                }
                              : null,
                          child: const Text('Cancel '),
                        )
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _inFreeDrive
                          ? null
                          : () async {
                              _inFreeDrive =
                                  await _controller?.startFreeDrive() ?? false;
                            },
                      child: const Text("Free Drive "),
                    ),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          "Long-Press Embedded Map to Set Destination",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.grey,
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: (Text(
                          _instruction == null
                              ? "Banner Instruction Here"
                              : _instruction!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        )),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 20.0, right: 20, top: 20, bottom: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Text("Duration Remaining: "),
                              Text(_durationRemaining != null
                                  ? "${(_durationRemaining! / 60).toStringAsFixed(0)} minutes"
                                  : "---")
                            ],
                          ),
                          Row(
                            children: <Widget>[
                              const Text("Distance Remaining: "),
                              Text(_distanceRemaining != null
                                  ? "${(_distanceRemaining! * 0.000621371).toStringAsFixed(1)} miles"
                                  : "---")
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider()
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 300,
              child: Container(
                color: Colors.grey,
                child: MapBoxNavigationView(
                    options: _navigationOption,
                    onRouteEvent: _onEmbeddedRouteEvent,
                    onCreated:
                        (MapBoxNavigationViewController controller) async {
                      _controller = controller;
                      controller.initialize();
                    }),
              ),
            )
          ]),
        ),
      ),
    );
  }

  Future<void> _onEmbeddedRouteEvent(e) async {
    _distanceRemaining = await MapBoxNavigation.instance.getDistanceRemaining();
    _durationRemaining = await MapBoxNavigation.instance.getDurationRemaining();

    switch (e.eventType) {
      case MapBoxEvent.progress_change:
        var progressEvent = e.data as RouteProgressEvent;
        if (progressEvent.currentStepInstruction != null) {
          _instruction = progressEvent.currentStepInstruction;
        }
        break;
      case MapBoxEvent.route_building:
      case MapBoxEvent.route_built:
        setState(() {
          _routeBuilt = true;
        });
        break;
      case MapBoxEvent.route_build_failed:
        setState(() {
          _routeBuilt = false;
        });
        break;
      case MapBoxEvent.navigation_running:
        setState(() {
          _isNavigating = true;
        });
        break;
      case MapBoxEvent.on_arrival:
        if (!_isMultipleStop) {
          await Future.delayed(const Duration(seconds: 3));
          await _controller?.finishNavigation();
        } else {}
        break;
      case MapBoxEvent.navigation_finished:
      case MapBoxEvent.navigation_cancelled:
        setState(() {
          _routeBuilt = false;
          _isNavigating = false;
        });
        break;
      default:
        break;
    }
    setState(() {});
  }
}
