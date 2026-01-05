package com.eopeter.fluttermapboxnavigation

import android.annotation.SuppressLint
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.Toast
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.eopeter.fluttermapboxnavigation.databinding.MapboxActivityReplayViewBinding
import com.mapbox.maps.CameraOptions
import com.mapbox.maps.plugin.locationcomponent.location
import com.mapbox.maps.plugin.animation.camera
import com.mapbox.maps.extension.style.expressions.dsl.generated.interpolate
import com.mapbox.maps.extension.style.expressions.dsl.generated.zoom
import com.mapbox.maps.extension.style.expressions.dsl.generated.literal
import com.mapbox.navigation.base.ExperimentalPreviewMapboxNavigationAPI
import com.mapbox.navigation.base.options.NavigationOptions
import com.mapbox.navigation.core.MapboxNavigation
import com.mapbox.navigation.core.lifecycle.MapboxNavigationApp
import com.mapbox.navigation.core.lifecycle.MapboxNavigationObserver
import com.mapbox.navigation.core.lifecycle.requireMapboxNavigation
import com.mapbox.navigation.core.trip.session.LocationMatcherResult
import com.mapbox.navigation.core.trip.session.LocationObserver
import com.mapbox.navigation.core.directions.session.RoutesObserver


import com.mapbox.navigation.ui.maps.NavigationStyles
import com.mapbox.navigation.ui.maps.location.NavigationLocationProvider
// 移除路线绘制相关导入，只保留真实轨迹绘制
import kotlinx.coroutines.launch
import com.mapbox.navigation.core.replay.history.ReplaySetNavigationRoute
import com.mapbox.navigation.ui.maps.camera.NavigationCamera
import com.mapbox.navigation.ui.maps.camera.data.MapboxNavigationViewportDataSource
import com.mapbox.navigation.ui.maps.camera.lifecycle.NavigationBasicGesturesHandler
import com.mapbox.geojson.Point
import com.mapbox.geojson.LineString
import com.mapbox.geojson.Feature
import com.mapbox.geojson.FeatureCollection
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
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.abs
import com.mapbox.navigation.ui.maps.camera.state.NavigationCameraState
import com.mapbox.maps.plugin.compass.compass
import com.mapbox.maps.plugin.scalebar.scalebar
import com.mapbox.maps.EdgeInsets
import kotlinx.coroutines.delay
// Replay stats temporarily disabled - import com.eopeter.fluttermapboxnavigation.replay.ReplayStatsBottomSheet
// Replay stats temporarily disabled - import com.eopeter.fluttermapboxnavigation.replay.ReplayStatsCalculator
import com.mapbox.navigation.core.replay.history.ReplayEventBase
import com.eopeter.fluttermapboxnavigation.utilities.StatusBarStyleManager
import com.eopeter.fluttermapboxnavigation.utilities.MapStyleManager
import com.eopeter.fluttermapboxnavigation.utilities.NavigationHistoryManager
import com.eopeter.fluttermapboxnavigation.activity.MapStyleSelectorActivity

/**
 * 导航历史回放页面 - 参照官方示例重构
 * 流程：1.初始化导航 -> 2.加载历史数据 -> 3.开始回放
 */
@OptIn(ExperimentalPreviewMapboxNavigationAPI::class)
class NavigationReplayActivity : AppCompatActivity() {

    companion object { private const val TAG = "NavigationReplayActivity" }

    private lateinit var binding: MapboxActivityReplayViewBinding
    private val navigationLocationProvider = NavigationLocationProvider()
    private var isLocationInitialized = false
    private var isOverviewMode = false
    private var lastCameraUpdateTime = 0L

    // 不再需要路线绘制组件，只显示真实行驶轨迹

    // 相机和视口组件
    private lateinit var navigationCamera: NavigationCamera
    private lateinit var viewportDataSource: MapboxNavigationViewportDataSource

    // 增量轨迹绘制所需状态
    private val traveledPoints = mutableListOf<Point>()
    private val traveledSpeedsKmh = mutableListOf<Double>()
    private val traveledCumDistMeters = mutableListOf<Double>()
    private var lastPointTimeMs: Long = 0L
    private var travelLastUpdateAt = 0L
    private var gradientLastUpdateAt = 0L
    private var startPointAdded = false
    private var endPointCoord: Point? = null

    private val locationObserver = object : LocationObserver {
        override fun onNewRawLocation(rawLocation: android.location.Location) {
            Log.d(TAG, "收到原始位置更新: lat=${rawLocation.latitude}, lng=${rawLocation.longitude}")
        }

        override fun onNewLocationMatcherResult(locationMatcherResult: LocationMatcherResult) {
            Log.d(TAG, "收到位置匹配结果: lat=${locationMatcherResult.enhancedLocation.latitude}, lng=${locationMatcherResult.enhancedLocation.longitude}")

            if (!isLocationInitialized) {
                isLocationInitialized = true
                // 首次定位时设置相机
                val location = locationMatcherResult.enhancedLocation
                binding.mapView.getMapboxMap().setCamera(
                    CameraOptions.Builder()
                        .center(com.mapbox.geojson.Point.fromLngLat(location.longitude, location.latitude))
                        .zoom(15.0)
                        .build()
                )
                lastCameraUpdateTime = System.currentTimeMillis()
                Log.d(TAG, "首次位置更新，设置相机位置")
            } else {
                // 智能相机跟随：只在 puck 接近屏幕边缘时才调整相机
                if (!isOverviewMode) {
                    val location = locationMatcherResult.enhancedLocation
                    val currentPoint = com.mapbox.geojson.Point.fromLngLat(location.longitude, location.latitude)

                    if (shouldUpdateCamera(currentPoint)) {
                        binding.mapView.camera.easeTo(
                            CameraOptions.Builder()
                                .center(currentPoint)
                                .build(),
                            com.mapbox.maps.plugin.animation.MapAnimationOptions.Builder()
                                .duration(800) // 稍微延长动画时间，让移动更平滑
                                .build()
                        )
                        lastCameraUpdateTime = System.currentTimeMillis()
                        Log.d(TAG, "Puck接近边缘，调整相机位置")
                    }
                }
            }

            navigationLocationProvider.changePosition(
                locationMatcherResult.enhancedLocation,
                locationMatcherResult.keyPoints,
            )

                    // 只记录位置更新，不绘制额外的标记（使用系统的location puck即可）
            Log.d(TAG, "位置更新: lat=${locationMatcherResult.enhancedLocation.latitude}, lng=${locationMatcherResult.enhancedLocation.longitude}")
        }
    }

    // 不再需要路线观察者，因为我们只显示真实行驶轨迹



    private val mapboxNavigation: MapboxNavigation by requireMapboxNavigation(
        onResumedObserver = object : MapboxNavigationObserver {
            @SuppressLint("MissingPermission")
            override fun onAttached(mapboxNavigation: MapboxNavigation) {
                mapboxNavigation.registerLocationObserver(locationObserver)
                // 不注册路线观察者，因为我们只显示真实行驶轨迹
                // 不要在回放页面启动真实定位会话，避免相机先跳到设备当前位置
                // mapboxNavigation.startTripSession()
                // 导航初始化完成后处理回放文件（将使用 startReplayTripSession）
                handleReplayFile()
            }

            override fun onDetached(mapboxNavigation: MapboxNavigation) {
                mapboxNavigation.unregisterLocationObserver(locationObserver)
                // 不需要注销路线观察者
            }
        },
        onInitialize = this::initNavigation
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        // 确保使用 MaterialComponents 主题，避免 Material 组件膨胀失败
        setTheme(R.style.KtMaterialTheme_NoActionBar)
        super.onCreate(savedInstanceState)

        // 设置透明状态栏和全屏显示
        StatusBarStyleManager.setupTransparentStatusBar(this)

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        binding = MapboxActivityReplayViewBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // 设置标题栏
        setupTitleBar()

        // 注册地图视图到样式管理器
        MapStyleManager.registerMapView(binding.mapView)
        
        // 初始化地图样式
        val styleUri = MapStyleSelectorActivity.getStyleForUiMode(this)
        binding.mapView.getMapboxMap().loadStyleUri(styleUri)
        // 根据地图样式调整状态栏文字颜色
        StatusBarStyleManager.updateStatusBarForMapStyle(this@NavigationReplayActivity, styleUri)

        // 设置初始相机位置
        binding.mapView.getMapboxMap().setCamera(
            CameraOptions.Builder()
                .zoom(15.0)
                .build()
        )

        // 延迟处理回放文件，等待导航初始化完成
        // handleReplayFile() 将在 onAttached 回调中调用
    }

    private fun initNavigation() {
        // 初始化"真实行驶轨迹"源与图层（基于回放位置点绘制折线），并添加起终点图层
        binding.mapView.getMapboxMap().getStyle { style ->
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

        MapboxNavigationApp.setup(
            NavigationOptions.Builder(this)
                .build()
        )

        // 不再初始化路线绘制组件，只显示真实行驶轨迹

        // 初始化相机和视口组件
        viewportDataSource = MapboxNavigationViewportDataSource(binding.mapView.getMapboxMap())
        navigationCamera = NavigationCamera(
            binding.mapView.getMapboxMap(),
            binding.mapView.camera,
            viewportDataSource
        )
        // 设置手势处理器
        binding.mapView.camera.addCameraAnimationsLifecycleListener(
            NavigationBasicGesturesHandler(navigationCamera)
        )

        // 配置地图位置组件 - 使用默认配置
        binding.mapView.location.apply {
            setLocationProvider(navigationLocationProvider)
            enabled = true
            pulsingEnabled = true
        }

        // 设置路线全览按钮点击事件 - 支持切换
        binding.routeOverview.setOnClickListener {
            Log.d(TAG, "全览按钮被点击，当前模式: ${if (isOverviewMode) "全览" else "跟随"}")
            
            if (isOverviewMode) {
                Log.d(TAG, "用户点击切换到跟随模式")
                switchToFollowingMode()
            } else {
                Log.d(TAG, "用户点击切换到全览模式")
                if (traveledPoints.isEmpty()) {
                    Log.w(TAG, "轨迹数据为空，无法切换到全览模式")
                } else {
                    switchToOverviewMode()
                }
            }
        }

        // 显示路线全览按钮并设置初始状态
        binding.routeOverview.visibility = android.view.View.VISIBLE
        isOverviewMode = false
        updateOverviewButtonState()

        // 延迟调整地图组件位置，等待标题栏布局完成
        binding.titleBar.post {
            adjustMapComponentsForStatusBar()
        }
    }

    @SuppressLint("MissingPermission")
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

                // 预解析所有位置数据并一次性绘制完整路线
                Log.d(TAG, "准备调用预解析函数...")
                preDrawCompleteRoute(events)
                Log.d(TAG, "预解析函数调用完成")

                // 判断是否只做解析落盘
                val dumpOnly = intent.getBooleanExtra("dumpOnly", false)
                if (dumpOnly) {
                    // Temporarily disabled - val out = com.eopeter.fluttermapboxnavigation.replay.ReplayHistoryDumper.dumpToJson(this@NavigationReplayActivity, filePath, true)
                    Log.i(TAG, "dumpOnly mode temporarily disabled")
                    finish()
                    return@launch
                }

                // 推荐回放倍速函数：将实际时长压缩到可观看范围并取常用档位
                fun recommendReplaySpeed(distanceKm: Double, avgSpeedKmh: Double): Double {
                    val safeAvg = if (avgSpeedKmh > 0.1) avgSpeedKmh else 0.1
                    val durationSec = (distanceKm / safeAvg) * 3600.0
                    // 更激进：目标观看时长 1-5 分钟
                    val targetSec = (90.0 + 15.0 * ln(1.0 + distanceKm)).coerceIn(60.0, 300.0)
                    var speed = (durationSec / targetSec).coerceIn(4.0, 128.0)
                    // 慢速轨迹再加速
                    if (avgSpeedKmh < 5.0) speed *= 1.5
                    // 基于预计时长分级（越久 → 下限越高），更激进
                    when {
                        durationSec < 120.0   -> speed = max(speed, 4.0)    // < 2min
                        durationSec < 300.0   -> speed = max(speed, 8.0)    // < 5min
                        durationSec < 600.0   -> speed = max(speed, 12.0)   // < 10min
                        durationSec < 1200.0  -> speed = max(speed, 16.0)   // < 20min
                        durationSec < 2400.0  -> speed = max(speed, 24.0)   // < 40min
                        durationSec < 3600.0  -> speed = max(speed, 32.0)   // < 60min
                        else                   -> speed = max(speed, 48.0)   // ≥ 60min
                    }
                    // 总上限 128x（硬件允许的情况下）
                    val steps = doubleArrayOf(4.0, 6.0, 8.0, 10.0, 12.0, 16.0, 24.0, 32.0, 48.0, 64.0, 96.0, 128.0)
                    return steps.minBy { abs(it - speed) }
                }

                // 计算统计数据并绑定到底部面板（隐藏显示）
                Log.d(TAG, "开始计算统计数据...")
                // Temporarily disabled - val stats = ReplayStatsCalculator.calculate(events)
                Log.d(TAG, "统计数据计算完成（功能暂时禁用）")
                // 隐藏底部统计面板
                // Temporarily disabled - binding.replayStatsSheet.visibility = View.GONE
                // Temporarily disabled - binding.replayStatsSheet.bind(stats)

                // 从回放事件中提取路线
                val routeEvents = events.filterIsInstance<ReplaySetNavigationRoute>()
                val routes = routeEvents.mapNotNull { it.route }
                Log.d(TAG, "从回放事件中提取到 ${routes.size} 条路线")

                // 清空并推送事件
                mapboxNavigation.mapboxReplayer.clearEvents()
                mapboxNavigation.mapboxReplayer.pushEvents(events)

                // 重置会话并开始回放 - 参照官方示例
                mapboxNavigation.resetTripSession {
                    // 关键：使用 startReplayTripSession 而不是 startTripSession
                    mapboxNavigation.startReplayTripSession()

                    // 不设置导航路线，只显示真实行驶轨迹
                    mapboxNavigation.setNavigationRoutes(emptyList())
                    Log.d(TAG, "清空导航路线，仅显示真实行驶轨迹")

                    // 重置首次定位标志，让相机在第一帧回放位置处初始化
                    isLocationInitialized = false

                    // 在开始播放前，将相机强制移动到回放起点，避免先飞到设备当前位置
                    val firstLoc = events.firstOrNull { it.javaClass.simpleName.contains("Location", true) || it.javaClass.simpleName.contains("Position", true) }
                    try {
                        val locField = firstLoc?.javaClass?.declaredFields?.firstOrNull { it.name == "location" }
                        locField?.let {
                            it.isAccessible = true
                            val loc = it.get(firstLoc)
                            val lat = (loc?.javaClass?.declaredFields?.firstOrNull { f -> f.name == "latitude" }?.apply { isAccessible = true }?.get(loc) as? Number)?.toDouble()
                            val lon = (loc?.javaClass?.declaredFields?.firstOrNull { f -> f.name == "longitude" }?.apply { isAccessible = true }?.get(loc) as? Number)?.toDouble()
                            if (lat != null && lon != null) {
                                binding.mapView.getMapboxMap().setCamera(
                                    CameraOptions.Builder()
                                        .center(com.mapbox.geojson.Point.fromLngLat(lon, lat))
                                        .zoom(15.0)
                                        .build()
                                )
                                Log.d(TAG, "相机定位到回放起点: lat=$lat, lon=$lon")
                            }
                        }
                    } catch (_: Throwable) {}

                    // 根据轨迹统计动态计算推荐回放倍速
                    // Temporarily use default speed since stats calculation is disabled
                    val recommendedSpeed = 16.0 // recommendReplaySpeed(stats.totalDistance, stats.averageSpeed)
                    mapboxNavigation.mapboxReplayer.playbackSpeed(recommendedSpeed)
                    Log.d(TAG, "设置回放倍速为 ${recommendedSpeed}x")

                    // 先播第一帧，再开始播放
                    mapboxNavigation.mapboxReplayer.playFirstLocation()
                    mapboxNavigation.mapboxReplayer.play()
                    Log.d(TAG, "回放已开始，事件数: ${events.size}")

                    // 高速回放容错：若 1.5s 内没有位置更新，自动降速到 16x
                    lifecycleScope.launch {
                        delay(1500)
                        if (!isLocationInitialized) {
                            mapboxNavigation.mapboxReplayer.playbackSpeed(16.0)
                            Log.w(TAG, "高速回放无位置更新，自动降速至 16x")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "回放处理失败: ${e.message}", e)
            }
        }
    }





    /**
     * 切换到全览模式
     */
    private fun switchToOverviewMode() {
        try {
            if (traveledPoints.isEmpty()) {
                Log.w(TAG, "轨迹数据为空，无法切换到全览模式")
                return
            }

            // 计算轨迹边界
            var minLat = Double.MAX_VALUE
            var maxLat = Double.MIN_VALUE
            var minLon = Double.MAX_VALUE
            var maxLon = Double.MIN_VALUE

            for (point in traveledPoints) {
                minLat = kotlin.math.min(minLat, point.latitude())
                maxLat = kotlin.math.max(maxLat, point.latitude())
                minLon = kotlin.math.min(minLon, point.longitude())
                maxLon = kotlin.math.max(maxLon, point.longitude())
            }

            Log.d(TAG, "轨迹原始边界: lat[$minLat, $maxLat], lon[$minLon, $maxLon]")
            Log.d(TAG, "轨迹范围: lat=${maxLat - minLat}, lon=${maxLon - minLon}")

            // 增加边距到30%，确保轨迹完全可见
            val latPadding = (maxLat - minLat) * 0.3
            val lonPadding = (maxLon - minLon) * 0.3

            val bounds = com.mapbox.maps.CoordinateBounds(
                com.mapbox.geojson.Point.fromLngLat(minLon - lonPadding, minLat - latPadding),
                com.mapbox.geojson.Point.fromLngLat(maxLon + lonPadding, maxLat + latPadding)
            )

            // 计算中心点
            val center = com.mapbox.geojson.Point.fromLngLat(
                (bounds.southwest.longitude() + bounds.northeast.longitude()) / 2,
                (bounds.southwest.latitude() + bounds.northeast.latitude()) / 2
            )

            Log.d(TAG, "计算后的边界: SW(${bounds.southwest.longitude()}, ${bounds.southwest.latitude()}), NE(${bounds.northeast.longitude()}, ${bounds.northeast.latitude()})")
            Log.d(TAG, "中心点: (${center.longitude()}, ${center.latitude()})")

            // 计算合适的缩放级别
            val latDiff = bounds.northeast.latitude() - bounds.southwest.latitude()
            val lonDiff = bounds.northeast.longitude() - bounds.southwest.longitude()
            val zoom = calculateOverviewZoom(latDiff, lonDiff)

            Log.d(TAG, "边界差值: latDiff=$latDiff, lonDiff=$lonDiff, 计算缩放级别: $zoom")

            // 设置相机到全览位置
            binding.mapView.camera.easeTo(
                CameraOptions.Builder()
                    .center(center)
                    .zoom(zoom)
                    .build(),
                com.mapbox.maps.plugin.animation.MapAnimationOptions.Builder()
                    .duration(1000)
                    .build()
            )

            isOverviewMode = true
            updateOverviewButtonState()
            Log.d(TAG, "已切换到轨迹全览模式，轨迹点数: ${traveledPoints.size}, 最终缩放级别: $zoom")
        } catch (e: Exception) {
            Log.e(TAG, "显示轨迹全览失败: ${e.message}", e)
        }
    }

    /**
     * 计算全览模式的缩放级别
     */
    private fun calculateOverviewZoom(latDiff: Double, lonDiff: Double): Double {
        val screenWidth = resources.displayMetrics.widthPixels.toDouble()
        val screenHeight = resources.displayMetrics.heightPixels.toDouble()
        
        Log.d(TAG, "屏幕尺寸: ${screenWidth}x${screenHeight}")
        
        // 使用简化的缩放级别计算
        // 基于经验值：不同范围对应不同的合适缩放级别
        val maxDiff = kotlin.math.max(latDiff, lonDiff)
        
        val zoom = when {
            maxDiff > 0.1 -> 10.0   // 很大范围（提高2级）
            maxDiff > 0.05 -> 12.0  // 大范围（提高2级）
            maxDiff > 0.02 -> 14.0  // 中等范围（提高2级）
            maxDiff > 0.01 -> 15.0  // 小范围（提高1级）
            maxDiff > 0.005 -> 16.0 // 很小范围（提高1级）
            else -> 17.0            // 极小范围（提高1级）
        }
        
        Log.d(TAG, "缩放计算: latDiff=$latDiff, lonDiff=$lonDiff, maxDiff=$maxDiff, 选择缩放级别: $zoom")
        
        return zoom
    }

    /**
     * 切换到跟随模式
     */
    private fun switchToFollowingMode() {
        try {
            // 获取当前位置
            val currentLocation = navigationLocationProvider.lastLocation
            if (currentLocation != null) {
                // 直接设置相机到当前位置，使用跟随模式的缩放级别
                val currentPoint = com.mapbox.geojson.Point.fromLngLat(
                    currentLocation.longitude, 
                    currentLocation.latitude
                )
                
                binding.mapView.camera.easeTo(
                    CameraOptions.Builder()
                        .center(currentPoint)
                        .zoom(16.0) // 跟随模式使用较高的缩放级别
                        .build(),
                    com.mapbox.maps.plugin.animation.MapAnimationOptions.Builder()
                        .duration(1000)
                        .build()
                )
                Log.d(TAG, "已切换到跟随模式，定位到当前位置")
            } else {
                Log.w(TAG, "当前位置为空，无法切换到跟随模式")
            }
            
            isOverviewMode = false
            updateOverviewButtonState()
        } catch (e: Exception) {
            Log.e(TAG, "切换到跟随模式失败: ${e.message}", e)
        }
    }

    /**
     * 更新全览按钮的状态显示
     */
    private fun updateOverviewButtonState() {
        try {
            // 根据当前模式更新按钮的视觉状态
            if (isOverviewMode) {
                // 全览模式：按钮应该显示为"激活"状态
                binding.routeOverview.alpha = 1.0f
                Log.d(TAG, "全览按钮状态：激活（全览模式）")
            } else {
                // 跟随模式：按钮应该显示为"非激活"状态
                binding.routeOverview.alpha = 0.7f
                Log.d(TAG, "全览按钮状态：非激活（跟随模式）")
            }
        } catch (e: Exception) {
            Log.e(TAG, "更新按钮状态失败: ${e.message}", e)
        }
    }

    /**
     * 设置标题栏
     */
    private fun setupTitleBar() {
        try {
            // 从Intent获取标题参数
            val customTitle = intent.getStringExtra("title")
            if (!customTitle.isNullOrEmpty()) {
                binding.titleText.text = customTitle
                Log.d(TAG, "设置自定义标题: $customTitle")
            } else {
                // 使用默认标题
                binding.titleText.setText(R.string.navigation_replay_title)
                Log.d(TAG, "使用默认标题")
            }

            // 设置返回按钮点击事件
            binding.backButton.setOnClickListener {
                Log.d(TAG, "返回按钮被点击")
                onBackPressedDispatcher.onBackPressed()
            }

            // 调整标题栏位置以适配状态栏
            adjustTitleBarForStatusBar()

        } catch (e: Exception) {
            Log.e(TAG, "设置标题栏失败: ${e.message}", e)
        }
    }

    /**
     * 调整标题栏位置以适配状态栏
     */
    private fun adjustTitleBarForStatusBar() {
        val statusBarHeight = getStatusBarHeight()
        Log.d(TAG, "调整标题栏位置，状态栏高度: ${statusBarHeight}px")

        // 设置标题栏的上边距为状态栏高度
        val layoutParams = binding.titleBar.layoutParams as androidx.constraintlayout.widget.ConstraintLayout.LayoutParams
        layoutParams.topMargin = statusBarHeight.toInt()
        binding.titleBar.layoutParams = layoutParams
    }



    /**
     * 调整地图组件位置以避免标题栏和状态栏遮挡
     */
    private fun adjustMapComponentsForStatusBar() {
        // 获取状态栏高度和标题栏高度
        val statusBarHeight = getStatusBarHeight()
        val titleBarHeight = binding.titleBar.height.toFloat()
        val totalTopMargin = statusBarHeight + titleBarHeight + 16f // 状态栏 + 标题栏 + 16dp 间距
        
        Log.d(TAG, "状态栏高度: ${statusBarHeight}px, 标题栏高度: ${titleBarHeight}px")

        // 隐藏比例尺
        binding.mapView.scalebar.updateSettings {
            enabled = false
        }

        // 调整罗盘位置 - 在标题栏下方
        binding.mapView.compass.updateSettings {
            marginTop = totalTopMargin
            marginRight = 16f
        }

        Log.d(TAG, "已调整地图组件位置，避免标题栏遮挡")
    }

    /**
     * 获取状态栏高度
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
     * 判断是否需要更新相机位置
     * 只在 puck 接近屏幕边缘或距离上次更新时间较长时才更新
     */
    private fun shouldUpdateCamera(currentPoint: com.mapbox.geojson.Point): Boolean {
        val now = System.currentTimeMillis()

        // 如果距离上次更新时间超过5秒，强制更新一次
        if (now - lastCameraUpdateTime > 5000) {
            return true
        }

        // 获取当前相机中心点
        val currentCamera = binding.mapView.getMapboxMap().cameraState
        val cameraCenter = currentCamera.center

        // 获取屏幕尺寸
        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels

        // 将地理坐标转换为屏幕坐标
        val currentScreenPoint = binding.mapView.getMapboxMap().pixelForCoordinate(currentPoint)

        // 定义边缘阈值（距离屏幕边缘的像素距离）
        val edgeThreshold = 100 // 100像素

        // 检查是否接近屏幕边缘
        val nearLeftEdge = currentScreenPoint.x < edgeThreshold
        val nearRightEdge = currentScreenPoint.x > screenWidth - edgeThreshold
        val nearTopEdge = currentScreenPoint.y < edgeThreshold
        val nearBottomEdge = currentScreenPoint.y > screenHeight - edgeThreshold

        val isNearEdge = nearLeftEdge || nearRightEdge || nearTopEdge || nearBottomEdge

        if (isNearEdge) {
            Log.d(TAG, "Puck接近边缘: 屏幕坐标(${currentScreenPoint.x.toInt()}, ${currentScreenPoint.y.toInt()}), 屏幕尺寸(${screenWidth}x${screenHeight})")
        }

        return isNearEdge
    }

    /**
     * 预解析所有回放事件中的位置数据，一次性绘制完整路线
     */
    private fun preDrawCompleteRoute(events: List<ReplayEventBase>) {
        try {
            Log.d(TAG, "开始预解析回放事件中的位置数据...")

            val allPoints = mutableListOf<Point>()
            val allSpeeds = mutableListOf<Double>()
            val allDistances = mutableListOf<Double>()
            var totalDistance = 0.0

            // 遍历所有事件，提取位置信息
            for (event in events) {
                try {
                    // 直接检查事件类型，寻找包含位置信息的事件
                    val eventClass = event.javaClass
                    Log.d(TAG, "处理事件类型: ${eventClass.simpleName}")

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
                                    if (allPoints.isNotEmpty()) {
                                        val lastPoint = allPoints.last()
                                        val distance = TurfMeasurement.distance(lastPoint, point, TurfConstants.UNIT_METERS)

                                        // 过滤过近的点
                                        if (distance > 0.5) {
                                            totalDistance += distance
                                            allPoints.add(point)
                                            allSpeeds.add(speedKmh)
                                            allDistances.add(totalDistance)

                                            if (allPoints.size <= 5) {
                                                Log.d(TAG, "添加轨迹点${allPoints.size}: lat=$lat, lng=$lng, 速度=${speedKmh.toInt()}km/h")
                                            }
                                        }
                                    } else {
                                        // 第一个点
                                        allPoints.add(point)
                                        allSpeeds.add(speedKmh)
                                        allDistances.add(0.0)
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

            Log.d(TAG, "预解析完成: 总点数=${allPoints.size}, 总距离=${totalDistance.toInt()}m")

            if (allPoints.size >= 2) {
                // 保存到全局变量
                traveledPoints.clear()
                traveledPoints.addAll(allPoints)
                traveledSpeedsKmh.clear()
                traveledSpeedsKmh.addAll(allSpeeds)
                traveledCumDistMeters.clear()
                traveledCumDistMeters.addAll(allDistances)

                // 一次性绘制完整路线
                drawCompleteRoute()
            }

        } catch (e: Exception) {
            Log.e(TAG, "预解析路线失败: ${e.message}", e)
        }
    }

    /**
     * 一次性绘制完整路线
     */
    private fun drawCompleteRoute() {
        binding.mapView.getMapboxMap().getStyle { style ->
            try {
                // 绘制完整轨迹线
                val line = LineString.fromLngLats(traveledPoints)
                style.getSourceAs<GeoJsonSource>("replay-travel-line-source")?.feature(Feature.fromGeometry(line))

                // 设置起点和终点
                if (traveledPoints.isNotEmpty()) {
                    val startPoint = traveledPoints.first()
                    val endPoint = traveledPoints.last()

                    style.getSourceAs<GeoJsonSource>("replay-start-source")?.feature(Feature.fromGeometry(startPoint))
                    style.getSourceAs<GeoJsonSource>("replay-end-source")?.feature(Feature.fromGeometry(endPoint))

                    endPointCoord = endPoint
                }

                // 应用速度渐变
                val gradientExpr = buildSpeedGradientExpression()
                val layer = style.getLayerAs<LineLayer>("replay-travel-line-layer")
                layer?.lineGradient(gradientExpr)

                val avgSpeed = if (traveledSpeedsKmh.isNotEmpty()) traveledSpeedsKmh.average() else 0.0
                Log.d(TAG, "✅ 完整路线绘制完成: 轨迹点${traveledPoints.size}, 平均速度${String.format("%.1f", avgSpeed)}km/h")

            } catch (e: Exception) {
                Log.e(TAG, "绘制完整路线失败: ${e.message}", e)
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

    // 骑行速度分段配色（km/h）- 调整为更适合骑行的速度阈值
    private fun colorForSpeedExpr(speedKmh: Double): Expression {
        val hex = when {
            speedKmh < 5.0  -> "#2E7DFF" // 蓝色 - 慢速/停车
            speedKmh < 10.0 -> "#00E5FF" // 青色 - 休闲骑行
            speedKmh < 15.0 -> "#00E676" // 绿色 - 正常骑行
            speedKmh < 20.0 -> "#C6FF00" // 黄绿色 - 快速骑行
            speedKmh < 25.0 -> "#FFD600" // 黄色 - 高速骑行
            speedKmh < 30.0 -> "#FF9100" // 橙色 - 冲刺速度
            else            -> "#FF1744" // 红色 - 极速/下坡
        }
        return toColor { literal(hex) }
    }

    override fun onDestroy() {
        super.onDestroy()
        
        // 注销地图视图
        MapStyleManager.unregisterMapView(binding.mapView)
        
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}