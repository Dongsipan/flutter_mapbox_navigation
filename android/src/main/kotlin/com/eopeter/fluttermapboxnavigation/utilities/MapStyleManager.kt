package com.eopeter.fluttermapboxnavigation.utilities

import com.mapbox.maps.MapView

/**
 * 地图样式管理器
 */
object MapStyleManager {
    
    private val registeredMapViews = mutableListOf<MapView>()
    
    /**
     * 注册地图视图
     */
    fun registerMapView(mapView: MapView) {
        if (!registeredMapViews.contains(mapView)) {
            registeredMapViews.add(mapView)
        }
    }
    
    /**
     * 注销地图视图
     */
    fun unregisterMapView(mapView: MapView) {
        registeredMapViews.remove(mapView)
    }
    
    /**
     * 清理所有注册的地图视图
     */
    fun cleanup() {
        registeredMapViews.clear()
    }
}
