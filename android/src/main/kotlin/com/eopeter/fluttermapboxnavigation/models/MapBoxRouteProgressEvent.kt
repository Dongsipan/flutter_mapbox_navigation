package com.eopeter.fluttermapboxnavigation.models

import com.google.gson.Gson
import com.google.gson.JsonObject
import com.mapbox.navigation.base.trip.model.RouteProgress

class MapBoxRouteProgressEvent(progress: RouteProgress) {

    var arrived: Boolean? = null
    private var distance: Float? = null
    private var duration: Double? = null
    private var distanceTraveled: Float? = null
    private var currentLegDistanceTraveled: Float? = null
    private var currentLegDistanceRemaining: Float? = null
    private var currentStepInstruction: String? = null
    private var currentStepDistanceRemaining: Float? = null
    private var legIndex: Int? = null
    var stepIndex: Int? = null
    private var currentLeg: MapBoxRouteLeg? = null
    var priorLeg: MapBoxRouteLeg? = null
    lateinit var remainingLegs: List<MapBoxRouteLeg>
    private var currentVisualInstruction: Map<String, Any?>? = null

    init {
        android.util.Log.d("MapBoxRouteProgressEvent", "🔄 Creating RouteProgressEvent")
        
        // Determine if arrived (last leg and close to destination)
        val isLastLeg = progress.currentLegProgress?.legIndex == progress.navigationRoute.directionsRoute.legs()?.size?.minus(1)
        arrived = isLastLeg && progress.distanceRemaining < 50 // Within 50 meters of destination
        android.util.Log.d("MapBoxRouteProgressEvent", "   Arrived: $arrived (isLastLeg=$isLastLeg, distanceRemaining=${progress.distanceRemaining})")
        
        distance = progress.distanceRemaining
        duration = progress.durationRemaining
        distanceTraveled = progress.distanceTraveled
        legIndex = progress.currentLegProgress?.legIndex
        
        // Get step index from current step progress
        stepIndex = progress.currentLegProgress?.currentStepProgress?.stepIndex
        android.util.Log.d("MapBoxRouteProgressEvent", "   Leg Index: $legIndex, Step Index: $stepIndex")
        
        // Current leg
        val leg = progress.currentLegProgress?.routeLeg
        if (leg != null) {
            currentLeg = MapBoxRouteLeg(leg)
            android.util.Log.d("MapBoxRouteProgressEvent", "   Current Leg: ${leg.summary()}")
        }
        
        // Prior leg (if exists)
        val priorLegIndex = (progress.currentLegProgress?.legIndex ?: 0) - 1
        if (priorLegIndex >= 0) {
            progress.navigationRoute.directionsRoute.legs()?.getOrNull(priorLegIndex)?.let {
                priorLeg = MapBoxRouteLeg(it)
                android.util.Log.d("MapBoxRouteProgressEvent", "   Prior Leg exists: ${it.summary()}")
            }
        }
        
        // Remaining legs
        val currentLegIdx = progress.currentLegProgress?.legIndex ?: 0
        val allLegs = progress.navigationRoute.directionsRoute.legs() ?: emptyList()
        remainingLegs = allLegs.drop(currentLegIdx + 1).map { MapBoxRouteLeg(it) }
        android.util.Log.d("MapBoxRouteProgressEvent", "   Remaining Legs: ${remainingLegs.size}")
        
        // Current step instruction from banner instructions
        currentStepInstruction = progress.bannerInstructions?.primary()?.text()
        currentLegDistanceTraveled = progress.currentLegProgress?.distanceTraveled
        currentLegDistanceRemaining = progress.currentLegProgress?.distanceRemaining
        
        // Get current step distance remaining from currentStepProgress
        currentStepDistanceRemaining = progress.currentLegProgress?.currentStepProgress?.distanceRemaining
        
        // Extract current visual instruction (v3 SDK)
        progress.bannerInstructions?.let { banner ->
            val primary = banner.primary()
            currentVisualInstruction = mapOf(
                "text" to primary?.text(),
                "secondaryText" to banner.secondary()?.text(),
                "maneuverType" to primary?.type(),
                "maneuverDirection" to primary?.modifier(),
                "distanceAlongStep" to (currentStepDistanceRemaining?.toDouble() ?: 0.0)
            )
            android.util.Log.d("MapBoxRouteProgressEvent", "   Visual Instruction: ${primary?.text()} (${primary?.type()} ${primary?.modifier()})")
        }
        
        android.util.Log.d("MapBoxRouteProgressEvent", "✅ RouteProgressEvent created successfully")
    }

    fun toJson(): String {
        return Gson().toJson(toJsonObject())
    }

    private fun toJsonObject(): JsonObject {
        val json = JsonObject()
        addProperty(json, "arrived", arrived)
        addProperty(json, "distance", distance)
        addProperty(json, "duration", duration)
        addProperty(json, "distanceTraveled", distanceTraveled)
        addProperty(json, "legIndex", legIndex)
        addProperty(json, "stepIndex", stepIndex)
        addProperty(json, "currentLegDistanceRemaining", currentLegDistanceRemaining)
        addProperty(json, "currentLegDistanceTraveled", currentLegDistanceTraveled)
        addProperty(json, "currentStepInstruction", currentStepInstruction)
        addProperty(json, "currentStepDistanceRemaining", currentStepDistanceRemaining)

        if (currentLeg != null) {
            json.add("currentLeg", currentLeg!!.toJsonObject())
        }
        
        if (priorLeg != null) {
            json.add("priorLeg", priorLeg!!.toJsonObject())
        }
        
        if (remainingLegs.isNotEmpty()) {
            val remainingLegsArray = com.google.gson.JsonArray()
            remainingLegs.forEach { leg ->
                remainingLegsArray.add(leg.toJsonObject())
            }
            json.add("remainingLegs", remainingLegsArray)
        }
        
        if (currentVisualInstruction != null) {
            val visualInstructionJson = JsonObject()
            currentVisualInstruction?.forEach { (key, value) ->
                when (value) {
                    is String -> visualInstructionJson.addProperty(key, value)
                    is Number -> visualInstructionJson.addProperty(key, value)
                    is Boolean -> visualInstructionJson.addProperty(key, value)
                    null -> visualInstructionJson.add(key, com.google.gson.JsonNull.INSTANCE)
                }
            }
            json.add("currentVisualInstruction", visualInstructionJson)
        }

        return json
    }

    private fun addProperty(json: JsonObject, prop: String, value: Boolean?) {
        if (value != null) {
            json.addProperty(prop, value)
        }
    }

    private fun addProperty(json: JsonObject, prop: String, value: Double?) {
        if (value != null) {
            json.addProperty(prop, value)
        }
    }

    private fun addProperty(json: JsonObject, prop: String, value: Int?) {
        if (value != null) {
            json.addProperty(prop, value)
        }
    }

    private fun addProperty(json: JsonObject, prop: String, value: String?) {
        if (value?.isNotEmpty() == true) {
            json.addProperty(prop, value)
        }
    }

    private fun addProperty(json: JsonObject, prop: String, value: Float?) {
        if (value != null) {
            json.addProperty(prop, value)
        }
    }
}
