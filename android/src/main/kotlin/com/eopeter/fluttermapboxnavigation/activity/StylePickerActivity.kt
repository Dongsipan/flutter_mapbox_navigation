package com.eopeter.fluttermapboxnavigation.activity

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import com.eopeter.fluttermapboxnavigation.R
import com.mapbox.maps.Style

/**
 * 地图样式选择器 Activity
 * 
 * 允许用户选择地图样式和 Light Preset 设置
 */
class StylePickerActivity : AppCompatActivity() {
    
    companion object {
        const val EXTRA_CURRENT_STYLE = "current_style"
        const val EXTRA_CURRENT_LIGHT_PRESET = "current_light_preset"
        const val EXTRA_LIGHT_PRESET_MODE = "light_preset_mode"
        
        const val RESULT_STYLE = "map_style"
        const val RESULT_LIGHT_PRESET = "light_preset"
        const val RESULT_LIGHT_PRESET_MODE = "light_preset_mode"
    }
    
    private var selectedStyle: String = "standard"
    private var selectedLightPreset: String = "day"
    private var lightPresetMode: String = "manual"
    
    // 支持 Light Preset 的样式
    private val stylesWithLightPreset = setOf("standard", "standardSatellite", "faded", "monochrome")
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_style_picker)
        
        // 获取当前设置
        selectedStyle = intent.getStringExtra(EXTRA_CURRENT_STYLE) ?: "standard"
        selectedLightPreset = intent.getStringExtra(EXTRA_CURRENT_LIGHT_PRESET) ?: "day"
        lightPresetMode = intent.getStringExtra(EXTRA_LIGHT_PRESET_MODE) ?: "manual"
        
        setupUI()
    }
    
    private fun setupUI() {
        // 设置标题
        supportActionBar?.title = "地图样式设置"
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        
        // 地图样式选择
        val styleSpinner = findViewById<Spinner>(R.id.styleSpinner)
        val styleAdapter = ArrayAdapter.createFromResource(
            this,
            R.array.map_styles,
            android.R.layout.simple_spinner_item
        )
        styleAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        styleSpinner.adapter = styleAdapter
        
        // 设置当前选中的样式
        val stylePosition = getStylePosition(selectedStyle)
        styleSpinner.setSelection(stylePosition)
        
        styleSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                selectedStyle = getStyleValue(position)
                updateLightPresetVisibility()
            }
            
            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }
        
        // Light Preset 选择
        val lightPresetSpinner = findViewById<Spinner>(R.id.lightPresetSpinner)
        val lightPresetAdapter = ArrayAdapter.createFromResource(
            this,
            R.array.light_presets,
            android.R.layout.simple_spinner_item
        )
        lightPresetAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        lightPresetSpinner.adapter = lightPresetAdapter
        
        // 设置当前选中的 Light Preset
        val lightPresetPosition = getLightPresetPosition(selectedLightPreset)
        lightPresetSpinner.setSelection(lightPresetPosition)
        
        lightPresetSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                selectedLightPreset = getLightPresetValue(position)
            }
            
            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }
        
        // 自动调整开关
        val autoAdjustSwitch = findViewById<Switch>(R.id.autoAdjustSwitch)
        autoAdjustSwitch.isChecked = lightPresetMode == "automatic"
        autoAdjustSwitch.setOnCheckedChangeListener { _, isChecked ->
            lightPresetMode = if (isChecked) "automatic" else "manual"
        }
        
        // 应用按钮
        findViewById<Button>(R.id.applyButton).setOnClickListener {
            val resultIntent = Intent().apply {
                putExtra(RESULT_STYLE, selectedStyle)
                putExtra(RESULT_LIGHT_PRESET, selectedLightPreset)
                putExtra(RESULT_LIGHT_PRESET_MODE, lightPresetMode)
            }
            setResult(Activity.RESULT_OK, resultIntent)
            finish()
        }
        
        // 取消按钮
        findViewById<Button>(R.id.cancelButton).setOnClickListener {
            setResult(Activity.RESULT_CANCELED)
            finish()
        }
        
        // 初始化 Light Preset 可见性
        updateLightPresetVisibility()
    }
    
    private fun updateLightPresetVisibility() {
        val lightPresetContainer = findViewById<LinearLayout>(R.id.lightPresetContainer)
        val autoAdjustContainer = findViewById<LinearLayout>(R.id.autoAdjustContainer)
        
        val supportsLightPreset = stylesWithLightPreset.contains(selectedStyle)
        lightPresetContainer.visibility = if (supportsLightPreset) View.VISIBLE else View.GONE
        autoAdjustContainer.visibility = if (supportsLightPreset) View.VISIBLE else View.GONE
    }
    
    private fun getStylePosition(style: String): Int {
        return when (style) {
            "standard" -> 0
            "standardSatellite" -> 1
            "faded" -> 2
            "monochrome" -> 3
            "light" -> 4
            "dark" -> 5
            "outdoors" -> 6
            else -> 0
        }
    }
    
    private fun getStyleValue(position: Int): String {
        return when (position) {
            0 -> "standard"
            1 -> "standardSatellite"
            2 -> "faded"
            3 -> "monochrome"
            4 -> "light"
            5 -> "dark"
            6 -> "outdoors"
            else -> "standard"
        }
    }
    
    private fun getLightPresetPosition(preset: String): Int {
        return when (preset) {
            "dawn" -> 0
            "day" -> 1
            "dusk" -> 2
            "night" -> 3
            else -> 1
        }
    }
    
    private fun getLightPresetValue(position: Int): String {
        return when (position) {
            0 -> "dawn"
            1 -> "day"
            2 -> "dusk"
            3 -> "night"
            else -> "day"
        }
    }
    
    override fun onSupportNavigateUp(): Boolean {
        onBackPressed()
        return true
    }
}
