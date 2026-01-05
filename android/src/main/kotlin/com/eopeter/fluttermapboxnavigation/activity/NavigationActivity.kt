package com.eopeter.fluttermapboxnavigation.activity

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import com.eopeter.fluttermapboxnavigation.FlutterMapboxNavigationPlugin
import com.eopeter.fluttermapboxnavigation.R
import com.eopeter.fluttermapboxnavigation.databinding.NavigationActivityBinding
import com.eopeter.fluttermapboxnavigation.models.MapBoxEvents
import com.eopeter.fluttermapboxnavigation.models.MapBoxRouteProgressEvent
import com.eopeter.fluttermapboxnavigation.models.Waypoint
import com.eopeter.fluttermapboxnavigation.models.WaypointSet
import com.eopeter.fluttermapboxnavigation.utilities.PluginUtilities
import com.eopeter.fluttermapboxnavigation.utilities.PluginUtilities.Companion.sendEvent
import com.eopeter.fluttermapboxnavigation.utilities.MapStyleManager
import com.google.gson.Gson
import com.mapbox.api.directions.v5.models.RouteOptions
import com.mapbox.geojson.Point
import com.mapbox.maps.CameraOptions
import com.mapbox.maps.EdgeInsets
import com.mapbox.maps.Style
import com.mapbox.maps.plugin.animation.camera
import com.mapbox.maps.plugin.gestures.OnMapClickListener
import com.mapbox.maps.plugin.gestures.OnMapLongClickListener
import com.mapbox.maps.plugin.gestures.gestures
import com.mapbox.maps.plugin.locationcomponent.location
import com.mapbox.navigation.base.extensions.applyDefaultNavigationOptions
import com.mapbox.navigation.base.extensions.applyLanguageAndVoiceUnitOptions
import com.mapbox.navigation.base.options.NavigationOptions
import com.mapbox.navigation.base.route.NavigationRoute
import com.mapbox.navigation.base.route.NavigationRouterCallback
import com.mapbox.navigation.base.route.RouterFailure
import com.mapbox.navigation.base.route.RouterOrigin
import com.mapbox.navigation.base.trip.model.RouteLegProgress
import com.mapbox.navigation.base.trip.model.RouteProgress
import com.mapbox.navigation.core.MapboxNavigation
import com.mapbox.navigation.core.arrival.ArrivalObserver
import com.mapbox.navigation.core.directions.session.RoutesObserver
import com.mapbox.navigation.core.lifecycle.MapboxNavigationApp
import com.mapbox.navigation.core.lifecycle.MapboxNavigationObserver
import com.mapbox.navigation.core.lifecycle.requireMapboxNavigation
import com.mapbox.navigation.core.trip.session.BannerInstructionsObserver
import com.mapbox.navigation.core.trip.session.LocationMatcherResult
import com.mapbox.navigation.core.trip.session.LocationObserver
import com.mapbox.navigation.core.trip.session.OffRouteObserver
import com.mapbox.navigation.core.trip.session.RouteProgressObserver
import com.mapbox.navigation.core.trip.session.VoiceInstructionsObserver
import com.mapbox.navigation.ui.maps.route.line.api.MapboxRouteLineApi
import com.mapbox.navigation.ui.maps.route.line.api.MapboxRouteLineView
import com.mapbox.navigation.ui.maps.route.line.model.MapboxRouteLineApiOptions
import com.mapbox.navigation.ui.maps.route.line.model.MapboxRouteLineViewOptions
import com.mapbox.navigation.ui.maps.camera.NavigationCamera
import com.mapbox.navigation.ui.maps.camera.data.MapboxNavigationViewportDataSource
import com.mapbox.navigation.ui.maps.camera.lifecycle.NavigationBasicGesturesHandler
import com.mapbox.navigation.ui.maps.camera.state.NavigationCameraState
import com.mapbox.navigation.ui.voice.api.MapboxSpeechApi
import com.mapbox.navigation.ui.voice.api.MapboxVoiceInstructionsPlayer
import com.mapbox.navigation.ui.voice.api.VoiceInstructionsPlayerCallback
import com.mapbox.navigation.ui.voice.model.SpeechAnnouncement
import com.mapbox.navigation.ui.voice.model.SpeechError
import com.mapbox.navigation.ui.maps.route.arrow.api.MapboxRouteArrowApi
import com.mapbox.navigation.ui.maps.route.arrow.api.MapboxRouteArrowView
import com.mapbox.navigation.ui.maps.route.arrow.model.RouteArrowOptions
import com.mapbox.navigation.ui.maneuver.api.MapboxManeuverApi
import com.mapbox.navigation.ui.maneuver.model.MapboxManeuverOptions
import com.mapbox.navigation.ui.tripprogress.api.MapboxTripProgressApi
import com.mapbox.navigation.ui.tripprogress.model.TripProgressUpdateFormatter
import org.json.JSONObject
import java.text.DecimalFormat

/**
 * NavigationActivity - MVP 版本
 * 使用 Mapbox Navigation SDK v3 核心 API
 * 
 * 功能：
 * - 基础地图显示
 * - 路线规划和显示
 * - 导航启动/停止
 * - 位置跟踪
 * - 进度事件
 */
class NavigationActivity : AppCompatActivity() {
    
    companion object {
        private const val TAG = "NavigationActivity"
    }
    
    // View Binding
    private lateinit var binding: NavigationActivityBinding
    
    // Broadcast Receivers
    private var finishBroadcastReceiver: BroadcastReceiver? = null
    private var addWayPointsBroadcastReceiver: BroadcastReceiver? = null
    
    // Navigation State
    private var points: MutableList<Waypoint> = mutableListOf()
    private var waypointSet: WaypointSet = WaypointSet()
    private var lastLocation: android.location.Location? = null
    private var isNavigationInProgress = false
    private var accessToken: String? = null
    private var currentRoutes: List<NavigationRoute> = emptyList()
    private var selectedRouteIndex: Int = 0
    private var isShowingRouteSelection: Boolean = false
    
    // Route Line API for drawing routes on map
    private lateinit var routeLineApi: MapboxRouteLineApi
    private lateinit var routeLineView: MapboxRouteLineView
    
    // Route Arrow API for showing turn arrows
    private lateinit var routeArrowApi: com.mapbox.navigation.ui.maps.route.arrow.api.MapboxRouteArrowApi
    private lateinit var routeArrowView: com.mapbox.navigation.ui.maps.route.arrow.api.MapboxRouteArrowView
    
    // Maneuver API for turn instructions
    private lateinit var maneuverApi: com.mapbox.navigation.ui.maneuver.api.MapboxManeuverApi
    
    // Trip Progress API for progress information
    private lateinit var tripProgressApi: com.mapbox.navigation.ui.tripprogress.api.MapboxTripProgressApi
    
    // History Recording
    private var isRecordingHistory = false
    private var currentHistoryFilePath: String? = null
    
    // Navigation Camera for automatic camera management (following official Turn-by-Turn pattern)
    private lateinit var navigationCamera: NavigationCamera
    private lateinit var viewportDataSource: MapboxNavigationViewportDataSource
    
    // Camera state tracking
    private var isCameraFollowing = true
    private var userHasMovedMap = false
    
    // Replay Route Mapper for simulation
    private val replayRouteMapper = com.mapbox.navigation.core.replay.route.ReplayRouteMapper()
    
    // Voice Instructions components
    private lateinit var speechApi: com.mapbox.navigation.ui.voice.api.MapboxSpeechApi
    private lateinit var voiceInstructionsPlayer: com.mapbox.navigation.ui.voice.api.MapboxVoiceInstructionsPlayer
    private val voiceInstructionsObserverImpl = VoiceInstructionsObserverImpl()
    
    // MapboxNavigation observer for lifecycle management
    private val mapboxNavigationObserver = object : MapboxNavigationObserver {
        override fun onAttached(mapboxNavigation: MapboxNavigation) {
            android.util.Log.d(TAG, "🔗 MapboxNavigationObserver onAttached - registering observers")
            // Register observers when navigation is attached
            mapboxNavigation.registerLocationObserver(locationObserver)
            mapboxNavigation.registerRouteProgressObserver(routeProgressObserver)
            mapboxNavigation.registerRoutesObserver(routesObserver)
            mapboxNavigation.registerArrivalObserver(arrivalObserver)
            mapboxNavigation.registerOffRouteObserver(offRouteObserver)
            mapboxNavigation.registerBannerInstructionsObserver(bannerInstructionObserver)
            mapboxNavigation.registerVoiceInstructionsObserver(voiceInstructionObserver)
            android.util.Log.d(TAG, "✅ All observers registered successfully")
        }

        override fun onDetached(mapboxNavigation: MapboxNavigation) {
            android.util.Log.d(TAG, "🔌 MapboxNavigationObserver onDetached - unregistering observers")
            // Unregister observers when navigation is detached
            mapboxNavigation.unregisterLocationObserver(locationObserver)
            mapboxNavigation.unregisterRouteProgressObserver(routeProgressObserver)
            mapboxNavigation.unregisterRoutesObserver(routesObserver)
            mapboxNavigation.unregisterArrivalObserver(arrivalObserver)
            mapboxNavigation.unregisterOffRouteObserver(offRouteObserver)
            mapboxNavigation.unregisterBannerInstructionsObserver(bannerInstructionObserver)
            mapboxNavigation.unregisterVoiceInstructionsObserver(voiceInstructionObserver)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setTheme(R.style.AppTheme)
        
        // Initialize View Binding
        binding = NavigationActivityBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        // Check location permissions
        if (!checkLocationPermissions()) {
            android.util.Log.e(TAG, "❌ Location permissions not granted, finishing activity")
            finish()
            return
        }
        
        // Get Mapbox access token
        accessToken = PluginUtilities.getResourceFromContext(
            this.applicationContext,
            "mapbox_access_token"
        )
        
        // Initialize Navigation
        initializeNavigation()
        
        // Initialize Map
        initializeMap()
        
        // Initialize Navigation Camera (must be after map initialization)
        initializeNavigationCamera()
        
        // Initialize Voice Instructions
        initializeVoiceInstructions()
        
        // Initialize Maneuver API
        initializeManeuverApi()
        
        // Initialize Trip Progress API
        initializeTripProgressApi()
        
        // Initialize Route Line API
        initializeRouteLine()
        
        // Setup UI
        setupUI()
        
        // Setup Broadcast Receivers
        setupBroadcastReceivers()
        
        // Handle Free Drive Mode
        if (FlutterMapboxNavigationPlugin.enableFreeDriveMode) {
            startFreeDrive()
            return
        }
        
        // Get waypoints from intent and request routes
        val p = intent.getSerializableExtra("waypoints") as? MutableList<Waypoint>
        if (p != null) {
            points = p
            points.map { waypointSet.add(it) }
            requestRoutes(waypointSet)
        }
    }
    
    private fun initializeNavigation() {
        try {
            // In SDK v3, access token is automatically retrieved from resources
            val navigationOptions = NavigationOptions.Builder(this.applicationContext)
                .build()
            
            MapboxNavigationApp
                .setup { navigationOptions }
                .attach(this)
            
            // Register navigation observer
            MapboxNavigationApp.registerObserver(mapboxNavigationObserver)
            
            android.util.Log.d(TAG, "Navigation initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to initialize navigation: ${e.message}", e)
            sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
            finish()
        }
    }
    
    private fun initializeMap() {
        try {
            // Register map view with MapStyleManager
            MapStyleManager.registerMapView(binding.mapView)
            
            // Set day and night styles
            val dayStyle = FlutterMapboxNavigationPlugin.mapStyleUrlDay ?: Style.MAPBOX_STREETS
            val nightStyle = FlutterMapboxNavigationPlugin.mapStyleUrlNight ?: Style.DARK
            MapStyleManager.setDayStyle(dayStyle)
            MapStyleManager.setNightStyle(nightStyle)
            
            // Load map style
            val styleUrl = FlutterMapboxNavigationPlugin.mapStyleUrlDay ?: Style.MAPBOX_STREETS
            
            binding.mapView.mapboxMap.loadStyle(styleUrl) {
                // Enable location component
                binding.mapView.location.updateSettings {
                    enabled = true
                    pulsingEnabled = true
                }
                
                // Register position changed listener for vanishing route line
                binding.mapView.location.addOnIndicatorPositionChangedListener(onIndicatorPositionChangedListener)
                
                android.util.Log.d(TAG, "Map style loaded successfully: $styleUrl")
            }
            
            // Setup map gestures
            if (FlutterMapboxNavigationPlugin.longPressDestinationEnabled) {
                binding.mapView.gestures.addOnMapLongClickListener(onMapLongClick)
            }
            
            if (FlutterMapboxNavigationPlugin.enableOnMapTapCallback) {
                binding.mapView.gestures.addOnMapClickListener(onMapClick)
            }
            
            // Start GPS signal monitoring
            startGpsSignalMonitoring()
            
            android.util.Log.d(TAG, "Map initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to initialize map: ${e.message}", e)
            sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
            finish()
        }
    }
    
    private fun initializeNavigationCamera() {
        try {
            // Initialize viewport data source (following official Turn-by-Turn pattern)
            viewportDataSource = MapboxNavigationViewportDataSource(binding.mapView.mapboxMap)
            
            // Configure camera padding for better UX
            val pixelDensity = resources.displayMetrics.density
            val overviewPadding = EdgeInsets(
                140.0 * pixelDensity,
                40.0 * pixelDensity,
                120.0 * pixelDensity,
                40.0 * pixelDensity
            )
            val followingPadding = EdgeInsets(
                180.0 * pixelDensity,
                40.0 * pixelDensity,
                150.0 * pixelDensity,
                40.0 * pixelDensity
            )
            
            viewportDataSource.overviewPadding = overviewPadding
            viewportDataSource.followingPadding = followingPadding
            
            // Support configurable camera settings from plugin
            if (FlutterMapboxNavigationPlugin.zoom > 0) {
                // Apply custom zoom if provided
                android.util.Log.d(TAG, "📷 Using custom zoom: ${FlutterMapboxNavigationPlugin.zoom}")
            }
            
            // Initialize navigation camera
            navigationCamera = NavigationCamera(
                binding.mapView.mapboxMap,
                binding.mapView.camera,
                viewportDataSource
            )
            
            // Add gesture handler to stop camera following when user interacts with map
            binding.mapView.camera.addCameraAnimationsLifecycleListener(
                NavigationBasicGesturesHandler(navigationCamera)
            )
            
            // Register camera state change observer
            navigationCamera.registerNavigationCameraStateChangeObserver { navigationCameraState ->
                android.util.Log.d(TAG, "📷 Camera state changed: $navigationCameraState")
                
                // Update camera following state
                isCameraFollowing = when (navigationCameraState) {
                    NavigationCameraState.FOLLOWING -> true
                    NavigationCameraState.OVERVIEW -> false
                    NavigationCameraState.IDLE -> false
                    else -> isCameraFollowing
                }
                
                // Show/hide recenter button based on camera state
                runOnUiThread {
                    if (isCameraFollowing) {
                        binding.recenterButton.visibility = View.GONE
                        userHasMovedMap = false
                    } else if (isNavigationInProgress) {
                        binding.recenterButton.visibility = View.VISIBLE
                        userHasMovedMap = true
                    }
                }
            }
            
            android.util.Log.d(TAG, "Navigation camera initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to initialize navigation camera: ${e.message}", e)
        }
    }
    
    private fun initializeVoiceInstructions() {
        try {
            // Initialize Speech API for voice instructions
            speechApi = com.mapbox.navigation.ui.voice.api.MapboxSpeechApi(
                this,
                accessToken ?: "",
                FlutterMapboxNavigationPlugin.navigationLanguage
            )
            
            // Initialize Voice Instructions Player
            voiceInstructionsPlayer = com.mapbox.navigation.ui.voice.api.MapboxVoiceInstructionsPlayer(
                this,
                FlutterMapboxNavigationPlugin.navigationLanguage
            )
            
            android.util.Log.d(TAG, "Voice instructions initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to initialize voice instructions: ${e.message}", e)
        }
    }
    
    private fun initializeManeuverApi() {
        try {
            // Initialize Maneuver API for turn instructions
            maneuverApi = com.mapbox.navigation.ui.maneuver.api.MapboxManeuverApi(
                com.mapbox.navigation.ui.maneuver.model.MapboxManeuverOptions.Builder().build()
            )
            
            android.util.Log.d(TAG, "Maneuver API initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to initialize maneuver API: ${e.message}", e)
        }
    }
    
    private fun initializeTripProgressApi() {
        try {
            // Initialize Trip Progress API for progress information
            tripProgressApi = com.mapbox.navigation.ui.tripprogress.api.MapboxTripProgressApi(
                com.mapbox.navigation.ui.tripprogress.model.TripProgressUpdateFormatter.Builder(this)
                    .build()
            )
            
            android.util.Log.d(TAG, "Trip Progress API initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to initialize trip progress API: ${e.message}", e)
        }
    }
    
    private fun initializeRouteLine() {
        // Configure vanishing route line with transparent traveled route (official style)
        val customColorResources = com.mapbox.navigation.ui.maps.route.line.model.RouteLineColorResources.Builder()
            .routeLineTraveledColor(android.graphics.Color.TRANSPARENT) // 走过的路线变透明（官方规范）
            .routeLineTraveledCasingColor(android.graphics.Color.TRANSPARENT) // 走过路线的边框也透明
            .build()
        
        val apiOptions = MapboxRouteLineApiOptions.Builder()
            .vanishingRouteLineEnabled(true) // 启用消失路线功能
            .styleInactiveRouteLegsIndependently(true) // 独立样式化非活动路段
            .build()
        
        val viewOptions = MapboxRouteLineViewOptions.Builder(this)
            .routeLineColorResources(customColorResources) // 应用自定义颜色
            .build()
        
        routeLineApi = MapboxRouteLineApi(apiOptions)
        routeLineView = MapboxRouteLineView(viewOptions)
        
        // Initialize Route Arrow API for turn arrows
        routeArrowApi = com.mapbox.navigation.ui.maps.route.arrow.api.MapboxRouteArrowApi()
        routeArrowView = com.mapbox.navigation.ui.maps.route.arrow.api.MapboxRouteArrowView(
            com.mapbox.navigation.ui.maps.route.arrow.model.RouteArrowOptions.Builder(this).build()
        )
        
        android.util.Log.d(TAG, "Route line and arrow initialized with vanishing route line enabled (transparent style)")
    }
    
    private fun setupUI() {
        // End Navigation Button
        binding.endNavigationButton.setOnClickListener {
            stopNavigation()
        }
        
        // Recenter Button
        binding.recenterButton.setOnClickListener {
            recenterCamera()
        }
        
        // Initially hide control panel and recenter button
        binding.navigationControlPanel.visibility = View.GONE
        binding.recenterButton.visibility = View.GONE
    }
    
    private fun setupBroadcastReceivers() {
        finishBroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                finish()
            }
        }
        
        addWayPointsBroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val stops = intent.getSerializableExtra("waypoints") as? MutableList<Waypoint>
                if (stops != null) {
                    val nextIndex = 1
                    if (points.count() >= nextIndex) {
                        points.addAll(nextIndex, stops)
                    } else {
                        points.addAll(stops)
                    }
                }
            }
        }
        
        // Android 14+ requires explicit export flag for BroadcastReceiver
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                finishBroadcastReceiver,
                IntentFilter(NavigationLauncher.KEY_STOP_NAVIGATION),
                Context.RECEIVER_NOT_EXPORTED
            )
            
            registerReceiver(
                addWayPointsBroadcastReceiver,
                IntentFilter(NavigationLauncher.KEY_ADD_WAYPOINTS),
                Context.RECEIVER_NOT_EXPORTED
            )
        } else {
            registerReceiver(
                finishBroadcastReceiver,
                IntentFilter(NavigationLauncher.KEY_STOP_NAVIGATION)
            )
            
            registerReceiver(
                addWayPointsBroadcastReceiver,
                IntentFilter(NavigationLauncher.KEY_ADD_WAYPOINTS)
            )
        }
    }
    
    private fun requestRoutes(waypointSet: WaypointSet) {
        // Check network connectivity before requesting routes
        if (!isNetworkAvailable()) {
            android.util.Log.e(TAG, "❌ No network connection available")
            
            val errorData = mapOf(
                "message" to "No internet connection. Please check your network settings.",
                "type" to "NETWORK_ERROR"
            )
            sendEvent(MapBoxEvents.ROUTE_BUILD_FAILED, org.json.JSONObject(errorData).toString())
            return
        }
        
        sendEvent(MapBoxEvents.ROUTE_BUILDING)
        
        requestRoutesWithRetry(waypointSet, maxRetries = 3, currentAttempt = 1)
    }
    
    private fun requestRoutesWithRetry(waypointSet: WaypointSet, maxRetries: Int, currentAttempt: Int) {
        android.util.Log.d(TAG, "🔄 Requesting routes (attempt $currentAttempt/$maxRetries)")
        
        MapboxNavigationApp.current()?.requestRoutes(
            routeOptions = RouteOptions.builder()
                .applyDefaultNavigationOptions()
                .applyLanguageAndVoiceUnitOptions(this)
                .coordinatesList(waypointSet.coordinatesList())
                .waypointIndicesList(waypointSet.waypointsIndices())
                .waypointNamesList(waypointSet.waypointsNames())
                .language(FlutterMapboxNavigationPlugin.navigationLanguage)
                .alternatives(FlutterMapboxNavigationPlugin.showAlternateRoutes)
                .voiceUnits(FlutterMapboxNavigationPlugin.navigationVoiceUnits)
                .bannerInstructions(FlutterMapboxNavigationPlugin.bannerInstructionsEnabled)
                .voiceInstructions(FlutterMapboxNavigationPlugin.voiceInstructionsEnabled)
                .steps(true)
                .build(),
            callback = object : NavigationRouterCallback {
                override fun onCanceled(routeOptions: RouteOptions, routerOrigin: String) {
                    android.util.Log.w(TAG, "⚠️ Route request canceled")
                    sendEvent(MapBoxEvents.ROUTE_BUILD_CANCELLED)
                }

                override fun onFailure(reasons: List<RouterFailure>, routeOptions: RouteOptions) {
                    // Improved error handling with detailed error messages
                    val errorMessage = reasons.joinToString("; ") { failure ->
                        when {
                            failure.message.contains("No route found", ignoreCase = true) -> 
                                "No route found between the selected locations"
                            failure.message.contains("network", ignoreCase = true) || 
                            failure.message.contains("connection", ignoreCase = true) -> 
                                "Network connection failed. Please check your internet connection"
                            failure.message.contains("timeout", ignoreCase = true) -> 
                                "Request timed out. Please try again"
                            failure.message.contains("unauthorized", ignoreCase = true) || 
                            failure.message.contains("token", ignoreCase = true) -> 
                                "Invalid access token. Please check your Mapbox configuration"
                            else -> failure.message ?: "Unknown error occurred"
                        }
                    }
                    
                    android.util.Log.e(TAG, "❌ Route build failed: $errorMessage")
                    
                    // Check if we should retry
                    val shouldRetry = reasons.any { failure ->
                        failure.message.contains("network", ignoreCase = true) ||
                        failure.message.contains("connection", ignoreCase = true) ||
                        failure.message.contains("timeout", ignoreCase = true)
                    }
                    
                    if (shouldRetry && currentAttempt < maxRetries) {
                        // Retry with exponential backoff
                        val delayMs = (1000 * currentAttempt).toLong()
                        android.util.Log.d(TAG, "🔄 Retrying in ${delayMs}ms...")
                        
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            requestRoutesWithRetry(waypointSet, maxRetries, currentAttempt + 1)
                        }, delayMs)
                    } else {
                        // Send detailed error to Flutter
                        val errorData = mapOf(
                            "message" to errorMessage,
                            "reasons" to reasons.map { it.message },
                            "attempts" to currentAttempt
                        )
                        sendEvent(MapBoxEvents.ROUTE_BUILD_FAILED, org.json.JSONObject(errorData).toString())
                    }
                }

                override fun onRoutesReady(
                    routes: List<NavigationRoute>,
                    routerOrigin: String
                ) {
                    if (routes.isEmpty()) {
                        sendEvent(MapBoxEvents.ROUTE_BUILD_NO_ROUTES_FOUND)
                        return
                    }
                    
                    sendEvent(
                        MapBoxEvents.ROUTE_BUILT,
                        Gson().toJson(routes.map { it.directionsRoute.toJson() })
                    )
                    
                    currentRoutes = routes
                    
                    // If alternative routes are enabled and we have multiple routes, show route selection
                    if (FlutterMapboxNavigationPlugin.showAlternateRoutes && routes.size > 1) {
                        showRouteSelection(routes)
                    } else {
                        // Start navigation immediately with the first route
                        startNavigation(routes)
                    }
                }
            }
        )
    }
    
    @OptIn(com.mapbox.navigation.base.ExperimentalPreviewMapboxNavigationAPI::class)
    private fun startNavigation(routes: List<NavigationRoute>) {
        val mapboxNavigation = MapboxNavigationApp.current() ?: run {
            android.util.Log.e(TAG, "MapboxNavigation is null, cannot start navigation")
            sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
            return
        }
        
        try {
            android.util.Log.d(TAG, "Starting navigation with ${routes.size} routes, simulateRoute=${FlutterMapboxNavigationPlugin.simulateRoute}")
            
            // Set navigation in progress FIRST
            isNavigationInProgress = true
            android.util.Log.d(TAG, "isNavigationInProgress set to true")
            
            // Set routes for navigation
            mapboxNavigation.setNavigationRoutes(routes)
            android.util.Log.d(TAG, "Routes set, count: ${routes.size}")
            
            // Start trip session based on simulation mode
            if (FlutterMapboxNavigationPlugin.simulateRoute) {
                // Use replay trip session for simulation
                mapboxNavigation.startReplayTripSession()
                android.util.Log.d(TAG, "Started replay trip session for simulation")
                
                // CRITICAL: Push replay events to mapboxReplayer
                // This is what actually generates the simulated location updates
                val replayData = replayRouteMapper.mapDirectionsRouteGeometry(
                    routes.first().directionsRoute
                )
                android.util.Log.d(TAG, "Generated ${replayData.size} replay events")
                
                mapboxNavigation.mapboxReplayer.pushEvents(replayData)
                mapboxNavigation.mapboxReplayer.seekTo(replayData.first())
                mapboxNavigation.mapboxReplayer.play()
                android.util.Log.d(TAG, "Mapbox replayer started playing")
            } else {
                // Use regular trip session for real navigation
                mapboxNavigation.startTripSession()
                android.util.Log.d(TAG, "Started regular trip session")
            }
            
            // Draw routes on map
            routeLineApi.setNavigationRoutes(routes) { result ->
                binding.mapView.mapboxMap.style?.let { style ->
                    routeLineView.renderRouteDrawData(style, result)
                    android.util.Log.d(TAG, "Route drawn on map")
                }
            }
            
            // Use NavigationCamera to show route overview first, then switch to following
            // This is the official Turn-by-Turn pattern
            navigationCamera.requestNavigationCameraToOverview()
            android.util.Log.d(TAG, "📷 Camera set to overview mode")
            
            // After a short delay, switch to following mode to start turn-by-turn navigation
            binding.mapView.postDelayed({
                navigationCamera.requestNavigationCameraToFollowing()
                android.util.Log.d(TAG, "📷 Camera switched to following mode")
            }, 1500)
            
            // Show control panel
            binding.navigationControlPanel.visibility = View.VISIBLE
            
            // Start history recording if enabled
            if (FlutterMapboxNavigationPlugin.enableHistoryRecording) {
                startHistoryRecording()
            }
            
            sendEvent(MapBoxEvents.NAVIGATION_RUNNING)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to start navigation: ${e.message}", e)
            sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        }
    }
    
    // Note: adjustCameraToRoute is no longer needed as NavigationCamera handles this automatically
    
    /**
     * Recenter camera to follow user location
     * Called when user taps the recenter button
     */
    private fun recenterCamera() {
        try {
            android.util.Log.d(TAG, "📷 Recentering camera")
            
            // Request camera to follow mode with smooth animation
            navigationCamera.requestNavigationCameraToFollowing()
            
            // Hide recenter button
            binding.recenterButton.visibility = View.GONE
            userHasMovedMap = false
            isCameraFollowing = true
            
            android.util.Log.d(TAG, "✅ Camera recentered successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to recenter camera: ${e.message}", e)
        }
    }
    
    /**
     * Show route selection UI with multiple alternative routes
     */
    private fun showRouteSelection(routes: List<NavigationRoute>) {
        try {
            android.util.Log.d(TAG, "📍 Showing route selection with ${routes.size} routes")
            
            isShowingRouteSelection = true
            selectedRouteIndex = 0
            
            // Draw all routes on map with different styles
            routeLineApi.setNavigationRoutes(routes) { result ->
                binding.mapView.mapboxMap.style?.let { style ->
                    routeLineView.renderRouteDrawData(style, result)
                    android.util.Log.d(TAG, "All routes drawn on map")
                }
            }
            
            // Show route overview camera
            navigationCamera.requestNavigationCameraToOverview()
            
            // Show route selection UI
            binding.routeSelectionPanel.visibility = View.VISIBLE
            binding.navigationControlPanel.visibility = View.GONE
            
            // Display route information
            displayRouteInformation(routes)
            
            // Setup route click listener
            setupRouteClickListener(routes)
            
            // Setup start navigation button
            binding.startNavigationButton.setOnClickListener {
                hideRouteSelection()
                startNavigation(routes)
            }
            
            android.util.Log.d(TAG, "✅ Route selection UI displayed")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to show route selection: ${e.message}", e)
            // Fallback: start navigation with first route
            startNavigation(routes)
        }
    }
    
    /**
     * Hide route selection UI
     */
    private fun hideRouteSelection() {
        isShowingRouteSelection = false
        binding.routeSelectionPanel.visibility = View.GONE
    }
    
    /**
     * Display route information for all routes
     */
    private fun displayRouteInformation(routes: List<NavigationRoute>) {
        try {
            // Clear previous route info
            binding.routeInfoContainer.removeAllViews()
            
            routes.forEachIndexed { index, route ->
                val routeInfo = route.directionsRoute
                val distance = routeInfo.distance() ?: 0.0
                val duration = routeInfo.duration() ?: 0.0
                
                // Format distance
                val distanceText = if (distance >= 1000) {
                    "${DecimalFormat("#.#").format(distance / 1000)} km"
                } else {
                    "${distance.toInt()} m"
                }
                
                // Format duration
                val hours = (duration / 3600).toInt()
                val minutes = ((duration % 3600) / 60).toInt()
                val durationText = if (hours > 0) {
                    "${hours}h ${minutes}min"
                } else {
                    "${minutes}min"
                }
                
                // Create route info view
                val routeInfoView = android.widget.LinearLayout(this).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    setPadding(16, 16, 16, 16)
                    setBackgroundResource(
                        if (index == selectedRouteIndex) 
                            android.R.drawable.list_selector_background 
                        else 
                            android.R.color.transparent
                    )
                    
                    // Route label
                    addView(android.widget.TextView(this@NavigationActivity).apply {
                        text = if (index == 0) "Fastest Route" else "Alternative ${index}"
                        textSize = 16f
                        setTypeface(null, android.graphics.Typeface.BOLD)
                        setTextColor(if (index == selectedRouteIndex) 
                            android.graphics.Color.BLUE 
                        else 
                            android.graphics.Color.BLACK)
                    })
                    
                    // Distance and duration
                    addView(android.widget.TextView(this@NavigationActivity).apply {
                        text = "$distanceText • $durationText"
                        textSize = 14f
                        setTextColor(android.graphics.Color.GRAY)
                    })
                    
                    // Click listener to select this route
                    setOnClickListener {
                        selectRoute(index, routes)
                    }
                }
                
                binding.routeInfoContainer.addView(routeInfoView)
            }
            
            android.util.Log.d(TAG, "Route information displayed for ${routes.size} routes")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to display route information: ${e.message}", e)
        }
    }
    
    /**
     * Setup route click listener on map
     */
    private fun setupRouteClickListener(routes: List<NavigationRoute>) {
        try {
            binding.mapView.gestures.addOnMapClickListener { point ->
                if (isShowingRouteSelection) {
                    // Find which route was clicked
                    val clickedRouteIndex = findClickedRoute(point, routes)
                    if (clickedRouteIndex >= 0) {
                        selectRoute(clickedRouteIndex, routes)
                        return@addOnMapClickListener true
                    }
                }
                false
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to setup route click listener: ${e.message}", e)
        }
    }
    
    /**
     * Find which route was clicked based on point
     */
    private fun findClickedRoute(point: Point, routes: List<NavigationRoute>): Int {
        // Simple implementation: check distance from point to each route
        // In production, you might want more sophisticated hit testing
        var closestRouteIndex = -1
        var minDistance = Double.MAX_VALUE
        
        routes.forEachIndexed { index, route ->
            val routeGeometry = route.directionsRoute.geometry()
            if (routeGeometry != null) {
                // Calculate approximate distance from click point to route
                // This is a simplified implementation
                val distance = calculateDistanceToRoute(point, routeGeometry)
                if (distance < minDistance && distance < 0.001) { // ~100m threshold
                    minDistance = distance
                    closestRouteIndex = index
                }
            }
        }
        
        return closestRouteIndex
    }
    
    /**
     * Calculate distance from point to route (simplified)
     */
    private fun calculateDistanceToRoute(point: Point, geometry: String): Double {
        // Simplified distance calculation
        // In production, use proper geometry libraries
        return 0.0005 // Placeholder
    }
    
    /**
     * Select a specific route
     */
    private fun selectRoute(index: Int, routes: List<NavigationRoute>) {
        try {
            if (index < 0 || index >= routes.size) {
                android.util.Log.w(TAG, "Invalid route index: $index")
                return
            }
            
            selectedRouteIndex = index
            android.util.Log.d(TAG, "📍 Route $index selected")
            
            // Reorder routes to make selected route primary
            val reorderedRoutes = routes.toMutableList()
            if (index != 0) {
                val selectedRoute = reorderedRoutes.removeAt(index)
                reorderedRoutes.add(0, selectedRoute)
            }
            
            // Update route display with new primary route
            routeLineApi.setNavigationRoutes(reorderedRoutes) { result ->
                binding.mapView.mapboxMap.style?.let { style ->
                    routeLineView.renderRouteDrawData(style, result)
                }
            }
            
            // Update route information display
            displayRouteInformation(routes)
            
            // Update current routes
            currentRoutes = reorderedRoutes
            
            android.util.Log.d(TAG, "✅ Route selection updated")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to select route: ${e.message}", e)
        }
    }
    
    private fun startFreeDrive() {
        val mapboxNavigation = MapboxNavigationApp.current() ?: run {
            android.util.Log.e(TAG, "MapboxNavigation is null, cannot start free drive")
            sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
            return
        }
        
        try {
            // Start trip session without routes (free drive)
            mapboxNavigation.startTripSession()
            
            isNavigationInProgress = true
            
            android.util.Log.d(TAG, "Free drive started successfully")
            sendEvent(MapBoxEvents.NAVIGATION_RUNNING)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to start free drive: ${e.message}", e)
            sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        }
    }
    
    @OptIn(com.mapbox.navigation.base.ExperimentalPreviewMapboxNavigationAPI::class)
    private fun stopNavigation() {
        val mapboxNavigation = MapboxNavigationApp.current() ?: run {
            android.util.Log.w(TAG, "MapboxNavigation is null when stopping navigation")
            finish()
            return
        }
        
        try {
            // Stop history recording if active
            if (isRecordingHistory) {
                stopHistoryRecording()
            }
            
            // Stop replayer if it was running
            if (FlutterMapboxNavigationPlugin.simulateRoute) {
                mapboxNavigation.mapboxReplayer.stop()
                mapboxNavigation.mapboxReplayer.clearEvents()
                android.util.Log.d(TAG, "Mapbox replayer stopped")
            }
            
            // Stop trip session
            mapboxNavigation.stopTripSession()
            
            // Clear routes
            mapboxNavigation.setNavigationRoutes(emptyList())
            
            // Clear route arrows from map
            binding.mapView.mapboxMap.style?.let { style ->
                routeArrowView.render(style, routeArrowApi.clearArrows())
            }
            
            isNavigationInProgress = false
            
            // Hide control panel
            binding.navigationControlPanel.visibility = View.GONE
            
            android.util.Log.d(TAG, "Navigation stopped successfully")
            sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
            
            // Finish activity
            finish()
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error stopping navigation: ${e.message}", e)
            sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
            finish()
        }
    }
    
    // ==================== Observers ====================
    
    // Position changed listener for vanishing route line
    private val onIndicatorPositionChangedListener = com.mapbox.maps.plugin.locationcomponent.OnIndicatorPositionChangedListener { point ->
        // Update traveled route line based on current position
        val result = routeLineApi.updateTraveledRouteLine(point)
        binding.mapView.mapboxMap.style?.let { style ->
            routeLineView.renderRouteLineUpdate(style, result)
        }
    }
    
    // GPS signal quality tracking
    private var lastLocationUpdateTime = 0L
    private var isGpsSignalWeak = false
    private val GPS_SIGNAL_TIMEOUT_MS = 10000L // 10 seconds without update = weak signal
    
    private val locationObserver = object : LocationObserver {
        override fun onNewRawLocation(rawLocation: com.mapbox.common.location.Location) {
            // Required by SDK v3 - receives raw location updates
            android.util.Log.d(TAG, "📍 Raw location: lat=${rawLocation.latitude}, lng=${rawLocation.longitude}")
            
            // Update last location time
            lastLocationUpdateTime = System.currentTimeMillis()
            
            // Check if GPS signal was weak and now recovered
            if (isGpsSignalWeak) {
                isGpsSignalWeak = false
                android.util.Log.d(TAG, "✅ GPS signal recovered")
                sendEvent(MapBoxEvents.GPS_SIGNAL_RECOVERED)
                
                // Hide GPS warning UI if visible
                runOnUiThread {
                    binding.gpsWarningPanel?.visibility = View.GONE
                }
            }
        }

        override fun onNewLocationMatcherResult(locationMatcherResult: LocationMatcherResult) {
            // Convert to android.location.Location for compatibility
            val enhancedLocation = locationMatcherResult.enhancedLocation
            android.util.Log.d(TAG, "📍 Location update: lat=${enhancedLocation.latitude}, lng=${enhancedLocation.longitude}, bearing=${enhancedLocation.bearing}, speed=${enhancedLocation.speed}, isNavigationInProgress=$isNavigationInProgress")
            
            lastLocation = android.location.Location("").apply {
                latitude = enhancedLocation.latitude
                longitude = enhancedLocation.longitude
                bearing = enhancedLocation.bearing?.toFloat() ?: 0f
                speed = enhancedLocation.speed?.toFloat() ?: 0f
                accuracy = enhancedLocation.horizontalAccuracy?.toFloat() ?: 0f
            }
            
            // Check location accuracy for GPS signal quality
            val accuracy = enhancedLocation.horizontalAccuracy
            if (accuracy != null && accuracy > 50.0) {
                // Poor GPS accuracy (> 50 meters)
                android.util.Log.w(TAG, "⚠️ Poor GPS accuracy: ${accuracy}m")
                if (!isGpsSignalWeak) {
                    isGpsSignalWeak = true
                    sendEvent(MapBoxEvents.GPS_SIGNAL_WEAK)
                    
                    // Show GPS warning UI
                    runOnUiThread {
                        binding.gpsWarningPanel?.visibility = View.VISIBLE
                        binding.gpsWarningText?.text = "Weak GPS signal. Accuracy: ${accuracy.toInt()}m"
                    }
                }
            }
            
            // Update viewport data source with new location (official Turn-by-Turn pattern)
            viewportDataSource.onLocationChanged(enhancedLocation)
            viewportDataSource.evaluate()
            
            android.util.Log.d(TAG, "📷 ViewportDataSource updated with location")
        }
    }
    
    private val routeProgressObserver = RouteProgressObserver { routeProgress ->
        // Update UI
        updateNavigationUI(routeProgress)
        
        // Send progress event to Flutter
        val progressEvent = MapBoxRouteProgressEvent(routeProgress)
        FlutterMapboxNavigationPlugin.distanceRemaining = routeProgress.distanceRemaining
        FlutterMapboxNavigationPlugin.durationRemaining = routeProgress.durationRemaining
        sendEvent(progressEvent)
        
        // Update viewport data source with route progress (official Turn-by-Turn pattern)
        viewportDataSource.onRouteProgressChanged(routeProgress)
        viewportDataSource.evaluate()
        
        // Update route line with progress
        routeLineApi.updateWithRouteProgress(routeProgress) { result ->
            binding.mapView.mapboxMap.style?.let { style ->
                routeLineView.renderRouteLineUpdate(style, result)
            }
        }
        
        // Update route arrow (show upcoming maneuver arrow)
        val arrowUpdate = routeArrowApi.addUpcomingManeuverArrow(routeProgress)
        binding.mapView.mapboxMap.style?.let { style ->
            routeArrowView.renderManeuverUpdate(style, arrowUpdate)
        }
    }
    
    private val routesObserver = RoutesObserver { routeUpdateResult ->
        android.util.Log.d(TAG, "RoutesObserver triggered, routes count: ${routeUpdateResult.navigationRoutes.size}, reason: ${routeUpdateResult.reason}")
        
        if (routeUpdateResult.navigationRoutes.isNotEmpty()) {
            // Update viewport data source with new route (official Turn-by-Turn pattern)
            viewportDataSource.onRouteChanged(routeUpdateResult.navigationRoutes.first())
            viewportDataSource.evaluate()
            
            // Draw routes on map
            routeLineApi.setNavigationRoutes(routeUpdateResult.navigationRoutes) { result ->
                binding.mapView.mapboxMap.style?.let { style ->
                    routeLineView.renderRouteDrawData(style, result)
                }
            }
            
            // Send reroute event if applicable
            sendEvent(MapBoxEvents.REROUTE_ALONG)
        } else {
            // Clear route data from viewport
            viewportDataSource.clearRouteData()
            viewportDataSource.evaluate()
        }
    }
    
    private val arrivalObserver = object : ArrivalObserver {
        override fun onFinalDestinationArrival(routeProgress: RouteProgress) {
            android.util.Log.d(TAG, "🏁 Final destination arrival")
            isNavigationInProgress = false
            sendEvent(MapBoxEvents.ON_ARRIVAL)
            
            // Send detailed arrival information
            val arrivalData = mapOf(
                "isFinalDestination" to true,
                "legIndex" to routeProgress.currentLegProgress?.legIndex,
                "distanceRemaining" to routeProgress.distanceRemaining,
                "durationRemaining" to routeProgress.durationRemaining
            )
            sendEvent(MapBoxEvents.ON_ARRIVAL, org.json.JSONObject(arrivalData).toString())
        }

        override fun onNextRouteLegStart(routeLegProgress: RouteLegProgress) {
            android.util.Log.d(TAG, "🚩 Next route leg started: leg ${routeLegProgress.legIndex}")
            
            // Send waypoint arrival event when moving to next leg
            val waypointData = mapOf(
                "legIndex" to routeLegProgress.legIndex,
                "distanceRemaining" to routeLegProgress.distanceRemaining,
                "durationRemaining" to routeLegProgress.durationRemaining
            )
            sendEvent(MapBoxEvents.WAYPOINT_ARRIVAL, org.json.JSONObject(waypointData).toString())
        }

        override fun onWaypointArrival(routeProgress: RouteProgress) {
            android.util.Log.d(TAG, "📍 Waypoint arrival: leg ${routeProgress.currentLegProgress?.legIndex}")
            
            // Send waypoint arrival event
            val waypointData = mapOf(
                "isFinalDestination" to false,
                "legIndex" to routeProgress.currentLegProgress?.legIndex,
                "distanceRemaining" to routeProgress.distanceRemaining,
                "durationRemaining" to routeProgress.durationRemaining
            )
            sendEvent(MapBoxEvents.WAYPOINT_ARRIVAL, org.json.JSONObject(waypointData).toString())
        }
    }
    
    private val offRouteObserver = OffRouteObserver { offRoute ->
        if (offRoute) {
            sendEvent(MapBoxEvents.USER_OFF_ROUTE)
        }
    }
    
    private val bannerInstructionObserver = BannerInstructionsObserver { bannerInstructions ->
        // Send event to Flutter
        val text = bannerInstructions.primary().text()
        sendEvent(MapBoxEvents.BANNER_INSTRUCTION, text)
        
        // Update maneuver UI using ManeuverApi
        if (FlutterMapboxNavigationPlugin.bannerInstructionsEnabled) {
            updateManeuverUI(bannerInstructions)
        }
    }
    
    private fun updateManeuverUI(bannerInstructions: com.mapbox.api.directions.v5.models.BannerInstructions) {
        try {
            // Get maneuver data from API
            val maneuver = maneuverApi.getManeuver(bannerInstructions)
            
            maneuver.fold(
                { error ->
                    android.util.Log.e(TAG, "Failed to get maneuver: ${error.errorMessage}")
                },
                { maneuverData ->
                    // Update maneuver text
                    binding.maneuverText.text = maneuverData.primary.text
                    
                    // Update maneuver distance
                    val distance = bannerInstructions.distanceAlongGeometry()
                    val distanceText = if (distance >= 1000) {
                        "${java.text.DecimalFormat("#.#").format(distance / 1000)} km"
                    } else {
                        "${distance.toInt()} m"
                    }
                    binding.maneuverDistance.text = "In $distanceText"
                    
                    // Update maneuver icon
                    maneuverData.primary.maneuverModifier?.let { modifier ->
                        // Get turn icon based on maneuver type and modifier
                        val iconResId = getManeuverIconResource(
                            maneuverData.primary.type,
                            modifier
                        )
                        if (iconResId != 0) {
                            binding.maneuverIcon.setImageResource(iconResId)
                            binding.maneuverIcon.visibility = View.VISIBLE
                        }
                    }
                    
                    // Update next maneuver if available
                    maneuverData.secondary?.let { secondary ->
                        binding.nextManeuverText.text = "Then ${secondary.text}"
                        secondary.maneuverModifier?.let { modifier ->
                            val iconResId = getManeuverIconResource(secondary.type, modifier)
                            if (iconResId != 0) {
                                binding.nextManeuverIcon.setImageResource(iconResId)
                            }
                        }
                        binding.nextManeuverLayout.visibility = View.VISIBLE
                    } ?: run {
                        binding.nextManeuverLayout.visibility = View.GONE
                    }
                    
                    // Show maneuver panel
                    binding.maneuverPanel.visibility = View.VISIBLE
                }
            )
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to update maneuver UI: ${e.message}", e)
        }
    }
    
    private fun getManeuverIconResource(type: String?, modifier: String?): Int {
        // Map maneuver types and modifiers to Android drawable resources
        // Using system icons for now, can be replaced with custom icons
        return when (type) {
            "turn" -> when (modifier) {
                "left" -> android.R.drawable.ic_menu_directions
                "right" -> android.R.drawable.ic_menu_directions
                "slight left" -> android.R.drawable.ic_menu_directions
                "slight right" -> android.R.drawable.ic_menu_directions
                "sharp left" -> android.R.drawable.ic_menu_directions
                "sharp right" -> android.R.drawable.ic_menu_directions
                else -> android.R.drawable.ic_menu_directions
            }
            "arrive" -> android.R.drawable.ic_menu_mylocation
            "depart" -> android.R.drawable.ic_menu_mylocation
            "merge" -> android.R.drawable.ic_menu_directions
            "fork" -> android.R.drawable.ic_menu_directions
            "roundabout" -> android.R.drawable.ic_menu_rotate
            "rotary" -> android.R.drawable.ic_menu_rotate
            "continue" -> android.R.drawable.ic_menu_directions
            else -> android.R.drawable.ic_menu_directions
        }
    }
    
    private val voiceInstructionObserver = VoiceInstructionsObserver { voiceInstructions ->
        // Send event to Flutter
        sendEvent(MapBoxEvents.SPEECH_ANNOUNCEMENT, voiceInstructions.announcement() ?: "")
        
        // Play voice instruction if enabled
        if (FlutterMapboxNavigationPlugin.voiceInstructionsEnabled) {
            voiceInstructionsObserverImpl.onNewVoiceInstructions(voiceInstructions)
        }
    }
    
    // Voice Instructions Observer Implementation
    private inner class VoiceInstructionsObserverImpl {
        fun onNewVoiceInstructions(voiceInstructions: com.mapbox.api.directions.v5.models.VoiceInstructions) {
            try {
                // Generate speech announcement using Speech API
                speechApi.generate(
                    voiceInstructions,
                    object : com.mapbox.navigation.ui.voice.api.MapboxSpeechApi.VoiceCallback {
                        override fun onAvailable(announcement: com.mapbox.navigation.ui.voice.model.SpeechAnnouncement) {
                            // Play the speech announcement
                            voiceInstructionsPlayer.play(
                                announcement,
                                object : com.mapbox.navigation.ui.voice.api.VoiceInstructionsPlayerCallback {
                                    override fun onDone(announcement: com.mapbox.navigation.ui.voice.model.SpeechAnnouncement) {
                                        android.util.Log.d(TAG, "🔊 Voice instruction played successfully")
                                    }
                                }
                            )
                        }

                        override fun onError(
                            error: com.mapbox.navigation.ui.voice.model.SpeechError,
                            fallback: com.mapbox.navigation.ui.voice.model.SpeechAnnouncement
                        ) {
                            android.util.Log.w(TAG, "⚠️ Speech API error: ${error.errorMessage}, using fallback")
                            // Play fallback announcement (text-to-speech)
                            voiceInstructionsPlayer.play(
                                fallback,
                                object : com.mapbox.navigation.ui.voice.api.VoiceInstructionsPlayerCallback {
                                    override fun onDone(announcement: com.mapbox.navigation.ui.voice.model.SpeechAnnouncement) {
                                        android.util.Log.d(TAG, "🔊 Fallback voice instruction played")
                                    }
                                }
                            )
                        }
                    }
                )
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Failed to play voice instruction: ${e.message}", e)
            }
        }
    }
    
    // ==================== Map Gestures ====================
    
    private val onMapLongClick = OnMapLongClickListener { point ->
        lastLocation?.let {
            val waypointSet = WaypointSet()
            waypointSet.add(Waypoint(Point.fromLngLat(it.longitude, it.latitude)))
            waypointSet.add(Waypoint(point))
            requestRoutes(waypointSet)
        }
        true
    }
    
    private val onMapClick = OnMapClickListener { point ->
        val waypoint = mapOf(
            "latitude" to point.latitude().toString(),
            "longitude" to point.longitude().toString()
        )
        sendEvent(MapBoxEvents.ON_MAP_TAP, JSONObject(waypoint).toString())
        true
    }
    
    // ==================== UI Updates ====================
    
    private fun updateNavigationUI(routeProgress: RouteProgress) {
        try {
            // Use TripProgressApi to get formatted progress data
            val tripProgressUpdate = tripProgressApi.getTripProgress(routeProgress)
            
            // Update distance remaining
            val distanceRemaining = tripProgressUpdate.distanceRemaining
            binding.distanceRemainingText.text = distanceRemaining
            
            // Update duration remaining
            val timeRemaining = tripProgressUpdate.estimatedTimeToArrival
            binding.durationRemainingText.text = timeRemaining
            
            // Update ETA (Estimated Time of Arrival)
            val eta = tripProgressUpdate.currentLegTimeRemaining
            binding.etaText.text = formatETA(routeProgress.durationRemaining)
            
            android.util.Log.d(TAG, "📊 Progress updated: distance=$distanceRemaining, time=$timeRemaining")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to update navigation UI: ${e.message}", e)
            // Fallback to manual formatting
            updateNavigationUIFallback(routeProgress)
        }
    }
    
    private fun updateNavigationUIFallback(routeProgress: RouteProgress) {
        // Fallback: Update distance
        val distanceRemaining = routeProgress.distanceRemaining
        val distanceText = if (distanceRemaining >= 1000) {
            "${DecimalFormat("#.#").format(distanceRemaining / 1000)} km"
        } else {
            "${distanceRemaining.toInt()} m"
        }
        binding.distanceRemainingText.text = distanceText
        
        // Fallback: Update duration
        val durationRemaining = routeProgress.durationRemaining
        val hours = (durationRemaining / 3600).toInt()
        val minutes = ((durationRemaining % 3600) / 60).toInt()
        val durationText = if (hours > 0) {
            "${hours}h ${minutes}min"
        } else {
            "${minutes}min"
        }
        binding.durationRemainingText.text = durationText
        
        // Fallback: Update ETA
        binding.etaText.text = formatETA(durationRemaining)
    }
    
    private fun formatETA(durationRemaining: Double): String {
        // Calculate ETA based on current time + duration remaining
        val currentTime = System.currentTimeMillis()
        val etaTime = currentTime + (durationRemaining * 1000).toLong()
        
        val calendar = java.util.Calendar.getInstance()
        calendar.timeInMillis = etaTime
        
        val hour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        val minute = calendar.get(java.util.Calendar.MINUTE)
        
        return String.format("%02d:%02d", hour, minute)
    }
    
    // ==================== GPS Signal Monitoring ====================
    
    private var gpsMonitoringHandler: android.os.Handler? = null
    private val gpsMonitoringRunnable = object : Runnable {
        override fun run() {
            val currentTime = System.currentTimeMillis()
            val timeSinceLastUpdate = currentTime - lastLocationUpdateTime
            
            if (timeSinceLastUpdate > GPS_SIGNAL_TIMEOUT_MS && isNavigationInProgress) {
                // No GPS update for too long
                if (!isGpsSignalWeak) {
                    isGpsSignalWeak = true
                    android.util.Log.w(TAG, "⚠️ GPS signal lost - no updates for ${timeSinceLastUpdate}ms")
                    sendEvent(MapBoxEvents.GPS_SIGNAL_LOST)
                    
                    // Show GPS warning UI
                    runOnUiThread {
                        binding.gpsWarningPanel?.visibility = View.VISIBLE
                        binding.gpsWarningText?.text = "GPS signal lost. Please move to an open area."
                    }
                }
            }
            
            // Schedule next check
            gpsMonitoringHandler?.postDelayed(this, 5000) // Check every 5 seconds
        }
    }
    
    private fun startGpsSignalMonitoring() {
        gpsMonitoringHandler = android.os.Handler(android.os.Looper.getMainLooper())
        lastLocationUpdateTime = System.currentTimeMillis()
        gpsMonitoringHandler?.postDelayed(gpsMonitoringRunnable, 5000)
        android.util.Log.d(TAG, "📡 GPS signal monitoring started")
    }
    
    private fun stopGpsSignalMonitoring() {
        gpsMonitoringHandler?.removeCallbacks(gpsMonitoringRunnable)
        gpsMonitoringHandler = null
        android.util.Log.d(TAG, "📡 GPS signal monitoring stopped")
    }
    
    // ==================== Permission Handling ====================
    
    private fun checkLocationPermissions(): Boolean {
        val fineLocationGranted = androidx.core.content.ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        
        val coarseLocationGranted = androidx.core.content.ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_COARSE_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        
        if (!fineLocationGranted || !coarseLocationGranted) {
            android.util.Log.e(TAG, "❌ Location permissions not granted")
            
            // Send error event to Flutter
            val errorData = mapOf(
                "message" to "Location permissions are required for navigation",
                "type" to "PERMISSION_DENIED"
            )
            sendEvent(MapBoxEvents.NAVIGATION_CANCELLED, org.json.JSONObject(errorData).toString())
            
            return false
        }
        
        return true
    }
    
    // ==================== Network Connectivity ====================
    
    private fun isNetworkAvailable(): Boolean {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            val network = connectivityManager.activeNetwork ?: return false
            val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
            return capabilities.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET)
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = connectivityManager.activeNetworkInfo
            @Suppress("DEPRECATION")
            return networkInfo?.isConnected == true
        }
    }
    
    // ==================== Lifecycle ====================
    
    // ==================== History Recording ====================
    
    private fun startHistoryRecording() {
        try {
            val mapboxNavigation = MapboxNavigationApp.current()
            if (mapboxNavigation == null) {
                android.util.Log.e(TAG, "MapboxNavigation is null, cannot start history recording")
                sendEvent(MapBoxEvents.HISTORY_RECORDING_ERROR)
                return
            }
            
            // Start history recording using SDK v3 API
            mapboxNavigation.historyRecorder.startRecording()
            
            isRecordingHistory = true
            
            android.util.Log.d(TAG, "📹 History recording started")
            sendEvent(MapBoxEvents.HISTORY_RECORDING_STARTED)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to start history recording: ${e.message}", e)
            sendEvent(MapBoxEvents.HISTORY_RECORDING_ERROR)
        }
    }
    
    private fun stopHistoryRecording() {
        try {
            val mapboxNavigation = MapboxNavigationApp.current()
            if (mapboxNavigation == null) {
                android.util.Log.w(TAG, "MapboxNavigation is null when stopping history recording")
                isRecordingHistory = false
                currentHistoryFilePath = null
                return
            }
            
            // Stop history recording
            mapboxNavigation.historyRecorder.stopRecording { historyFilePath ->
                if (historyFilePath != null) {
                    android.util.Log.d(TAG, "📹 History recording stopped and saved: $historyFilePath")
                    currentHistoryFilePath = historyFilePath
                    
                    // Send file path to Flutter
                    val eventData = mapOf(
                        "historyFilePath" to historyFilePath
                    )
                    sendEvent(
                        MapBoxEvents.HISTORY_RECORDING_STOPPED,
                        org.json.JSONObject(eventData).toString()
                    )
                } else {
                    android.util.Log.w(TAG, "📹 History recording stopped but no file path returned")
                    sendEvent(MapBoxEvents.HISTORY_RECORDING_STOPPED)
                }
            }
            
            isRecordingHistory = false
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to stop history recording: ${e.message}", e)
            isRecordingHistory = false
            currentHistoryFilePath = null
            sendEvent(MapBoxEvents.HISTORY_RECORDING_ERROR)
        }
    }
    
    // ==================== Lifecycle ====================
    
    override fun onDestroy() {
        super.onDestroy()
        
        try {
            // Stop GPS signal monitoring
            stopGpsSignalMonitoring()
            
            // Clean up voice instructions
            try {
                voiceInstructionsPlayer.shutdown()
                speechApi.cancel()
                android.util.Log.d(TAG, "Voice instructions cleaned up")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error cleaning up voice instructions: ${e.message}", e)
            }
            
            // Unregister broadcast receivers
            unregisterReceiver(finishBroadcastReceiver)
            unregisterReceiver(addWayPointsBroadcastReceiver)
            
            // Unregister navigation observer
            MapboxNavigationApp.unregisterObserver(mapboxNavigationObserver)
            
            // Clean up map
            binding.mapView.gestures.removeOnMapLongClickListener(onMapLongClick)
            binding.mapView.gestures.removeOnMapClickListener(onMapClick)
            
            // Remove position changed listener
            binding.mapView.location.removeOnIndicatorPositionChangedListener(onIndicatorPositionChangedListener)
            
            // Unregister map view from MapStyleManager
            MapStyleManager.unregisterMapView(binding.mapView)
            
            android.util.Log.d(TAG, "NavigationActivity destroyed successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error in onDestroy: ${e.message}", e)
        }
    }
}
