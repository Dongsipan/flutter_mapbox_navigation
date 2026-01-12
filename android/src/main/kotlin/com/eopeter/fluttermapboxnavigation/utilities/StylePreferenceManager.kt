package com.eopeter.fluttermapboxnavigation.utilities

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.mapbox.bindgen.Value
import com.mapbox.maps.Style

/**
 * 地图样式偏好设置管理器
 * 
 * 统一管理地图样式、Light Preset 等设置的保存和读取
 */
object StylePreferenceManager {
    
    private const val TAG = "StylePreferenceManager"
    private const val PREFS_NAME = "mapbox_style_settings"
    private const val KEY_MAP_STYLE = "map_style"
    private const val KEY_LIGHT_PRESET = "light_preset"
    private const val KEY_LIGHT_PRESET_MODE = "light_preset_mode"
    
    // 默认值
    private const val DEFAULT_STYLE = "standard"
    private const val DEFAULT_LIGHT_PRESET = "day"
    private const val DEFAULT_LIGHT_PRESET_MODE = "manual"
    
    /**
     * 获取 SharedPreferences 实例
     */
    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
    
    /**
     * 保存地图样式设置
     */
    fun saveStyleSettings(
        context: Context,
        mapStyle: String,
        lightPreset: String,
        lightPresetMode: String
    ) {
        getPrefs(context).edit().apply {
            putString(KEY_MAP_STYLE, mapStyle)
            putString(KEY_LIGHT_PRESET, lightPreset)
            putString(KEY_LIGHT_PRESET_MODE, lightPresetMode)
            apply()
        }
        Log.d(TAG, "Saved style settings: style=$mapStyle, lightPreset=$lightPreset, mode=$lightPresetMode")
    }
    
    /**
     * 获取当前地图样式名称
     */
    fun getMapStyle(context: Context): String {
        return getPrefs(context).getString(KEY_MAP_STYLE, DEFAULT_STYLE) ?: DEFAULT_STYLE
    }
    
    /**
     * 获取当前 Light Preset
     */
    fun getLightPreset(context: Context): String {
        return getPrefs(context).getString(KEY_LIGHT_PRESET, DEFAULT_LIGHT_PRESET) ?: DEFAULT_LIGHT_PRESET
    }
    
    /**
     * 获取 Light Preset 模式
     */
    fun getLightPresetMode(context: Context): String {
        return getPrefs(context).getString(KEY_LIGHT_PRESET_MODE, DEFAULT_LIGHT_PRESET_MODE) ?: DEFAULT_LIGHT_PRESET_MODE
    }
    
    /**
     * 获取当前地图样式的 URL
     */
    fun getMapStyleUrl(context: Context): String {
        val styleName = getMapStyle(context)
        return getStyleUrl(styleName)
    }
    
    /**
     * 根据样式名称获取样式 URL
     */
    fun getStyleUrl(styleName: String): String {
        return when (styleName) {
            "standard" -> Style.MAPBOX_STREETS
            "standardSatellite" -> Style.SATELLITE_STREETS
            "faded" -> Style.LIGHT
            "monochrome" -> Style.DARK
            "light" -> Style.LIGHT
            "dark" -> Style.DARK
            "outdoors" -> Style.OUTDOORS
            else -> Style.MAPBOX_STREETS
        }
    }
    
    /**
     * Apply Light Preset to a loaded style if the style supports it
     * 
     * @param context Android context
     * @param style Loaded Mapbox style object
     */
    fun applyLightPresetToStyle(context: Context, style: Style) {
        val mapStyle = getMapStyle(context)
        val lightPreset = getLightPreset(context)
        
        // Only apply Light Preset to styles that support it
        if (supportsLightPreset(mapStyle)) {
            try {
                style.setStyleImportConfigProperty(
                    "basemap",
                    "lightPreset",
                    Value.valueOf(lightPreset)
                )
                Log.d(TAG, "✅ Applied Light Preset: $lightPreset to style: $mapStyle")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to apply Light Preset: ${e.message}", e)
            }
        } else {
            Log.d(TAG, "ℹ️ Style $mapStyle does not support Light Preset, skipping")
        }
    }
    
    /**
     * Check if a style supports Light Preset
     * 
     * Only standard, standardSatellite, faded, and monochrome styles support Light Preset
     */
    private fun supportsLightPreset(styleName: String): Boolean {
        return styleName in listOf("standard", "standardSatellite", "faded", "monochrome")
    }
    
    /**
     * 清除所有样式设置
     */
    fun clearSettings(context: Context) {
        getPrefs(context).edit().clear().apply()
        Log.d(TAG, "Cleared all style settings")
    }
    
    /**
     * 获取所有样式设置
     */
    fun getAllSettings(context: Context): Map<String, String> {
        return mapOf(
            "mapStyle" to getMapStyle(context),
            "lightPreset" to getLightPreset(context),
            "lightPresetMode" to getLightPresetMode(context)
        )
    }
}
