package com.eopeter.fluttermapboxnavigation.activity

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.Menu
import android.view.MenuItem
import android.widget.FrameLayout
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.SearchView
import androidx.core.view.ViewCompat
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import com.eopeter.fluttermapboxnavigation.R
import com.eopeter.fluttermapboxnavigation.models.WayPointData
import com.eopeter.fluttermapboxnavigation.utilities.LocationHelper
import com.eopeter.fluttermapboxnavigation.utilities.PluginUtilities
import com.eopeter.fluttermapboxnavigation.utilities.StylePreferenceManager
import com.mapbox.common.MapboxOptions
import com.mapbox.geojson.Point
import com.mapbox.maps.CameraOptions
import com.mapbox.maps.MapView
import com.mapbox.maps.plugin.annotation.annotations
import com.mapbox.maps.EdgeInsets
import com.mapbox.maps.plugin.annotation.generated.CircleAnnotationOptions
import com.mapbox.maps.plugin.annotation.generated.createCircleAnnotationManager
import com.mapbox.maps.plugin.locationcomponent.OnIndicatorPositionChangedListener
import com.mapbox.maps.plugin.locationcomponent.location
import com.mapbox.android.gestures.Utils.dpToPx
import com.mapbox.search.ApiType
import com.mapbox.search.ResponseInfo
import com.mapbox.search.SearchEngine
import com.mapbox.search.SearchEngineSettings
import com.mapbox.search.offline.OfflineResponseInfo
import com.mapbox.search.offline.OfflineSearchEngine
import com.mapbox.search.offline.OfflineSearchEngineSettings
import com.mapbox.search.offline.OfflineSearchResult
import com.mapbox.search.record.HistoryRecord
import com.mapbox.search.result.SearchResult
import com.mapbox.search.result.SearchSuggestion
import com.mapbox.search.ui.adapter.engines.SearchEngineUiAdapter
import com.mapbox.search.ui.view.CommonSearchViewConfiguration
import com.mapbox.search.ui.view.DistanceUnitType
import com.mapbox.search.ui.view.SearchResultsView
import com.mapbox.search.ui.view.place.SearchPlace
import com.mapbox.search.ui.view.place.SearchPlaceBottomSheetView
import kotlinx.coroutines.launch

/**
 * 地图搜索 Activity
 * 
 * 参照 Mapbox Search SDK 官方示例实现
 * 提供带有搜索功能的地图界面，允许用户搜索地点并生成导航路径点
 * 
 * 功能：
 * - 地图显示和交互
 * - 地点搜索和自动补全
 * - 搜索结果显示
 * - 地图标记
 * - 底部抽屉显示地点详情
 * - 生成起点和终点的wayPoints数组
 */
class SearchActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_RESULT_WAYPOINTS = "result_waypoints"
        const val REQUEST_CODE = 9002
        private const val TAG = "SearchActivity"
    }

    // UI组件
    private lateinit var mapView: MapView
    private lateinit var searchView: SearchView
    private lateinit var searchResultsView: SearchResultsView
    private lateinit var searchPlaceView: SearchPlaceBottomSheetView

    // Mapbox组件
    private lateinit var searchEngineUiAdapter: SearchEngineUiAdapter
    private lateinit var mapMarkersManager: MapMarkersManager

    // 辅助类
    private lateinit var locationHelper: LocationHelper

    // 状态
    private var currentLocation: Point? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 初始化 Mapbox access token
        val accessToken = PluginUtilities.getResourceFromContext(
            this.applicationContext,
            "mapbox_access_token"
        )
        MapboxOptions.accessToken = accessToken
        
        setContentView(R.layout.activity_search)

        // 初始化辅助类
        locationHelper = LocationHelper(this)

        // 初始化UI组件
        initializeViews()

        // 初始化地图
        setupMapView()

        // 初始化搜索引擎和UI适配器
        setupSearchEngine()
        
        // 设置导航监听器
        setupNavigationListener()
    }

    /**
     * 初始化视图组件
     */
    private fun initializeViews() {
        mapView = findViewById(R.id.mapView)
        searchResultsView = findViewById(R.id.search_results_view)
        searchPlaceView = findViewById(R.id.search_place_view)
        
        // 设置 ActionBar（使用深色背景而非主题色）
        supportActionBar?.apply {
            title = getString(R.string.simple_ui_toolbar_title)
            setDisplayHomeAsUpEnabled(true)
            elevation = 4f
            // 设置 ActionBar 背景为深色
            setBackgroundDrawable(
                android.graphics.drawable.ColorDrawable(
                    resources.getColor(R.color.colorBackground, null)
                )
            )
        }
        
        // 初始化底部抽屉 - 参照官方示例
        searchPlaceView.apply {
            initialize(CommonSearchViewConfiguration(DistanceUnitType.IMPERIAL))
            addOnCloseClickListener {
                mapMarkersManager.clearMarkers()
                hide()
                // 如果搜索框是展开状态，重新显示搜索结果列表
                if (::searchView.isInitialized && !searchView.isIconified) {
                    searchResultsView.isVisible = true
                }
            }
            addOnShareClickListener { searchPlace ->
                startActivity(shareIntent(searchPlace))
            }
        }
        
        // 初始化搜索结果视图
        searchResultsView.apply {
            initialize(
                SearchResultsView.Configuration(
                    CommonSearchViewConfiguration(DistanceUnitType.IMPERIAL)
                )
            )
            isVisible = false
        }
        
        // 确保 SearchPlaceBottomSheetView 初始状态是隐藏的
        searchPlaceView.hide()
    }

    /**
     * 设置地图视图 - 参照官方示例
     */
    private fun setupMapView() {
        // 创建标记管理器
        mapMarkersManager = MapMarkersManager(mapView)

        // Load user's preferred map style
        val styleUrl = StylePreferenceManager.getMapStyleUrl(this)
        Log.d(TAG, "Loading saved user preference style: $styleUrl")
        
        mapView.mapboxMap.loadStyle(styleUrl) { style ->
            // Apply Light Preset if the style supports it
            StylePreferenceManager.applyLightPresetToStyle(this, style)
            
            Log.d(TAG, "Map style loaded successfully: $styleUrl")
        }

        // 启用用户位置显示并自动定位 - 参照官方示例
        mapView.location.updateSettings {
            enabled = true
            pulsingEnabled = true
        }
        
        // 添加位置监听器，在获取到第一个位置后自动移动相机
        mapView.location.addOnIndicatorPositionChangedListener(object : OnIndicatorPositionChangedListener {
            override fun onIndicatorPositionChanged(point: Point) {
                currentLocation = point
                mapView.mapboxMap.setCamera(
                    CameraOptions.Builder()
                        .center(point)
                        .zoom(14.0)
                        .build()
                )
                // 只在第一次获取位置时移动相机，然后移除监听器
                mapView.location.removeOnIndicatorPositionChangedListener(this)
                Log.d(TAG, "自动定位到当前位置: $point")
            }
        })

        Log.d(TAG, "地图视图初始化完成")
    }

    /**
     * 设置搜索引擎和UI适配器 - 完全按照示例
     */
    private fun setupSearchEngine() {
        val searchEngine = SearchEngine.createSearchEngineWithBuiltInDataProviders(
            apiType = ApiType.SEARCH_BOX,
            settings = SearchEngineSettings()
        )

        val offlineSearchEngine = OfflineSearchEngine.create(
            OfflineSearchEngineSettings()
        )

        searchEngineUiAdapter = SearchEngineUiAdapter(
            view = searchResultsView,
            searchEngine = searchEngine,
            offlineSearchEngine = offlineSearchEngine
        )

        searchEngineUiAdapter.addSearchListener(object : SearchEngineUiAdapter.SearchListener {
            override fun onSuggestionsShown(
                suggestions: List<SearchSuggestion>,
                responseInfo: ResponseInfo
            ) {
                // Nothing to do
            }

            override fun onSearchResultsShown(
                suggestion: SearchSuggestion,
                results: List<SearchResult>,
                responseInfo: ResponseInfo
            ) {
                closeSearchView()
                mapMarkersManager.showMarkers(results.map { it.coordinate })
            }

            override fun onOfflineSearchResultsShown(
                results: List<OfflineSearchResult>,
                responseInfo: OfflineResponseInfo
            ) {
                // Nothing to do
            }

            override fun onSuggestionSelected(searchSuggestion: SearchSuggestion): Boolean {
                return false
            }

            override fun onSearchResultSelected(
                searchResult: SearchResult,
                responseInfo: ResponseInfo
            ) {
                closeSearchView()
                searchPlaceView.open(SearchPlace.createFromSearchResult(searchResult, responseInfo))
                mapMarkersManager.showMarker(searchResult.coordinate)
            }

            override fun onOfflineSearchResultSelected(
                searchResult: OfflineSearchResult,
                responseInfo: OfflineResponseInfo
            ) {
                closeSearchView()
                searchPlaceView.open(SearchPlace.createFromOfflineSearchResult(searchResult))
                mapMarkersManager.showMarker(searchResult.coordinate)
            }

            override fun onError(e: Exception) {
                Toast.makeText(applicationContext, "Error happened: $e", Toast.LENGTH_SHORT).show()
            }

            override fun onHistoryItemClick(historyRecord: HistoryRecord) {
                closeSearchView()
                searchPlaceView.open(
                    SearchPlace.createFromIndexableRecord(historyRecord, distanceMeters = null)
                )
                mapMarkersManager.showMarker(historyRecord.coordinate)
            }

            override fun onPopulateQueryClick(
                suggestion: SearchSuggestion,
                responseInfo: ResponseInfo
            ) {
                if (::searchView.isInitialized) {
                    searchView.setQuery(suggestion.name, true)
                }
            }

            override fun onFeedbackItemClick(responseInfo: ResponseInfo) {
                // Not implemented
            }
        })
    }

    /**
     * 创建选项菜单 - 完全按照示例
     */
    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.simple_ui_activity_options_menu, menu)
        
        val searchActionView = menu.findItem(R.id.action_search)
        searchActionView.setOnActionExpandListener(object : MenuItem.OnActionExpandListener {
            override fun onMenuItemActionExpand(item: MenuItem): Boolean {
                searchResultsView.isVisible = true
                searchPlaceView.hide()
                return true
            }

            override fun onMenuItemActionCollapse(item: MenuItem): Boolean {
                searchResultsView.isVisible = false
                return true
            }
        })

        searchView = searchActionView.actionView as SearchView
        searchView.queryHint = getString(R.string.query_hint)
        searchView.setOnQueryTextListener(object : SearchView.OnQueryTextListener {
            override fun onQueryTextSubmit(query: String): Boolean {
                return false
            }

            override fun onQueryTextChange(newText: String): Boolean {
                searchEngineUiAdapter.search(newText)
                return false
            }
        })

        return true
    }

    /**
     * 关闭搜索视图
     */
    private fun closeSearchView() {
        searchView.setQuery("", false)
        searchView.clearFocus()
        searchResultsView.isVisible = false
    }

    /**
     * 处理权限请求结果
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == LocationHelper.LOCATION_PERMISSION_REQUEST_CODE) {
            if (!locationHelper.hasLocationPermission()) {
                Toast.makeText(
                    this,
                    R.string.location_permission_required,
                    Toast.LENGTH_LONG
                ).show()
            }
            // 位置监听器会自动处理定位
        }
    }



    /**
     * 处理导航按钮点击 - 添加导航监听器
     */
    private fun setupNavigationListener() {
        searchPlaceView.addOnNavigateClickListener { searchPlace ->
            lifecycleScope.launch {
                try {
                    val wayPoints = generateWayPoints(searchPlace)
                    returnResult(wayPoints)
                } catch (e: Exception) {
                    Log.e(TAG, "生成wayPoints失败", e)
                    Toast.makeText(
                        this@SearchActivity,
                        "生成路径失败: ${e.message}",
                        Toast.LENGTH_SHORT
                    ).show()
                }
            }
        }
    }

    /**
     * 生成wayPoints数组
     */
    private suspend fun generateWayPoints(searchPlace: SearchPlace): List<Map<String, Any>> {
        val currentLoc = locationHelper.getCurrentLocation()
            ?: throw Exception("无法获取当前位置")
        
        val currentLocationName = locationHelper.reverseGeocode(currentLoc)
        
        val startPoint = WayPointData(
            name = currentLocationName,
            latitude = currentLoc.latitude(),
            longitude = currentLoc.longitude(),
            isSilent = false,
            address = ""
        )
        
        val endPoint = WayPointData(
            name = searchPlace.name,
            latitude = searchPlace.coordinate.latitude(),
            longitude = searchPlace.coordinate.longitude(),
            isSilent = false,
            address = searchPlace.address?.formattedAddress() ?: ""
        )
        
        return listOf(startPoint.toMap(), endPoint.toMap())
    }

    /**
     * 创建分享 Intent
     */
    private fun shareIntent(searchPlace: SearchPlace): Intent {
        val shareText = buildString {
            append(searchPlace.name)
            searchPlace.address?.formattedAddress()?.let { address ->
                append("\n")
                append(address)
            }
            append("\n")
            append("https://www.google.com/maps/search/?api=1&query=${searchPlace.coordinate.latitude()},${searchPlace.coordinate.longitude()}")
        }
        
        return Intent().apply {
            action = Intent.ACTION_SEND
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, shareText)
        }
    }

    /**
     * 返回结果给Flutter
     */
    private fun returnResult(wayPoints: List<Map<String, Any>>) {
        val resultIntent = Intent().apply {
            putExtra(EXTRA_RESULT_WAYPOINTS, ArrayList(wayPoints))
        }
        setResult(Activity.RESULT_OK, resultIntent)
        finish()
    }
    
    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            android.R.id.home -> {
                finish()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }
}

/**
 * 地图标记管理器 - 参照官方示例
 * 管理搜索结果在地图上的标记显示
 */
private class MapMarkersManager(mapView: MapView) {
    private val mapboxMap = mapView.mapboxMap
    private val circleAnnotationManager = mapView.annotations.createCircleAnnotationManager(null)
    private val markers = mutableMapOf<String, Point>()

    val hasMarkers: Boolean
        get() = markers.isNotEmpty()

    fun clearMarkers() {
        markers.clear()
        circleAnnotationManager.deleteAll()
    }

    fun showMarker(coordinate: Point) {
        showMarkers(listOf(coordinate))
    }

    fun showMarkers(coordinates: List<Point>) {
        clearMarkers()
        if (coordinates.isEmpty()) {
            return
        }

        coordinates.forEach { coordinate ->
            val circleAnnotationOptions = CircleAnnotationOptions()
                .withPoint(coordinate)
                .withCircleRadius(8.0)
                .withCircleColor("#ee4e8b")
                .withCircleStrokeWidth(2.0)
                .withCircleStrokeColor("#ffffff")

            val annotation = circleAnnotationManager.create(circleAnnotationOptions)
            markers[annotation.id] = coordinate
        }

        val onOptionsReadyCallback: (CameraOptions) -> Unit = {
            mapboxMap.setCamera(it)
        }

        if (coordinates.size == 1) {
            val options = CameraOptions.Builder()
                .center(coordinates.first())
                .padding(MARKERS_INSETS_OPEN_CARD)
                .zoom(14.0)
                .build()
            onOptionsReadyCallback(options)
        } else {
            mapboxMap.cameraForCoordinates(
                coordinates,
                CameraOptions.Builder().build(),
                MARKERS_INSETS,
                null,
                null,
                onOptionsReadyCallback,
            )
        }
    }

    companion object {
        private val MARKERS_EDGE_OFFSET = dpToPx(64f).toDouble()
        private val PLACE_CARD_HEIGHT = dpToPx(300f).toDouble()
        private val MARKERS_INSETS = EdgeInsets(
            MARKERS_EDGE_OFFSET,
            MARKERS_EDGE_OFFSET,
            MARKERS_EDGE_OFFSET,
            MARKERS_EDGE_OFFSET
        )
        private val MARKERS_INSETS_OPEN_CARD = EdgeInsets(
            MARKERS_EDGE_OFFSET,
            MARKERS_EDGE_OFFSET,
            PLACE_CARD_HEIGHT,
            MARKERS_EDGE_OFFSET
        )
    }
}
