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
import com.eopeter.fluttermapboxnavigation.utilities.StylePreferenceManager
import com.google.gson.Gson
import com.mapbox.api.directions.v5.models.RouteOptions
import com.mapbox.geojson.Point
import com.mapbox.bindgen.Expected
import com.mapbox.maps.CameraOptions
import com.mapbox.maps.EdgeInsets
import com.mapbox.maps.Style
import com.mapbox.maps.plugin.animation.camera
import com.mapbox.maps.plugin.gestures.OnMapClickListener
import com.mapbox.maps.plugin.gestures.OnMapLongClickListener
import com.mapbox.maps.plugin.gestures.gestures
import com.mapbox.maps.plugin.locationcomponent.location
import com.mapbox.maps.plugin.LocationPuck2D
import com.mapbox.maps.ImageHolder
import com.mapbox.navigation.ui.maps.location.NavigationLocationProvider
import com.mapbox.navigation.voice.model.SpeechVolume
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
import com.mapbox.navigation.voice.api.MapboxSpeechApi
import com.mapbox.navigation.voice.api.MapboxVoiceInstructionsPlayer
import com.mapbox.navigation.voice.model.SpeechAnnouncement
import com.mapbox.navigation.voice.model.SpeechError
import com.mapbox.navigation.voice.model.SpeechValue
import com.mapbox.navigation.ui.maps.route.arrow.api.MapboxRouteArrowApi
import com.mapbox.navigation.ui.maps.route.arrow.api.MapboxRouteArrowView
import com.mapbox.navigation.ui.maps.route.arrow.model.RouteArrowOptions
import com.mapbox.navigation.tripdata.maneuver.api.MapboxManeuverApi
import com.mapbox.navigation.tripdata.progress.api.MapboxTripProgressApi
import com.mapbox.navigation.tripdata.progress.model.DistanceRemainingFormatter
import com.mapbox.navigation.tripdata.progress.model.EstimatedTimeToArrivalFormatter
import com.mapbox.navigation.tripdata.progress.model.PercentDistanceTraveledFormatter
import com.mapbox.navigation.tripdata.progress.model.TimeRemainingFormatter
import com.mapbox.navigation.tripdata.progress.model.TripProgressUpdateFormatter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import com.mapbox.navigation.base.formatter.DistanceFormatterOptions
import com.mapbox.navigation.core.formatter.MapboxDistanceFormatter
import com.mapbox.navigation.base.TimeFormat
import com.mapbox.navigation.ui.base.util.MapboxNavigationConsumer
import com.mapbox.navigation.ui.components.maneuver.view.MapboxManeuverView
import com.mapbox.navigation.ui.components.tripprogress.view.MapboxTripProgressView
import org.json.JSONObject
import java.text.DecimalFormat

/**
 * NavigationActivity - Mapbox Navigation SDK v3 Implementation
 * 
 * This implementation follows the official Mapbox Navigation SDK v3 patterns and best practices.
 * Reference: https://github.com/mapbox/mapbox-navigation-android-examples
 * 
 * Key Features:
 * - Uses MapboxNavigationApp lifecycle management (SDK v3 official pattern)
 * - Implements NavigationCamera for automatic camera transitions
 * - Uses MapboxRouteLineApi/View for route rendering with vanishing route line
 * - Integrates MapboxSpeechApi and MapboxVoiceInstructionsPlayer for voice guidance
 * - Supports MapboxManeuverApi and MapboxTripProgressApi for UI updates
 * - Implements route selection with alternative routes
 * - Includes history recording capabilities
 * - Supports both real and simulated navigation
 * 
 * SDK v3 Changes from v2:
 * - Voice/Maneuver/TripProgress APIs moved to tripdata package
 * - UI components available in ui-components package
 * - MapboxNavigationApp replaces direct MapboxNavigation instantiation
 * - NavigationCamera replaces manual camera management
 * - Expected<Error, Value> pattern for async operations
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
    private lateinit var routeArrowApi: MapboxRouteArrowApi
    private lateinit var routeArrowView: MapboxRouteArrowView
    
    // Maneuver API for turn instructions (from tripdata package in SDK v3)
    private lateinit var maneuverApi: MapboxManeuverApi
    
    // Trip Progress API for progress information (from tripdata package in SDK v3)
    private lateinit var tripProgressApi: MapboxTripProgressApi
    
    // History Recording
    private var isRecordingHistory = false
    private var currentHistoryFilePath: String? = null
    private var navigationStartTime: Long = 0L
    private var navigationInitialDistance: Float? = null  // 初始路线总距离
    private var navigationDistanceTraveled: Float = 0f    // 已行驶距离
    
    // Navigation Camera for automatic camera management (following official Turn-by-Turn pattern)
    private lateinit var navigationCamera: NavigationCamera
    private lateinit var viewportDataSource: MapboxNavigationViewportDataSource
    
    // Camera state tracking
    private var isCameraFollowing = true
    private var userHasMovedMap = false
    
    // Replay Route Mapper for simulation
    private val replayRouteMapper = com.mapbox.navigation.core.replay.route.ReplayRouteMapper()
    
    // Voice Instructions components
    private lateinit var speechApi: com.mapbox.navigation.voice.api.MapboxSpeechApi
    private lateinit var voiceInstructionsPlayer: com.mapbox.navigation.voice.api.MapboxVoiceInstructionsPlayer
    private val voiceInstructionsObserverImpl = VoiceInstructionsObserverImpl()
    
    // NavigationLocationProvider for location puck (官方示例模式)
    private val navigationLocationProvider = NavigationLocationProvider()
    
    // Voice instructions mute state (官方示例模式)
    private var isVoiceInstructionsMuted = false
        set(value) {
            field = value
            if (value) {
                binding.soundButton?.muteAndExtend(1500L)
                voiceInstructionsPlayer.volume(SpeechVolume(0f))
            } else {
                binding.soundButton?.unmuteAndExtend(1500L)
                voiceInstructionsPlayer.volume(SpeechVolume(1f))
            }
        }
    
    // 存储待处理的路线请求
    private var pendingWaypointSet: WaypointSet? = null
    private var isNavigationReady = false
    
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
            
            // 标记导航已准备好
            isNavigationReady = true
            
            // 处理待处理的路线请求
            pendingWaypointSet?.let { waypointSet ->
                android.util.Log.d(TAG, "🚀 Processing pending route request")
                requestRoutes(waypointSet)
                pendingWaypointSet = null
            }
        }

        override fun onDetached(mapboxNavigation: MapboxNavigation) {
            android.util.Log.d(TAG, "🔌 MapboxNavigationObserver onDetached - unregistering observers")
            isNavigationReady = false
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
        
        // Initialize Maneuver API (SDK v3 style)
        initializeManeuverApi()
        
        // Initialize Trip Progress API (SDK v3 style)
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
        
        // Get waypoints from intent
        val p = intent.getSerializableExtra("waypoints") as? MutableList<Waypoint>
        if (p != null) {
            points = p
            points.map { waypointSet.add(it) }
            
            // 如果导航已经准备好，立即请求路线；否则存储待处理
            if (isNavigationReady) {
                android.util.Log.d(TAG, "🚀 Navigation ready, requesting routes immediately")
                requestRoutes(waypointSet)
            } else {
                pendingWaypointSet = waypointSet
                android.util.Log.d(TAG, "📦 Waypoints stored, waiting for MapboxNavigationApp to be ready")
            }
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
            
            // Initialize location puck (官方示例模式 - 在 initNavigation 中初始化)
            // 设置 puck 在最上层，使用 topImage 确保可见性
            binding.mapView.location.apply {
                setLocationProvider(navigationLocationProvider)
                this.locationPuck = LocationPuck2D(
                    topImage = ImageHolder.from(
                        com.mapbox.navigation.ui.maps.R.drawable.mapbox_navigation_puck_icon
                    ),
                    bearingImage = ImageHolder.from(
                        com.mapbox.navigation.ui.maps.R.drawable.mapbox_navigation_puck_icon
                    )
                )
                puckBearingEnabled = true
                enabled = true
            }
            
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
            
            // Priority: Plugin override > User preference > Default
            // This maintains backward compatibility while supporting user preferences
            val styleUrl = when {
                FlutterMapboxNavigationPlugin.mapStyleUrlDay != null -> {
                    // Use plugin override (backward compatibility)
                    android.util.Log.d(TAG, "Using plugin override style: ${FlutterMapboxNavigationPlugin.mapStyleUrlDay}")
                    FlutterMapboxNavigationPlugin.mapStyleUrlDay!!
                }
                else -> {
                    // Use saved user preference (new behavior)
                    val savedStyle = StylePreferenceManager.getMapStyleUrl(this)
                    android.util.Log.d(TAG, "Using saved user preference style: $savedStyle")
                    savedStyle
                }
            }
            
            // Set day and night styles for MapStyleManager
            val dayStyle = FlutterMapboxNavigationPlugin.mapStyleUrlDay ?: styleUrl
            val nightStyle = FlutterMapboxNavigationPlugin.mapStyleUrlNight ?: Style.DARK
            MapStyleManager.setDayStyle(dayStyle)
            MapStyleManager.setNightStyle(nightStyle)
            
            // Load map style
            binding.mapView.mapboxMap.loadStyle(styleUrl) { style ->
                // Apply Light Preset if the style supports it
                StylePreferenceManager.applyLightPresetToStyle(this, style)
                
                // 初始化路线层级 (官方示例模式)
                // 先初始化路线层，这样它们会在 location puck 下方
                routeLineView.initializeLayers(style)
                
                // 确保 location puck 在最上层
                // 通过重新设置 location provider 来刷新 puck 层级
                binding.mapView.location.apply {
                    enabled = false
                    enabled = true
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
            
            // Register camera state change observer (官方示例模式)
            navigationCamera.registerNavigationCameraStateChangeObserver { navigationCameraState ->
                android.util.Log.d(TAG, "📷 Camera state changed: $navigationCameraState")
                
                // Update camera following state
                isCameraFollowing = when (navigationCameraState) {
                    NavigationCameraState.FOLLOWING -> true
                    NavigationCameraState.OVERVIEW -> false
                    NavigationCameraState.IDLE -> false
                    else -> isCameraFollowing
                }
                
                // 根据相机状态显示/隐藏 recenter 按钮 (官方示例模式)
                when (navigationCameraState) {
                    NavigationCameraState.TRANSITION_TO_FOLLOWING,
                    NavigationCameraState.FOLLOWING -> binding.recenter?.visibility = View.INVISIBLE
                    NavigationCameraState.TRANSITION_TO_OVERVIEW,
                    NavigationCameraState.OVERVIEW,
                    NavigationCameraState.IDLE -> binding.recenter?.visibility = View.VISIBLE
                }
            }
            
            android.util.Log.d(TAG, "Navigation camera initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to initialize navigation camera: ${e.message}", e)
        }
    }
    
    private fun initializeVoiceInstructions() {
        try {
            // Initialize Speech API for voice instructions (SDK v3 style)
            speechApi = MapboxSpeechApi(
                this,
                FlutterMapboxNavigationPlugin.navigationLanguage
            )
            
            // Initialize Voice Instructions Player
            voiceInstructionsPlayer = MapboxVoiceInstructionsPlayer(
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
            // Initialize Maneuver API following official example
            val distanceFormatterOptions = DistanceFormatterOptions.Builder(this).build()
            maneuverApi = MapboxManeuverApi(
                MapboxDistanceFormatter(distanceFormatterOptions)
            )
            
            android.util.Log.d(TAG, "Maneuver API initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to initialize maneuver API: ${e.message}", e)
        }
    }
    
    private fun initializeTripProgressApi() {
        try {
            // Initialize Trip Progress API following official example
            val distanceFormatterOptions = DistanceFormatterOptions.Builder(this).build()
            
            tripProgressApi = MapboxTripProgressApi(
                TripProgressUpdateFormatter.Builder(this)
                    .distanceRemainingFormatter(DistanceRemainingFormatter(distanceFormatterOptions))
                    .timeRemainingFormatter(TimeRemainingFormatter(this))
                    .percentRouteTraveledFormatter(PercentDistanceTraveledFormatter())
                    .estimatedTimeToArrivalFormatter(EstimatedTimeToArrivalFormatter(this, TimeFormat.NONE_SPECIFIED))
                    .build()
            )
            
            android.util.Log.d(TAG, "Trip Progress API initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to initialize trip progress API: ${e.message}", e)
        }
    }
    
    private fun initializeRouteLine() {
        // Configure vanishing route line (SDK v3 official feature)
        // This makes the traveled portion of the route transparent as you progress
        val customColorResources = com.mapbox.navigation.ui.maps.route.line.model.RouteLineColorResources.Builder()
            .routeLineTraveledColor(android.graphics.Color.TRANSPARENT) // Traveled route becomes transparent
            .routeLineTraveledCasingColor(android.graphics.Color.TRANSPARENT) // Traveled route casing also transparent
            .build()
        
        val apiOptions = MapboxRouteLineApiOptions.Builder()
            .vanishingRouteLineEnabled(true) // Enable vanishing route line feature
            .styleInactiveRouteLegsIndependently(true) // Style inactive route legs independently
            .build()
        
        // 设置路线层级，确保路线在 location puck 下方
        // 不指定 routeLineBelowLayerId，让路线层自动放置在合适的位置
        // location puck 会自动显示在最上层
        val viewOptions = MapboxRouteLineViewOptions.Builder(this)
            .routeLineColorResources(customColorResources) // Apply custom colors
            .build()
        
        routeLineApi = MapboxRouteLineApi(apiOptions)
        routeLineView = MapboxRouteLineView(viewOptions)
        
        // Initialize Route Arrow API for turn arrows (SDK v3 official pattern)
        routeArrowApi = MapboxRouteArrowApi()
        routeArrowView = MapboxRouteArrowView(
            RouteArrowOptions.Builder(this).build()
        )
        
        android.util.Log.d(TAG, "Route line and arrow initialized with vanishing route line enabled")
    }
    
    private fun setupUI() {
        // Stop/End Navigation Button (官方组件)
        binding.stop?.setOnClickListener {
            stopNavigation()
        }
        
        // Recenter Button (官方组件)
        binding.recenter?.setOnClickListener {
            navigationCamera.requestNavigationCameraToFollowing()
            binding.routeOverview?.showTextAndExtend(1500L)
        }
        
        // Route Overview Button (官方组件)
        binding.routeOverview?.setOnClickListener {
            navigationCamera.requestNavigationCameraToOverview()
            binding.recenter?.showTextAndExtend(1500L)
        }
        
        // Sound Button (官方组件) - 静音/取消静音语音指令
        binding.soundButton?.setOnClickListener {
            isVoiceInstructionsMuted = !isVoiceInstructionsMuted
        }
        
        // 设置初始声音按钮状态
        binding.soundButton?.unmute()
        
        // 初始隐藏官方 UI 组件
        binding.tripProgressCard?.visibility = View.INVISIBLE
        binding.maneuverView?.visibility = View.INVISIBLE
        binding.soundButton?.visibility = View.INVISIBLE
        binding.routeOverview?.visibility = View.INVISIBLE
        
        // 自定义组件
        binding.gpsWarningPanel?.visibility = View.GONE
        binding.routeSelectionPanel?.visibility = View.GONE
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
        
        // 检查 MapboxNavigationApp 是否已初始化
        val mapboxNavigation = MapboxNavigationApp.current()
        if (mapboxNavigation == null) {
            android.util.Log.e(TAG, "❌ MapboxNavigationApp.current() is null!")
            val errorData = mapOf(
                "message" to "MapboxNavigation not initialized",
                "type" to "INITIALIZATION_ERROR"
            )
            sendEvent(MapBoxEvents.ROUTE_BUILD_FAILED, org.json.JSONObject(errorData).toString())
            return
        }
        
        android.util.Log.d(TAG, "✅ MapboxNavigationApp is initialized")
        
        // 添加超时检测
        val timeoutHandler = android.os.Handler(android.os.Looper.getMainLooper())
        var isCallbackReceived = false
        
        val timeoutRunnable = Runnable {
            if (!isCallbackReceived) {
                android.util.Log.e(TAG, "⏱️ Route request timeout after 30 seconds")
                
                if (currentAttempt < maxRetries) {
                    val delayMs = (1000 * currentAttempt).toLong()
                    android.util.Log.d(TAG, "🔄 Retrying due to timeout in ${delayMs}ms...")
                    
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        requestRoutesWithRetry(waypointSet, maxRetries, currentAttempt + 1)
                    }, delayMs)
                } else {
                    val errorData = mapOf(
                        "message" to "Route request timed out after $maxRetries attempts",
                        "type" to "TIMEOUT_ERROR",
                        "attempts" to currentAttempt
                    )
                    sendEvent(MapBoxEvents.ROUTE_BUILD_FAILED, org.json.JSONObject(errorData).toString())
                }
            }
        }
        
        // 设置 30 秒超时
        timeoutHandler.postDelayed(timeoutRunnable, 30000)
        
        android.util.Log.d(TAG, "📡 Calling MapboxNavigationApp.requestRoutes()...")
        
        mapboxNavigation.requestRoutes(
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
                    isCallbackReceived = true
                    timeoutHandler.removeCallbacks(timeoutRunnable)
                    android.util.Log.w(TAG, "⚠️ Route request canceled")
                    sendEvent(MapBoxEvents.ROUTE_BUILD_CANCELLED)
                }

                override fun onFailure(reasons: List<RouterFailure>, routeOptions: RouteOptions) {
                    isCallbackReceived = true
                    timeoutHandler.removeCallbacks(timeoutRunnable)
                    
                    // Log detailed failure information
                    android.util.Log.e(TAG, "❌ Route request failed:")
                    android.util.Log.e(TAG, "   Attempt: $currentAttempt/$maxRetries")
                    android.util.Log.e(TAG, "   Number of failures: ${reasons.size}")
                    reasons.forEachIndexed { index, failure ->
                        android.util.Log.e(TAG, "   Failure #${index + 1}:")
                        android.util.Log.e(TAG, "     Message: ${failure.message}")
                        android.util.Log.e(TAG, "     Throwable: ${failure.throwable?.message}")
                        android.util.Log.e(TAG, "     Stack trace: ${failure.throwable?.stackTraceToString()}")
                    }
                    
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
                    
                    android.util.Log.e(TAG, "❌ Processed error message: $errorMessage")
                    
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
                    isCallbackReceived = true
                    timeoutHandler.removeCallbacks(timeoutRunnable)
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
            
            // Update viewport data source with the route BEFORE requesting camera overview
            // This is critical for the camera to know where to position itself
            viewportDataSource.onRouteChanged(routes.first())
            viewportDataSource.evaluate()
            android.util.Log.d(TAG, "📍 Viewport data source updated with route")
            
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
            
            // 显示官方 UI 组件
            binding.tripProgressCard?.visibility = View.VISIBLE
            binding.maneuverView?.visibility = View.VISIBLE
            binding.soundButton?.visibility = View.VISIBLE
            binding.routeOverview?.visibility = View.VISIBLE
            
            // Capture initial route distance for history recording
            navigationInitialDistance = routes.firstOrNull()?.directionsRoute?.distance()?.toFloat()
            navigationDistanceTraveled = 0f
            android.util.Log.d(TAG, "Initial route distance: ${navigationInitialDistance}m")
            
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
            
            // 官方 MapboxRecenterButton 会自动处理
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
            
            // Update viewport data source with the first route BEFORE requesting camera overview
            viewportDataSource.onRouteChanged(routes.first())
            viewportDataSource.evaluate()
            android.util.Log.d(TAG, "📍 Viewport data source updated with route for selection")
            
            // Draw all routes on map with different styles
            routeLineApi.setNavigationRoutes(routes) { result ->
                binding.mapView.mapboxMap.style?.let { style ->
                    routeLineView.renderRouteDrawData(style, result)
                    android.util.Log.d(TAG, "All routes drawn on map")
                }
            }
            
            // Show route overview camera
            navigationCamera.requestNavigationCameraToOverview()
            android.util.Log.d(TAG, "📷 Requested camera overview for route selection")
            
            // Show route selection UI
            binding.routeSelectionPanel.visibility = View.VISIBLE
            
            // 隐藏官方 UI 组件
            binding.tripProgressCard?.visibility = View.GONE
            binding.maneuverView?.visibility = View.GONE
            binding.soundButton?.visibility = View.GONE
            binding.routeOverview?.visibility = View.GONE
            
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
     * Calculate distance from point to route
     * Note: This is a simplified placeholder implementation
     * For production use, consider using Mapbox's geometry libraries or Turf.js equivalent
     */
    private fun calculateDistanceToRoute(point: Point, geometry: String): Double {
        // TODO: Implement proper distance calculation using geometry libraries
        // For now, return a small threshold value for basic functionality
        return 0.0005 // ~50m threshold
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
            
            // 隐藏官方 UI 组件
            binding.tripProgressCard?.visibility = View.GONE
            binding.maneuverView?.visibility = View.GONE
            binding.soundButton?.visibility = View.GONE
            binding.routeOverview?.visibility = View.GONE
            
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
        var firstLocationUpdateReceived = false
        
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
            
            // 更新位置 puck 的位置 (官方示例模式)
            navigationLocationProvider.changePosition(
                location = enhancedLocation,
                keyPoints = locationMatcherResult.keyPoints,
            )
            
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
            
            // 如果是第一次收到位置更新，立即移动相机到当前位置
            if (!firstLocationUpdateReceived) {
                firstLocationUpdateReceived = true
                navigationCamera.requestNavigationCameraToOverview(
                    stateTransitionOptions = com.mapbox.navigation.ui.maps.camera.transition.NavigationCameraTransitionOptions.Builder()
                        .maxDuration(0) // instant transition
                        .build()
                )
            }
            
            android.util.Log.d(TAG, "📷 ViewportDataSource updated with location")
        }
    }
    
    private val routeProgressObserver = RouteProgressObserver { routeProgress ->
        // Track distance traveled for history recording
        if (isRecordingHistory) {
            navigationDistanceTraveled = routeProgress.distanceTraveled
        }
        
        // 📊 Log detailed route progress information
        android.util.Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        android.util.Log.d(TAG, "📍 Route Progress Update:")
        android.util.Log.d(TAG, "   Distance Remaining: ${String.format("%.1f", routeProgress.distanceRemaining)}m")
        android.util.Log.d(TAG, "   Duration Remaining: ${String.format("%.1f", routeProgress.durationRemaining)}s")
        android.util.Log.d(TAG, "   Distance Traveled: ${String.format("%.1f", routeProgress.distanceTraveled)}m")
        android.util.Log.d(TAG, "   Leg Index: ${routeProgress.currentLegProgress?.legIndex}")
        android.util.Log.d(TAG, "   Step Index: ${routeProgress.currentLegProgress?.currentStepProgress?.stepIndex}")
        android.util.Log.d(TAG, "   Current Step Distance Remaining: ${String.format("%.1f", routeProgress.currentLegProgress?.currentStepProgress?.distanceRemaining ?: 0f)}m")
        
        // Log banner instructions
        routeProgress.bannerInstructions?.let { banner ->
            android.util.Log.d(TAG, "   📢 Banner Instruction:")
            android.util.Log.d(TAG, "      Primary: ${banner.primary()?.text()}")
            android.util.Log.d(TAG, "      Type: ${banner.primary()?.type()}")
            android.util.Log.d(TAG, "      Modifier: ${banner.primary()?.modifier()}")
            banner.secondary()?.let { secondary ->
                android.util.Log.d(TAG, "      Secondary: ${secondary.text()}")
            }
        }
        
        // Log voice instructions
        routeProgress.voiceInstructions?.let { voice ->
            android.util.Log.d(TAG, "   🔊 Voice Instruction: ${voice.announcement()}")
        }
        
        android.util.Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // 更新官方 Trip Progress View (SDK v3 官方方式)
        binding.tripProgressView?.render(
            tripProgressApi.getTripProgress(routeProgress)
        )
        
        // 更新官方 Maneuver View (SDK v3 官方方式)
        val maneuvers = maneuverApi.getManeuvers(routeProgress)
        maneuvers.fold(
            { error ->
                android.util.Log.e(TAG, "Maneuver error: ${error.errorMessage}")
                Unit
            },
            {
                binding.maneuverView?.visibility = View.VISIBLE
                binding.maneuverView?.renderManeuvers(maneuvers)
                Unit
            }
        )
        
        // Send progress event to Flutter
        val progressEvent = MapBoxRouteProgressEvent(routeProgress)
        FlutterMapboxNavigationPlugin.distanceRemaining = routeProgress.distanceRemaining
        FlutterMapboxNavigationPlugin.durationRemaining = routeProgress.durationRemaining
        
        // Log the JSON being sent to Flutter
        android.util.Log.v(TAG, "📤 Sending to Flutter: ${progressEvent.toJson()}")
        
        sendEvent(progressEvent)
        
        // Update viewport data source with route progress (SDK v3 official pattern)
        // This ensures the camera follows the route progress automatically
        viewportDataSource.onRouteProgressChanged(routeProgress)
        viewportDataSource.evaluate()
        
        // Update route line with progress (vanishing route line feature)
        // This makes the traveled portion of the route transparent
        routeLineApi.updateWithRouteProgress(routeProgress) { result ->
            binding.mapView.mapboxMap.style?.let { style ->
                routeLineView.renderRouteLineUpdate(style, result)
            }
        }
        
        // Update route arrow to show upcoming maneuver (SDK v3 official pattern)
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
            
            // 显示到达 UI (官方示例模式)
            runOnUiThread {
                // 隐藏导航 UI
                binding.maneuverView?.visibility = View.INVISIBLE
                binding.tripProgressCard?.visibility = View.INVISIBLE
                binding.soundButton?.visibility = View.INVISIBLE
                binding.routeOverview?.visibility = View.INVISIBLE
                
                // 显示到达消息
                android.widget.Toast.makeText(
                    this@NavigationActivity,
                    "🏁 You have arrived at your destination!",
                    android.widget.Toast.LENGTH_LONG
                ).show()
                
                // 切换相机到概览模式
                navigationCamera.requestNavigationCameraToOverview()
            }
            
            sendEvent(MapBoxEvents.ON_ARRIVAL)
            
            // Send detailed arrival information
            val arrivalData = mapOf(
                "isFinalDestination" to true,
                "legIndex" to routeProgress.currentLegProgress?.legIndex,
                "distanceRemaining" to routeProgress.distanceRemaining,
                "durationRemaining" to routeProgress.durationRemaining
            )
            sendEvent(MapBoxEvents.ON_ARRIVAL, org.json.JSONObject(arrivalData).toString())
            
            // 延迟 3 秒后自动结束导航并关闭 Activity
            binding.mapView.postDelayed({
                android.util.Log.d(TAG, "🏁 Auto-finishing navigation after arrival")
                stopNavigation()
            }, 3000)
        }

        override fun onNextRouteLegStart(routeLegProgress: RouteLegProgress) {
            android.util.Log.d(TAG, "🚩 Next route leg started: leg ${routeLegProgress.legIndex}")
            
            // 显示下一段路程开始的消息
            runOnUiThread {
                android.widget.Toast.makeText(
                    this@NavigationActivity,
                    "🚩 Starting next leg of the route",
                    android.widget.Toast.LENGTH_SHORT
                ).show()
            }
            
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
            
            // 显示途经点到达的消息
            runOnUiThread {
                android.widget.Toast.makeText(
                    this@NavigationActivity,
                    "📍 Waypoint reached!",
                    android.widget.Toast.LENGTH_SHORT
                ).show()
            }
            
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
        
        // MapboxManeuverView 会自动更新，不需要手动调用 updateManeuverUI
        // 官方组件通过 routeProgressObserver 中的 maneuverApi.getManeuvers() 自动更新
    }
    
    /*
    // 已废弃：使用官方 MapboxManeuverView 替代
    // MapboxManeuverView 通过 maneuverApi.getManeuvers() 自动更新
    private fun updateManeuverUI(bannerInstructions: com.mapbox.api.directions.v5.models.BannerInstructions) {
        try {
            // Use ManeuverApi with ManeuverView (SDK v3 official way)
            // If you have MapboxManeuverView in your layout, use:
            // val maneuvers = maneuverApi.getManeuvers(routeProgress)
            // maneuvers.fold(
            //     { error -> Log.e(TAG, error.errorMessage) },
            //     { binding.maneuverView?.renderManeuvers(maneuvers) }
            // )
            
            // For custom UI without MapboxManeuverView, extract data directly:
            val primary = bannerInstructions.primary()
            
            binding.maneuverText?.text = primary.text()
            
            val distance = bannerInstructions.distanceAlongGeometry()
            val distanceText = if (distance >= 1000) {
                "${java.text.DecimalFormat("#.#").format(distance / 1000)} km"
            } else {
                "${distance.toInt()} m"
            }
            binding.maneuverDistance?.text = "In $distanceText"
            
            val iconResId = getManeuverIconResource(primary.type(), primary.modifier())
            if (iconResId != 0) {
                binding.maneuverIcon?.setImageResource(iconResId)
                binding.maneuverIcon?.visibility = View.VISIBLE
            }
            
            val secondary = bannerInstructions.secondary()
            if (secondary != null) {
                binding.nextManeuverText?.text = "Then ${secondary.text()}"
                val nextIconResId = getManeuverIconResource(secondary.type(), secondary.modifier())
                if (nextIconResId != 0) {
                    binding.nextManeuverIcon?.setImageResource(nextIconResId)
                }
                binding.nextManeuverLayout?.visibility = View.VISIBLE
            } else {
                binding.nextManeuverLayout?.visibility = View.GONE
            }
            
            binding.maneuverPanel?.visibility = View.VISIBLE
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to update maneuver UI: ${e.message}", e)
        }
    }
    */
    
    /*
    // 已废弃：官方 MapboxManeuverView 自动处理图标
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
    */
    
    private val voiceInstructionObserver = VoiceInstructionsObserver { voiceInstructions ->
        // Send event to Flutter
        sendEvent(MapBoxEvents.SPEECH_ANNOUNCEMENT, voiceInstructions.announcement() ?: "")
        
        // Play voice instruction if enabled
        if (FlutterMapboxNavigationPlugin.voiceInstructionsEnabled) {
            voiceInstructionsObserverImpl.onNewVoiceInstructions(voiceInstructions)
        }
    }
    
    // Voice Instructions Observer Implementation (following official example)
    private inner class VoiceInstructionsObserverImpl {
        fun onNewVoiceInstructions(voiceInstructions: com.mapbox.api.directions.v5.models.VoiceInstructions) {
            try {
                // Generate speech announcement using Speech API (SDK v3 official pattern)
                speechApi.generate(voiceInstructions, speechCallback)
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Failed to play voice instruction: ${e.message}", e)
            }
        }
    }
    
    // Speech callback following official example
    private val speechCallback =
        MapboxNavigationConsumer<com.mapbox.bindgen.Expected<SpeechError, SpeechValue>> { expected ->
            expected.fold(
                { error ->
                    // play the instruction via fallback text-to-speech engine
                    voiceInstructionsPlayer.play(
                        error.fallback,
                        voiceInstructionsPlayerCallback
                    )
                    android.util.Log.w(TAG, "⚠️ Speech API error: ${error.errorMessage}, using fallback")
                },
                { value ->
                    // play the sound file from the external generator
                    voiceInstructionsPlayer.play(
                        value.announcement,
                        voiceInstructionsPlayerCallback
                    )
                    android.util.Log.d(TAG, "🔊 Voice instruction played successfully")
                }
            )
        }
    
    // Voice instructions player callback following official example
    private val voiceInstructionsPlayerCallback =
        MapboxNavigationConsumer<SpeechAnnouncement> { value ->
            // remove already consumed file to free-up space
            speechApi.clean(value)
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
    // 注意：使用官方 MapboxTripProgressView 和 MapboxManeuverView 后，
    // 以下函数不再需要，已在 routeProgressObserver 中直接使用官方组件
    
    /*
    // 已废弃：使用官方 MapboxTripProgressView 替代
    private fun updateNavigationUI(routeProgress: RouteProgress) {
        try {
            // Use TripProgressApi with TripProgressView (SDK v3 official way)
            // If you have MapboxTripProgressView in your layout, use:
            // binding.tripProgressView?.render(tripProgressApi.getTripProgress(routeProgress))
            
            // For custom UI without MapboxTripProgressView, format manually:
            val distanceRemaining = routeProgress.distanceRemaining
            val distanceText = if (distanceRemaining >= 1000) {
                "${DecimalFormat("#.#").format(distanceRemaining / 1000)} km"
            } else {
                "${distanceRemaining.toInt()} m"
            }
            binding.distanceRemainingText?.text = distanceText
            
            val durationRemaining = routeProgress.durationRemaining
            val hours = (durationRemaining / 3600).toInt()
            val minutes = ((durationRemaining % 3600) / 60).toInt()
            val durationText = if (hours > 0) {
                "${hours}h ${minutes}min"
            } else {
                "${minutes}min"
            }
            binding.durationRemainingText?.text = durationText
            
            binding.etaText?.text = formatETA(durationRemaining)
            
            android.util.Log.d(TAG, "📊 Progress updated: distance=$distanceText, time=$durationText")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to update navigation UI: ${e.message}", e)
        }
    }
    */
    
    /*
    // 已废弃：官方 MapboxTripProgressView 自动格式化 ETA
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
    */
    
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
            navigationStartTime = System.currentTimeMillis()
            
            // Reset distance tracking (initial distance already captured in startNavigation)
            navigationDistanceTraveled = 0f
            
            android.util.Log.d(TAG, "📹 History recording started at $navigationStartTime, initial distance: ${navigationInitialDistance}m")
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
            
            // ✅ 立即捕获必要数据，防止异步回调时被重置
            val capturedHistoryId = java.util.UUID.randomUUID().toString()
            val capturedStartTime = navigationStartTime
            val capturedStartPointName = waypointSet.getFirstWaypointName()
            val capturedEndPointName = waypointSet.getLastWaypointName()
            val capturedNavigationMode = if (FlutterMapboxNavigationPlugin.simulateRoute) "simulation" else "real"
            val capturedMapStyle = com.eopeter.fluttermapboxnavigation.utilities.StylePreferenceManager.getMapStyle(this)
            val capturedLightPreset = com.eopeter.fluttermapboxnavigation.utilities.StylePreferenceManager.getLightPreset(this)
            val capturedDistanceTraveled = navigationDistanceTraveled
            val capturedInitialDistance = navigationInitialDistance
            
            // Stop history recording
            mapboxNavigation.historyRecorder.stopRecording { historyFilePath ->
                if (historyFilePath != null) {
                    android.util.Log.d(TAG, "📹 History recording stopped and saved: $historyFilePath")
                    currentHistoryFilePath = historyFilePath
                    
                    // Calculate duration
                    val navigationEndTime = System.currentTimeMillis()
                    val duration = if (capturedStartTime > 0) {
                        ((navigationEndTime - capturedStartTime) / 1000).toInt()
                    } else {
                        0
                    }
                    
                    // Calculate total distance using actual distance traveled
                    val totalDistance: Double? = if (capturedDistanceTraveled > 0) {
                        capturedDistanceTraveled.toDouble()
                    } else {
                        capturedInitialDistance?.toDouble()
                    }
                    
                    android.util.Log.d(TAG, "📊 Navigation Summary:")
                    android.util.Log.d(TAG, "  - Start Time: $capturedStartTime")
                    android.util.Log.d(TAG, "  - End Time: $navigationEndTime")
                    android.util.Log.d(TAG, "  - Duration: ${duration}s")
                    android.util.Log.d(TAG, "  - Initial Distance: ${capturedInitialDistance}m")
                    android.util.Log.d(TAG, "  - Distance Traveled: ${capturedDistanceTraveled}m")
                    android.util.Log.d(TAG, "  - Total Distance: ${totalDistance}m")
                    android.util.Log.d(TAG, "  - Start Point: $capturedStartPointName")
                    android.util.Log.d(TAG, "  - End Point: $capturedEndPointName")
                    android.util.Log.d(TAG, "  - Mode: $capturedNavigationMode")
                    
                    // Save history record to HistoryManager (without cover first)
                    try {
                        val historyData: Map<String, Any?> = mapOf(
                            "id" to capturedHistoryId,
                            "filePath" to historyFilePath,
                            "startTime" to capturedStartTime,
                            "endTime" to navigationEndTime,
                            "distance" to totalDistance,
                            "duration" to duration.toLong(),
                            "startPointName" to capturedStartPointName,
                            "endPointName" to capturedEndPointName,
                            "navigationMode" to capturedNavigationMode
                        )
                        
                        android.util.Log.d(TAG, "💾 Saving history data: $historyData")
                        
                        val saved = FlutterMapboxNavigationPlugin.historyManager.saveHistoryRecord(historyData)
                        if (saved) {
                            android.util.Log.d(TAG, "✅ History record saved to database: $capturedStartPointName -> $capturedEndPointName, duration: ${duration}s")
                            
                            // 异步生成封面（不阻塞历史记录保存）
                            kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main).launch {
                                com.eopeter.fluttermapboxnavigation.utilities.HistoryCoverGenerator.generateHistoryCover(
                                    this@NavigationActivity,
                                    historyFilePath,
                                    capturedHistoryId,
                                    capturedMapStyle,
                                    capturedLightPreset,
                                    object : com.eopeter.fluttermapboxnavigation.utilities.HistoryCoverGenerator.HistoryCoverCallback {
                                        override fun onSuccess(coverPath: String) {
                                            android.util.Log.d(TAG, "✅ 封面生成成功: $coverPath")
                                        }
                                        
                                        override fun onFailure(error: String) {
                                            android.util.Log.w(TAG, "⚠️ 封面生成失败: $error")
                                        }
                                    }
                                )
                            }
                        } else {
                            android.util.Log.w(TAG, "⚠️ Failed to save history record to database")
                        }
                    } catch (e: Exception) {
                        android.util.Log.e(TAG, "❌ Error saving history record: ${e.message}", e)
                    }
                    
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
