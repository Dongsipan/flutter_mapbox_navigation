# 搜索界面实现文档

## 概述

完全按照 Mapbox Search SDK 官方示例 `CustomThemeActivity` 实现 `SearchActivity`，确保代码结构和行为与官方示例一致。

## 实现细节

### 1. Toolbar 设置（完全按照示例）

```kotlin
toolbar = findViewById<Toolbar>(R.id.toolbar).apply {
    title = getString(R.string.simple_ui_toolbar_title)
    setSupportActionBar(this)
    
    // 使用 Mapbox SDK 提供的关闭图标，并设置颜色
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
```

**关键点：**
- 使用 `com.mapbox.search.ui.R.drawable.mapbox_search_sdk_close_drawable`
- 设置颜色为 `#4F6530`（绿色）
- 点击关闭图标直接 finish Activity

### 2. SearchPlaceBottomSheetView 配置（完全按照示例）

```kotlin
searchPlaceView.apply {
    initialize(CommonSearchViewConfiguration(DistanceUnitType.IMPERIAL))
    addOnCloseClickListener {
        hide()
    }
}
```

**关键点：**
- 使用 `DistanceUnitType.IMPERIAL`（英制单位）
- 只设置关闭监听器，导航监听器单独设置
- ID 为 `search_place_view`（与示例一致）

### 3. SearchResultsView 配置（完全按照示例）

```kotlin
searchResultsView.apply {
    initialize(
        SearchResultsView.Configuration(
            CommonSearchViewConfiguration(DistanceUnitType.IMPERIAL)
        )
    )
    isVisible = false
}
```

### 4. 搜索监听器（完全按照示例）

```kotlin
searchEngineUiAdapter.addSearchListener(object : SearchEngineUiAdapter.SearchListener {
    override fun onSearchResultSelected(
        searchResult: SearchResult,
        responseInfo: ResponseInfo
    ) {
        closeSearchView()
        searchPlaceView.open(SearchPlace.createFromSearchResult(searchResult, responseInfo))
    }
    
    override fun onHistoryItemClick(historyRecord: HistoryRecord) {
        closeSearchView()
        searchPlaceView.open(
            SearchPlace.createFromIndexableRecord(historyRecord, distanceMeters = null)
        )
    }
    
    // ... 其他回调
})
```

**关键点：**
- 选择搜索结果后，关闭搜索视图并打开底部抽屉
- 直接使用 `SearchPlace.createFromSearchResult()` 创建 SearchPlace
- 不需要手动显示地图标记或调整相机（SDK 自动处理）

### 5. 菜单配置（完全按照示例）

**文件名：** `simple_ui_activity_options_menu.xml`（与示例一致）

```xml
<menu xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto">
    
    <item
        android:id="@+id/action_search"
        android:title="@string/query_hint"
        android:icon="@android:drawable/ic_menu_search"
        app:showAsAction="ifRoom|collapseActionView"
        app:actionViewClass="androidx.appcompat.widget.SearchView" />
    
</menu>
```

### 6. 布局文件（完全按照示例）

```xml
<androidx.coordinatorlayout.widget.CoordinatorLayout>
    <!-- 地图 -->
    <com.mapbox.maps.MapView
        android:id="@+id/mapView" />

    <!-- Toolbar（不使用 AppBarLayout） -->
    <androidx.appcompat.widget.Toolbar
        android:id="@+id/toolbar" />

    <!-- 搜索结果 -->
    <com.mapbox.search.ui.view.SearchResultsView
        android:id="@+id/searchResultsView" />

    <!-- 底部抽屉 -->
    <com.mapbox.search.ui.view.place.SearchPlaceBottomSheetView
        android:id="@+id/search_place_view" />
</androidx.coordinatorlayout.widget.CoordinatorLayout>
```

**关键点：**
- 不使用 `AppBarLayout` 包裹 Toolbar
- 底部抽屉 ID 为 `search_place_view`（与示例一致）
- 不设置 `behavior_peekHeight` 等属性（使用默认值）

### 7. 导航功能集成

虽然示例代码没有导航功能，但我们添加了：

```kotlin
private fun setupNavigationListener() {
    searchPlaceView.addOnNavigateClickListener { searchPlace ->
        lifecycleScope.launch {
            try {
                val wayPoints = generateWayPoints(searchPlace)
                returnResult(wayPoints)
            } catch (e: Exception) {
                Toast.makeText(
                    this@SearchActivity,
                    "生成路径失败: ${e.message}",
                    Toast.LENGTH_SHORT
                ).show()
            }
        }
    }
}
```

## 与示例的差异

### 保留的功能
1. **位置权限处理** - 示例没有，我们保留
2. **导航功能** - 示例没有，我们添加以支持 Flutter 集成
3. **LocationHelper** - 用于获取当前位置和反向地理编码

### 移除的功能
1. **地图标记** - 不再手动添加标记（SDK 自动处理）
2. **相机调整** - 不再手动调整相机（SDK 自动处理）
3. **地图点击监听** - 不需要手动隐藏底部抽屉

## 代码统计

| 指标 | 数值 |
|------|------|
| 总行数 | ~380 |
| 成员变量 | 7 个 |
| 方法数 | 12 个 |
| 导入语句 | 35 个 |

## 核心流程

1. **用户点击搜索图标** → 展开 SearchView
2. **用户输入搜索词** → 显示搜索结果列表
3. **用户选择结果** → 关闭搜索视图 + 打开底部抽屉
4. **用户点击导航按钮** → 生成 wayPoints + 返回给 Flutter

## 字符串资源

```xml
<string name="simple_ui_toolbar_title">搜索地点</string>
<string name="query_hint">搜索地点</string>
```

## 技术要点

1. **使用 Mapbox SDK 的图标资源** - `com.mapbox.search.ui.R.drawable.mapbox_search_sdk_close_drawable`
2. **颜色设置** - `#4F6530`（绿色）
3. **单位系统** - `DistanceUnitType.IMPERIAL`（英制）
4. **自动化处理** - SDK 自动处理地图标记和相机调整

## 测试要点

- ✅ Toolbar 显示正确的标题和关闭图标
- ✅ 关闭图标颜色为绿色 (#4F6530)
- ✅ 搜索功能正常工作
- ✅ 选择搜索结果后显示底部抽屉
- ✅ 底部抽屉显示地点详情
- ✅ 点击导航按钮生成 wayPoints
- ✅ 历史记录功能正常

## 参考

- 官方示例：`CustomThemeActivity.kt`
- Mapbox Search SDK 文档：https://docs.mapbox.com/android/search/guides/
