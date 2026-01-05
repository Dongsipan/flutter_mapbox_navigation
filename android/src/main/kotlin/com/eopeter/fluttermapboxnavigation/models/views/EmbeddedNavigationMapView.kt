package com.eopeter.fluttermapboxnavigation.models.views

import android.app.Activity
import android.content.Context
import android.view.View
import com.eopeter.fluttermapboxnavigation.TurnByTurn
import com.eopeter.fluttermapboxnavigation.databinding.NavigationActivityBinding
import com.eopeter.fluttermapboxnavigation.models.MapBoxEvents
import com.eopeter.fluttermapboxnavigation.utilities.PluginUtilities
import com.eopeter.fluttermapboxnavigation.utilities.MapStyleManager
import com.mapbox.geojson.Point
import com.mapbox.maps.MapView
import com.mapbox.maps.Style
import com.mapbox.maps.plugin.gestures.OnMapClickListener
import com.mapbox.maps.plugin.gestures.OnMapLongClickListener
import com.mapbox.maps.plugin.gestures.gestures
import com.mapbox.maps.plugin.locationcomponent.location
import com.mapbox.navigation.core.lifecycle.MapboxNavigationApp
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import org.json.JSONObject

/**
 * EmbeddedNavigationMapView - SDK v3 版本
 * 使用 Mapbox Navigation SDK v3 核心 API
 * 
 * 功能：
 * - 嵌入式地图视图
 * - 支持地图点击和长按
 * - 完整的导航功能
 */
class EmbeddedNavigationMapView(
    context: Context,
    activity: Activity,
    binding: NavigationActivityBinding,
    binaryMessenger: BinaryMessenger,
    vId: Int,
    args: Any?,
    accessToken: String
) : PlatformView, TurnByTurn(context, activity, binding, accessToken) {
    
    private val viewId: Int = vId
    private val messenger: BinaryMessenger = binaryMessenger
    private val arguments = args as? Map<*, *>
    
    // Map gesture listeners
    private var onMapClickListener: OnMapClickListener? = null
    private var onMapLongClickListener: OnMapLongClickListener? = null

    override fun initFlutterChannelHandlers() {
        methodChannel = MethodChannel(messenger, "flutter_mapbox_navigation/${viewId}")
        eventChannel = EventChannel(messenger, "flutter_mapbox_navigation/${viewId}/events")
        super.initFlutterChannelHandlers()
    }

    open fun initialize() {
        initFlutterChannelHandlers()
        initNavigation()
        initializeMap()
        setupMapGestures()
    }
    
    private fun initializeMap() {
        // Register map view with MapStyleManager
        MapStyleManager.registerMapView(binding.mapView)
        
        // Set day and night styles
        val dayStyle = arguments?.get("mapStyleUrlDay") as? String ?: Style.MAPBOX_STREETS
        val nightStyle = arguments?.get("mapStyleUrlNight") as? String ?: Style.DARK
        MapStyleManager.setDayStyle(dayStyle)
        MapStyleManager.setNightStyle(nightStyle)
        
        // Load map style
        val styleUrl = dayStyle
        
        binding.mapView.mapboxMap.loadStyle(styleUrl) {
            // Enable location component
            binding.mapView.location.updateSettings {
                enabled = true
                pulsingEnabled = true
            }
        }
    }
    
    private fun setupMapGestures() {
        // Setup map click listener if enabled
        val enableOnMapTapCallback = arguments?.get("enableOnMapTapCallback") as? Boolean ?: false
        if (enableOnMapTapCallback) {
            onMapClickListener = OnMapClickListener { point ->
                val waypoint = mapOf(
                    "latitude" to point.latitude().toString(),
                    "longitude" to point.longitude().toString()
                )
                PluginUtilities.sendEvent(MapBoxEvents.ON_MAP_TAP, JSONObject(waypoint).toString())
                true
            }
            binding.mapView.gestures.addOnMapClickListener(onMapClickListener!!)
        }
        
        // Setup long press listener if enabled
        val longPressDestinationEnabled = arguments?.get("longPressDestinationEnabled") as? Boolean ?: false
        if (longPressDestinationEnabled) {
            onMapLongClickListener = OnMapLongClickListener { point ->
                // Get current location and build route
                lastLocation?.let {
                    val waypointSet = com.eopeter.fluttermapboxnavigation.models.WaypointSet()
                    waypointSet.add(com.eopeter.fluttermapboxnavigation.models.Waypoint(
                        Point.fromLngLat(it.longitude, it.latitude)
                    ))
                    waypointSet.add(com.eopeter.fluttermapboxnavigation.models.Waypoint(point))
                    // Note: This would need to call a route building method
                    // For now, just send an event
                    val waypoint = mapOf(
                        "latitude" to point.latitude().toString(),
                        "longitude" to point.longitude().toString()
                    )
                    PluginUtilities.sendEvent(MapBoxEvents.ON_MAP_TAP, JSONObject(waypoint).toString())
                }
                true
            }
            binding.mapView.gestures.addOnMapLongClickListener(onMapLongClickListener!!)
        }
    }

    override fun getView(): View {
        return binding.root
    }

    override fun dispose() {
        // Remove map gesture listeners
        onMapClickListener?.let {
            binding.mapView.gestures.removeOnMapClickListener(it)
        }
        onMapLongClickListener?.let {
            binding.mapView.gestures.removeOnMapLongClickListener(it)
        }
        
        // Unregister map view from MapStyleManager
        MapStyleManager.unregisterMapView(binding.mapView)
        
        // Unregister navigation observers
        unregisterObservers()
    }
}

