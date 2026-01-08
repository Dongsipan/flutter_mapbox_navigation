package com.eopeter.fluttermapboxnavigation.utilities

import com.mapbox.navigation.core.history.MapboxHistoryReader
import com.mapbox.navigation.core.replay.history.ReplayEventBase
import com.mapbox.navigation.core.replay.history.ReplayHistoryMapper
import com.mapbox.navigation.core.replay.history.ReplayEventUpdateLocation
import com.mapbox.navigation.core.replay.history.ReplaySetNavigationRoute
import com.mapbox.navigation.core.replay.history.ReplayEventLocation
import com.mapbox.navigation.base.route.NavigationRoute
import java.io.File

/**
 * 导航历史事件解析器
 * 解析 Mapbox 历史文件并提取事件数据
 * 
 * 注意：Android 端的 MapboxHistoryReader 返回 Iterator<HistoryEvent>，
 * 不像 iOS 端有 History 聚合对象。我们使用 ReplayHistoryMapper 来提取可用数据。
 */
class HistoryEventsParser {
    
    /**
     * 解析历史文件并返回事件数据
     * 
     * @param filePath 历史文件路径
     * @param historyId 历史记录ID
     * @return 包含事件、位置和路线信息的 Map
     */
    fun parseHistoryFile(filePath: String, historyId: String): Map<String, Any?> {
        android.util.Log.d("HistoryEventsParser", "📖 Starting to parse history file: $filePath")
        android.util.Log.d("HistoryEventsParser", "📖 History ID: $historyId")
        
        val file = File(filePath)
        if (!file.exists()) {
            throw Exception("History file not found at path: $filePath")
        }
        
        val events = mutableListOf<Map<String, Any?>>()
        val rawLocations = mutableListOf<Map<String, Any?>>()
        var initialRoute: Map<String, Any?>? = null
        
        try {
            // 使用 MapboxHistoryReader 读取历史文件
            val historyReader = MapboxHistoryReader(filePath)
            android.util.Log.d("HistoryEventsParser", "✅ HistoryReader created successfully")
            
            // 使用 ReplayHistoryMapper 转换事件
            val replayHistoryMapper = ReplayHistoryMapper.Builder().build()
            android.util.Log.d("HistoryEventsParser", "✅ ReplayHistoryMapper created")
            
            var eventCount = 0
            var locationCount = 0
            var routeCount = 0
            
            // 读取所有事件
            while (historyReader.hasNext()) {
                try {
                    val historyEvent = historyReader.next()
                    val replayEvent = replayHistoryMapper.mapToReplayEvent(historyEvent)
                    
                    if (replayEvent != null) {
                        eventCount++
                        
                        when (replayEvent) {
                            is ReplayEventUpdateLocation -> {
                                // 位置更新事件
                                val replayLoc = replayEvent.location
                                val locationData = serializeReplayLocation(replayLoc)
                                
                                rawLocations.add(locationData)
                                locationCount++
                                
                                // 同时添加到事件列表
                                events.add(mapOf(
                                    "eventType" to "location_update",
                                    "data" to locationData
                                ))
                                
                                android.util.Log.v("HistoryEventsParser", "📍 Location event #$locationCount: ${replayLoc.lat}, ${replayLoc.lon}")
                            }
                            is ReplaySetNavigationRoute -> {
                                // 路线设置事件
                                routeCount++
                                val routeData = serializeRoute(replayEvent)
                                
                                // 保存第一个路线作为初始路线
                                if (initialRoute == null && routeData != null) {
                                    initialRoute = routeData
                                    android.util.Log.d("HistoryEventsParser", "🗺️ Initial route captured")
                                }
                                
                                if (routeData != null) {
                                    events.add(mapOf(
                                        "eventType" to "route_assignment",
                                        "data" to routeData
                                    ))
                                }
                            }
                            else -> {
                                // 其他类型的回放事件
                                android.util.Log.v("HistoryEventsParser", "⚠️ Unknown replay event type: ${replayEvent::class.simpleName}")
                            }
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.w("HistoryEventsParser", "⚠️ Failed to process event #$eventCount: ${e.message}")
                }
            }
            
            android.util.Log.d("HistoryEventsParser", "✅ Parsing complete:")
            android.util.Log.d("HistoryEventsParser", "   - Total events processed: $eventCount")
            android.util.Log.d("HistoryEventsParser", "   - Location updates: $locationCount")
            android.util.Log.d("HistoryEventsParser", "   - Route events: $routeCount")
            android.util.Log.d("HistoryEventsParser", "   - Has initial route: ${initialRoute != null}")
            
            return mapOf(
                "historyId" to historyId,
                "events" to events,
                "rawLocations" to rawLocations,
                "initialRoute" to initialRoute
            )
            
        } catch (e: Exception) {
            android.util.Log.e("HistoryEventsParser", "❌ Failed to parse history file: ${e.message}", e)
            throw Exception("Failed to parse history file: ${e.message}")
        }
    }
    
    /**
     * 序列化 ReplayEventLocation（来自回放历史）
     */
    private fun serializeReplayLocation(location: ReplayEventLocation): Map<String, Any?> {
        val data = mutableMapOf<String, Any?>(
            "latitude" to location.lat,
            "longitude" to location.lon
        )
        
        // time 是 Double?，单位是秒，转换为毫秒
        location.time?.let { timeSeconds ->
            data["timestamp"] = (timeSeconds * 1000).toLong()
        }
        
        // 添加可选字段
        location.altitude?.let { 
            data["altitude"] = it 
        }
        
        location.accuracyHorizontal?.let {
            data["accuracy"] = it
            data["horizontalAccuracy"] = it
        }
        
        location.speed?.let { 
            data["speed"] = it 
        }
        
        location.bearing?.let { 
            data["course"] = it 
        }
        
        return data
    }
    
    /**
     * 序列化路线数据（来自 ReplaySetNavigationRoute）
     */
    private fun serializeRoute(replaySetRoute: ReplaySetNavigationRoute): Map<String, Any?>? {
        return try {
            val navigationRoute: NavigationRoute = replaySetRoute.route ?: return null
            
            val data = mutableMapOf<String, Any?>()
            
            // 从 NavigationRoute 中获取 DirectionsRoute
            try {
                val directionsRoute = navigationRoute.directionsRoute
                data["distance"] = directionsRoute.distance()
                data["duration"] = directionsRoute.duration()
                
                // 添加几何信息
                val geometry = directionsRoute.geometry()
                if (geometry != null) {
                    data["geometry"] = geometry
                }
            } catch (e: Exception) {
                android.util.Log.w("HistoryEventsParser", "⚠️ Failed to access DirectionsRoute: ${e.message}")
            }
            
            data
        } catch (e: Exception) {
            android.util.Log.w("HistoryEventsParser", "⚠️ Failed to serialize route: ${e.message}")
            null
        }
    }
}
