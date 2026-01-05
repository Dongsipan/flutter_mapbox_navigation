package com.eopeter.fluttermapboxnavigation.utilities

import android.util.Log
import com.mapbox.maps.MapView
import com.mapbox.maps.Style

/**
 * 地图样式管理器 - SDK v3
 * 管理地图样式切换和日夜模式
 */
object MapStyleManager {
    
    private const val TAG = "MapStyleManager"
    
    private val registeredMapViews = mutableListOf<MapView>()
    private var currentDayStyle: String = Style.MAPBOX_STREETS
    private var currentNightStyle: String = Style.DARK
    private var isDarkMode: Boolean = false
    
    /**
     * 注册地图视图
     */
    fun registerMapView(mapView: MapView) {
        if (!registeredMapViews.contains(mapView)) {
            registeredMapViews.add(mapView)
            Log.d(TAG, "Registered map view, total: ${registeredMapViews.size}")
        }
    }
    
    /**
     * 注销地图视图
     */
    fun unregisterMapView(mapView: MapView) {
        registeredMapViews.remove(mapView)
        Log.d(TAG, "Unregistered map view, remaining: ${registeredMapViews.size}")
    }
    
    /**
     * 设置日间样式 URL
     */
    fun setDayStyle(styleUrl: String) {
        currentDayStyle = styleUrl
        Log.d(TAG, "Day style set to: $styleUrl")
        
        // 如果当前是日间模式，立即应用
        if (!isDarkMode) {
            applyStyleToAllMaps(styleUrl)
        }
    }
    
    /**
     * 设置夜间样式 URL
     */
    fun setNightStyle(styleUrl: String) {
        currentNightStyle = styleUrl
        Log.d(TAG, "Night style set to: $styleUrl")
        
        // 如果当前是夜间模式，立即应用
        if (isDarkMode) {
            applyStyleToAllMaps(styleUrl)
        }
    }
    
    /**
     * 切换到日间模式
     */
    fun switchToDayMode() {
        if (isDarkMode) {
            isDarkMode = false
            applyStyleToAllMaps(currentDayStyle)
            Log.d(TAG, "Switched to day mode")
        }
    }
    
    /**
     * 切换到夜间模式
     */
    fun switchToNightMode() {
        if (!isDarkMode) {
            isDarkMode = true
            applyStyleToAllMaps(currentNightStyle)
            Log.d(TAG, "Switched to night mode")
        }
    }
    
    /**
     * 切换日夜模式
     */
    fun toggleDayNightMode() {
        if (isDarkMode) {
            switchToDayMode()
        } else {
            switchToNightMode()
        }
    }
    
    /**
     * 获取当前样式 URL
     */
    fun getCurrentStyle(): String {
        return if (isDarkMode) currentNightStyle else currentDayStyle
    }
    
    /**
     * 是否为夜间模式
     */
    fun isDarkMode(): Boolean {
        return isDarkMode
    }
    
    /**
     * 应用样式到所有注册的地图
     */
    private fun applyStyleToAllMaps(styleUrl: String) {
        registeredMapViews.forEach { mapView ->
            try {
                mapView.mapboxMap.loadStyle(styleUrl) {
                    Log.d(TAG, "Style loaded successfully: $styleUrl")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load style: ${e.message}", e)
            }
        }
    }
    
    /**
     * 应用自定义样式到指定地图
     */
    fun applyCustomStyle(mapView: MapView, styleUrl: String) {
        try {
            mapView.mapboxMap.loadStyle(styleUrl) {
                Log.d(TAG, "Custom style loaded: $styleUrl")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load custom style: ${e.message}", e)
        }
    }
    
    /**
     * 清理所有注册的地图视图
     */
    fun cleanup() {
        registeredMapViews.clear()
        Log.d(TAG, "Cleaned up all registered map views")
    }
}
