import Foundation
import MapboxDirections
import MapboxNavigationUIKit
import MapboxNavigationCore

public class MapBoxRouteProgressEvent : Codable
{
    let arrived: Bool
    let distance: Double
    let duration: Double
    let distanceTraveled: Double
    let currentLegDistanceTraveled: Double
    let currentLegDistanceRemaining: Double
    let currentStepInstruction: String
    let legIndex: Int
    let stepIndex: Int
    let currentLeg: MapBoxRouteLeg
    var priorLeg: MapBoxRouteLeg? = nil
    var remainingLegs: [MapBoxRouteLeg] = []
    // Added current visual instruction info (subset for Flutter)
    var currentVisualInstruction: MapBoxVisualInstructionBanner? = nil

    init(progress: RouteProgress) {

        arrived = progress.isFinalLeg && progress.currentLegProgress.userHasArrivedAtWaypoint
        distance = progress.distanceRemaining
        distanceTraveled = progress.distanceTraveled
        duration = progress.durationRemaining
        legIndex = progress.legIndex
        stepIndex = progress.currentLegProgress.stepIndex

        currentLeg = MapBoxRouteLeg(leg: progress.currentLeg)

        if(progress.priorLeg != nil)
        {
            priorLeg = MapBoxRouteLeg(leg: progress.priorLeg!)
        }

        for leg in progress.remainingLegs
        {
            remainingLegs.append(MapBoxRouteLeg(leg: leg))
        }

        currentLegDistanceTraveled = progress.currentLegProgress.distanceTraveled
        currentLegDistanceRemaining = progress.currentLegProgress.distanceRemaining
        currentStepInstruction = progress.currentLegProgress.currentStep.description

        // Map current visual instruction (v3)
        if let banner = progress.currentLegProgress.currentStepProgress.currentVisualInstruction {
            let primaryText = banner.primaryInstruction.text
            let secondaryText = banner.secondaryInstruction?.text
            let maneuverType = banner.primaryInstruction.maneuverType?.rawValue
            let maneuverDirection = banner.primaryInstruction.maneuverDirection?.rawValue
            let distanceAlongStep = banner.distanceAlongStep
            currentVisualInstruction = MapBoxVisualInstructionBanner(
                text: primaryText,
                secondaryText: secondaryText,
                maneuverType: maneuverType,
                maneuverDirection: maneuverDirection,
                distanceAlongStep: distanceAlongStep
            )
        }
    }


}

public struct MapBoxVisualInstructionBanner: Codable {
    let text: String?
    let secondaryText: String?
    let maneuverType: String?
    let maneuverDirection: String?
    let distanceAlongStep: Double?
}
