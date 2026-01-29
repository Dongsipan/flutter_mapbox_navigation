package com.eopeter.fluttermapboxnavigation.utilities

import android.content.Context
import android.util.Log
import com.mapbox.geojson.Point
import com.mapbox.search.ResponseInfo
import com.mapbox.search.ReverseGeoOptions
import com.mapbox.search.SearchEngine
import com.mapbox.search.SearchEngineSettings
import com.mapbox.search.result.SearchResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/**
 * 反地理编码工具类
 * 使用 Mapbox SearchEngine 将坐标转换为地点名称
 * 不依赖 Google Play Services
 */
object ReverseGeocoder {
    private const val TAG = "ReverseGeocoder"
    private const val TIMEOUT_MS = 5000L // 5秒超时
    
    private var searchEngine: SearchEngine? = null
    
    /**
     * 初始化 SearchEngine（延迟初始化）
     * 使用 SEARCH_BOX API（官方推荐用于反地理编码）
     */
    private fun getSearchEngine(): SearchEngine {
        if (searchEngine == null) {
            searchEngine = SearchEngine.createSearchEngineWithBuiltInDataProviders(
                com.mapbox.search.ApiType.SEARCH_BOX,
                SearchEngineSettings()
            )
        }
        return searchEngine!!
    }
    
    /**
     * 占位符名称列表
     * 这些名称被认为是无效的，需要进行反地理编码
     */
    private val PLACEHOLDER_NAMES = setOf(
        "起点", "终点", 
        "未知起点", "未知终点",
        "Start", "End", 
        "Start Point", "End Point",
        "Destination",
        "Unknown",
        ""
    )
    
    /**
     * 检查名称是否是占位符
     */
    fun isPlaceholderName(name: String?): Boolean {
        return name == null || name.trim() in PLACEHOLDER_NAMES
    }
    
    /**
     * 检查字符串是否是邮政编码
     * 邮政编码通常是纯数字或特定格式
     */
    private fun isPostalCode(name: String): Boolean {
        // 检查是否是纯数字（如 "215008"）
        if (name.matches(Regex("^\\d+$"))) {
            return true
        }
        // 检查是否是带连字符的邮政编码（如 "215008-1234"）
        if (name.matches(Regex("^\\d+-\\d+$"))) {
            return true
        }
        return false
    }
    
    /**
     * 反地理编码：将坐标转换为地点名称
     * 使用 Mapbox SearchEngine，不依赖 Google Play Services
     * 
     * @param context Android Context（未使用，保留以兼容接口）
     * @param point 坐标点
     * @return 地点名称，如果失败返回 null
     */
    suspend fun reverseGeocode(context: Context, point: Point): String? {
        return withTimeoutOrNull(TIMEOUT_MS) {
            suspendCancellableCoroutine { continuation ->
                try {
                    val latitude = point.latitude()
                    val longitude = point.longitude()
                    
                    Log.d(TAG, "📍 正在反地理编码 (Mapbox): $latitude, $longitude")
                    
                    val options = ReverseGeoOptions(
                        center = point,
                        limit = 1
                    )
                    
                    val task = getSearchEngine().search(options, object : com.mapbox.search.SearchCallback {
                        override fun onResults(results: List<SearchResult>, responseInfo: ResponseInfo) {
                            if (results.isNotEmpty()) {
                                val result = results.first()
                                
                                // 打印详细的调试信息
                                Log.d(TAG, "========== 反地理编码结果详情 ==========")
                                Log.d(TAG, "result.name: ${result.name}")
                                Log.d(TAG, "result.address: ${result.address}")
                                result.address?.let { addr ->
                                    Log.d(TAG, "  - street: ${addr.street}")
                                    Log.d(TAG, "  - neighborhood: ${addr.neighborhood}")
                                    Log.d(TAG, "  - locality: ${addr.locality}")
                                    Log.d(TAG, "  - place: ${addr.place}")
                                    Log.d(TAG, "  - district: ${addr.district}")
                                    Log.d(TAG, "  - region: ${addr.region}")
                                    Log.d(TAG, "  - country: ${addr.country}")
                                    Log.d(TAG, "  - postcode: ${addr.postcode}")
                                    Log.d(TAG, "  - formattedAddress: ${addr.formattedAddress()}")
                                }
                                Log.d(TAG, "result.descriptionText: ${result.descriptionText}")
                                Log.d(TAG, "result.matchingName: ${result.matchingName}")
                                Log.d(TAG, "========================================")
                                
                                // 提取有意义的地点名称
                                // 参考 iOS 的逻辑：优先级 name > thoroughfare > locality
                                // 但要过滤掉邮政编码
                                val placeName = when {
                                    // 1. 如果 name 不是邮政编码，优先使用
                                    !result.name.isNullOrEmpty() && !isPostalCode(result.name) -> {
                                        result.name
                                    }
                                    // 2. 使用街道名（对应 iOS 的 thoroughfare）
                                    !result.address?.street.isNullOrEmpty() -> {
                                        result.address?.street
                                    }
                                    // 3. 使用格式化地址
                                    !result.address?.formattedAddress().isNullOrEmpty() -> {
                                        result.address?.formattedAddress()
                                    }
                                    // 4. 使用地区名（对应 iOS 的 locality）
                                    !result.address?.place.isNullOrEmpty() -> {
                                        result.address?.place
                                    }
                                    // 5. 使用城市名
                                    !result.address?.locality.isNullOrEmpty() -> {
                                        result.address?.locality
                                    }
                                    // 6. 最后才使用 name（即使是邮政编码）
                                    !result.name.isNullOrEmpty() -> {
                                        result.name
                                    }
                                    else -> null
                                }
                                
                                if (!placeName.isNullOrEmpty()) {
                                    Log.d(TAG, "✅ 反地理编码成功: $placeName (原始name: ${result.name})")
                                    continuation.resume(placeName)
                                } else {
                                    Log.w(TAG, "⚠️ 反地理编码返回空名称")
                                    continuation.resume(null)
                                }
                            } else {
                                Log.w(TAG, "⚠️ 反地理编码返回空结果")
                                continuation.resume(null)
                            }
                        }
                        
                        override fun onError(e: Exception) {
                            Log.e(TAG, "⚠️ 反地理编码失败: ${e.message}", e)
                            continuation.resume(null)
                        }
                    })
                    
                    // 设置取消回调
                    continuation.invokeOnCancellation {
                        task.cancel()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "⚠️ 反地理编码异常: ${e.message}", e)
                    continuation.resume(null)
                }
            }
        }
    }
    
    /**
     * 批量反地理编码
     * 
     * @param context Android Context
     * @param startPoint 起点坐标
     * @param endPoint 终点坐标
     * @param startName 起点名称（如果是占位符会被替换）
     * @param endName 终点名称（如果是占位符会被替换）
     * @return Pair<起点名称, 终点名称>
     */
    suspend fun reverseGeocodeWaypoints(
        context: Context,
        startPoint: Point,
        endPoint: Point,
        startName: String?,
        endName: String?
    ): Pair<String, String> = withContext(Dispatchers.IO) {
        var finalStartName = startName ?: "Unknown"
        var finalEndName = endName ?: "Unknown"
        
        // 检查起点名称
        if (isPlaceholderName(startName)) {
            Log.d(TAG, "🔍 起点名称是占位符: $startName，开始反地理编码")
            reverseGeocode(context, startPoint)?.let { name ->
                finalStartName = name
                Log.d(TAG, "✅ 起点反地理编码成功: $name")
            } ?: run {
                Log.w(TAG, "⚠️ 起点反地理编码失败，使用默认值")
                finalStartName = "Unknown Start"
            }
        } else {
            Log.d(TAG, "✅ 使用起点名称: $startName")
        }
        
        // 检查终点名称
        if (isPlaceholderName(endName)) {
            Log.d(TAG, "🔍 终点名称是占位符: $endName，开始反地理编码")
            reverseGeocode(context, endPoint)?.let { name ->
                finalEndName = name
                Log.d(TAG, "✅ 终点反地理编码成功: $name")
            } ?: run {
                Log.w(TAG, "⚠️ 终点反地理编码失败，使用默认值")
                finalEndName = "Unknown End"
            }
        } else {
            Log.d(TAG, "✅ 使用终点名称: $endName")
        }
        
        Pair(finalStartName, finalEndName)
    }
}
