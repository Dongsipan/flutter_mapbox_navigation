package com.eopeter.fluttermapboxnavigation.activity

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.MenuItem
import android.view.View
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import com.eopeter.fluttermapboxnavigation.R
import com.google.android.material.button.MaterialButton
import com.google.android.material.switchmaterial.SwitchMaterial
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
        // 设置标题和返回按钮（使用深色背景）
        supportActionBar?.apply {
            title = "地图样式设置"
            setDisplayHomeAsUpEnabled(true)
            elevation = 4f
            // 设置 ActionBar 背景为深色
            setBackgroundDrawable(
                android.graphics.drawable.ColorDrawable(
                    resources.getColor(R.color.colorBackground, null)
                )
            )
        }
        
        // 地图样式选择
        val styleSpinner = findViewById<Spinner>(R.id.styleSpinner)
        val styleAdapter = ArrayAdapter.createFromResource(
            this,
            R.array.map_styles,
            R.layout.spinner_item_white
        )
        styleAdapter.setDropDownViewResource(R.layout.spinner_dropdown_item_white)
        styleSpinner.adapter = styleAdapter
        
        // 设置当前选中的样式
        val stylePosition = getStylePosition(selectedStyle)
        styleSpinner.setSelection(stylePosition)
        
        styleSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                // 设置选中项的文字颜色为白色
                (view as? TextView)?.setTextColor(resources.getColor(R.color.textPrimary, null))
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
            R.layout.spinner_item_white
        )
        lightPresetAdapter.setDropDownViewResource(R.layout.spinner_dropdown_item_white)
        lightPresetSpinner.adapter = lightPresetAdapter
        
        // 设置当前选中的 Light Preset
        val lightPresetPosition = getLightPresetPosition(selectedLightPreset)
        lightPresetSpinner.setSelection(lightPresetPosition)
        
        lightPresetSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                // 设置选中项的文字颜色为白色
                (view as? TextView)?.setTextColor(resources.getColor(R.color.textPrimary, null))
                selectedLightPreset = getLightPresetValue(position)
            }
            
            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }
        
        // 自动调整开关 - 使用 Material Switch
        val autoAdjustSwitch = findViewById<SwitchMaterial>(R.id.autoAdjustSwitch)
        autoAdjustSwitch.isChecked = lightPresetMode == "automatic"
        autoAdjustSwitch.setOnCheckedChangeListener { _, isChecked ->
            lightPresetMode = if (isChecked) "automatic" else "manual"
            // 当开启自动模式时，禁用手动选择
            lightPresetSpinner.isEnabled = !isChecked
        }
        
        // 初始化 spinner 状态
        lightPresetSpinner.isEnabled = lightPresetMode != "automatic"
        
        // 应用按钮 - 使用 Material Button
        findViewById<MaterialButton>(R.id.applyButton).setOnClickListener {
            val resultIntent = Intent().apply {
                putExtra(RESULT_STYLE, selectedStyle)
                putExtra(RESULT_LIGHT_PRESET, selectedLightPreset)
                putExtra(RESULT_LIGHT_PRESET_MODE, lightPresetMode)
            }
            setResult(Activity.RESULT_OK, resultIntent)
            finish()
        }
        
        // 取消按钮 - 使用 Material Button
        findViewById<MaterialButton>(R.id.cancelButton).setOnClickListener {
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
    
    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            android.R.id.home -> {
                setResult(Activity.RESULT_CANCELED)
                finish()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }
    
    override fun onBackPressed() {
        setResult(Activity.RESULT_CANCELED)
        super.onBackPressed()
    }
}
