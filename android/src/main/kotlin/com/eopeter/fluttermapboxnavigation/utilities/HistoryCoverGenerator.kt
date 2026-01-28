package com.eopeter.fluttermapboxnavigation.utilities

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.mapbox.geojson.Point
import com.mapbox.geojson.LineString
import com.mapbox.geojson.Feature
import com.mapbox.maps.MapSnapshotOptions
import com.mapbox.maps.Size
import com.mapbox.maps.Snapshotter
import com.mapbox.maps.Style
import com.mapbox.maps.SnapshotStyleListener
import com.mapbox.maps.extension.style.expressions.dsl.generated.*
import com.mapbox.maps.extension.style.expressions.generated.Expression
import com.mapbox.maps.extension.style.sources.generated.geoJsonSource
import com.mapbox.maps.extension.style.layers.generated.lineLayer
import com.mapbox.maps.extension.style.layers.generated.circleLayer
import com.mapbox.maps.extension.style.layers.properties.generated.LineCap
import com.mapbox.maps.extension.style.layers.properties.generated.LineJoin
import com.mapbox.maps.extension.style.sources.addSource
import com.mapbox.maps.extension.style.layers.addLayer
import com.mapbox.bindgen.Value
import com.mapbox.navigation.core.replay.history.ReplayEventBase
import com.mapbox.turf.TurfMeasurement
import com.mapbox.turf.TurfConstants
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/**
 * 历史封面生成器
 * 负责为导航历史记录生成带速度渐变的路线封面图
 */
object HistoryCoverGenerator {
    
    private const val TAG = "HistoryCoverGenerator"
    
    // 封面尺寸配置
    // 生成更高的封面以包含底部水印区域
    // 生成比例约 1.69:1 (720:426)
    // 显示时使用 2.2:1 和 1.91:1，会自动裁剪底部水印
    private const val COVER_WIDTH = 720f
    private const val COVER_HEIGHT = 426f  // 比2.2:1的327px高出约100px
    
    // 渲染配置
    // lineWidth 单位是像素（pixels），不需要乘以 density
    // 与 iOS 的 setLineWidth 使用相同的数值以保持视觉一致
    // 如果视觉上仍有差异，可以微调此值（建议范围：4.0 - 6.0）
    private const val LINE_WIDTH = 6.0  // 像素单位，与 iOS 保持一致
    private const val MARKER_RADIUS = 6.0
    private const val MIN_POINT_DISTANCE = 0.5  // 米
    
    // 图层和数据源 ID
    private const val ROUTE_SOURCE_ID = "route-source"
    private const val ROUTE_LAYER_ID = "route-layer"
    private const val START_POINT_SOURCE_ID = "start-point-source"
    private const val START_POINT_LAYER_ID = "start-point-layer"
    private const val END_POINT_SOURCE_ID = "end-point-source"
    private const val END_POINT_LAYER_ID = "end-point-layer"
    
    /**
     * 封面生成回调接口
     */
    interface HistoryCoverCallback {
        fun onSuccess(coverPath: String)
        fun onFailure(error: String)
    }
    
    /**
     * 生成历史封面的主入口方法
     */
    suspend fun generateHistoryCover(
        context: Context,
        filePath: String,
        historyId: String,
        mapStyle: String?,
        lightPreset: String?,
        callback: HistoryCoverCallback
    ) = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "开始生成封面: historyId=$historyId, filePath=$filePath")
            
            // 1. 加载历史文件
            val events = NavigationHistoryManager.loadReplayEvents(filePath)
            if (events.isEmpty()) {
                Log.w(TAG, "历史文件为空")
                callback.onFailure("历史文件为空")
                return@withContext
            }
            
            // 2. 提取位置数据
            val (points, speeds, cumDistances) = extractLocationData(events)
            if (points.size < 2) {
                Log.w(TAG, "轨迹点不足，无法生成封面")
                callback.onFailure("轨迹点不足")
                return@withContext
            }
            
            Log.d(TAG, "提取位置数据完成: 点数=${points.size}")
            
            // 3. 在主线程创建 Snapshotter
            withContext(Dispatchers.Main) {
                createSnapshot(
                    context,
                    points,
                    speeds,
                    cumDistances,
                    historyId,
                    mapStyle,
                    lightPreset,
                    callback
                )
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "生成封面失败: ${e.message}", e)
            callback.onFailure("生成封面失败: ${e.message}")
        }
    }
    
    /**
     * 从历史事件中提取位置和速度数据
     * 返回: Triple<位置点列表, 速度列表(km/h), 累计距离列表(米)>
     */
    private fun extractLocationData(
        events: List<ReplayEventBase>
    ): Triple<List<Point>, List<Double>, List<Double>> {
        val points = mutableListOf<Point>()
        val speedsKmh = mutableListOf<Double>()
        val cumDistMeters = mutableListOf<Double>()
        var totalDistance = 0.0
        
        for (event in events) {
            try {
                val eventClass = event.javaClass
                val allFields = eventClass.declaredFields
                
                for (field in allFields) {
                    field.isAccessible = true
                    val fieldValue = field.get(event) ?: continue
                    
                    val fieldClass = fieldValue.javaClass
                    val latField = fieldClass.declaredFields.firstOrNull { f ->
                        f.name.contains("lat", ignoreCase = true) || f.name == "latitude"
                    }
                    val lngField = fieldClass.declaredFields.firstOrNull { f ->
                        f.name.contains("lng", ignoreCase = true) || 
                        f.name.contains("lon", ignoreCase = true) || 
                        f.name == "longitude"
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
                            val speedKmh = speed * 3.6  // 米/秒转km/h
                            
                            // 计算距离（如果不是第一个点）
                            if (points.isNotEmpty()) {
                                val lastPoint = points.last()
                                val distance = TurfMeasurement.distance(
                                    lastPoint, 
                                    point, 
                                    TurfConstants.UNIT_METERS
                                )
                                
                                // 过滤过近的点
                                if (distance > MIN_POINT_DISTANCE) {
                                    totalDistance += distance
                                    points.add(point)
                                    speedsKmh.add(speedKmh)
                                    cumDistMeters.add(totalDistance)
                                }
                            } else {
                                // 第一个点
                                points.add(point)
                                speedsKmh.add(speedKmh)
                                cumDistMeters.add(0.0)
                            }
                            
                            break
                        }
                    }
                }
            } catch (e: Exception) {
                // 忽略解析失败的事件
                continue
            }
        }
        
        Log.d(TAG, "位置数据提取完成: 总点数=${points.size}, 总距离=${totalDistance.toInt()}m")
        return Triple(points, speedsKmh, cumDistMeters)
    }
    
    /**
     * 根据速度获取对应的颜色（与 iOS 和 NavigationReplayActivity 保持一致）
     */
    private fun getColorForSpeed(speedKmh: Double): String {
        return when {
            speedKmh < 5.0  -> "#2E7DFF"  // 蓝色 - 慢速/停车
            speedKmh < 10.0 -> "#00E5FF"  // 青色 - 休闲骑行
            speedKmh < 15.0 -> "#00E676"  // 绿色 - 正常骑行
            speedKmh < 20.0 -> "#C6FF00"  // 黄绿色 - 快速骑行
            speedKmh < 25.0 -> "#FFD600"  // 黄色 - 高速骑行
            speedKmh < 30.0 -> "#FF9100"  // 橙色 - 冲刺速度
            else            -> "#FF1744"  // 红色 - 极速/下坡
        }
    }
    
    /**
     * 获取地图样式 URI
     */
    private fun getStyleUri(mapStyle: String?): String {
        return when (mapStyle) {
            "standard", "faded", "monochrome" -> Style.STANDARD
            "standardSatellite" -> Style.SATELLITE_STREETS
            "light" -> Style.LIGHT
            "dark" -> Style.DARK
            "outdoors" -> Style.OUTDOORS
            else -> Style.MAPBOX_STREETS
        }
    }
    
    /**
     * 应用样式配置（light preset 和 theme）
     */
    private fun applyStyleConfig(
        style: Style,
        mapStyle: String,
        lightPreset: String
    ) {
        val supportedStyles = listOf("standard", "standardSatellite", "faded", "monochrome")
        if (!supportedStyles.contains(mapStyle)) {
            Log.d(TAG, "样式 '$mapStyle' 不支持 Light Preset")
            return
        }
        
        try {
            // 1. 应用 light preset - 使用 Value 包装
            style.setStyleImportConfigProperty(
                "basemap",
                "lightPreset",
                Value(lightPreset)
            )
            Log.d(TAG, "Light preset 已应用: $lightPreset")
            
            // 2. 应用 theme - 使用 Value 包装
            when (mapStyle) {
                "faded" -> {
                    style.setStyleImportConfigProperty(
                        "basemap",
                        "theme",
                        Value("faded")
                    )
                    Log.d(TAG, "Theme 已应用: faded")
                }
                "monochrome" -> {
                    style.setStyleImportConfigProperty(
                        "basemap",
                        "theme",
                        Value("monochrome")
                    )
                    Log.d(TAG, "Theme 已应用: monochrome")
                }
                "standard" -> {
                    style.setStyleImportConfigProperty(
                        "basemap",
                        "theme",
                        Value("default")
                    )
                    Log.d(TAG, "Theme 已重置: default")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "应用样式配置失败: ${e.message}", e)
        }
    }
    
    /**
     * 在主线程创建快照
     */
    private fun createSnapshot(
        context: Context,
        points: List<Point>,
        speeds: List<Double>,
        cumDistances: List<Double>,
        historyId: String,
        mapStyle: String?,
        lightPreset: String?,
        callback: HistoryCoverCallback
    ) {
        try {
            // 1. 创建 LineString
            val lineString = LineString.fromLngLats(points)
            
            // 2. 配置快照选项
            val pixelRatio = context.resources.displayMetrics.density
            val snapshotOptions = MapSnapshotOptions.Builder()
                .size(Size(COVER_WIDTH, COVER_HEIGHT))
                .pixelRatio(pixelRatio)
                .build()
            
            // 3. 创建 Snapshotter
            val snapshotter = Snapshotter(context, snapshotOptions)
            
            // 4. 设置样式
            val styleUri = getStyleUri(mapStyle)
            snapshotter.setStyleUri(styleUri)
            Log.d(TAG, "使用样式: $styleUri")
            
            // 5. 设置相机位置（使用 cameraForCoordinates 自动计算）
            // 调整边距：
            // - top: 增加，确保轨迹不会太靠上
            // - bottom: 大幅增加，确保轨迹不会延伸到会被裁剪的区域
            //   (2.2:1会裁剪底部99px，1.91:1会裁剪底部49px)
            // - left/right: 保持，确保宽屏下轨迹完整
            val padding = com.mapbox.maps.EdgeInsets(50.0, 50.0, 110.0, 50.0)
            val camera = snapshotter.cameraForCoordinates(lineString.coordinates(), padding, null, null)
            snapshotter.setCamera(camera)
            Log.d(TAG, "相机已设置: center=${camera.center}, zoom=${camera.zoom}")
            Log.d(TAG, "封面尺寸: ${COVER_WIDTH}x${COVER_HEIGHT} (约1.69:1 比例，包含底部水印区域)")
            Log.d(TAG, "边距: top=50, left=50, bottom=110, right=50")
            Log.d(TAG, "说明: 底部padding=110px，确保轨迹不会延伸到裁剪区域(99px)")
            
            // 6. 设置样式监听器
            snapshotter.setStyleListener(object : SnapshotStyleListener {
                override fun onDidFinishLoadingStyle(style: Style) {
                    Log.d(TAG, "样式加载完成，开始添加图层")
                    
                    try {
                        // 添加数据源和图层
                        addRouteLayersToStyle(
                            style,
                            lineString,
                            points,
                            speeds,
                            cumDistances
                        )
                        
                        // 应用样式配置
                        if (mapStyle != null && lightPreset != null) {
                            applyStyleConfig(style, mapStyle, lightPreset)
                        }
                        
                        // 开始生成快照（Mapbox v11 回调签名：bitmap 和 error）
                        snapshotter.start { bitmap, error ->
                            handleSnapshotResult(
                                bitmap,
                                error,
                                snapshotter,
                                context,
                                historyId,
                                callback
                            )
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "添加图层失败: ${e.message}", e)
                        snapshotter.cancel()
                        callback.onFailure("添加图层失败: ${e.message}")
                    }
                }
            })
            
        } catch (e: Exception) {
            Log.e(TAG, "创建快照失败: ${e.message}", e)
            callback.onFailure("创建快照失败: ${e.message}")
        }
    }
    
    /**
     * 添加路线图层到样式
     */
    private fun addRouteLayersToStyle(
        style: Style,
        lineString: LineString,
        points: List<Point>,
        speeds: List<Double>,
        cumDistances: List<Double>
    ) {
        // 1. 添加路线数据源（必须开启 lineMetrics）
        val routeSource = geoJsonSource(ROUTE_SOURCE_ID) {
            lineMetrics(true)
            feature(Feature.fromGeometry(lineString))
        }
        style.addSource(routeSource)
        Log.d(TAG, "路线数据源已添加")
        
        // 2. 构建速度渐变表达式
        val gradientExpression = buildSpeedGradientExpression(speeds, cumDistances)
        
        // 3. 添加路线图层
        val routeLayer = lineLayer(ROUTE_LAYER_ID, ROUTE_SOURCE_ID) {
            lineCap(LineCap.ROUND)
            lineJoin(LineJoin.ROUND)
            lineWidth(LINE_WIDTH)
            lineGradient(gradientExpression)
        }
        style.addLayer(routeLayer)
        Log.d(TAG, "路线图层已添加，lineWidth = $LINE_WIDTH pixels（不乘 density）")
        
        // 4. 添加起点标记
        val startPoint = points.first()
        val startSource = geoJsonSource(START_POINT_SOURCE_ID) {
            feature(Feature.fromGeometry(startPoint))
        }
        style.addSource(startSource)
        
        val startLayer = circleLayer(START_POINT_LAYER_ID, START_POINT_SOURCE_ID) {
            circleColor("#00E676")  // 绿色
            circleRadius(MARKER_RADIUS)
        }
        style.addLayer(startLayer)
        Log.d(TAG, "起点标记已添加")
        
        // 5. 添加终点标记
        val endPoint = points.last()
        val endSource = geoJsonSource(END_POINT_SOURCE_ID) {
            feature(Feature.fromGeometry(endPoint))
        }
        style.addSource(endSource)
        
        val endLayer = circleLayer(END_POINT_LAYER_ID, END_POINT_SOURCE_ID) {
            circleColor("#FF5252")  // 红色
            circleRadius(MARKER_RADIUS)
        }
        style.addLayer(endLayer)
        Log.d(TAG, "终点标记已添加")
    }
    
    /**
     * 构建速度渐变表达式
     */
    private fun buildSpeedGradientExpression(
        speeds: List<Double>,
        cumDistances: List<Double>
    ): Expression {
        if (speeds.size < 2 || cumDistances.isEmpty()) {
            Log.w(TAG, "速度数据不足，使用默认颜色")
            return toColor { literal("#4CAF50") }
        }
        
        val totalDist = cumDistances.lastOrNull() ?: 0.0
        if (totalDist <= 0.0) {
            Log.w(TAG, "总距离为0，使用默认颜色")
            return toColor { literal("#4CAF50") }
        }
        
        // 收集渐变节点（最多20个）
        val gradientStops = mutableListOf<Pair<Double, String>>()
        
        // 起点
        gradientStops.add(0.0 to getColorForSpeed(speeds.first()))
        
        // 中间点 - 采样
        val step = kotlin.math.max(1, speeds.size / 20)
        for (i in step until speeds.size step step) {
            val dist = cumDistances.getOrNull(i) ?: continue
            val progress = (dist / totalDist).coerceIn(0.0, 1.0)
            val speed = speeds.getOrNull(i) ?: 0.0
            val color = getColorForSpeed(speed)
            
            // 只添加进度值大于前一个的节点
            if (gradientStops.isEmpty() || progress > gradientStops.last().first) {
                gradientStops.add(progress to color)
            }
        }
        
        // 终点
        val lastProgress = gradientStops.lastOrNull()?.first ?: 0.0
        if (lastProgress < 1.0) {
            gradientStops.add(1.0 to getColorForSpeed(speeds.last()))
        }
        
        Log.d(TAG, "渐变节点数: ${gradientStops.size}")
        
        // 构建 interpolate 表达式
        return interpolate {
            linear()
            lineProgress()
            
            for ((progress, color) in gradientStops) {
                stop {
                    literal(progress)
                    toColor { literal(color) }
                }
            }
        }
    }
    
    /**
     * 处理快照生成结果
     */
    private fun handleSnapshotResult(
        bitmap: Bitmap?,
        error: String?,
        snapshotter: Snapshotter,
        context: Context,
        historyId: String,
        callback: HistoryCoverCallback
    ) {
        try {
            if (error != null) {
                Log.e(TAG, "快照生成失败: $error")
                callback.onFailure("快照生成失败: $error")
            } else if (bitmap != null) {
                Log.d(TAG, "快照生成成功")
                
                // 保存快照
                val coverPath = saveSnapshot(bitmap, context, historyId)
                if (coverPath != null) {
                    // 更新历史记录
                    updateHistoryRecord(context, historyId, coverPath)
                    callback.onSuccess(coverPath)
                } else {
                    callback.onFailure("保存快照失败")
                }
            } else {
                Log.e(TAG, "快照生成失败: bitmap 和 error 都为 null")
                callback.onFailure("快照生成失败")
            }
        } finally {
            // 释放资源
            snapshotter.cancel()
            Log.d(TAG, "Snapshotter 已释放")
        }
    }
    
    /**
     * 保存快照到文件
     */
    private fun saveSnapshot(
        bitmap: Bitmap,
        context: Context,
        historyId: String
    ): String? {
        return try {
            val historyManager = HistoryManager(context)
            val historyDir = historyManager.getHistoryDirectory()
            val coverFile = File(historyDir, "${historyId}_cover.png")
            
            // 确保目录存在
            if (!historyDir.exists()) {
                historyDir.mkdirs()
            }
            
            // 保存为 PNG
            FileOutputStream(coverFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            
            Log.d(TAG, "封面已保存: ${coverFile.absolutePath}")
            coverFile.absolutePath
            
        } catch (e: Exception) {
            Log.e(TAG, "保存封面失败: ${e.message}", e)
            null
        }
    }
    
    /**
     * 更新历史记录的封面路径
     */
    private fun updateHistoryRecord(
        context: Context,
        historyId: String,
        coverPath: String
    ) {
        try {
            val historyManager = HistoryManager(context)
            val success = historyManager.updateHistoryCover(historyId, coverPath)
            if (success) {
                Log.d(TAG, "历史记录封面路径已更新")
            } else {
                Log.w(TAG, "更新历史记录封面路径失败")
            }
        } catch (e: Exception) {
            Log.e(TAG, "更新历史记录失败: ${e.message}", e)
        }
    }
}
