package com.eopeter.fluttermapboxnavigation

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import android.util.Log
import androidx.lifecycle.LifecycleOwner
import com.eopeter.fluttermapboxnavigation.databinding.NavigationActivityBinding
import com.eopeter.fluttermapboxnavigation.models.MapBoxEvents
import com.eopeter.fluttermapboxnavigation.models.MapBoxRouteProgressEvent
import com.eopeter.fluttermapboxnavigation.models.Waypoint
import com.eopeter.fluttermapboxnavigation.models.WaypointSet
import com.eopeter.fluttermapboxnavigation.utilities.CustomInfoPanelEndNavButtonBinder
import com.eopeter.fluttermapboxnavigation.utilities.PluginUtilities
import com.eopeter.fluttermapboxnavigation.utilities.StylePreferenceManager
import com.google.gson.Gson
import com.mapbox.maps.Style
import com.mapbox.api.directions.v5.DirectionsCriteria
import com.mapbox.api.directions.v5.models.RouteOptions
import com.mapbox.geojson.Point
import com.mapbox.navigation.base.extensions.applyDefaultNavigationOptions
import com.mapbox.navigation.base.extensions.applyLanguageAndVoiceUnitOptions
import com.mapbox.navigation.base.options.NavigationOptions
import com.mapbox.navigation.base.route.NavigationRoute
import com.mapbox.navigation.base.route.NavigationRouterCallback
import com.mapbox.navigation.base.route.RouterFailure
import com.mapbox.navigation.base.route.RouterOrigin
import com.mapbox.navigation.base.trip.model.RouteLegProgress
import com.mapbox.navigation.base.trip.model.RouteProgress
import com.mapbox.navigation.core.arrival.ArrivalObserver
import com.mapbox.navigation.core.directions.session.RoutesObserver
import com.mapbox.navigation.core.lifecycle.MapboxNavigationApp
import com.mapbox.navigation.core.trip.session.*
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*
import java.io.File

open class TurnByTurn(
    ctx: Context,
    act: Activity,
    bind: NavigationActivityBinding,
    accessToken: String
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    Application.ActivityLifecycleCallbacks {

    companion object {
        private const val TAG = "TurnByTurn"
    }

    open fun initFlutterChannelHandlers() {
        this.methodChannel?.setMethodCallHandler(this)
        this.eventChannel?.setStreamHandler(this)
    }

    open fun initNavigation() {
        // In SDK v3, access token is automatically retrieved from resources
        val navigationOptions = NavigationOptions.Builder(this.context)
            .build()

        MapboxNavigationApp
            .setup { navigationOptions }
            .attach(this.activity as LifecycleOwner)

        // Note: MapboxHistoryRecorder is internal in SDK v3
        // History recording will be handled differently

        // initialize navigation trip observers
        this.registerObservers()
    }

    override fun onMethodCall(methodCall: MethodCall, result: MethodChannel.Result) {
        when (methodCall.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "enableOfflineRouting" -> {
                // downloadRegionForOfflineRouting(call, result)
            }
            "buildRoute" -> {
                this.buildRoute(methodCall, result)
            }
            "clearRoute" -> {
                this.clearRoute(methodCall, result)
            }
            "startFreeDrive" -> {
                FlutterMapboxNavigationPlugin.enableFreeDriveMode = true
                this.startFreeDrive()
            }
            "startNavigation" -> {
                FlutterMapboxNavigationPlugin.enableFreeDriveMode = false
                this.startNavigation(methodCall, result)
            }
            "finishNavigation" -> {
                this.finishNavigation(methodCall, result)
            }
            "getDistanceRemaining" -> {
                result.success(this.distanceRemaining)
            }
            "getDurationRemaining" -> {
                result.success(this.durationRemaining)
            }
            else -> result.notImplemented()
        }
    }

    private fun buildRoute(methodCall: MethodCall, result: MethodChannel.Result) {
        this.isNavigationCanceled = false

        val arguments = methodCall.arguments as? Map<*, *>
        if (arguments != null) this.setOptions(arguments)
        this.addedWaypoints.clear()
        val points = arguments?.get("wayPoints") as HashMap<*, *>
        for (item in points) {
            val point = item.value as HashMap<*, *>
            val latitude = point["Latitude"] as Double
            val longitude = point["Longitude"] as Double
            val isSilent = point["IsSilent"] as Boolean
            this.addedWaypoints.add(Waypoint(Point.fromLngLat(longitude, latitude),isSilent))
        }
        this.getRoute(this.context)
        result.success(true)
    }

    private fun getRoute(context: Context) {
        MapboxNavigationApp.current()!!.requestRoutes(
            routeOptions = RouteOptions
                .builder()
                .applyDefaultNavigationOptions(navigationMode)
                .applyLanguageAndVoiceUnitOptions(context)
                .coordinatesList(this.addedWaypoints.coordinatesList())
                .waypointIndicesList(this.addedWaypoints.waypointsIndices())
                .waypointNamesList(this.addedWaypoints.waypointsNames())
                .language(navigationLanguage)
                .alternatives(alternatives)
                .steps(true)
                .voiceUnits(navigationVoiceUnits)
                .bannerInstructions(bannerInstructionsEnabled)
                .voiceInstructions(voiceInstructionsEnabled)
                .build(),
            callback = object : NavigationRouterCallback {
                override fun onRoutesReady(
                    routes: List<NavigationRoute>,
                    routerOrigin: String
                ) {
                    this@TurnByTurn.currentRoutes = routes
                    PluginUtilities.sendEvent(
                        MapBoxEvents.ROUTE_BUILT,
                        Gson().toJson(routes.map { it.directionsRoute.toJson() })
                    )
                    // NavigationView API removed in SDK v3 - needs complete rewrite
                    // Temporarily disabled for MVP
                    // this@TurnByTurn.binding.navigationView.api.routeReplayEnabled(
                    //     this@TurnByTurn.simulateRoute
                    // )
                    // this@TurnByTurn.binding.navigationView.api.startRoutePreview(routes)
                    // this@TurnByTurn.binding.navigationView.customizeViewBinders {
                    //     this.infoPanelEndNavigationButtonBinder =
                    //         CustomInfoPanelEndNavButtonBinder(activity)
                    // }
                }

                override fun onFailure(
                    reasons: List<RouterFailure>,
                    routeOptions: RouteOptions
                ) {
                    PluginUtilities.sendEvent(MapBoxEvents.ROUTE_BUILD_FAILED)
                }

                override fun onCanceled(
                    routeOptions: RouteOptions,
                    routerOrigin: String
                ) {
                    PluginUtilities.sendEvent(MapBoxEvents.ROUTE_BUILD_CANCELLED)
                }
            }
        )
    }

    private fun clearRoute(methodCall: MethodCall, result: MethodChannel.Result) {
        this.currentRoutes = null
        val navigation = MapboxNavigationApp.current()
        navigation?.stopTripSession()
        PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
    }

    private fun startFreeDrive() {
        val mapboxNavigation = MapboxNavigationApp.current() ?: run {
            Log.e(TAG, "MapboxNavigation not initialized")
            PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
            return
        }
        
        try {
            // 启动 trip session 但不设置路线（Free Drive 模式）
            mapboxNavigation.startTripSession()
            
            // 发送事件到 Flutter
            PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_RUNNING)
            
            Log.d(TAG, "Free Drive mode started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Free Drive mode: ${e.message}", e)
            PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        }
    }

    private fun startNavigation(methodCall: MethodCall, result: MethodChannel.Result) {
        val arguments = methodCall.arguments as? Map<*, *>
        if (arguments != null) {
            this.setOptions(arguments)
        }

        this.startNavigation()

        if (this.currentRoutes != null) {
            result.success(true)
        } else {
            result.success(false)
        }
    }

    private fun finishNavigation(methodCall: MethodCall, result: MethodChannel.Result) {
        this.finishNavigation()

        if (this.currentRoutes != null) {
            result.success(true)
        } else {
            result.success(false)
        }
    }

    @OptIn(com.mapbox.navigation.base.ExperimentalPreviewMapboxNavigationAPI::class)
    @SuppressLint("MissingPermission")
    private fun startNavigation() {
        if (this.currentRoutes == null || this.currentRoutes!!.isEmpty()) {
            Log.w(TAG, "No routes available for navigation")
            PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
            return
        }
        
        val mapboxNavigation = MapboxNavigationApp.current() ?: run {
            Log.e(TAG, "MapboxNavigation not initialized")
            PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
            return
        }
        
        try {
            // 设置导航路线
            mapboxNavigation.setNavigationRoutes(this.currentRoutes!!)
            Log.d(TAG, "Navigation routes set, route count: ${this.currentRoutes!!.size}")
            
            // 根据 simulateRoute 标志选择 trip session 类型
            if (this.simulateRoute) {
                // 模拟导航
                mapboxNavigation.startReplayTripSession()
                Log.d(TAG, "Started simulated navigation")
            } else {
                // 真实导航
                mapboxNavigation.startTripSession()
                Log.d(TAG, "Started real navigation")
            }
            
            // 开始历史记录（如果启用）
            if (FlutterMapboxNavigationPlugin.enableHistoryRecording) {
                startHistoryRecording()
            }
            
            // 发送事件到 Flutter
            PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_RUNNING)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start navigation: ${e.message}", e)
            PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        }
    }

    private fun finishNavigation(isOffRouted: Boolean = false) {
        try {
            // 停止历史记录（如果正在记录）
            if (isRecordingHistory) {
                stopHistoryRecording()
            }
            
            val mapboxNavigation = MapboxNavigationApp.current()
            if (mapboxNavigation != null) {
                mapboxNavigation.stopTripSession()
                Log.d(TAG, "Navigation finished successfully")
            } else {
                Log.w(TAG, "MapboxNavigation is null when finishing navigation")
            }
            
            this.isNavigationCanceled = true
            PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        } catch (e: Exception) {
            Log.e(TAG, "Error finishing navigation: ${e.message}", e)
            this.isNavigationCanceled = true
            PluginUtilities.sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        }
    }

    private fun setOptions(arguments: Map<*, *>) {
        val navMode = arguments["mode"] as? String
        if (navMode != null) {
            when (navMode) {
                "walking" -> this.navigationMode = DirectionsCriteria.PROFILE_WALKING
                "cycling" -> this.navigationMode = DirectionsCriteria.PROFILE_CYCLING
                "driving" -> this.navigationMode = DirectionsCriteria.PROFILE_DRIVING
            }
        }

        val simulated = arguments["simulateRoute"] as? Boolean
        if (simulated != null) {
            this.simulateRoute = simulated
        }

        val language = arguments["language"] as? String
        if (language != null) {
            this.navigationLanguage = language
        }

        val units = arguments["units"] as? String

        if (units != null) {
            if (units == "imperial") {
                this.navigationVoiceUnits = DirectionsCriteria.IMPERIAL
            } else if (units == "metric") {
                this.navigationVoiceUnits = DirectionsCriteria.METRIC
            }
        }

        this.mapStyleUrlDay = arguments["mapStyleUrlDay"] as? String
        this.mapStyleUrlNight = arguments["mapStyleUrlNight"] as? String

        // Priority: Arguments override > User preference > Default
        // Set the style Uri - use saved preference if not provided in arguments
        if (this.mapStyleUrlDay == null) {
            this.mapStyleUrlDay = StylePreferenceManager.getMapStyleUrl(context)
            Log.d(TAG, "Using saved user preference for day style: ${this.mapStyleUrlDay}")
        } else {
            Log.d(TAG, "Using arguments override for day style: ${this.mapStyleUrlDay}")
        }
        
        if (this.mapStyleUrlNight == null) {
            this.mapStyleUrlNight = Style.DARK
        }

        // NavigationView API removed in SDK v3 - needs complete rewrite
        // Temporarily disabled for MVP
        // this@TurnByTurn.binding.navigationView.customizeViewOptions {
        //     mapStyleUriDay = this@TurnByTurn.mapStyleUrlDay
        //     mapStyleUriNight = this@TurnByTurn.mapStyleUrlNight
        // }           

        this.initialLatitude = arguments["initialLatitude"] as? Double
        this.initialLongitude = arguments["initialLongitude"] as? Double

        val zm = arguments["zoom"] as? Double
        if (zm != null) {
            this.zoom = zm
        }

        val br = arguments["bearing"] as? Double
        if (br != null) {
            this.bearing = br
        }

        val tt = arguments["tilt"] as? Double
        if (tt != null) {
            this.tilt = tt
        }

        val optim = arguments["isOptimized"] as? Boolean
        if (optim != null) {
            this.isOptimized = optim
        }

        val anim = arguments["animateBuildRoute"] as? Boolean
        if (anim != null) {
            this.animateBuildRoute = anim
        }

        val altRoute = arguments["alternatives"] as? Boolean
        if (altRoute != null) {
            this.alternatives = altRoute
        }

        val voiceEnabled = arguments["voiceInstructionsEnabled"] as? Boolean
        if (voiceEnabled != null) {
            this.voiceInstructionsEnabled = voiceEnabled
        }

        val bannerEnabled = arguments["bannerInstructionsEnabled"] as? Boolean
        if (bannerEnabled != null) {
            this.bannerInstructionsEnabled = bannerEnabled
        }

        val longPress = arguments["longPressDestinationEnabled"] as? Boolean
        if (longPress != null) {
            this.longPressDestinationEnabled = longPress
        }

        val onMapTap = arguments["enableOnMapTapCallback"] as? Boolean
        if (onMapTap != null) {
            this.enableOnMapTapCallback = onMapTap
        }
        
        // Handle history recording setting
        val historyRecording = arguments["enableHistoryRecording"] as? Boolean
        if (historyRecording != null) {
            FlutterMapboxNavigationPlugin.enableHistoryRecording = historyRecording
            Log.d(TAG, "History recording enabled: $historyRecording")
        }
    }

    open fun registerObservers() {
        // register event listeners
        MapboxNavigationApp.current()?.registerBannerInstructionsObserver(this.bannerInstructionObserver)
        MapboxNavigationApp.current()?.registerVoiceInstructionsObserver(this.voiceInstructionObserver)
        MapboxNavigationApp.current()?.registerOffRouteObserver(this.offRouteObserver)
        MapboxNavigationApp.current()?.registerRoutesObserver(this.routesObserver)
        MapboxNavigationApp.current()?.registerLocationObserver(this.locationObserver)
        MapboxNavigationApp.current()?.registerRouteProgressObserver(this.routeProgressObserver)
        MapboxNavigationApp.current()?.registerArrivalObserver(this.arrivalObserver)
    }

    open fun unregisterObservers() {
        // unregister event listeners to prevent leaks or unnecessary resource consumption
        MapboxNavigationApp.current()?.unregisterBannerInstructionsObserver(this.bannerInstructionObserver)
        MapboxNavigationApp.current()?.unregisterVoiceInstructionsObserver(this.voiceInstructionObserver)
        MapboxNavigationApp.current()?.unregisterOffRouteObserver(this.offRouteObserver)
        MapboxNavigationApp.current()?.unregisterRoutesObserver(this.routesObserver)
        MapboxNavigationApp.current()?.unregisterLocationObserver(this.locationObserver)
        MapboxNavigationApp.current()?.unregisterRouteProgressObserver(this.routeProgressObserver)
        MapboxNavigationApp.current()?.unregisterArrivalObserver(this.arrivalObserver)
    }

    // Flutter stream listener delegate methods
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        FlutterMapboxNavigationPlugin.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        FlutterMapboxNavigationPlugin.eventSink = null
    }

    protected val context: Context = ctx
    val activity: Activity = act
    private val token: String = accessToken
    open var methodChannel: MethodChannel? = null
    open var eventChannel: EventChannel? = null
    protected var lastLocation: android.location.Location? = null

    /**
     * Helper class that keeps added waypoints and transforms them to the [RouteOptions] params.
     */
    private val addedWaypoints = WaypointSet()

    // Config
    private var initialLatitude: Double? = null
    private var initialLongitude: Double? = null

    // val wayPoints: MutableList<Point> = mutableListOf()
    private var navigationMode = DirectionsCriteria.PROFILE_DRIVING_TRAFFIC
    var simulateRoute = false
    private var mapStyleUrlDay: String? = null
    private var mapStyleUrlNight: String? = null
    private var navigationLanguage = "en"
    private var navigationVoiceUnits = DirectionsCriteria.IMPERIAL
    private var zoom = 15.0
    private var bearing = 0.0
    private var tilt = 0.0
    private var distanceRemaining: Float? = null
    private var durationRemaining: Double? = null

    private var alternatives = true

    var allowsUTurnAtWayPoints = false
    var enableRefresh = false
    private var voiceInstructionsEnabled = true
    private var bannerInstructionsEnabled = true
    private var longPressDestinationEnabled = true
    private var enableOnMapTapCallback = false
    private var animateBuildRoute = true
    private var isOptimized = false

    private var currentRoutes: List<NavigationRoute>? = null
    private var isNavigationCanceled = false

    // History recording
    // Note: In SDK v3, MapboxHistoryRecorder is internal and not directly accessible
    // History recording functionality needs to be implemented differently
    private var isRecordingHistory = false
    private var currentHistoryFilePath: String? = null
    private var navigationStartTime: Long = 0
    private var navigationStartPointName: String? = null
    private var navigationEndPointName: String? = null

    /**
     * Bindings to the example layout.
     */
    open val binding: NavigationActivityBinding = bind

    /**
     * Gets notified with location updates.
     *
     * Exposes raw updates coming directly from the location services
     * and the updates enhanced by the Navigation SDK (cleaned up and matched to the road).
     */
    private val locationObserver = object : LocationObserver {
        override fun onNewRawLocation(rawLocation: com.mapbox.common.location.Location) {
            // Required by SDK v3 - receives raw location updates
        }

        override fun onNewLocationMatcherResult(locationMatcherResult: LocationMatcherResult) {
            // Convert to android.location.Location for compatibility
            val enhancedLocation = locationMatcherResult.enhancedLocation
            this@TurnByTurn.lastLocation = android.location.Location("").apply {
                latitude = enhancedLocation.latitude
                longitude = enhancedLocation.longitude
                bearing = enhancedLocation.bearing?.toFloat() ?: 0f
                speed = enhancedLocation.speed?.toFloat() ?: 0f
            }
        }
    }

    private val bannerInstructionObserver = BannerInstructionsObserver { bannerInstructions ->
        PluginUtilities.sendEvent(MapBoxEvents.BANNER_INSTRUCTION, bannerInstructions.primary().text())
    }

    private val voiceInstructionObserver = VoiceInstructionsObserver { voiceInstructions ->
        PluginUtilities.sendEvent(MapBoxEvents.SPEECH_ANNOUNCEMENT, voiceInstructions.announcement().toString())
    }

    private val offRouteObserver = OffRouteObserver { offRoute ->
        if (offRoute) {
            PluginUtilities.sendEvent(MapBoxEvents.USER_OFF_ROUTE)
        }
    }

    private val routesObserver = RoutesObserver { routeUpdateResult ->
        if (routeUpdateResult.navigationRoutes.isNotEmpty()) {
            PluginUtilities.sendEvent(MapBoxEvents.REROUTE_ALONG);
        }
    }

    /**
     * Gets notified with progress along the currently active route.
     */
    private val routeProgressObserver = RouteProgressObserver { routeProgress ->
        // update flutter events
        if (!this.isNavigationCanceled) {
            try {
                this.distanceRemaining = routeProgress.distanceRemaining
                this.durationRemaining = routeProgress.durationRemaining

                val progressEvent = MapBoxRouteProgressEvent(routeProgress)
                PluginUtilities.sendEvent(progressEvent)
            } catch (e: Exception) {
                Log.e(TAG, "Error processing route progress: ${e.message}", e)
            }
        }
    }

    private val arrivalObserver: ArrivalObserver = object : ArrivalObserver {
        override fun onFinalDestinationArrival(routeProgress: RouteProgress) {
            Log.d(TAG, "🏁 Final destination arrival")
            
            // Send detailed arrival information
            val arrivalData = mapOf(
                "isFinalDestination" to true,
                "legIndex" to routeProgress.currentLegProgress?.legIndex,
                "distanceRemaining" to routeProgress.distanceRemaining,
                "durationRemaining" to routeProgress.durationRemaining
            )
            PluginUtilities.sendEvent(MapBoxEvents.ON_ARRIVAL, com.google.gson.Gson().toJson(arrivalData))
        }

        override fun onNextRouteLegStart(routeLegProgress: RouteLegProgress) {
            Log.d(TAG, "🚩 Next route leg started: leg ${routeLegProgress.legIndex}")
            
            // Send waypoint arrival event when moving to next leg
            val waypointData = mapOf(
                "legIndex" to routeLegProgress.legIndex,
                "distanceRemaining" to routeLegProgress.distanceRemaining,
                "durationRemaining" to routeLegProgress.durationRemaining
            )
            PluginUtilities.sendEvent(MapBoxEvents.WAYPOINT_ARRIVAL, com.google.gson.Gson().toJson(waypointData))
        }

        override fun onWaypointArrival(routeProgress: RouteProgress) {
            Log.d(TAG, "📍 Waypoint arrival: leg ${routeProgress.currentLegProgress?.legIndex}")
            
            // Send waypoint arrival event
            val waypointData = mapOf(
                "isFinalDestination" to false,
                "legIndex" to routeProgress.currentLegProgress?.legIndex,
                "distanceRemaining" to routeProgress.distanceRemaining,
                "durationRemaining" to routeProgress.durationRemaining
            )
            PluginUtilities.sendEvent(MapBoxEvents.WAYPOINT_ARRIVAL, com.google.gson.Gson().toJson(waypointData))
        }
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        Log.d(TAG, "onActivityCreated")
    }

    override fun onActivityStarted(activity: Activity) {
        Log.d(TAG, "onActivityStarted")
    }

    override fun onActivityResumed(activity: Activity) {
        Log.d(TAG, "onActivityResumed")
    }

    override fun onActivityPaused(activity: Activity) {
        Log.d(TAG, "onActivityPaused")
    }

    override fun onActivityStopped(activity: Activity) {
        Log.d(TAG, "onActivityStopped")
    }

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {
        Log.d(TAG, "onActivitySaveInstanceState")
    }

    override fun onActivityDestroyed(activity: Activity) {
        try {
            // Stop history recording if active
            if (isRecordingHistory) {
                stopHistoryRecording()
            }
            
            // Unregister observers to prevent memory leaks
            unregisterObservers()
            Log.d(TAG, "onActivityDestroyed - observers unregistered successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error in onActivityDestroyed: ${e.message}", e)
        }
    }

    /**
     * 开始历史记录
     * Using SDK v3 HistoryRecordingStateHandler
     */
    private fun startHistoryRecording() {
        try {
            val mapboxNavigation = MapboxNavigationApp.current()
            if (mapboxNavigation == null) {
                Log.e(TAG, "MapboxNavigation is null, cannot start history recording")
                PluginUtilities.sendEvent(MapBoxEvents.HISTORY_RECORDING_ERROR)
                return
            }
            
            // Record navigation start time and waypoint info
            navigationStartTime = System.currentTimeMillis()
            
            // Use simple default names for now
            navigationStartPointName = "Start Point"
            navigationEndPointName = "End Point"
            
            // v3: startRecording() 有返回值 List<String>，可选接收
            val paths = mapboxNavigation.historyRecorder.startRecording()
            Log.d(TAG, "History recording started, will write to: $paths")
            
            isRecordingHistory = true
            
            Log.d(TAG, "History recording started at $navigationStartTime")
            Log.d(TAG, "Start point: $navigationStartPointName, End point: $navigationEndPointName")
            PluginUtilities.sendEvent(MapBoxEvents.HISTORY_RECORDING_STARTED)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start history recording: ${e.message}", e)
            PluginUtilities.sendEvent(MapBoxEvents.HISTORY_RECORDING_ERROR)
        }
    }

    /**
     * 停止历史记录
     * Using SDK v3 HistoryRecordingStateHandler
     */
    private fun stopHistoryRecording() {
        try {
            val mapboxNavigation = MapboxNavigationApp.current()
            if (mapboxNavigation == null) {
                Log.w(TAG, "MapboxNavigation is null when stopping history recording")
                isRecordingHistory = false
                currentHistoryFilePath = null
                return
            }
            
            // Stop history recording
            mapboxNavigation.historyRecorder.stopRecording { historyFilePath ->
                if (historyFilePath != null) {
                    Log.d(TAG, "History recording stopped and saved: $historyFilePath")
                    currentHistoryFilePath = historyFilePath
                    
                    // Calculate navigation duration
                    val navigationEndTime = System.currentTimeMillis()
                    val duration = ((navigationEndTime - navigationStartTime) / 1000).toInt() // in seconds
                    
                    // Save history record to HistoryManager
                    val historyData = mapOf(
                        "id" to java.util.UUID.randomUUID().toString(),
                        "filePath" to historyFilePath,
                        "startTime" to navigationStartTime,
                        "duration" to duration.toLong(),
                        "startPointName" to (navigationStartPointName ?: "Unknown Start"),
                        "endPointName" to (navigationEndPointName ?: "Unknown End"),
                        "navigationMode" to when (navigationMode) {
                            com.mapbox.api.directions.v5.DirectionsCriteria.PROFILE_DRIVING -> "driving"
                            com.mapbox.api.directions.v5.DirectionsCriteria.PROFILE_WALKING -> "walking"
                            com.mapbox.api.directions.v5.DirectionsCriteria.PROFILE_CYCLING -> "cycling"
                            else -> "driving"
                        }
                    )
                    
                    val saved = FlutterMapboxNavigationPlugin.historyManager.saveHistoryRecord(historyData)
                    if (saved) {
                        Log.d(TAG, "✅ History record saved to HistoryManager")
                    } else {
                        Log.e(TAG, "❌ Failed to save history record to HistoryManager")
                    }
                    
                    // Send file path to Flutter
                    val eventData = mapOf(
                        "historyFilePath" to historyFilePath,
                        "duration" to duration,
                        "startPointName" to (navigationStartPointName ?: "Unknown Start"),
                        "endPointName" to (navigationEndPointName ?: "Unknown End")
                    )
                    PluginUtilities.sendEvent(
                        MapBoxEvents.HISTORY_RECORDING_STOPPED,
                        com.google.gson.Gson().toJson(eventData)
                    )
                } else {
                    Log.w(TAG, "History recording stopped but no file path returned")
                    PluginUtilities.sendEvent(MapBoxEvents.HISTORY_RECORDING_STOPPED)
                }
            }
            
            isRecordingHistory = false
            // Reset navigation tracking variables
            navigationStartTime = 0
            navigationStartPointName = null
            navigationEndPointName = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop history recording: ${e.message}", e)
            isRecordingHistory = false
            currentHistoryFilePath = null
            PluginUtilities.sendEvent(MapBoxEvents.HISTORY_RECORDING_ERROR)
        }
    }
}
