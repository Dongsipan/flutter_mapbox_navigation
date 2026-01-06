package com.eopeter.fluttermapboxnavigation.activity

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.Log
import android.view.Menu
import android.view.MenuItem
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.SearchView
import androidx.appcompat.widget.Toolbar
import androidx.core.content.res.ResourcesCompat
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import com.eopeter.fluttermapboxnavigation.R
import com.eopeter.fluttermapboxnavigation.models.WayPointData
import com.eopeter.fluttermapboxnavigation.utilities.LocationHelper
import com.eopeter.fluttermapboxnavigation.utilities.PluginUtilities
import com.mapbox.common.MapboxOptions
import com.mapbox.geojson.Point
import com.mapbox.maps.CameraOptions
import com.mapbox.maps.MapView
import com.mapbox.maps.plugin.annotation.annotations
import com.mapbox.maps.plugin.annotation.generated.PointAnnotationManager
import com.mapbox.maps.plugin.annotation.generated.PointAnnotationOptions
import com.mapbox.maps.plugin.annotation.generated.createPointAnnotationManager
import com.mapbox.maps.plugin.locationcomponent.location
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
    private lateinit var toolbar: Toolbar
    private lateinit var searchView: SearchView
    private lateinit var searchResultsView: SearchResultsView
    private lateinit var searchPlaceView: SearchPlaceBottomSheetView

    // Mapbox组件
    private lateinit var searchEngineUiAdapter: SearchEngineUiAdapter
    private lateinit var pointAnnotationManager: PointAnnotationManager

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

        // 检查位置权限
        checkLocationPermission()
    }

    /**
     * 初始化视图组件
     */
    private fun initializeViews() {
        mapView = findViewById(R.id.mapView)
        searchResultsView = findViewById(R.id.search_results_view)
        searchPlaceView = findViewById(R.id.search_place_view)
        
        // 初始化底部抽屉 - 完全按照示例
        searchPlaceView.apply {
            initialize(CommonSearchViewConfiguration(DistanceUnitType.IMPERIAL))
            addOnCloseClickListener {
                hide()
            }
        }
        
        // 初始化 Toolbar - 完全按照示例
        toolbar = findViewById<Toolbar>(R.id.toolbar).apply {
            title = getString(R.string.simple_ui_toolbar_title)
            setSupportActionBar(this)
            
            // 设置导航图标和颜色 - 完全按照示例
            ResourcesCompat.getDrawable(
                resources,
                com.mapbox.search.ui.R.drawable.mapbox_search_sdk_close_drawable,
                theme
            )?.let { drawable ->
                drawable.setTint(Color.parseColor("#4F6530"))
                setNavigationIcon(drawable)
                setNavigationOnClickListener { 
                    this@SearchActivity.finish() 
                }
            }
        }
        
        // 初始化搜索结果视图 - 完全按照示例
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
     * 设置地图视图
     */
    private fun setupMapView() {
        // 创建点标注管理器
        pointAnnotationManager = mapView.annotations.createPointAnnotationManager()

        // 启用用户位置显示
        mapView.location.updateSettings {
            enabled = true
            pulsingEnabled = true
        }

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
                // Nothing to do
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
            }

            override fun onOfflineSearchResultSelected(
                searchResult: OfflineSearchResult,
                responseInfo: OfflineResponseInfo
            ) {
                closeSearchView()
                searchPlaceView.open(SearchPlace.createFromOfflineSearchResult(searchResult))
            }

            override fun onError(e: Exception) {
                Toast.makeText(applicationContext, "Error happened: $e", Toast.LENGTH_SHORT).show()
            }

            override fun onHistoryItemClick(historyRecord: HistoryRecord) {
                closeSearchView()
                searchPlaceView.open(
                    SearchPlace.createFromIndexableRecord(historyRecord, distanceMeters = null)
                )
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
     * 关闭搜索视图 - 完全按照示例
     */
    private fun closeSearchView() {
        toolbar.collapseActionView()
        searchView.setQuery("", false)
    }

    /**
     * 移动到当前位置
     */
    private fun moveToCurrentLocation() {
        lifecycleScope.launch {
            val location = locationHelper.getCurrentLocation()
            if (location != null) {
                currentLocation = location
                mapView.mapboxMap.setCamera(
                    CameraOptions.Builder()
                        .center(location)
                        .zoom(15.0)
                        .build()
                )
                Log.d(TAG, "移动到当前位置: $location")
            } else {
                Toast.makeText(
                    this@SearchActivity,
                    R.string.location_service_disabled,
                    Toast.LENGTH_SHORT
                ).show()
            }
        }
    }

    /**
     * 检查位置权限
     */
    private fun checkLocationPermission() {
        if (!locationHelper.hasLocationPermission()) {
            locationHelper.requestLocationPermission(this)
        } else {
            moveToCurrentLocation()
        }
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
            if (locationHelper.hasLocationPermission()) {
                moveToCurrentLocation()
            } else {
                Toast.makeText(
                    this,
                    R.string.location_permission_required,
                    Toast.LENGTH_LONG
                ).show()
            }
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
     * 返回结果给Flutter
     */
    private fun returnResult(wayPoints: List<Map<String, Any>>) {
        val resultIntent = Intent().apply {
            putExtra(EXTRA_RESULT_WAYPOINTS, ArrayList(wayPoints))
        }
        setResult(Activity.RESULT_OK, resultIntent)
        finish()
    }
}
