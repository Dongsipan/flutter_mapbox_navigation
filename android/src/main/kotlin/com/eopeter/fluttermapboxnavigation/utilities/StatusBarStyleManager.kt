package com.eopeter.fluttermapboxnavigation.utilities

import android.app.Activity
import android.os.Build
import android.view.View
import android.view.WindowInsetsController
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat

/**
 * 状态栏样式管理器
 */
object StatusBarStyleManager {
    
    /**
     * 设置透明状态栏
     */
    fun setupTransparentStatusBar(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.window.setDecorFitsSystemWindows(false)
        } else {
            @Suppress("DEPRECATION")
            activity.window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }
        
        // 设置状态栏为透明
        activity.window.statusBarColor = android.graphics.Color.TRANSPARENT
    }
    
    /**
     * 根据地图样式更新状态栏文字颜色
     */
    fun updateStatusBarForMapStyle(activity: Activity, styleUri: String) {
        val windowInsetsController = WindowCompat.getInsetsController(activity.window, activity.window.decorView)
        
        // 判断是否为深色主题
        val isDarkStyle = styleUri.contains("dark", ignoreCase = true) || 
                         styleUri.contains("night", ignoreCase = true)
        
        // 设置状态栏文字颜色
        windowInsetsController.isAppearanceLightStatusBars = !isDarkStyle
    }
}
