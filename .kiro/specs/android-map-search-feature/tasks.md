# 实现计划: Android地图搜索功能

## 概述

本实现计划将Android平台的地图搜索功能分解为可执行的任务。实现将完全按照Mapbox官方文档推荐的方式，使用PlaceAutocomplete API、SearchResultsView和SearchPlaceBottomSheetView等官方UI组件，并通过MethodChannel与Flutter通信。

## 任务

- [x] 1. 配置Mapbox Maven仓库和项目依赖
  - [x] 1.1 在settings.gradle中添加Mapbox Maven仓库配置
    - 添加maven仓库URL和认证配置
    - 配置使用MAPBOX_DOWNLOADS_TOKEN（secret token）
    - _需求: 1.1_

  - [x] 1.2 在android/build.gradle中添加Mapbox Search SDK依赖
    - 添加place-autocomplete-ndk27模块
    - 添加mapbox-search-android-ui-ndk27模块
    - 添加mapbox-search-android-ndk27模块
    - 添加CoordinatorLayout依赖
    - 确保minSdk >= 21
    - _需求: 1.1_

  - [x] 1.3 配置权限和Activity注册
    - 在AndroidManifest.xml中添加位置权限和网络权限
    - 在AndroidManifest.xml中注册SearchActivity
    - 在res/values/strings.xml中添加中文字符串资源
    - _需求: 1.4, 8.1_

- [x] 2. 创建数据模型和辅助类
  - [x] 2.1 创建WayPointData数据类
    - 定义name、latitude、longitude、isSilent、address字段
    - 实现toMap()方法用于转换为Map格式
    - _需求: 6.6_

  - [x] 2.2 为WayPointData编写属性测试
    - **属性 10: wayPoints数组格式正确性**
    - **验证: 需求 6.4, 6.6**

  - [x] 2.3 创建LocationHelper辅助类
    - 实现hasLocationPermission()检查权限
    - 实现requestLocationPermission()请求权限
    - 实现getCurrentLocation()获取当前位置
    - 使用Mapbox Search SDK的ReverseGeocodingSearchEngine实现reverseGeocode()
    - _需求: 6.1, 6.2, 8.1, 8.2_

  - [x] 2.4 为LocationHelper编写单元测试
    - 测试权限检查逻辑
    - 测试位置获取逻辑
    - 模拟反向地理编码调用
    - _需求: 6.1, 6.2_

- [x] 3. 创建SearchActivity布局文件
  - [x] 3.1 创建activity_search.xml主布局
    - 使用CoordinatorLayout作为根布局
    - 添加MapView地图视图
    - 添加顶部搜索栏（包含取消按钮、搜索框、定位按钮）
    - 添加SearchResultsView（官方UI组件）
    - 添加SearchPlaceBottomSheetView（官方UI组件）
    - _需求: 2.2, 2.3, 2.4, 2.5_

  - [x] 3.2 创建drawable资源文件
    - 添加ic_arrow_back图标
    - 添加ic_my_location图标
    - _需求: 10.1, 10.4_

- [x] 4. 实现SearchActivity核心功能
  - [x] 4.1 实现Activity基础结构
    - 创建SearchActivity类继承AppCompatActivity
    - 声明UI组件变量（mapView、placeAutocomplete、searchResultsView等）
    - 实现onCreate()方法
    - 实现onDestroy()清理资源
    - _需求: 2.1_

  - [x] 4.2 实现地图初始化
    - 在setupMapView()中初始化MapView
    - 配置地图样式
    - 启用用户位置显示（puck）
    - 设置地图初始位置为当前位置
    - 创建PointAnnotationManager
    - _需求: 2.2, 2.6, 8.5_

  - [x] 4.3 实现PlaceAutocomplete初始化
    - 使用PlaceAutocomplete.create()创建实例
    - 配置PlaceAutocompleteOptions
    - 初始化SearchResultsView并调用initialize()
    - 配置CommonSearchViewConfiguration（设置距离单位）
    - _需求: 1.2, 1.3, 3.1_

  - [x] 4.4 为PlaceAutocomplete初始化编写单元测试
    - 验证PlaceAutocomplete创建成功
    - 验证配置正确
    - _需求: 1.2_

- [x] 5. 实现搜索交互功能（使用官方SearchEngineUiAdapter）
  - [x] 5.1 创建SearchEngine和SearchEngineUiAdapter
    - 使用SearchEngine.createSearchEngineWithBuiltInDataProviders()创建SearchEngine
    - 配置ApiType.GEOCODING
    - 创建SearchEngineUiAdapter连接SearchResultsView和SearchEngine
    - _需求: 3.1_

  - [x] 5.2 实现搜索输入监听
    - 为searchEditText添加TextWatcher
    - 实现300ms防抖逻辑
    - 调用searchEngineUiAdapter.search()触发搜索
    - _需求: 3.1_

  - [x] 5.3 为搜索输入编写属性测试
    - **属性 1: 搜索输入触发自动补全**
    - **验证: 需求 3.1**

  - [x] 5.4 实现SearchEngineUiAdapter.SearchListener
    - 实现onSearchResultSelected()处理搜索结果选择
    - 调用showAnnotation()在地图上显示标记
    - 调用searchPlaceBottomSheetView.open()显示底部抽屉
    - 调整地图视角到选中位置
    - _需求: 3.3, 3.4, 4.1, 4.4_

  - [x] 5.5 为搜索结果选择编写属性测试
    - **属性 3: 选择搜索结果显示标记**
    - **属性 4: 选择搜索结果调整地图视角**
    - **验证: 需求 3.3, 3.4, 4.1, 4.2**

  - [x] 5.6 实现错误处理
    - 在onError()中显示Toast错误提示
    - 处理网络错误、搜索服务错误
    - 使用中文错误消息
    - _需求: 9.1, 9.2, 9.5_

  - [x] 5.7 为错误处理编写属性测试
    - **属性 13: 错误返回PlatformException**
    - **属性 14: 错误信息使用中文**
    - **验证: 需求 7.5, 9.5**

- [x] 6. 实现地图标记功能
  - [x] 6.1 实现showAnnotation()方法
    - 使用PointAnnotationManager创建PointAnnotation
    - 设置标记坐标、图标和文本
    - 添加标记到地图
    - _需求: 4.1, 4.2_

  - [x] 6.2 为地图标记编写属性测试
    - **属性 2: 搜索结果包含必需字段**
    - **验证: 需求 3.2**

  - [x] 6.3 实现标记点击监听
    - 为PointAnnotation设置点击监听器
    - 点击时调用searchPlaceBottomSheetView.open()
    - _需求: 4.4_

  - [x] 6.4 为标记点击编写属性测试
    - **属性 5: 点击标记显示详情**
    - **验证: 需求 4.4, 5.1, 5.2, 5.3**

  - [x] 6.5 实现多标记视角调整
    - 在showAnnotations()中计算所有标记的边界
    - 使用MapboxMap.camera()方法调整地图视角
    - _需求: 4.5_

  - [x] 6.6 为多标记视角编写属性测试
    - **属性 6: 多个标记自动调整视角**
    - **验证: 需求 4.5**

- [x] 7. 实现底部抽屉功能（使用官方SearchPlaceBottomSheetView）
  - [x] 7.1 初始化SearchPlaceBottomSheetView
    - 在onCreate()中获取searchPlaceBottomSheetView
    - 调用initialize()方法配置CommonSearchViewConfiguration
    - 设置isNavigateButtonVisible = true
    - 设置isShareButtonVisible = false
    - 设置isFavoriteButtonVisible = false
    - _需求: 5.1, 5.4_

  - [x] 7.2 实现底部抽屉显示
    - 使用SearchPlace.createFromSearchResult()创建SearchPlace对象
    - 调用searchPlaceBottomSheetView.open(searchPlace)显示抽屉
    - _需求: 5.1, 5.2, 5.3_

  - [x] 7.3 为底部抽屉显示编写属性测试
    - **属性 5: 点击标记显示详情**（已在6.4中测试）
    - 验证底部抽屉包含完整信息
    - _需求: 5.1, 5.2, 5.3_

  - [x] 7.4 实现底部抽屉关闭监听
    - 添加SearchPlaceBottomSheetView.CloseClickListener
    - 实现onCloseClick()方法
    - _需求: 5.5_

  - [x] 7.5 实现地图点击隐藏抽屉
    - 为mapView添加OnMapClickListener
    - 点击时调用searchPlaceBottomSheetView.hide()
    - _需求: 5.5_

  - [x] 7.6 为地图点击编写属性测试
    - **属性 7: 点击地图隐藏抽屉**
    - **验证: 需求 5.5**

- [x] 8. 实现"前往此处"功能（使用官方Navigate按钮）
  - [x] 8.1 实现Navigate按钮点击监听
    - 添加SearchPlaceBottomSheetView.NavigateClickListener
    - 在onNavigateClick()中获取SearchPlace对象
    - 调用generateWayPoints()生成路径点
    - 调用returnResult()返回结果
    - _需求: 6.1, 6.3, 6.4_

  - [x] 8.2 实现generateWayPoints()方法
    - 使用LocationHelper获取当前位置
    - 使用ReverseGeocodingSearchEngine获取起点名称
    - 创建起点WayPointData
    - 创建终点WayPointData（使用SearchPlace数据）
    - 返回包含两个元素的List
    - _需求: 6.1, 6.2, 6.3, 6.4, 6.6_

  - [x] 8.3 为wayPoints生成编写属性测试
    - **属性 8: 前往此处获取当前位置**
    - **属性 9: 反向地理编码获取位置名称**
    - **属性 10: wayPoints数组格式正确性**（已在2.2中测试）
    - **验证: 需求 6.1, 6.2, 6.4, 6.6**

  - [x] 8.4 实现反向地理编码错误处理
    - 在reverseGeocode()中捕获异常
    - 失败时返回默认名称"当前位置"
    - _需求: 9.4_

- [x] 9. 实现MethodChannel通信
  - [x] 9.1 在FlutterMapboxNavigationPlugin中注册搜索通道
    - 创建searchChannel: MethodChannel
    - 在onAttachedToEngine()中初始化通道
    - 设置MethodCallHandler
    - _需求: 7.1_

  - [x] 9.2 实现showSearchView方法处理
    - 在handleSearchMethod()中处理"showSearchView"调用
    - 启动SearchActivity并等待结果
    - 使用startActivityForResult()
    - 保存result回调
    - _需求: 7.2_

  - [x] 9.3 在SearchActivity中实现returnResult()方法
    - 创建Intent并putExtra wayPoints数据
    - 调用setResult(RESULT_OK, intent)
    - 调用finish()关闭Activity
    - _需求: 6.5, 7.3_

  - [x] 9.4 为MethodChannel通信编写属性测试
    - **属性 11: wayPoints通过MethodChannel返回**
    - **属性 12: 地点选择返回wayPoints**
    - **验证: 需求 6.5, 7.3**

  - [x] 9.5 实现取消操作处理
    - 为cancelButton设置OnClickListener
    - 调用setResult(RESULT_CANCELED)
    - 调用finish()
    - 在Plugin中处理RESULT_CANCELED，返回null给Flutter
    - _需求: 2.4, 7.4_

  - [x] 9.6 在Plugin中实现Activity结果处理
    - 添加ActivityResultListener
    - 在onActivityResult()中处理SearchActivity结果
    - 解析wayPoints数据并返回给Flutter
    - _需求: 7.3_

- [x] 10. 实现位置权限管理
  - [x] 10.1 在SearchActivity中检查位置权限
    - 在onCreate()中调用LocationHelper.hasLocationPermission()
    - 如果未授予，调用requestLocationPermission()
    - _需求: 8.1, 8.2_

  - [x] 10.2 实现权限请求结果处理
    - 重写onRequestPermissionsResult()
    - 如果授予权限，启用地图位置显示
    - 如果拒绝权限，显示Dialog说明原因
    - _需求: 8.3, 8.4_

  - [x] 10.3 实现定位按钮功能
    - 为locationButton设置OnClickListener
    - 点击时将地图视角移动到当前位置
    - 使用CameraOptions设置中心点
    - _需求: 2.5_

- [x] 11. 检查点 - 确保所有测试通过
  - 运行所有单元测试
  - 运行所有属性测试
  - 修复任何失败的测试
  - 确保代码编译无错误

- [ ] 12. 集成测试和优化
  - [ ] 12.1 实现端到端集成测试
    - 测试从Flutter调用到返回结果的完整流程
    - 测试真实的Mapbox API调用
    - _需求: 1.3_

  - [ ] 12.2 实现性能优化
    - 添加搜索防抖（300ms）
    - 实现内存管理（及时释放资源）
    - 添加搜索结果缓存
    - _需求: 3.1_

  - [ ] 12.3 实现UI优化
    - 使用SearchResultAdapterItem.Loading显示加载状态
    - 优化动画效果
    - 确保Material Design规范
    - _需求: 10.1, 10.2_

  - [ ] 12.4 实现可访问性支持
    - 为所有UI元素添加contentDescription
    - 确保触摸目标大小至少48dp
    - 测试TalkBack支持
    - _需求: 10.1_

- [ ] 13. 最终检查点 - 验证所有功能
  - 确保所有测试通过
  - 在真实设备上测试完整流程
  - 验证与iOS功能一致性
  - 询问用户是否有问题

## 注意事项

- 所有任务都是必需的，包括测试任务
- 每个任务都引用了相关的需求编号，便于追溯
- 属性测试应该运行至少100次迭代
- 所有错误消息必须使用中文
- 代码应该遵循Kotlin编码规范
- 完全按照Mapbox官方文档推荐的方式实现，使用官方UI组件
