package com.eopeter.fluttermapboxnavigation.activity

import android.content.Context
import android.content.res.Configuration
import com.mapbox.maps.Style

/**
 * 地图样式选择器
 */
object MapStyleSelectorActivity {
    
    /**
     * 根据UI模式获取地图样式
     */
    fun getStyleForUiMode(context: Context): String {
        val nightModeFlags = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return when (nightModeFlags) {
            Configuration.UI_MODE_NIGHT_YES -> Style.DARK
            else -> Style.MAPBOX_STREETS
        }
    }
}
