package com.eopeter.fluttermapboxnavigation.activity

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.util.Log
import android.widget.EditText
import android.widget.ImageButton
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.eopeter.fluttermapboxnavigation.R
import com.eopeter.fluttermapboxnavigation.models.WayPointData
import com.eopeter.fluttermapboxnavigation.utilities.LocationHelper
import com.mapbox.geojson.Point
import com.mapbox.maps.CameraOptions
import com.mapbox.maps.MapView
import com.mapbox.maps.plugin.annotation.AnnotationPlugin
import com.mapbox.maps.plugin.annotation.annotations
import com.mapbox.maps.plugin.annotation.generated.PointAnnotationManager
import com.mapbox.maps.plugin.annotation.generated.PointAnnotationOptions
import com.mapbox.maps.plugin.annotation.generated.createPointAnnotationManager
import com.mapbox.maps.plugin.gestures.addOnMapClickListener
import com.mapbox.maps.plugin.locationcomponent.location
import com.mapbox.search.ResponseInfo
import com.mapbox.search.SearchEngine
import com.mapbox.search.SearchEngineSettings
import com.mapbox.search.result.SearchResult
import com.mapbox.search.result.SearchSuggestion
import com.mapbox.search.ui.adapter.engines.SearchEngineUiAdapter
import com.mapbox.search.ui.view.CommonSearchViewConfiguration
import com.mapbox.search.ui.view.DistanceUnitType
import com.mapbox.search.ui.view.SearchResultsView
import com.mapbox.search.ui.view.place.SearchPlaceBottomSheetView
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 地图搜索 Activity
 * 
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
        private const val SEARCH_DEBOUNCE_MS = 300L
    }

    // UI组件
    private lateinit var mapView: MapView
    private lateinit var searchEditText: EditText
    private lateinit var cancelButton: ImageButton
    private lateinit var locationButton: ImageButton
    private lateinit var searchResultsView: SearchResultsView
    private lateinit var searchPlaceBottomSheetView: SearchPlaceBottomSheetView

    // Mapbox组件
    private lateinit var searchEngine: SearchEngine
    private lateinit var offlineSearchEngine: com.mapbox.search.offline.OfflineSearchEngine
    private lateinit var searchEngineUiAdapter: SearchEngineUiAdapter
    private lateinit var pointAnnotationManager: PointAnnotationManager

    // 辅助类
    private lateinit var locationHelper: LocationHelper

    // 状态
    private var selectedSearchResult: SearchResult? = null
    private var selectedResponseInfo: ResponseInfo? = null
    private var currentLocation: Point? = null
    private var searchJob: Job? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_search)

        // 初始化辅助类
        locationHelper = LocationHelper(this)

        // 初始化UI组件
        initializeViews()

        // 初始化地图
        setupMapView()

        // 初始化搜索引擎
        setupSearchEngine()

        // 初始化搜索结果视图
        setupSearchResultsView()

        // 初始化底部抽屉
        setupBottomSheet()

        // 设置UI监听器
        setupListeners()

        // 检查位置权限
        checkLocationPermission()
    }

    /**
     * 初始化视图组件
     */
    private fun initializeViews() {
        mapView = findViewById(R.id.mapView)
        searchEditText = findViewById(R.id.searchEditText)
        cancelButton = findViewById(R.id.cancelButton)
        locationButton = findViewById(R.id.locationButton)
        searchResultsView = findViewById(R.id.searchResultsView)
        searchPlaceBottomSheetView = findViewById(R.id.searchPlaceBottomSheetView)
    }

    /**
     * 设置地图视图
     * Task 4.2 的一部分
     */
    private fun setupMapView() {
        // 创建点标注管理器
        val annotationApi = mapView.annotations
        pointAnnotationManager = annotationApi.createPointAnnotationManager()

        // 启用用户位置显示
        mapView.location.updateSettings {
            enabled = true
            pulsingEnabled = true
        }

        Log.d(TAG, "地图视图初始化完成")
    }

    /**
     * 设置搜索引擎
     * Task 4.3 的一部分
     */
    private fun setupSearchEngine() {
        // 创建搜索引擎
        // 注意：SearchEngineSettings会自动从MapboxOptions获取token
        searchEngine = SearchEngine.createSearchEngineWithBuiltInDataProviders(
            apiType = com.mapbox.search.ApiType.SEARCH_BOX,
            settings = SearchEngineSettings()
        )

        Log.d(TAG, "搜索引擎初始化完成")
    }

    /**
     * 设置搜索结果视图
     * Task 5.1 的一部分
     */
    private fun setupSearchResultsView() {
        // 1. 初始化 SearchResultsView
        searchResultsView.initialize(
            com.mapbox.search.ui.view.SearchResultsView.Configuration(
                commonConfiguration = CommonSearchViewConfiguration(DistanceUnitType.METRIC)
            )
        )

        // 2. 创建 OfflineSearchEngine
        offlineSearchEngine = com.mapbox.search.offline.OfflineSearchEngine.create(
            com.mapbox.search.offline.OfflineSearchEngineSettings()
        )

        // 3. 创建SearchEngineUiAdapter（必须带offlineSearchEngine）
        searchEngineUiAdapter = SearchEngineUiAdapter(
            view = searchResultsView,
            searchEngine = searchEngine,
            offlineSearchEngine = offlineSearchEngine
        )

        // 4. 设置搜索监听器
        searchEngineUiAdapter.addSearchListener(object : SearchEngineUiAdapter.SearchListener {
            override fun onSuggestionSelected(searchSuggestion: SearchSuggestion): Boolean {
                // 当用户选择搜索建议时
                return false
            }

            override fun onSearchResultSelected(
                searchResult: SearchResult,
                responseInfo: ResponseInfo
            ) {
                // 当用户选择搜索结果时，传递responseInfo
                onSearchResultSelected(searchResult, responseInfo)
            }

            override fun onOfflineSearchResultSelected(
                searchResult: com.mapbox.search.offline.OfflineSearchResult,
                responseInfo: com.mapbox.search.offline.OfflineResponseInfo
            ) {
                // 离线搜索结果选择（暂不实现）
                Log.d(TAG, "离线搜索结果选择: ${searchResult.name}")
            }

            override fun onHistoryItemClick(historyRecord: com.mapbox.search.record.HistoryRecord) {
                // 历史记录点击
                Log.d(TAG, "历史记录点击: ${historyRecord.name}")
            }

            override fun onPopulateQueryClick(
                suggestion: SearchSuggestion,
                responseInfo: ResponseInfo
            ) {
                // 填充查询点击（用户点击搜索建议的箭头按钮）
                searchEditText.setText(suggestion.name)
                searchEditText.setSelection(suggestion.name.length)
                Log.d(TAG, "填充查询: ${suggestion.name}")
            }

            override fun onError(e: Exception) {
                // 搜索错误处理
                handleSearchError(e)
            }

            override fun onSuggestionsShown(
                suggestions: List<SearchSuggestion>,
                responseInfo: ResponseInfo
            ) {
                // 搜索建议显示时
                Log.d(TAG, "显示 ${suggestions.size} 个搜索建议")
            }

            override fun onSearchResultsShown(
                suggestion: SearchSuggestion,
                results: List<SearchResult>,
                responseInfo: ResponseInfo
            ) {
                // 搜索结果显示时
                Log.d(TAG, "显示 ${results.size} 个搜索结果")
            }

            override fun onOfflineSearchResultsShown(
                results: List<com.mapbox.search.offline.OfflineSearchResult>,
                responseInfo: com.mapbox.search.offline.OfflineResponseInfo
            ) {
                // 离线搜索结果显示（可选实现）
                Log.d(TAG, "显示 ${results.size} 个离线搜索结果")
            }

            override fun onFeedbackItemClick(responseInfo: ResponseInfo) {
                // 反馈项点击（可选实现）
                Log.d(TAG, "反馈项点击")
            }
        })

        Log.d(TAG, "搜索结果视图初始化完成")
    }

    /**
     * 设置底部抽屉
     * Task 7.1 的一部分
     */
    private fun setupBottomSheet() {
        // 配置底部抽屉
        searchPlaceBottomSheetView.initialize(
            CommonSearchViewConfiguration(DistanceUnitType.METRIC)
        )

        // 配置按钮可见性
        searchPlaceBottomSheetView.isNavigateButtonVisible = true
        searchPlaceBottomSheetView.isShareButtonVisible = false
        searchPlaceBottomSheetView.isFavoriteButtonVisible = false

        // 设置关闭监听器
        // Task 7.4 的一部分
        searchPlaceBottomSheetView.addOnCloseClickListener {
            Log.d(TAG, "底部抽屉关闭")
        }

        // 设置导航按钮监听器
        // Task 8.1 的一部分
        searchPlaceBottomSheetView.addOnNavigateClickListener { searchPlace ->
            Log.d(TAG, "点击导航按钮: ${searchPlace.name}")
            onNavigateButtonClicked(searchPlace)
        }

        Log.d(TAG, "底部抽屉初始化完成")
    }

    /**
     * 设置UI监听器
     */
    private fun setupListeners() {
        // 取消按钮
        cancelButton.setOnClickListener {
            setResult(Activity.RESULT_CANCELED)
            finish()
        }

        // 定位按钮
        locationButton.setOnClickListener {
            moveToCurrentLocation()
        }

        // 搜索输入监听（带防抖）
        searchEditText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}

            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                handleSearchInput(s?.toString() ?: "")
            }

            override fun afterTextChanged(s: Editable?) {}
        })

        // 地图点击监听 - 隐藏底部抽屉
        // Task 7.5 的一部分
        mapView.mapboxMap.addOnMapClickListener { point: Point ->
            if (searchPlaceBottomSheetView.isHidden().not()) {
                searchPlaceBottomSheetView.hide()
                Log.d(TAG, "点击地图，隐藏底部抽屉")
            }
            false  // 返回false允许其他监听器处理事件
        }
    }

    /**
     * 处理搜索输入（带防抖）
     * Task 5.2 的一部分
     */
    private fun handleSearchInput(query: String) {
        // 取消之前的搜索任务
        searchJob?.cancel()

        if (query.isEmpty()) {
            searchResultsView.visibility = android.view.View.GONE
            return
        }

        // 创建新的搜索任务（300ms防抖）
        searchJob = lifecycleScope.launch {
            delay(SEARCH_DEBOUNCE_MS)
            performSearch(query)
        }
    }

    /**
     * 执行搜索
     */
    private fun performSearch(query: String) {
        Log.d(TAG, "执行搜索: $query")
        
        // 使用SearchEngineUiAdapter执行搜索
        searchEngineUiAdapter.search(query)
        
        // 显示搜索结果视图
        searchResultsView.visibility = android.view.View.VISIBLE
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
     * Task 10.1 的一部分
     */
    private fun checkLocationPermission() {
        if (!locationHelper.hasLocationPermission()) {
            locationHelper.requestLocationPermission(this)
        } else {
            // 已有权限，移动到当前位置
            moveToCurrentLocation()
        }
    }

    /**
     * 处理权限请求结果
     * Task 10.2 的一部分
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == LocationHelper.LOCATION_PERMISSION_REQUEST_CODE) {
            if (locationHelper.hasLocationPermission()) {
                // 权限已授予
                moveToCurrentLocation()
            } else {
                // 权限被拒绝
                Toast.makeText(
                    this,
                    R.string.location_permission_required,
                    Toast.LENGTH_LONG
                ).show()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // 取消搜索任务
        searchJob?.cancel()
        Log.d(TAG, "Activity销毁")
    }

    /**
     * 处理搜索结果选择
     * Task 5.4 的一部分
     */
    private fun onSearchResultSelected(
        searchResult: SearchResult,
        responseInfo: ResponseInfo
    ) {
        Log.d(TAG, "选择搜索结果: ${searchResult.name}")
        
        // 保存选中的搜索结果和responseInfo
        selectedSearchResult = searchResult
        selectedResponseInfo = responseInfo
        
        // 隐藏搜索结果视图
        searchResultsView.visibility = android.view.View.GONE
        
        // 在地图上显示标记
        showAnnotation(searchResult)
        
        // 调整地图视角到选中位置
        adjustCameraToResult(searchResult)
        
        // 显示底部抽屉，传递responseInfo
        showBottomSheet(searchResult, responseInfo)
    }

    /**
     * 在地图上显示标记
     * Task 6.1 的一部分
     */
    private fun showAnnotation(searchResult: SearchResult) {
        // 清除之前的标记
        pointAnnotationManager.deleteAll()
        
        // 创建新标记
        val pointAnnotationOptions = PointAnnotationOptions()
            .withPoint(searchResult.coordinate)
            .withTextField(searchResult.name)
            .withTextSize(14.0)
        
        val annotation = pointAnnotationManager.create(pointAnnotationOptions)
        
        // 设置标记点击监听器
        // Task 6.3 的一部分
        pointAnnotationManager.addClickListener { clickedAnnotation ->
            if (clickedAnnotation.id == annotation.id) {
                // 点击标记时显示底部抽屉
                // 使用保存的searchResult和responseInfo
                if (selectedSearchResult != null && selectedResponseInfo != null) {
                    showBottomSheet(selectedSearchResult!!, selectedResponseInfo!!)
                }
                true
            } else {
                false
            }
        }
        
        Log.d(TAG, "在地图上显示标记: ${searchResult.name} at ${searchResult.coordinate}")
    }

    /**
     * 调整地图视角到搜索结果
     * Task 5.4 的一部分
     */
    private fun adjustCameraToResult(searchResult: SearchResult) {
        mapView.mapboxMap.setCamera(
            CameraOptions.Builder()
                .center(searchResult.coordinate)
                .zoom(15.0)
                .build()
        )
        
        Log.d(TAG, "调整地图视角到: ${searchResult.coordinate}")
    }

    /**
     * 显示底部抽屉
     * Task 7.2 的一部分
     */
    private fun showBottomSheet(
        searchResult: SearchResult,
        responseInfo: ResponseInfo
    ) {
        // 使用官方SearchPlaceBottomSheetView
        // 使用SDK回调提供的responseInfo，而不是手动构造
        try {
            val searchPlace = com.mapbox.search.ui.view.place.SearchPlace
                .createFromSearchResult(searchResult, responseInfo)
            
            searchPlaceBottomSheetView.open(searchPlace)
            
            Log.d(TAG, "显示底部抽屉: ${searchResult.name}")
        } catch (e: Exception) {
            Log.e(TAG, "显示底部抽屉失败", e)
            // 降级方案：显示Toast
            Toast.makeText(
                this@SearchActivity,
                "${searchResult.name}\n${searchResult.address?.formattedAddress() ?: ""}",
                Toast.LENGTH_LONG
            ).show()
        }
    }

    /**
     * 显示多个标记并调整视角
     * Task 6.5 的一部分
     */
    private fun showAnnotations(searchResults: List<SearchResult>) {
        // 清除之前的标记
        pointAnnotationManager.deleteAll()
        
        if (searchResults.isEmpty()) {
            return
        }
        
        // 创建所有标记
        val annotations = searchResults.map { result ->
            PointAnnotationOptions()
                .withPoint(result.coordinate)
                .withTextField(result.name)
                .withTextSize(14.0)
        }
        
        pointAnnotationManager.create(annotations)
        
        // 调整地图视角以包含所有标记
        if (searchResults.size == 1) {
            // 单个标记，直接移动到该位置
            adjustCameraToResult(searchResults.first())
        } else {
            // 多个标记，调整视角以包含所有标记
            adjustCameraToMultipleResults(searchResults)
        }
        
        Log.d(TAG, "显示 ${searchResults.size} 个标记")
    }

    /**
     * 调整地图视角以包含多个搜索结果
     * Task 6.5 的一部分
     */
    private fun adjustCameraToMultipleResults(searchResults: List<SearchResult>) {
        if (searchResults.isEmpty()) {
            return
        }
        
        // 计算所有标记的边界
        val coordinates = searchResults.map { it.coordinate }
        
        // 找出最小和最大的经纬度
        val minLat = coordinates.minOf { it.latitude() }
        val maxLat = coordinates.maxOf { it.latitude() }
        val minLon = coordinates.minOf { it.longitude() }
        val maxLon = coordinates.maxOf { it.longitude() }
        
        // 计算中心点
        val centerLat = (minLat + maxLat) / 2
        val centerLon = (minLon + maxLon) / 2
        val center = Point.fromLngLat(centerLon, centerLat)
        
        // 计算合适的缩放级别
        // 这是一个简化的计算，实际应该根据边界框大小动态调整
        val latDiff = maxLat - minLat
        val lonDiff = maxLon - minLon
        val maxDiff = maxOf(latDiff, lonDiff)
        
        val zoom = when {
            maxDiff > 10 -> 5.0
            maxDiff > 5 -> 7.0
            maxDiff > 2 -> 9.0
            maxDiff > 1 -> 11.0
            maxDiff > 0.5 -> 12.0
            maxDiff > 0.1 -> 13.0
            else -> 14.0
        }
        
        // 设置相机位置
        mapView.mapboxMap.setCamera(
            CameraOptions.Builder()
                .center(center)
                .zoom(zoom)
                .build()
        )
        
        Log.d(TAG, "调整地图视角以包含 ${searchResults.size} 个标记，中心: $center, 缩放: $zoom")
    }

    /**
     * 处理搜索错误
     * Task 5.6 的一部分
     */
    private fun handleSearchError(e: Exception) {
        Log.e(TAG, "搜索错误", e)
        
        // 根据错误类型显示不同的提示
        val errorMessage = when {
            e.message?.contains("network", ignoreCase = true) == true -> {
                getString(R.string.network_error)
            }
            else -> {
                getString(R.string.search_service_error)
            }
        }
        
        Toast.makeText(this, errorMessage, Toast.LENGTH_SHORT).show()
    }

    /**
     * 处理导航按钮点击
     * Task 8.1 的一部分
     */
    private fun onNavigateButtonClicked(searchPlace: com.mapbox.search.ui.view.place.SearchPlace) {
        Log.d(TAG, "导航按钮点击: ${searchPlace.name}")
        
        // 生成wayPoints并返回结果
        // 完整实现在Task 8中
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

    /**
     * 生成wayPoints数组
     * Task 8.2 的一部分
     */
    private suspend fun generateWayPoints(searchPlace: com.mapbox.search.ui.view.place.SearchPlace): List<Map<String, Any>> {
        // 获取当前位置
        val currentLoc = locationHelper.getCurrentLocation()
        
        if (currentLoc == null) {
            throw Exception("无法获取当前位置")
        }
        
        // 获取当前位置名称
        val currentLocationName = locationHelper.reverseGeocode(currentLoc)
        
        // 创建起点
        val startPoint = WayPointData(
            name = currentLocationName,
            latitude = currentLoc.latitude(),
            longitude = currentLoc.longitude(),
            isSilent = false,
            address = ""
        )
        
        // 创建终点
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
     * Task 9.3 的一部分
     */
    private fun returnResult(wayPoints: List<Map<String, Any>>) {
        val resultIntent = Intent().apply {
            putExtra(EXTRA_RESULT_WAYPOINTS, ArrayList(wayPoints))
        }
        setResult(Activity.RESULT_OK, resultIntent)
        finish()
    }
}
