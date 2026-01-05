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
    
    // Route Line API for drawing routes on map
    private lateinit var routeLineApi: MapboxRouteLineApi
    private lateinit var routeLineView: MapboxRouteLineView
    
    // Navigation Camera for automatic camera management (following official Turn-by-Turn pattern)
    private lateinit var navigationCamera: NavigationCamera
    private lateinit var viewportDataSource: MapboxNavigationViewportDataSource
    
    // Replay Route Mapper for simulation
    private val replayRouteMapper = com.mapbox.navigation.core.replay.route.ReplayRouteMapper()
    
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
            
            android.util.Log.d(TAG, "Map initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to initialize map: ${e.message}", e)
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
                // You can update UI based on camera state here
                // For example, show/hide recenter button
            }
            
            android.util.Log.d(TAG, "Navigation camera initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to initialize navigation camera: ${e.message}", e)
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
        
        android.util.Log.d(TAG, "Route line initialized with vanishing route line enabled (transparent style)")
    }
    
    private fun setupUI() {
        // End Navigation Button
        binding.endNavigationButton.setOnClickListener {
            stopNavigation()
        }
        
        // Initially hide control panel
        binding.navigationControlPanel.visibility = View.GONE
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
        sendEvent(MapBoxEvents.ROUTE_BUILDING)
        
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
                    sendEvent(MapBoxEvents.ROUTE_BUILD_CANCELLED)
                }

                override fun onFailure(reasons: List<RouterFailure>, routeOptions: RouteOptions) {
                    sendEvent(MapBoxEvents.ROUTE_BUILD_FAILED)
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
                    startNavigation(routes)
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
            
            sendEvent(MapBoxEvents.NAVIGATION_RUNNING)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to start navigation: ${e.message}", e)
            sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        }
    }
    
    // Note: adjustCameraToRoute is no longer needed as NavigationCamera handles this automatically
    
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
    
    private val locationObserver = object : LocationObserver {
        override fun onNewRawLocation(rawLocation: com.mapbox.common.location.Location) {
            // Required by SDK v3 - receives raw location updates
            android.util.Log.d(TAG, "📍 Raw location: lat=${rawLocation.latitude}, lng=${rawLocation.longitude}")
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
            isNavigationInProgress = false
            sendEvent(MapBoxEvents.ON_ARRIVAL)
        }

        override fun onNextRouteLegStart(routeLegProgress: RouteLegProgress) {
            // Waypoint arrival
        }

        override fun onWaypointArrival(routeProgress: RouteProgress) {
            // Waypoint arrival
        }
    }
    
    private val offRouteObserver = OffRouteObserver { offRoute ->
        if (offRoute) {
            sendEvent(MapBoxEvents.USER_OFF_ROUTE)
        }
    }
    
    private val bannerInstructionObserver = BannerInstructionsObserver { bannerInstructions ->
        val text = bannerInstructions.primary().text()
        binding.maneuverText.text = text
        binding.maneuverPanel.visibility = View.VISIBLE
        sendEvent(MapBoxEvents.BANNER_INSTRUCTION, text)
    }
    
    private val voiceInstructionObserver = VoiceInstructionsObserver { voiceInstructions ->
        sendEvent(MapBoxEvents.SPEECH_ANNOUNCEMENT, voiceInstructions.announcement() ?: "")
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
        // Update distance
        val distanceRemaining = routeProgress.distanceRemaining
        val distanceText = if (distanceRemaining >= 1000) {
            "${DecimalFormat("#.#").format(distanceRemaining / 1000)} km"
        } else {
            "${distanceRemaining.toInt()} m"
        }
        binding.distanceRemainingText.text = distanceText
        
        // Update duration
        val durationRemaining = routeProgress.durationRemaining
        val hours = (durationRemaining / 3600).toInt()
        val minutes = ((durationRemaining % 3600) / 60).toInt()
        val durationText = if (hours > 0) {
            "${hours}h ${minutes}min"
        } else {
            "${minutes}min"
        }
        binding.durationRemainingText.text = durationText
    }
    
    // ==================== Lifecycle ====================
    
    override fun onDestroy() {
        super.onDestroy()
        
        try {
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
