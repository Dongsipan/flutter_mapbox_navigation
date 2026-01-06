package com.eopeter.fluttermapboxnavigation

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.eopeter.fluttermapboxnavigation.activity.NavigationLauncher
import com.eopeter.fluttermapboxnavigation.factory.EmbeddedNavigationViewFactory
import com.eopeter.fluttermapboxnavigation.models.Waypoint
import com.eopeter.fluttermapboxnavigation.utilities.HistoryManager
import com.mapbox.api.directions.v5.DirectionsCriteria
import com.mapbox.api.directions.v5.models.DirectionsRoute
import com.mapbox.maps.Style
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.platform.PlatformViewRegistry

/** FlutterMapboxNavigationPlugin */
class FlutterMapboxNavigationPlugin : FlutterPlugin, MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var progressEventChannel: EventChannel
    private lateinit var stylePickerChannel: MethodChannel
    private lateinit var searchChannel: MethodChannel
    private var currentActivity: Activity? = null
    private lateinit var currentContext: Context
    private lateinit var historyManager: HistoryManager

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        channel = MethodChannel(messenger, "flutter_mapbox_navigation")
        channel.setMethodCallHandler(this)

        progressEventChannel = EventChannel(messenger, "flutter_mapbox_navigation/events")
        progressEventChannel.setStreamHandler(this)

        // 注册样式选择器 channel
        stylePickerChannel = MethodChannel(messenger, "flutter_mapbox_navigation/style_picker")
        stylePickerChannel.setMethodCallHandler { call, result ->
            handleStylePickerMethod(call, result)
        }

        // 注册搜索 channel (Task 9.1)
        searchChannel = MethodChannel(messenger, "flutter_mapbox_navigation/search")
        searchChannel.setMethodCallHandler { call, result ->
            handleSearchMethod(call, result)
        }

        platformViewRegistry = binding.platformViewRegistry
        binaryMessenger = messenger
        currentContext = binding.applicationContext
        historyManager = HistoryManager(currentContext)
    }

    companion object {

        var eventSink: EventChannel.EventSink? = null

        var PERMISSION_REQUEST_CODE: Int = 367

        lateinit var routes: List<DirectionsRoute>
        private var currentRoute: DirectionsRoute? = null
        val wayPoints: MutableList<Waypoint> = mutableListOf()

        var showAlternateRoutes: Boolean = true
        var longPressDestinationEnabled: Boolean = true
        var allowsUTurnsAtWayPoints: Boolean = false
        var enableOnMapTapCallback: Boolean = false
        var navigationMode = DirectionsCriteria.PROFILE_DRIVING_TRAFFIC
        var simulateRoute = false
        var enableFreeDriveMode = false
        var mapStyleUrlDay: String? = null
        var mapStyleUrlNight: String? = null
        var navigationLanguage = "en"
        var navigationVoiceUnits = DirectionsCriteria.IMPERIAL
        var voiceInstructionsEnabled = true
        var bannerInstructionsEnabled = true
        var zoom = 15.0
        var bearing = 0.0
        var tilt = 0.0
        var distanceRemaining: Float? = null
        var durationRemaining: Double? = null
        var platformViewRegistry: PlatformViewRegistry? = null
        var binaryMessenger: BinaryMessenger? = null
        var enableHistoryRecording = false

        var viewId = "FlutterMapboxNavigationView"
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }
            "getDistanceRemaining" -> {
                result.success(distanceRemaining)
            }
            "getDurationRemaining" -> {
                result.success(durationRemaining)
            }
            "startFreeDrive" -> {
                enableFreeDriveMode = true
                checkPermissionAndBeginNavigation(call)
            }
            "startNavigation" -> {
                enableFreeDriveMode = false
                checkPermissionAndBeginNavigation(call)
            }
            "addWayPoints" -> {
                addWayPointsToNavigation(call, result)
            }
            "finishNavigation" -> {
                NavigationLauncher.stopNavigation(currentActivity)
            }
            "enableOfflineRouting" -> {
                downloadRegionForOfflineRouting(call, result)
            }
            "getNavigationHistoryList" -> {
                getNavigationHistoryList(result)
            }
            "deleteNavigationHistory" -> {
                deleteNavigationHistory(call, result)
            }
            "clearAllNavigationHistory" -> {
                clearAllNavigationHistory(result)
            }
            "startHistoryReplay" -> {
                startHistoryReplay(call, result)
            }
            "stopHistoryReplay" -> {
                stopHistoryReplay(result)
            }
            "pauseHistoryReplay" -> {
                pauseHistoryReplay(result)
            }
            "resumeHistoryReplay" -> {
                resumeHistoryReplay(result)
            }
            "setHistoryReplaySpeed" -> {
                setHistoryReplaySpeed(call, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun downloadRegionForOfflineRouting(
        call: MethodCall,
        result: Result
    ) {
        result.error("TODO", "Not Implemented in Android", "will implement soon")
    }

    private fun getNavigationHistoryList(result: Result) {
        try {
            val historyList = historyManager.getHistoryList()
            val historyMaps = historyList.map { history ->
                mapOf(
                    "id" to history.id,
                    "historyFilePath" to history.historyFilePath,
                    "startTime" to history.startTime.time,
                    "duration" to history.duration,
                    "startPointName" to history.startPointName,
                    "endPointName" to history.endPointName,
                    "navigationMode" to history.navigationMode
                )
            }
            result.success(historyMaps)
        } catch (e: Exception) {
            result.error("HISTORY_ERROR", "Failed to get history list: ${e.message}", null)
        }
    }

    private fun deleteNavigationHistory(call: MethodCall, result: Result) {
        val arguments = call.arguments as? Map<String, Any>
        val historyId = arguments?.get("historyId") as? String
        if (historyId != null) {
            try {
                val success = historyManager.deleteHistoryRecord(historyId)
                result.success(success)
            } catch (e: Exception) {
                result.error("HISTORY_ERROR", "Failed to delete history: ${e.message}", null)
            }
        } else {
            result.error("INVALID_ARGUMENT", "historyId is required", null)
        }
    }

    private fun clearAllNavigationHistory(result: Result) {
        try {
            val success = historyManager.clearAllHistory()
            result.success(success)
        } catch (e: Exception) {
            result.error("HISTORY_ERROR", "Failed to clear history: ${e.message}", null)
        }
    }

    private fun startHistoryReplay(call: MethodCall, result: Result) {
        try {
            val historyFilePath = call.argument<String>("historyFilePath")
            val enableReplayUI = call.argument<Boolean>("enableReplayUI") ?: true

            if (historyFilePath == null) {
                result.error("INVALID_ARGUMENTS", "Missing historyFilePath", null)
                return
            }

            // Android端的历史记录回放实现
            // 注意：这里需要根据Mapbox Android SDK的具体API来实现
            // 目前Android SDK可能不支持历史记录回放功能，或者API不同

            // 临时返回false，表示Android端暂不支持
            result.success(false)
        } catch (e: Exception) {
            result.error("REPLAY_ERROR", "Failed to start history replay: ${e.message}", null)
        }
    }

    private fun stopHistoryReplay(result: Result) {
        try {
            // Android端的停止历史记录回放实现
            result.success(false)
        } catch (e: Exception) {
            result.error("REPLAY_ERROR", "Failed to stop history replay: ${e.message}", null)
        }
    }

    private fun pauseHistoryReplay(result: Result) {
        try {
            // Android端的暂停历史记录回放实现
            result.success(false)
        } catch (e: Exception) {
            result.error("REPLAY_ERROR", "Failed to pause history replay: ${e.message}", null)
        }
    }

    private fun resumeHistoryReplay(result: Result) {
        try {
            // Android端的恢复历史记录回放实现
            result.success(false)
        } catch (e: Exception) {
            result.error("REPLAY_ERROR", "Failed to resume history replay: ${e.message}", null)
        }
    }

    private fun setHistoryReplaySpeed(call: MethodCall, result: Result) {
        try {
            val speed = call.argument<Double>("speed")

            if (speed == null) {
                result.error("INVALID_ARGUMENTS", "Missing speed parameter", null)
                return
            }

            // Android端的设置回放速度实现
            result.success(false)
        } catch (e: Exception) {
            result.error("REPLAY_ERROR", "Failed to set history replay speed: ${e.message}", null)
        }
    }

    private fun checkPermissionAndBeginNavigation(
        call: MethodCall
    ) {
        val arguments = call.arguments as? Map<String, Any>

        val navMode = arguments?.get("mode") as? String
        if (navMode != null) {
            when (navMode) {
                "walking" -> navigationMode = DirectionsCriteria.PROFILE_WALKING
                "cycling" -> navigationMode = DirectionsCriteria.PROFILE_CYCLING
                "driving" -> navigationMode = DirectionsCriteria.PROFILE_DRIVING
            }
        }

        val alternateRoutes = arguments?.get("alternatives") as? Boolean
        if (alternateRoutes != null) {
            showAlternateRoutes = alternateRoutes
        }

        val simulated = arguments?.get("simulateRoute") as? Boolean
        if (simulated != null) {
            simulateRoute = simulated
        }

        val allowsUTurns = arguments?.get("allowsUTurnsAtWayPoints") as? Boolean
        if (allowsUTurns != null) {
            allowsUTurnsAtWayPoints = allowsUTurns
        }

        val onMapTap = arguments?.get("enableOnMapTapCallback") as? Boolean
        if (onMapTap != null) {
            enableOnMapTapCallback = onMapTap
        }

        val historyRecording = arguments?.get("enableHistoryRecording") as? Boolean
        if (historyRecording != null) {
            enableHistoryRecording = historyRecording
        }

        val language = arguments?.get("language") as? String
        if (language != null) {
            navigationLanguage = language
        }

        val voiceEnabled = arguments?.get("voiceInstructionsEnabled") as? Boolean
        if (voiceEnabled != null) {
            voiceInstructionsEnabled = voiceEnabled
        }

        val bannerEnabled = arguments?.get("bannerInstructionsEnabled") as? Boolean
        if (bannerEnabled != null) {
            bannerInstructionsEnabled = bannerEnabled
        }

        val units = arguments?.get("units") as? String

        if (units != null) {
            if (units == "imperial") {
                navigationVoiceUnits = DirectionsCriteria.IMPERIAL
            } else if (units == "metric") {
                navigationVoiceUnits = DirectionsCriteria.METRIC
            }
        }

        mapStyleUrlDay = arguments?.get("mapStyleUrlDay") as? String
        mapStyleUrlNight = arguments?.get("mapStyleUrlNight") as? String

        val longPress = arguments?.get("longPressDestinationEnabled") as? Boolean
        if (longPress != null) {
            longPressDestinationEnabled = longPress
        }

        wayPoints.clear()

        if (enableFreeDriveMode) {
            checkPermissionAndBeginNavigation(wayPoints)
            return
        }

        val points = arguments?.get("wayPoints") as HashMap<Int, Any>
        for (item in points) {
            val point = item.value as HashMap<*, *>
            val name = point["Name"] as String
            val latitude = point["Latitude"] as Double
            val longitude = point["Longitude"] as Double
            val isSilent = point["IsSilent"] as Boolean
            wayPoints.add(Waypoint(name, longitude, latitude, isSilent))
        }
        checkPermissionAndBeginNavigation(wayPoints)
    }

    private fun checkPermissionAndBeginNavigation(wayPoints: List<Waypoint>) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val haspermission =
                currentActivity?.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
            if (haspermission != PackageManager.PERMISSION_GRANTED) {
                //_activity.onRequestPermissionsResult((a,b,c) => onRequestPermissionsResult)
                currentActivity?.requestPermissions(
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                    PERMISSION_REQUEST_CODE
                )
                beginNavigation(wayPoints)
            } else
                beginNavigation(wayPoints)
        } else
            beginNavigation(wayPoints)
    }

    private fun beginNavigation(wayPoints: List<Waypoint>) {
        NavigationLauncher.startNavigation(currentActivity, wayPoints)
    }

    private fun addWayPointsToNavigation(
        call: MethodCall,
        result: Result
    ) {
        val arguments = call.arguments as? Map<String, Any>
        val points = arguments?.get("wayPoints") as HashMap<Int, Any>

        for (item in points) {
            val point = item.value as HashMap<*, *>
            val name = point["Name"] as String
            val latitude = point["Latitude"] as Double
            val longitude = point["Longitude"] as Double
            val isSilent = point["IsSilent"] as Boolean
            wayPoints.add(Waypoint(name, latitude, longitude, isSilent))
        }
        NavigationLauncher.addWayPoints(currentActivity, wayPoints)
    }

    override fun onListen(args: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(args: Any?) {
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        currentActivity = null
        channel.setMethodCallHandler(null)
        progressEventChannel.setStreamHandler(null)
    }

    override fun onDetachedFromActivity() {
        currentActivity!!.finish()
        currentActivity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        currentContext = binding.activity.applicationContext
        
        // 添加 Activity 结果监听器
        binding.addActivityResultListener { requestCode, resultCode, data ->
            if (requestCode == STYLE_PICKER_REQUEST_CODE) {
                handleStylePickerResult(resultCode, data)
                return@addActivityResultListener true
            }
            if (requestCode == SEARCH_REQUEST_CODE) {
                handleSearchResult(resultCode, data)
                return@addActivityResultListener true
            }
            false
        }
        
        if (platformViewRegistry != null && binaryMessenger != null && currentActivity != null) {
            platformViewRegistry?.registerViewFactory(
                viewId,
                EmbeddedNavigationViewFactory(binaryMessenger!!, currentActivity!!)
            )
        }
    }
    
    /**
     * 处理样式选择器 Activity 的返回结果
     */
    private fun handleStylePickerResult(resultCode: Int, data: android.content.Intent?) {
        val result = stylePickerResult ?: return
        stylePickerResult = null
        
        if (resultCode == Activity.RESULT_OK && data != null) {
            val mapStyle = data.getStringExtra(com.eopeter.fluttermapboxnavigation.activity.StylePickerActivity.RESULT_STYLE)
            val lightPreset = data.getStringExtra(com.eopeter.fluttermapboxnavigation.activity.StylePickerActivity.RESULT_LIGHT_PRESET)
            val lightPresetMode = data.getStringExtra(com.eopeter.fluttermapboxnavigation.activity.StylePickerActivity.RESULT_LIGHT_PRESET_MODE)
            
            // 保存到 SharedPreferences
            val activity = currentActivity
            if (activity != null && mapStyle != null) {
                val prefs = activity.getSharedPreferences("mapbox_style_settings", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putString("map_style", mapStyle)
                    putString("light_preset", lightPreset ?: "day")
                    putString("light_preset_mode", lightPresetMode ?: "manual")
                    apply()
                }
                
                // 更新全局样式设置
                mapStyleUrlDay = getStyleUrl(mapStyle)
                mapStyleUrlNight = mapStyleUrlDay
                
                result.success(true)
            } else {
                result.success(false)
            }
        } else {
            result.success(false)
        }
    }
    
    /**
     * 根据样式名称获取样式 URL
     */
    private fun getStyleUrl(styleName: String): String {
        return when (styleName) {
            "standard" -> Style.MAPBOX_STREETS
            "standardSatellite" -> Style.SATELLITE_STREETS
            "faded" -> "mapbox://styles/mapbox/light-v11"
            "monochrome" -> "mapbox://styles/mapbox/dark-v11"
            "light" -> Style.LIGHT
            "dark" -> Style.DARK
            "outdoors" -> Style.OUTDOORS
            else -> Style.MAPBOX_STREETS
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // To change body of created functions use File | Settings | File Templates.
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        when (requestCode) {
            367 -> {
                for (permission in permissions) {
                    if (permission == Manifest.permission.ACCESS_FINE_LOCATION) {
                        val haspermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            currentActivity?.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                        } else {
                            TODO("VERSION.SDK_INT < M")
                        }
                        if (haspermission == PackageManager.PERMISSION_GRANTED) {
                            if (wayPoints.isNotEmpty())
                                beginNavigation(wayPoints)
                        }
                        // Not all permissions granted. Show some message and return.
                        return
                    }
                }

                // All permissions are granted. Do the work accordingly.
            }
        }
        // super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    /**
     * 处理样式选择器相关的方法调用
     */
    private fun handleStylePickerMethod(call: MethodCall, result: Result) {
        when (call.method) {
            "showStylePicker" -> {
                showStylePicker(result)
            }
            "getStoredStyle" -> {
                getStoredStyle(result)
            }
            "clearStoredStyle" -> {
                clearStoredStyle(result)
            }
            else -> result.notImplemented()
        }
    }
    
    /**
     * 显示样式选择器
     */
    private fun showStylePicker(result: Result) {
        val activity = currentActivity
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity is null", null)
            return
        }
        
        // 从 SharedPreferences 读取当前设置
        val prefs = activity.getSharedPreferences("mapbox_style_settings", Context.MODE_PRIVATE)
        val currentStyle = prefs.getString("map_style", "standard") ?: "standard"
        val currentLightPreset = prefs.getString("light_preset", "day") ?: "day"
        val lightPresetMode = prefs.getString("light_preset_mode", "manual") ?: "manual"
        
        // 启动样式选择器 Activity
        val intent = android.content.Intent(activity, com.eopeter.fluttermapboxnavigation.activity.StylePickerActivity::class.java)
        intent.putExtra(com.eopeter.fluttermapboxnavigation.activity.StylePickerActivity.EXTRA_CURRENT_STYLE, currentStyle)
        intent.putExtra(com.eopeter.fluttermapboxnavigation.activity.StylePickerActivity.EXTRA_CURRENT_LIGHT_PRESET, currentLightPreset)
        intent.putExtra(com.eopeter.fluttermapboxnavigation.activity.StylePickerActivity.EXTRA_LIGHT_PRESET_MODE, lightPresetMode)
        
        // 保存 result 以便在 Activity 返回时使用
        stylePickerResult = result
        activity.startActivityForResult(intent, STYLE_PICKER_REQUEST_CODE)
    }
    
    /**
     * 获取存储的样式设置
     */
    private fun getStoredStyle(result: Result) {
        val activity = currentActivity
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity is null", null)
            return
        }
        
        val prefs = activity.getSharedPreferences("mapbox_style_settings", Context.MODE_PRIVATE)
        val styleSettings = mapOf(
            "mapStyle" to (prefs.getString("map_style", "standard") ?: "standard"),
            "lightPreset" to (prefs.getString("light_preset", "day") ?: "day"),
            "lightPresetMode" to (prefs.getString("light_preset_mode", "manual") ?: "manual")
        )
        result.success(styleSettings)
    }
    
    /**
     * 清除存储的样式设置
     */
    private fun clearStoredStyle(result: Result) {
        val activity = currentActivity
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity is null", null)
            return
        }
        
        val prefs = activity.getSharedPreferences("mapbox_style_settings", Context.MODE_PRIVATE)
        prefs.edit().clear().apply()
        
        // 重置为默认值
        mapStyleUrlDay = null
        mapStyleUrlNight = null
        
        result.success(true)
    }
    
    // 样式选择器请求码
    private val STYLE_PICKER_REQUEST_CODE = 9001
    private var stylePickerResult: Result? = null
    
    // 搜索请求码 (Task 9.2)
    private val SEARCH_REQUEST_CODE = 9002
    private var searchResult: Result? = null
    
    /**
     * 处理搜索相关的方法调用
     * Task 9.1 和 9.2
     */
    private fun handleSearchMethod(call: MethodCall, result: Result) {
        when (call.method) {
            "showSearchView" -> {
                showSearchView(result)
            }
            else -> result.notImplemented()
        }
    }
    
    /**
     * 显示搜索界面
     * Task 9.2
     */
    private fun showSearchView(result: Result) {
        val activity = currentActivity
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity为空", null)
            return
        }
        
        try {
            // 启动搜索 Activity
            val intent = android.content.Intent(
                activity, 
                com.eopeter.fluttermapboxnavigation.activity.SearchActivity::class.java
            )
            
            // 保存 result 以便在 Activity 返回时使用
            searchResult = result
            activity.startActivityForResult(intent, SEARCH_REQUEST_CODE)
        } catch (e: Exception) {
            result.error("SEARCH_ERROR", "启动搜索界面失败: ${e.message}", null)
        }
    }
    
    /**
     * 处理搜索 Activity 的返回结果
     * Task 9.6
     */
    private fun handleSearchResult(resultCode: Int, data: android.content.Intent?) {
        val result = searchResult ?: return
        searchResult = null
        
        when (resultCode) {
            Activity.RESULT_OK -> {
                // 用户选择了地点，返回wayPoints
                if (data != null) {
                    val wayPoints = data.getSerializableExtra(
                        com.eopeter.fluttermapboxnavigation.activity.SearchActivity.EXTRA_RESULT_WAYPOINTS
                    ) as? ArrayList<Map<String, Any>>
                    
                    if (wayPoints != null) {
                        result.success(wayPoints)
                    } else {
                        result.error("INVALID_RESULT", "wayPoints数据无效", null)
                    }
                } else {
                    result.error("NO_DATA", "未返回数据", null)
                }
            }
            Activity.RESULT_CANCELED -> {
                // 用户取消了搜索，返回null (Task 9.5)
                result.success(null)
            }
            else -> {
                result.error("UNKNOWN_RESULT", "未知的结果码: $resultCode", null)
            }
        }
    }
}

private const val MAPBOX_ACCESS_TOKEN_PLACEHOLDER = "YOUR_MAPBOX_ACCESS_TOKEN_GOES_HERE"