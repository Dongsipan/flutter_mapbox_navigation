# 设计文档 - Android地图搜索功能

## 概述

本设计文档描述了Android平台地图搜索功能的技术实现方案。该功能将集成Mapbox Search SDK for Android，创建一个带有搜索框的完整地图界面，允许用户搜索地点并生成导航所需的路径点数组。

设计目标：
- 与iOS平台功能保持一致
- 提供流畅的用户体验
- 遵循Android Material Design规范
- 确保代码可维护性和可扩展性

## 架构

### 整体架构

```
Flutter Layer (Dart)
    ↓ MethodChannel
Android Plugin Layer (Kotlin)
    ├── FlutterMapboxNavigationPlugin (主插件)
    ├── SearchActivity (搜索界面Activity)
    ├── SearchResultAdapter (搜索结果适配器)
    └── LocationHelper (位置辅助类)
    ↓
Mapbox Search SDK
    ├── SearchEngine (搜索引擎)
    ├── SearchResultsView (搜索结果视图)
    └── ReverseGeocodingSearchEngine (反向地理编码)
```

### 通信流程

```
1. Flutter调用showSearchView()
   ↓
2. MethodChannel传递到Android
   ↓
3. FlutterMapboxNavigationPlugin启动SearchActivity
   ↓
4. 用户在SearchActivity中搜索和选择地点
   ↓
5. SearchActivity生成wayPoints数组
   ↓
6. 通过MethodChannel返回给Flutter
   ↓
7. Flutter接收wayPoints数据
```

## 组件和接口

### 1. MethodChannel接口

#### 通道名称
```kotlin
const val SEARCH_CHANNEL = "flutter_mapbox_navigation/search"
```

#### 方法定义

**showSearchView**
- 输入：无参数
- 输出：`List<Map<String, Any>>?` - wayPoints数组或null（用户取消）
- 异常：`PlatformException` - 当发生错误时

wayPoints数组格式：
```kotlin
[
  {
    "name": String,        // 地点名称
    "latitude": Double,    // 纬度
    "longitude": Double,   // 经度
    "isSilent": Boolean,   // 是否静默（默认false）
    "address": String      // 地址（可选）
  },
  ...
]
```

### 2. SearchActivity

主要的搜索界面Activity，负责地图显示、搜索交互和结果处理。

#### 类定义

```kotlin
class SearchActivity : AppCompatActivity() {
    companion object {
        const val EXTRA_RESULT_WAYPOINTS = "result_waypoints"
        const val REQUEST_CODE = 9002
    }
    
    // 核心组件
    private lateinit var mapView: MapView
    private lateinit var placeAutocomplete: PlaceAutocomplete
    private lateinit var searchResultsView: SearchResultsView
    private lateinit var searchPlaceBottomSheetView: SearchPlaceBottomSheetView
    private lateinit var pointAnnotationManager: PointAnnotationManager
    private lateinit var locationProvider: LocationProvider
    
    // UI组件
    private lateinit var searchEditText: EditText
    private lateinit var cancelButton: ImageButton
    private lateinit var locationButton: ImageButton
    
    // 状态
    private var selectedSearchPlace: SearchPlace? = null
    private var currentLocation: Point? = null
}
```

#### 主要方法

```kotlin
// 初始化地图
private fun setupMapView()

// 初始化PlaceAutocomplete
private fun setupPlaceAutocomplete()

// 初始化搜索结果视图
private fun setupSearchResultsView()

// 初始化底部抽屉（使用官方SearchPlaceBottomSheetView）
private fun setupBottomSheet()

// 处理搜索输入
private fun handleSearchInput(query: String)

// 显示搜索结果
private fun showSearchResults(results: List<PlaceAutocompleteSuggestion>)

// 处理搜索结果选择
private fun onSearchResultSelected(suggestion: PlaceAutocompleteSuggestion)

// 在地图上显示标记
private fun showAnnotation(place: SearchPlace)

// 获取当前位置名称
private suspend fun getCurrentLocationName(point: Point): String

// 生成wayPoints数组
private suspend fun generateWayPoints(): List<Map<String, Any>>

// 返回结果给Flutter
private fun returnResult(wayPoints: List<Map<String, Any>>)
```

### 3. LocationHelper

位置相关的辅助类，处理位置权限和位置获取。

```kotlin
class LocationHelper(private val context: Context) {
    
    // 检查位置权限
    fun hasLocationPermission(): Boolean
    
    // 请求位置权限
    fun requestLocationPermission(activity: Activity)
    
    // 获取当前位置
    suspend fun getCurrentLocation(): Point?
    
    // 反向地理编码
    suspend fun reverseGeocode(point: Point): String
}
```

### 4. SearchResultAdapter

搜索结果列表的适配器。

```kotlin
class SearchResultAdapter(
    private val onItemClick: (SearchResult) -> Unit
) : RecyclerView.Adapter<SearchResultAdapter.ViewHolder>() {
    
    private var results: List<SearchResult> = emptyList()
    
    fun updateResults(newResults: List<SearchResult>)
    
    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val nameTextView: TextView
        val addressTextView: TextView
        val iconImageView: ImageView
    }
}
```

## 数据模型

### WayPoint数据结构

```kotlin
data class WayPointData(
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val isSilent: Boolean = false,
    val address: String = ""
) {
    fun toMap(): Map<String, Any> = mapOf(
        "name" to name,
        "latitude" to latitude,
        "longitude" to longitude,
        "isSilent" to isSilent,
        "address" to address
    )
}
```

### SearchState

```kotlin
sealed class SearchState {
    object Idle : SearchState()
    object Loading : SearchState()
    data class Results(val results: List<SearchResult>) : SearchState()
    data class Error(val message: String) : SearchState()
}
```

## 正确性属性

*属性是一个特征或行为，应该在系统的所有有效执行中保持为真——本质上是关于系统应该做什么的形式化陈述。属性作为人类可读规范和机器可验证正确性保证之间的桥梁。*

### 属性 1: 搜索输入触发自动补全

*对于任何*非空搜索输入字符串，系统应该触发搜索引擎并返回自动补全建议列表（可能为空）

**验证: 需求 3.1**

### 属性 2: 搜索结果包含必需字段

*对于任何*搜索结果，结果对象应该包含地点名称和地址信息字段

**验证: 需求 3.2**

### 属性 3: 选择搜索结果显示标记

*对于任何*搜索结果，当用户选择该结果时，系统应该在地图上添加对应的标记点，并且标记应该显示地点名称

**验证: 需求 3.3, 4.1, 4.2**

### 属性 4: 选择搜索结果调整地图视角

*对于任何*搜索结果，当用户选择该结果时，地图的中心点应该更新为该结果的坐标位置

**验证: 需求 3.4**

### 属性 5: 点击标记显示详情

*对于任何*地图上的标记点，当用户点击该标记时，系统应该显示底部抽屉，并且抽屉中应该包含地点名称和地址信息

**验证: 需求 4.4, 5.1, 5.2, 5.3**

### 属性 6: 多个标记自动调整视角

*对于任何*包含多个搜索结果的列表，当在地图上显示所有标记时，地图的可视区域应该自动调整以包含所有标记点

**验证: 需求 4.5**

### 属性 7: 点击地图隐藏抽屉

*对于任何*地图上的非标记区域，当用户点击该区域且底部抽屉处于显示状态时，底部抽屉应该隐藏

**验证: 需求 5.5**

### 属性 8: 前往此处获取当前位置

*对于任何*选中的搜索结果，当用户点击"前往此处"按钮时，系统应该获取用户的当前位置坐标

**验证: 需求 6.1**

### 属性 9: 反向地理编码获取位置名称

*对于任何*有效的地理坐标，系统应该调用反向地理编码服务获取该位置的名称（如果失败则使用默认名称）

**验证: 需求 6.2**

### 属性 10: wayPoints数组格式正确性

*对于任何*生成的wayPoints数组，数组应该包含恰好2个元素（起点和终点），并且每个元素都应该包含name、latitude、longitude、isSilent、address这5个字段

**验证: 需求 6.4, 6.6**

### 属性 11: wayPoints通过MethodChannel返回

*对于任何*成功生成的wayPoints数组，系统应该通过MethodChannel将数组返回给Flutter层

**验证: 需求 6.5**

### 属性 12: 地点选择返回wayPoints

*对于任何*用户完成的地点选择操作，系统应该返回包含起点和终点的wayPoints数组给Flutter

**验证: 需求 7.3**

### 属性 13: 错误返回PlatformException

*对于任何*在搜索过程中发生的错误，系统应该通过PlatformException将错误信息返回给Flutter层

**验证: 需求 7.5**

### 属性 14: 错误信息使用中文

*对于任何*错误提示信息，消息文本应该使用中文字符

**验证: 需求 9.5**

## 错误处理

### 错误类型和处理策略

#### 1. 网络错误
- **场景**: 无网络连接或网络请求超时
- **处理**: 显示Toast提示"网络连接失败，请检查网络设置"
- **恢复**: 允许用户重试搜索

#### 2. 搜索服务错误
- **场景**: Mapbox搜索服务不可用或返回错误
- **处理**: 显示Toast提示"搜索服务暂时不可用，请稍后重试"
- **恢复**: 允许用户重试搜索

#### 3. 位置权限错误
- **场景**: 用户拒绝位置权限
- **处理**: 显示Dialog说明需要位置权限的原因，提供"去设置"按钮
- **恢复**: 引导用户到系统设置页面授予权限

#### 4. 位置服务错误
- **场景**: GPS未开启或位置服务不可用
- **处理**: 显示Toast提示"请开启位置服务"
- **恢复**: 引导用户开启位置服务

#### 5. 反向地理编码错误
- **场景**: 反向地理编码API调用失败
- **处理**: 使用默认名称"当前位置"作为起点名称
- **恢复**: 不影响主流程，继续生成wayPoints

#### 6. Activity启动错误
- **场景**: SearchActivity无法启动
- **处理**: 通过PlatformException返回错误给Flutter
- **恢复**: Flutter层显示错误提示

### 错误日志

所有错误都应该记录到Android日志系统：
```kotlin
Log.e("SearchActivity", "Error message", exception)
```

## 测试策略

### 单元测试

使用JUnit和Mockito进行单元测试：

1. **LocationHelper测试**
   - 测试位置权限检查
   - 测试位置获取
   - 测试反向地理编码

2. **WayPointData测试**
   - 测试数据模型的toMap()方法
   - 测试字段验证

3. **MethodChannel通信测试**
   - 测试showSearchView方法调用
   - 测试返回值格式

### 属性测试

使用Kotest Property Testing进行属性测试：

1. **属性 1-14的实现**
   - 每个属性至少运行100次迭代
   - 使用随机生成的测试数据
   - 标记格式: `// Feature: android-map-search-feature, Property X: [属性描述]`

### UI测试

使用Espresso进行UI测试：

1. **界面元素测试**
   - 验证搜索框、按钮等UI元素存在
   - 验证底部抽屉显示和隐藏

2. **交互测试**
   - 测试搜索输入和结果显示
   - 测试地图标记点击
   - 测试按钮点击

### 集成测试

1. **端到端流程测试**
   - 从Flutter调用到返回结果的完整流程
   - 包含真实的Mapbox API调用

2. **错误场景测试**
   - 模拟各种错误情况
   - 验证错误处理逻辑

## 实现细节

### 依赖配置

在`android/build.gradle`中添加：

```gradle
dependencies {
    // Mapbox Search SDK (使用ndk27版本以支持16KB页面大小)
    implementation 'com.mapbox.search:mapbox-search-android-ndk27:2.17.1'
    implementation 'com.mapbox.search:mapbox-search-android-ui-ndk27:2.17.1'
    implementation 'com.mapbox.search:place-autocomplete-ndk27:2.17.1'
    
    // Mapbox Maps SDK (已有)
    implementation 'com.mapbox.maps:android:10.16.0'
    
    // Coroutines for async operations
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3'
    
    // Material Design (CoordinatorLayout required for SearchPlaceBottomSheetView)
    implementation 'com.google.android.material:material:1.9.0'
    implementation 'androidx.coordinatorlayout:coordinatorlayout:1.2.0'
}
```

### Maven仓库配置

在`settings.gradle`中添加Mapbox Maven仓库：

```gradle
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                basic(BasicAuthentication)
            }
            credentials {
                username = "mapbox"
                password = providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").get()
            }
        }
    }
}
```

注意：需要在`gradle.properties`中配置`MAPBOX_DOWNLOADS_TOKEN`（secret token）

### 布局文件

`activity_search.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<androidx.coordinatorlayout.widget.CoordinatorLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <!-- 地图视图 -->
    <com.mapbox.maps.MapView
        android:id="@+id/mapView"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <!-- 顶部搜索栏 -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:padding="16dp"
        android:background="@android:color/white"
        android:elevation="4dp">

        <ImageButton
            android:id="@+id/cancelButton"
            android:layout_width="48dp"
            android:layout_height="48dp"
            android:src="@drawable/ic_arrow_back"
            android:background="?attr/selectableItemBackgroundBorderless"
            android:contentDescription="@string/cancel" />

        <EditText
            android:id="@+id/searchEditText"
            android:layout_width="0dp"
            android:layout_height="48dp"
            android:layout_weight="1"
            android:hint="@string/search_hint"
            android:imeOptions="actionSearch"
            android:inputType="text"
            android:paddingStart="16dp"
            android:paddingEnd="16dp" />

        <ImageButton
            android:id="@+id/locationButton"
            android:layout_width="48dp"
            android:layout_height="48dp"
            android:src="@drawable/ic_my_location"
            android:background="?attr/selectableItemBackgroundBorderless"
            android:contentDescription="@string/my_location" />
    </LinearLayout>

    <!-- 搜索结果列表 (官方UI组件) -->
    <com.mapbox.search.ui.view.SearchResultsView
        android:id="@+id/searchResultsView"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="80dp"
        android:background="@android:color/white"
        android:elevation="4dp"
        android:visibility="gone" />

    <!-- 底部抽屉 (官方UI组件) -->
    <com.mapbox.search.ui.view.SearchPlaceBottomSheetView
        android:id="@+id/searchPlaceBottomSheetView"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        app:layout_behavior="com.google.android.material.bottomsheet.BottomSheetBehavior" />

</androidx.coordinatorlayout.widget.CoordinatorLayout>
```

注意：使用官方的`SearchResultsView`和`SearchPlaceBottomSheetView`组件，无需自定义底部抽屉布局。

### 权限配置

在`AndroidManifest.xml`中添加：

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />

<application>
    <activity
        android:name=".activity.SearchActivity"
        android:theme="@style/Theme.AppCompat.Light.NoActionBar"
        android:exported="false" />
</application>
```

### 字符串资源

在`res/values/strings.xml`中添加：

```xml
<string name="search_hint">搜索地点</string>
<string name="go_to_place">🧭 前往此处</string>
<string name="current_location">当前位置</string>
<string name="cancel">取消</string>
<string name="my_location">我的位置</string>
<string name="network_error">网络连接失败，请检查网络设置</string>
<string name="search_service_error">搜索服务暂时不可用，请稍后重试</string>
<string name="location_permission_required">需要位置权限才能使用此功能</string>
<string name="location_service_disabled">请开启位置服务</string>
<string name="no_results">未找到相关地点</string>
```

## 性能考虑

### 搜索防抖

实现搜索输入防抖，避免频繁调用API：

```kotlin
private val searchJob = Job()
private val searchScope = CoroutineScope(Dispatchers.Main + searchJob)

private fun handleSearchInput(query: String) {
    searchScope.launch {
        delay(300) // 300ms防抖
        performSearch(query)
    }
}
```

### 内存管理

- 及时释放MapView资源
- 清理不再使用的标记点
- 取消未完成的协程任务

### 缓存策略

- 缓存最近的搜索结果
- 缓存反向地理编码结果

## 安全考虑

### API密钥保护

- Mapbox访问令牌应存储在`local.properties`或环境变量中
- 不要将密钥硬编码在代码中
- 使用ProGuard混淆代码

### 权限处理

- 遵循Android权限最佳实践
- 在请求权限前说明原因
- 优雅处理权限拒绝情况

## 可访问性

- 为所有UI元素添加contentDescription
- 支持TalkBack屏幕阅读器
- 确保足够的触摸目标大小（最小48dp）
- 支持键盘导航

