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
    
    // MapboxNavigation observer for lifecycle management
    private val mapboxNavigationObserver = object : MapboxNavigationObserver {
        override fun onAttached(mapboxNavigation: MapboxNavigation) {
            // Register observers when navigation is attached
            mapboxNavigation.registerLocationObserver(locationObserver)
            mapboxNavigation.registerRouteProgressObserver(routeProgressObserver)
            mapboxNavigation.registerRoutesObserver(routesObserver)
            mapboxNavigation.registerArrivalObserver(arrivalObserver)
            mapboxNavigation.registerOffRouteObserver(offRouteObserver)
            mapboxNavigation.registerBannerInstructionsObserver(bannerInstructionObserver)
            mapboxNavigation.registerVoiceInstructionsObserver(voiceInstructionObserver)
        }

        override fun onDetached(mapboxNavigation: MapboxNavigation) {
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
        // In SDK v3, access token is automatically retrieved from resources
        val navigationOptions = NavigationOptions.Builder(this.applicationContext)
            .build()
        
        MapboxNavigationApp
            .setup { navigationOptions }
            .attach(this)
        
        // Register navigation observer
        MapboxNavigationApp.registerObserver(mapboxNavigationObserver)
    }
    
    private fun initializeMap() {
        // Load map style
        var styleUrl = FlutterMapboxNavigationPlugin.mapStyleUrlDay ?: Style.MAPBOX_STREETS
        
        binding.mapView.getMapboxMap().loadStyleUri(styleUrl) { style ->
            // Enable location component
            binding.mapView.location.updateSettings {
                enabled = true
                pulsingEnabled = true
            }
        }
        
        // Setup map gestures
        if (FlutterMapboxNavigationPlugin.longPressDestinationEnabled) {
            binding.mapView.gestures.addOnMapLongClickListener(onMapLongClick)
        }
        
        if (FlutterMapboxNavigationPlugin.enableOnMapTapCallback) {
            binding.mapView.gestures.addOnMapClickListener(onMapClick)
        }
    }
    
    private fun initializeRouteLine() {
        val apiOptions = MapboxRouteLineApiOptions.Builder()
            .build()
        
        val viewOptions = MapboxRouteLineViewOptions.Builder(this)
            .build()
        
        routeLineApi = MapboxRouteLineApi(apiOptions)
        routeLineView = MapboxRouteLineView(viewOptions)
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
        
        registerReceiver(
            finishBroadcastReceiver,
            IntentFilter(NavigationLauncher.KEY_STOP_NAVIGATION)
        )
        
        registerReceiver(
            addWayPointsBroadcastReceiver,
            IntentFilter(NavigationLauncher.KEY_ADD_WAYPOINTS)
        )
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
        val mapboxNavigation = MapboxNavigationApp.current() ?: return
        
        // Set routes
        mapboxNavigation.setNavigationRoutes(routes)
        
        // Start trip session
        mapboxNavigation.startTripSession()
        
        // Enable replay if simulating
        if (FlutterMapboxNavigationPlugin.simulateRoute) {
            mapboxNavigation.startReplayTripSession()
        }
        
        isNavigationInProgress = true
        
        // Show control panel
        binding.navigationControlPanel.visibility = View.VISIBLE
        
        sendEvent(MapBoxEvents.NAVIGATION_RUNNING)
    }
    
    private fun startFreeDrive() {
        val mapboxNavigation = MapboxNavigationApp.current() ?: return
        
        // Start trip session without routes (free drive)
        mapboxNavigation.startTripSession()
        
        isNavigationInProgress = true
        
        sendEvent(MapBoxEvents.NAVIGATION_RUNNING)
    }
    
    private fun stopNavigation() {
        val mapboxNavigation = MapboxNavigationApp.current() ?: return
        
        // Stop trip session
        mapboxNavigation.stopTripSession()
        
        // Clear routes
        mapboxNavigation.setNavigationRoutes(emptyList())
        
        isNavigationInProgress = false
        
        // Hide control panel
        binding.navigationControlPanel.visibility = View.GONE
        
        sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        
        // Finish activity
        finish()
    }
    
    // ==================== Observers ====================
    
    private val locationObserver = object : LocationObserver {
        override fun onNewRawLocation(rawLocation: com.mapbox.common.location.Location) {
            // Required by SDK v3 but not used in MVP
        }

        override fun onNewLocationMatcherResult(locationMatcherResult: LocationMatcherResult) {
            // Convert to android.location.Location for compatibility
            val enhancedLocation = locationMatcherResult.enhancedLocation
            lastLocation = android.location.Location("").apply {
                latitude = enhancedLocation.latitude
                longitude = enhancedLocation.longitude
                bearing = enhancedLocation.bearing?.toFloat() ?: 0f
                speed = enhancedLocation.speed?.toFloat() ?: 0f
            }
            
            // Update camera to follow location
            val cameraOptions = CameraOptions.Builder()
                .center(Point.fromLngLat(
                    enhancedLocation.longitude,
                    enhancedLocation.latitude
                ))
                .zoom(15.0)
                .bearing(enhancedLocation.bearing?.toDouble() ?: 0.0)
                .pitch(45.0)
                .build()
            
            binding.mapView.camera.easeTo(cameraOptions)
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
        
        // Update route line
        routeLineApi.updateWithRouteProgress(routeProgress) { result ->
            binding.mapView.getMapboxMap().getStyle()?.let { style ->
                routeLineView.renderRouteLineUpdate(style, result)
            }
        }
    }
    
    private val routesObserver = RoutesObserver { routeUpdateResult ->
        if (routeUpdateResult.navigationRoutes.isNotEmpty()) {
            // Draw routes on map
            routeLineApi.setNavigationRoutes(routeUpdateResult.navigationRoutes) { result ->
                binding.mapView.getMapboxMap().getStyle()?.let { style ->
                    routeLineView.renderRouteDrawData(style, result)
                }
            }
            
            // Camera to route overview
            val routes = routeUpdateResult.navigationRoutes
            if (routes.isNotEmpty()) {
                val routePoints = routes.first().directionsRoute.geometry()?.let { geometry ->
                    com.mapbox.geojson.LineString.fromPolyline(geometry, 6).coordinates()
                }
                
                if (routePoints != null && routePoints.isNotEmpty()) {
                    val cameraOptions = binding.mapView.getMapboxMap().cameraForCoordinates(
                        routePoints,
                        EdgeInsets(100.0, 100.0, 100.0, 100.0)
                    )
                    binding.mapView.camera.easeTo(cameraOptions)
                }
            }
            
            sendEvent(MapBoxEvents.REROUTE_ALONG)
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
        
        // Unregister broadcast receivers
        unregisterReceiver(finishBroadcastReceiver)
        unregisterReceiver(addWayPointsBroadcastReceiver)
        
        // Unregister navigation observer
        MapboxNavigationApp.unregisterObserver(mapboxNavigationObserver)
        
        // Clean up map
        binding.mapView.gestures.removeOnMapLongClickListener(onMapLongClick)
        binding.mapView.gestures.removeOnMapClickListener(onMapClick)
    }
}
