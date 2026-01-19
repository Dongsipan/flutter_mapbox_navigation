package com.eopeter.fluttermapboxnavigation.activity

import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.eopeter.fluttermapboxnavigation.R
import com.eopeter.fluttermapboxnavigation.databinding.MapboxActivityReplayViewBinding
import com.mapbox.maps.CameraOptions
import com.mapbox.maps.EdgeInsets
import com.mapbox.maps.extension.style.expressions.dsl.generated.interpolate
import com.mapbox.maps.extension.style.expressions.dsl.generated.literal
import kotlinx.coroutines.launch
import com.mapbox.geojson.Point
import com.mapbox.geojson.LineString
import com.mapbox.geojson.Feature
import com.mapbox.maps.extension.style.sources.generated.geoJsonSource
import com.mapbox.maps.extension.style.sources.generated.GeoJsonSource
import com.mapbox.maps.extension.style.layers.generated.lineLayer
import com.mapbox.maps.extension.style.layers.generated.LineLayer
import com.mapbox.maps.extension.style.layers.generated.circleLayer
import com.mapbox.maps.extension.style.layers.properties.generated.LineJoin
import com.mapbox.maps.extension.style.expressions.dsl.generated.*
import com.mapbox.maps.extension.style.expressions.generated.Expression
import com.mapbox.maps.extension.style.sources.getSourceAs
import com.mapbox.maps.extension.style.layers.getLayerAs
import com.mapbox.maps.extension.style.sources.addSource
import com.mapbox.maps.extension.style.layers.addLayer
import com.mapbox.maps.extension.style.layers.addLayerBelow
import com.mapbox.maps.extension.style.sources.getSource
import com.mapbox.maps.extension.style.layers.getLayer
import com.mapbox.turf.TurfMeasurement
import com.mapbox.turf.TurfConstants
import kotlin.math.max
import kotlin.math.min
import com.mapbox.maps.plugin.compass.compass
import com.mapbox.maps.plugin.scalebar.scalebar
import com.mapbox.navigation.core.replay.history.ReplayEventBase
import com.eopeter.fluttermapboxnavigation.utilities.StatusBarStyleManager
import com.eopeter.fluttermapboxnavigation.utilities.MapStyleManager
import com.eopeter.fluttermapboxnavigation.utilities.NavigationHistoryManager
import com.eopeter.fluttermapboxnavigation.utilities.StylePreferenceManager

/**
 * 导航历史回放页面 - 静态轨迹渐变显示
 * 功能：加载历史文件 -> 提取位置和速度数据 -> 绘制速度渐变轨迹 -> 全览显示
 */
class NavigationReplayActivity : AppCompatActivity() {

    companion object { private const val TAG = "NavigationReplayActivity" }

    private lateinit var binding: MapboxActivityReplayViewBinding

    // 轨迹数据
    private val traveledPoints = mutableListOf<Point>()
    private val traveledSpeedsKmh = mutableListOf<Double>()
    private val traveledCumDistMeters = mutableListOf<Double>()

    override fun onCreate(savedInstanceState: Bundle?) {
        // 使用带 ActionBar 的主题（与 StylePickerActivity 一致）
        setTheme(R.style.KtMaterialTheme)
        super.onCreate(savedInstanceState)

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        binding = MapboxActivityReplayViewBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // 设置标题栏（使用 supportActionBar）
        setupActionBar()

        // 注册地图视图到样式管理器
        MapStyleManager.registerMapView(binding.mapView)
        
        // 加载用户偏好的地图样式
        val styleUri = StylePreferenceManager.getMapStyleUrl(this)
        Log.d(TAG, "Loading saved user preference style: $styleUri")
        
        binding.mapView.mapboxMap.loadStyle(styleUri) { style ->
            // Apply Light Preset if the style supports it
            StylePreferenceManager.applyLightPresetToStyle(this, style)
            
            Log.d(TAG, "Map style loaded successfully: $styleUri")
            
            // 样式加载完成后初始化图层并加载历史文件
            initTravelLineLayer(style)
            adjustMapComponentsForStatusBar()
            handleReplayFile()
        }
    }

    private fun handleReplayFile() {
        val filePath = intent.getStringExtra("replayFilePath")
        if (filePath.isNullOrEmpty()) {
            Log.w(TAG, "未提供回放文件路径")
            return
        }
        Log.d(TAG, "回放文件路径: $filePath")

        lifecycleScope.launch {
            try {
                // 加载回放事件
                val events = NavigationHistoryManager.loadReplayEvents(filePath)
                Log.d(TAG, "加载回放事件完成，事件数量: ${events.size}")
                if (events.isEmpty()) {
                    Log.w(TAG, "未能加载回放事件")
                    return@launch
                }

                // 提取位置数据并一次性绘制完整路线
                extractLocationData(events)
                drawCompleteRoute()
                
            } catch (e: Exception) {
                Log.e(TAG, "回放处理失败: ${e.message}", e)
            }
        }
    }

    /**
     * 从历史事件中提取位置和速度数据
     */
    private fun extractLocationData(events: List<ReplayEventBase>) {
        try {
            Log.d(TAG, "开始提取位置数据...")

            traveledPoints.clear()
            traveledSpeedsKmh.clear()
            traveledCumDistMeters.clear()
            
            var totalDistance = 0.0

            // 遍历所有事件，提取位置信息
            for (event in events) {
                try {
                    val eventClass = event.javaClass
                    
                    // 查找所有可能包含位置信息的字段
                    val allFields = eventClass.declaredFields
                    for (field in allFields) {
                        field.isAccessible = true
                        val fieldValue = field.get(event)

                        if (fieldValue != null) {
                            // 检查字段是否包含经纬度信息
                            val fieldClass = fieldValue.javaClass
                            val latField = fieldClass.declaredFields.firstOrNull { f ->
                                f.name.contains("lat", ignoreCase = true) || f.name == "latitude"
                            }
                            val lngField = fieldClass.declaredFields.firstOrNull { f ->
                                f.name.contains("lng", ignoreCase = true) || f.name.contains("lon", ignoreCase = true) || f.name == "longitude"
                            }

                            if (latField != null && lngField != null) {
                                latField.isAccessible = true
                                lngField.isAccessible = true

                                val lat = (latField.get(fieldValue) as? Number)?.toDouble()
                                val lng = (lngField.get(fieldValue) as? Number)?.toDouble()

                                if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                                    val point = Point.fromLngLat(lng, lat)

                                    // 查找速度字段
                                    val speedField = fieldClass.declaredFields.firstOrNull { f ->
                                        f.name.contains("speed", ignoreCase = true)
                                    }
                                    speedField?.isAccessible = true
                                    val speed = (speedField?.get(fieldValue) as? Number)?.toDouble() ?: 0.0
                                    val speedKmh = speed * 3.6 // 米/秒转km/h

                                    // 计算距离（如果不是第一个点）
                                    if (traveledPoints.isNotEmpty()) {
                                        val lastPoint = traveledPoints.last()
                                        val distance = TurfMeasurement.distance(lastPoint, point, TurfConstants.UNIT_METERS)

                                        // 过滤过近的点
                                        if (distance > 0.5) {
                                            totalDistance += distance
                                            traveledPoints.add(point)
                                            traveledSpeedsKmh.add(speedKmh)
                                            traveledCumDistMeters.add(totalDistance)

                                            if (traveledPoints.size <= 5) {
                                                Log.d(TAG, "添加轨迹点${traveledPoints.size}: lat=$lat, lng=$lng, 速度=${speedKmh.toInt()}km/h")
                                            }
                                        }
                                    } else {
                                        // 第一个点
                                        traveledPoints.add(point)
                                        traveledSpeedsKmh.add(speedKmh)
                                        traveledCumDistMeters.add(0.0)
                                        Log.d(TAG, "添加起点: lat=$lat, lng=$lng, 速度=${speedKmh.toInt()}km/h")
                                    }

                                    break // 找到位置信息后跳出字段循环
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    // 忽略解析失败的事件
                    continue
                }
            }

            Log.d(TAG, "位置数据提取完成: 总点数=${traveledPoints.size}, 总距离=${totalDistance.toInt()}m")

        } catch (e: Exception) {
            Log.e(TAG, "提取位置数据失败: ${e.message}", e)
        }
    }







    /**
     * 设置 ActionBar（与 StylePickerActivity 一致）
     */
    private fun setupActionBar() {
        try {
            // 从Intent获取标题参数
            val customTitle = intent.getStringExtra("title")
            
            supportActionBar?.apply {
                if (!customTitle.isNullOrEmpty()) {
                    title = customTitle
                    Log.d(TAG, "设置自定义标题: $customTitle")
                } else {
                    title = getString(R.string.navigation_replay_title)
                    Log.d(TAG, "使用默认标题")
                }
                
                setDisplayHomeAsUpEnabled(true)
                elevation = 4f
                // 设置 ActionBar 背景为深色
                setBackgroundDrawable(
                    android.graphics.drawable.ColorDrawable(
                        resources.getColor(R.color.colorBackground, null)
                    )
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "设置 ActionBar 失败: ${e.message}", e)
        }
    }
    
    override fun onOptionsItemSelected(item: android.view.MenuItem): Boolean {
        return when (item.itemId) {
            android.R.id.home -> {
                Log.d(TAG, "返回按钮被点击")
                onBackPressedDispatcher.onBackPressed()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }



    /**
     * 调整地图组件位置
     */
    private fun adjustMapComponentsForStatusBar() {
        Log.d(TAG, "调整地图组件位置")

        // 隐藏比例尺
        binding.mapView.scalebar.updateSettings {
            enabled = false
        }

        // 调整罗盘位置 - 右上角，留出适当边距
        binding.mapView.compass.updateSettings {
            marginTop = 16f
            marginRight = 16f
        }
        
        // 隐藏全览按钮（不需要模式切换）
        binding.routeOverview.visibility = View.GONE

        Log.d(TAG, "已调整地图组件位置")
    }

    /**
     * 获取状态栏高度（保留用于其他可能的用途）
     */
    private fun getStatusBarHeight(): Float {
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resourceId > 0) {
            resources.getDimensionPixelSize(resourceId).toFloat()
        } else {
            // 默认状态栏高度（约24dp转换为px）
            (24 * resources.displayMetrics.density)
        }
    }

    /**
     * 一次性绘制完整路线
     */
    private fun drawCompleteRoute() {
        if (traveledPoints.size < 2) {
            Log.w(TAG, "轨迹点不足，无法绘制路线")
            return
        }
        
        binding.mapView.mapboxMap.style?.let { style ->
            try {
                Log.d(TAG, "开始绘制路线，轨迹点数: ${traveledPoints.size}")
                
                // 绘制完整轨迹线
                val line = LineString.fromLngLats(traveledPoints)
                val lineSource = style.getSourceAs<GeoJsonSource>("replay-travel-line-source")
                if (lineSource != null) {
                    lineSource.feature(Feature.fromGeometry(line))
                    Log.d(TAG, "✅ 轨迹线已更新到 GeoJsonSource")
                } else {
                    Log.e(TAG, "❌ 找不到 replay-travel-line-source")
                }

                // 设置起点和终点
                val startPoint = traveledPoints.first()
                val endPoint = traveledPoints.last()
                
                Log.d(TAG, "起点: lat=${startPoint.latitude()}, lng=${startPoint.longitude()}")
                Log.d(TAG, "终点: lat=${endPoint.latitude()}, lng=${endPoint.longitude()}")

                val startSource = style.getSourceAs<GeoJsonSource>("replay-start-source")
                if (startSource != null) {
                    startSource.feature(Feature.fromGeometry(startPoint))
                    Log.d(TAG, "✅ 起点标记已更新")
                } else {
                    Log.e(TAG, "❌ 找不到 replay-start-source")
                }
                
                val endSource = style.getSourceAs<GeoJsonSource>("replay-end-source")
                if (endSource != null) {
                    endSource.feature(Feature.fromGeometry(endPoint))
                    Log.d(TAG, "✅ 终点标记已更新")
                } else {
                    Log.e(TAG, "❌ 找不到 replay-end-source")
                }
                    
                // 调整相机以显示整个轨迹
                adjustCameraToShowRoute()

                // 应用速度渐变
                val gradientExpr = buildSpeedGradientExpression()
                val layer = style.getLayerAs<LineLayer>("replay-travel-line-layer")
                if (layer != null) {
                    layer.lineGradient(gradientExpr)
                    Log.d(TAG, "✅ 速度渐变已应用到图层")
                } else {
                    Log.e(TAG, "❌ 找不到 replay-travel-line-layer")
                }

                val avgSpeed = if (traveledSpeedsKmh.isNotEmpty()) traveledSpeedsKmh.average() else 0.0
                Log.d(TAG, "✅ 完整路线绘制完成: 轨迹点${traveledPoints.size}, 平均速度${String.format("%.1f", avgSpeed)}km/h")

            } catch (e: Exception) {
                Log.e(TAG, "绘制完整路线失败: ${e.message}", e)
                e.printStackTrace()
            }
        } ?: Log.w(TAG, "❌ 样式未加载，无法绘制路线")
    }
    
    /**
     * 调整相机以显示整个路线（全览模式）
     */
    private fun adjustCameraToShowRoute() {
        if (traveledPoints.isEmpty()) {
            Log.w(TAG, "没有轨迹点，无法调整相机")
            return
        }
        
        try {
            // 计算所有点的边界
            var minLat = Double.POSITIVE_INFINITY
            var maxLat = Double.NEGATIVE_INFINITY
            var minLng = Double.POSITIVE_INFINITY
            var maxLng = Double.NEGATIVE_INFINITY
            
            for (point in traveledPoints) {
                minLat = min(minLat, point.latitude())
                maxLat = max(maxLat, point.latitude())
                minLng = min(minLng, point.longitude())
                maxLng = max(maxLng, point.longitude())
            }
            
            Log.d(TAG, "轨迹边界: lat[$minLat, $maxLat], lng[$minLng, $maxLng]")
            
            // 使用 Mapbox 的 cameraForCoordinates API 自动计算最佳相机位置
            val coordinateBounds = com.mapbox.geojson.Point.fromLngLat(minLng, minLat) to 
                                   com.mapbox.geojson.Point.fromLngLat(maxLng, maxLat)
            
            // 设置边距（像素）- 上下左右各留出空间
            val padding = com.mapbox.maps.EdgeInsets(
                100.0,  // top - 为标题栏留出空间
                50.0,   // left
                100.0,  // bottom
                50.0    // right
            )
            
            // 使用 cameraForCoordinateBounds 计算最佳相机位置
            val cameraOptions = binding.mapView.mapboxMap.cameraForCoordinateBounds(
                com.mapbox.maps.CoordinateBounds(
                    com.mapbox.geojson.Point.fromLngLat(minLng, minLat),
                    com.mapbox.geojson.Point.fromLngLat(maxLng, maxLat)
                ),
                padding
            )
            
            // 设置相机
            binding.mapView.mapboxMap.setCamera(cameraOptions)
            
            Log.d(TAG, "✅ 相机已调整到轨迹全览: center=${cameraOptions.center}, zoom=${cameraOptions.zoom}")
        } catch (e: Exception) {
            Log.e(TAG, "调整相机失败: ${e.message}", e)
            e.printStackTrace()
        }
    }
    
    /**
     * 计算全览模式的缩放级别
     */
    private fun calculateOverviewZoom(latDiff: Double, lngDiff: Double): Double {
        val maxDiff = max(latDiff, lngDiff)
        
        return when {
            maxDiff > 0.1 -> 10.0   // 很大范围
            maxDiff > 0.05 -> 12.0  // 大范围
            maxDiff > 0.02 -> 14.0  // 中等范围
            maxDiff > 0.01 -> 15.0  // 小范围
            maxDiff > 0.005 -> 16.0 // 很小范围
            else -> 17.0            // 极小范围
        }
    }

    /**
     * 初始化轨迹线图层（提取为独立函数以便复用）
     */
    private fun initTravelLineLayer(style: com.mapbox.maps.Style) {
        val travelSourceId = "replay-travel-line-source"
        val travelLayerId = "replay-travel-line-layer"
        val startSrcId = "replay-start-source"
        val endSrcId = "replay-end-source"
        val startLayerId = "replay-start-layer"
        val endLayerId = "replay-end-layer"

        if (style.getSource(travelSourceId) == null) {
            style.addSource(geoJsonSource(travelSourceId) { lineMetrics(true) })
        }
        // 找到位置图层的ID，确保我们的图层添加在它下面
        val locationLayerId = "mapbox-location-indicator-layer"
        val belowLayerId = if (style.getLayer(locationLayerId) != null) locationLayerId else null

        if (style.getLayer(travelLayerId) == null) {
            val layer = lineLayer(travelLayerId, travelSourceId) {
                // 不设置lineColor，使用lineGradient
                lineWidth(8.0) // 增加线宽从4.0到8.0，让轨迹更明显
                lineJoin(LineJoin.ROUND)
                // lineCap(LineCap.ROUND) // 添加圆形端点，让线条更美观 - 暂时注释掉，避免导入问题
                // 设置初始渐变（单色）
                lineGradient(toColor { literal("#4CAF50") })
            }

            if (belowLayerId != null) {
                style.addLayerBelow(layer, belowLayerId)
            } else {
                style.addLayer(layer)
            }
        }
        if (style.getSource(startSrcId) == null) {
            style.addSource(geoJsonSource(startSrcId) { })
        }
        if (style.getSource(endSrcId) == null) {
            style.addSource(geoJsonSource(endSrcId) { })
        }
        if (style.getLayer(startLayerId) == null) {
            if (belowLayerId != null) {
                style.addLayerBelow(circleLayer(startLayerId, startSrcId) {
                    circleColor("#00E676")
                    circleRadius(6.0)
                }, belowLayerId)
            } else {
                style.addLayer(circleLayer(startLayerId, startSrcId) {
                    circleColor("#00E676")
                    circleRadius(6.0)
                })
            }
        }
        if (style.getLayer(endLayerId) == null) {
            if (belowLayerId != null) {
                style.addLayerBelow(circleLayer(endLayerId, endSrcId) {
                    circleColor("#FF5252")
                    circleRadius(6.0)
                }, belowLayerId)
            } else {
                style.addLayer(circleLayer(endLayerId, endSrcId) {
                    circleColor("#FF5252")
                    circleRadius(6.0)
                })
            }
        }
    }

    // --- 速度渐变构建（骑行优化） ---
    private fun buildSpeedGradientExpression(): Expression {
        if (traveledPoints.size < 2 || traveledSpeedsKmh.isEmpty() || traveledCumDistMeters.isEmpty()) {
            Log.w(TAG, "❌ 轨迹点不足，使用默认颜色 - 点数:${traveledPoints.size}, 速度数:${traveledSpeedsKmh.size}")
            return toColor { literal("#4CAF50") }
        }

        val totalDist = traveledCumDistMeters.lastOrNull() ?: 0.0
        if (totalDist <= 0.0) {
            Log.w(TAG, "❌ 总距离为0，使用默认颜色")
            return toColor { literal("#4CAF50") }
        }

        Log.d(TAG, "✅ 构建速度渐变 - 点数:${traveledPoints.size}, 速度数:${traveledSpeedsKmh.size}, 总距离:${totalDist.toInt()}m")

        // 构建完整的多段速度渐变，确保进度值严格递增
        Log.d(TAG, "构建多段速度渐变，总距离: ${totalDist.toInt()}m")

        // 收集所有渐变节点，确保进度值唯一且递增
        val gradientStops = mutableListOf<Pair<Double, String>>()

        // 起点
        gradientStops.add(0.0 to getColorForSpeed(traveledSpeedsKmh.firstOrNull() ?: 0.0))

        // 中间点 - 每隔几个点创建一个渐变节点，避免过多节点
        val step = kotlin.math.max(1, traveledSpeedsKmh.size / 20) // 最多20个渐变节点
        for (i in step until traveledSpeedsKmh.size step step) {
            val dist = traveledCumDistMeters.getOrNull(i) ?: continue
            val progress = (dist / totalDist).coerceIn(0.0, 1.0)
            val speed = traveledSpeedsKmh.getOrNull(i) ?: 0.0
            val color = getColorForSpeed(speed)

            // 只添加进度值大于前一个的节点
            if (gradientStops.isEmpty() || progress > gradientStops.last().first) {
                gradientStops.add(progress to color)

                if (gradientStops.size <= 3) { // 只打印前几个点的调试信息
                    Log.d(TAG, "渐变节点: 进度=${(progress*100).toInt()}%, 速度=${String.format("%.1f", speed)}km/h, 颜色=$color")
                }
            }
        }

        // 终点 - 确保终点进度值为1.0且不重复
        val lastProgress = gradientStops.lastOrNull()?.first ?: 0.0
        if (lastProgress < 1.0) {
            gradientStops.add(1.0 to getColorForSpeed(traveledSpeedsKmh.lastOrNull() ?: 0.0))
        }

        return interpolate {
            linear()
            lineProgress()

            // 添加所有渐变节点
            for ((progress, color) in gradientStops) {
                stop {
                    literal(progress)
                    toColor { literal(color) }
                }
            }
        }
    }

    // 简化的颜色获取函数
    private fun getColorForSpeed(speedKmh: Double): String {
        return when {
            speedKmh < 5.0  -> "#2E7DFF" // 蓝色 - 慢速/停车
            speedKmh < 10.0 -> "#00E5FF" // 青色 - 休闲骑行
            speedKmh < 15.0 -> "#00E676" // 绿色 - 正常骑行
            speedKmh < 20.0 -> "#C6FF00" // 黄绿色 - 快速骑行
            speedKmh < 25.0 -> "#FFD600" // 黄色 - 高速骑行
            speedKmh < 30.0 -> "#FF9100" // 橙色 - 冲刺速度
            else            -> "#FF1744" // 红色 - 极速/下坡
        }
    }



    override fun onDestroy() {
        super.onDestroy()
        
        // 注销地图视图
        MapStyleManager.unregisterMapView(binding.mapView)
        
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}