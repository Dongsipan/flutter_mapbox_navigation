// ignore_for_file: public_member_api_docs

import 'package:flutter_mapbox_navigation/src/helpers.dart';
import 'package:flutter_mapbox_navigation/src/models/route_leg.dart';

/// 导航进行中任意时刻的进度信息（Route / Leg / Step）。每次位置更新都会生成最新的进度数据。
///
/// 示例（单位：distance 距离=米 m，duration 时长=秒 s）：
///
/// ```json
/// {
///   "arrived": false,
///   "distance": 2463.3588,
///   "duration": 537.404,
///   "distanceTraveled": 112.6682,
///   "currentLegDistanceTraveled": 112.6682,
///   "currentLegDistanceRemaining": 2463.3588,
///   "currentStepInstruction": "Links auf Scott Street abbiegen.",
///   "legIndex": 0,
///   "stepIndex": 1,
///   "currentLeg": {
///     "name": "Sanchez Street, 17th Street",
///     "distance": 2576.027,
///     "expectedTravelTime": 557.567,
///     "steps": 9
///   },
///   "priorLegExists": false,
///   "remainingLegsCount": 0,
///   "currentVisualInstruction": {
///     "text": "Haight Street",
///     "secondaryText": null,
///     "maneuverType": "turn",
///     "maneuverDirection": "left",
///     "distanceAlongStep": 315.835
///   }
/// }
/// ```
///
/// 说明：
/// - 距离单位为米（m），时长单位为秒（s）。
/// - `currentVisualInstruction` 对应 iOS v3 的 `RouteStepProgress.currentVisualInstruction`，
///   其中包含主指令文本（text）、机动类型（maneuverType）、方向（maneuverDirection）以及步内剩余距离（distanceAlongStep）。
/// - 参考文档：
///   - RouteStepProgress.currentVisualInstruction
///   - VisualInstructionBanner.primaryInstruction（text / maneuverType / maneuverDirection）
class RouteProgressEvent {
  RouteProgressEvent({
    this.arrived,
    this.distance,
    this.duration,
    this.distanceTraveled,
    this.currentLegDistanceTraveled,
    this.currentLegDistanceRemaining,
    this.currentStepInstruction,
    this.currentLeg,
    this.priorLeg,
    this.remainingLegs,
    this.legIndex,
    this.stepIndex,
    this.isProgressEvent,
    this.currentVisualInstruction,
  });

  RouteProgressEvent.fromJson(Map<String, dynamic> json) {
    isProgressEvent = json['arrived'] != null;
    arrived = json['arrived'] == null ? false : json['arrived'] as bool?;
    distance = isNullOrZero(json['distance'] as num?)
        ? 0.0
        : (json['distance'] as num).toDouble();
    duration = isNullOrZero(json['duration'] as num?)
        ? 0.0
        : (json['duration'] as num).toDouble();
    distanceTraveled = isNullOrZero(json['distanceTraveled'] as num?)
        ? 0.0
        : (json['distanceTraveled'] as num).toDouble();
    currentLegDistanceTraveled =
        isNullOrZero(json['currentLegDistanceTraveled'] as num?)
            ? 0.0
            : (json['currentLegDistanceTraveled'] as num).toDouble();
    currentLegDistanceRemaining =
        isNullOrZero(json['currentLegDistanceRemaining'] as num?)
            ? 0.0
            : (json['currentLegDistanceRemaining'] as num).toDouble();
    currentStepInstruction = json['currentStepInstruction'] as String?;
    currentLeg = json['currentLeg'] == null
        ? null
        : RouteLeg.fromJson(json['currentLeg'] as Map<String, dynamic>);
    priorLeg = json['priorLeg'] == null
        ? null
        : RouteLeg.fromJson(json['priorLeg'] as Map<String, dynamic>);
    remainingLegs = (json['remainingLegs'] as List?)
        ?.map(
          (e) =>
              e == null ? null : RouteLeg.fromJson(e as Map<String, dynamic>),
        )
        .cast<RouteLeg>()
        .toList();
    legIndex = json['legIndex'] as int?;
    stepIndex = json['stepIndex'] as int?;
    // v3 current visual instruction (subset)
    final vis = json['currentVisualInstruction'] as Map<String, dynamic>?;
    if (vis != null) {
      currentVisualInstruction = VisualInstructionBanner.fromJson(vis);
    }
  }

  bool? arrived;
  double? distance;
  double? duration;
  double? distanceTraveled;
  double? currentLegDistanceTraveled;
  double? currentLegDistanceRemaining;
  String? currentStepInstruction;
  RouteLeg? currentLeg;
  RouteLeg? priorLeg;
  List<RouteLeg>? remainingLegs;
  int? legIndex;
  int? stepIndex;
  bool? isProgressEvent;
  VisualInstructionBanner? currentVisualInstruction;
}

class VisualInstructionBanner {
  VisualInstructionBanner({
    this.text,
    this.secondaryText,
    this.maneuverType,
    this.maneuverDirection,
    this.distanceAlongStep,
  });

  VisualInstructionBanner.fromJson(Map<String, dynamic> json)
      : text = json['text'] as String?,
        secondaryText = json['secondaryText'] as String?,
        maneuverType = json['maneuverType'] as String?,
        maneuverDirection = json['maneuverDirection'] as String?,
        distanceAlongStep = (json['distanceAlongStep'] as num?)?.toDouble();

  final String? text;
  final String? secondaryText;
  final String? maneuverType;
  final String? maneuverDirection;
  final double? distanceAlongStep;
}
