import MapboxDirections
import MapboxMaps
import MapboxNavigationCore
import MapboxNavigationUIKit
import UIKit
import Combine

/// 历史轨迹回放视图控制器
/// 按照官方最新建议：订阅 HistoryReplayController.locations 位置流
/// 将位置更新到自定义 MapView，不启动导航相关组件
final class HistoryReplayViewController: UIViewController {

    // MARK: - Properties (following official example pattern)

    private let historyFilePath: String

    // Combine 订阅管理
    private var cancellables = Set<AnyCancellable>()

    // 使用普通的 MapView 而不是 NavigationMapView，避免导航相关逻辑
    private var mapView: MapView! {
        didSet {
            if let mapView = oldValue {
                mapView.removeFromSuperview()
            }

            if mapView != nil {
                configure()
            }
        }
    }

    // 按照官方建议：仅创建 HistoryReplayController，不与导航引擎结合
    private lazy var historyReplayController: HistoryReplayController = {
        print("Creating HistoryReplayController for trajectory-only replay: \(historyFilePath)")

        // Smart path resolution for iOS sandbox changes
        let currentHistoryDir = defaultHistoryDirectoryURL()
        print("当前应用历史记录目录: \(currentHistoryDir.path)")

        // List current directory contents
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: currentHistoryDir.path) {
            print("当前历史记录目录内容 (\(contents.count) 个文件):")
            for file in contents {
                print("  - \(file)")
            }
        }

        let fileURL = URL(fileURLWithPath: historyFilePath)
        print("提供的文件URL: \(fileURL)")
        print("文件URL路径: \(fileURL.path)")
        print("文件URL绝对字符串: \(fileURL.absoluteString)")

        var finalFileURL = fileURL

        // Check if file exists, if not try to find it in current directory
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            print("❌ 原始路径文件不存在")

            // Extract filename and try to find it in current directory
            let filename = fileURL.lastPathComponent
            let currentDirFileURL = currentHistoryDir.appendingPathComponent(filename)
            print("在当前目录中查找文件: \(currentDirFileURL.path)")

            if FileManager.default.fileExists(atPath: currentDirFileURL.path) {
                print("✅ 在当前目录中找到同名文件")
                finalFileURL = currentDirFileURL
            } else {
                print("❌ 在当前目录中也未找到文件")
            }
        } else {
            print("✅ 原始路径文件存在")
        }

        print("✅ 创建HistoryReader用于轨迹回放，使用路径: \(finalFileURL.path)")

        guard let historyReader = HistoryReader(fileUrl: finalFileURL, readOptions: nil) else {
            fatalError("Failed to create HistoryReader with file: \(finalFileURL.path)")
        }

        var historyReplayController = HistoryReplayController(historyReader: historyReader)
        historyReplayController.delegate = self
        return historyReplayController
    }()

    // 按照官方最新建议：订阅 HistoryReplayController.locations 位置流
    private var locationSubscription: AnyCancellable?

    // 管理地图事件订阅的生命周期
    private var cancelables = Set<AnyCancellable>()

    // 轨迹绘制相关属性
    private var historyLocations: [CLLocation] = []
    private let historyRouteSourceId = "history-route-source"
    private let historyRouteLayerId = "history-route-layer"
    private let currentLocationSourceId = "current-location-source"
    private let currentLocationLayerId = "current-location-layer"

    // 不需要 MapboxNavigationProvider 和相关导航组件

    // MARK: - Initialization

    init(historyFilePath: String) {
        self.historyFilePath = historyFilePath
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // 确保资源清理
        locationSubscription?.cancel()
        cancelables.removeAll()
        historyReplayController.pause()
        print("HistoryReplayViewController deinitialized")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        loadMapViewIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 开始历史轨迹回放，仅显示轨迹，不启动导航界面
        startHistoryReplay()
    }

    // MARK: - Private Methods

    private func loadMapViewIfNeeded() {
        if mapView == nil {
            // 按照官方最新建议：使用普通的 MapView，不使用 NavigationMapView
            mapView = MapView(frame: view.bounds)

            // 启用位置显示
            mapView.location.options.puckType = .puck2D()

            // 设置地图样式加载完成后的回调
            mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
                self?.setupTrajectoryLayers()
            }.store(in: &cancelables)

            print("MapView created for trajectory display")
        }
    }

    private func configure() {
        setupMapView()
    }

    private func startHistoryReplay() {
        print("🚀 Starting history trajectory replay by parsing history file first")

        // 按照官方建议：先解析历史文件获取完整轨迹
        Task {
            await parseHistoryFileAndDrawRoute()

            // 然后订阅位置流用于当前位置更新
            await MainActor.run {
                print("🎯 Setting up location stream subscription")

                locationSubscription = historyReplayController.locations
                    .receive(on: RunLoop.main)
                    .sink { [weak self] location in
                        print("📍 Received location update: \(location.coordinate)")
                        self?.updateCurrentLocation(location)
                    }

                // 开始回放
                print("▶️ Starting history replay controller")
                historyReplayController.play()

                print("✅ History replay started - route drawn and location stream subscribed")
            }
        }
    }

    private func parseHistoryFileAndDrawRoute() async {
        print("🔍 Parsing history file to extract trajectory")

        // 直接使用当前目录中的同名文件（与 HistoryReplayController 相同的方式）
        let currentHistoryDir = defaultHistoryDirectoryURL()
        let fileName = URL(fileURLWithPath: historyFilePath).lastPathComponent
        let finalFileURL = currentHistoryDir.appendingPathComponent(fileName)

        print("✅ Using current directory file: \(finalFileURL.path)")

        do {
            // 按照官方建议：使用 HistoryReader 解析历史文件
            guard let reader = HistoryReader(fileUrl: finalFileURL, readOptions: nil) else {
                print("❌ Failed to create HistoryReader")
                return
            }

            let history = try await reader.parse()
            historyLocations = history.rawLocations

            print("✅ Parsed \(historyLocations.count) locations from history file")

            if historyLocations.isEmpty {
                print("⚠️ No locations found in history file")
                return
            }

            // 打印前几个位置用于调试
            for (index, location) in historyLocations.prefix(3).enumerated() {
                print("📍 Location \(index): \(location.coordinate) at \(location.timestamp)")
            }

            // 在主线程绘制路线
            await MainActor.run {
                drawHistoryRoute()
            }

        } catch {
            print("❌ Error parsing history file: \(error)")
        }
    }

    private func drawHistoryRoute() {
        guard !historyLocations.isEmpty else {
            print("❌ No locations to draw")
            return
        }

        print("🎯 Drawing history route with \(historyLocations.count) points")

        // 按照官方建议：提取坐标数组
        let coordinates = historyLocations.map { $0.coordinate }
        print("📍 Coordinates: \(coordinates.prefix(3))...") // 打印前3个坐标用于调试

        guard let mapView = mapView else {
            print("❌ MapView is nil")
            return
        }

        // 按照官方建议：先移除已存在的数据源和图层（避免重复添加）
        try? mapView.mapboxMap.removeLayer(withId: historyRouteLayerId)
        try? mapView.mapboxMap.removeSource(withId: historyRouteSourceId)

        // 创建 LineString 并绘制轨迹线
        let lineString = LineString(coordinates)
        let feature = Feature(geometry: .lineString(lineString))

        // 创建并添加历史路线数据源
        var routeLineSource = GeoJSONSource(id: historyRouteSourceId)
        routeLineSource.data = .feature(feature)

        do {
            try mapView.mapboxMap.addSource(routeLineSource)
            print("✅ Route source added successfully")
        } catch {
            print("❌ Failed to add route source: \(error)")
            return
        }

        // 创建并添加历史路线图层
        var lineLayer = LineLayer(id: historyRouteLayerId, source: historyRouteSourceId)
        lineLayer.lineColor = .constant(StyleColor(.systemBlue))
        lineLayer.lineWidth = .constant(4.0)
        lineLayer.lineCap = .constant(.round)
        lineLayer.lineJoin = .constant(.round)

        do {
            try mapView.mapboxMap.addLayer(lineLayer)
            print("✅ Route layer added successfully")
        } catch {
            print("❌ Failed to add route layer: \(error)")
            return
        }

        // 设置地图视角以显示完整路线
        if let firstLocation = historyLocations.first {
            let cameraOptions = CameraOptions(
                center: firstLocation.coordinate,
                zoom: 13.0
            )
            mapView.camera.ease(to: cameraOptions, duration: 1.0)
            print("📷 Camera set to first location: \(firstLocation.coordinate)")
        }

        print("✅ History route drawn successfully")
    }

    private func setupTrajectoryLayers() {
        guard let mapView = mapView else {
            print("❌ MapView is nil in setupTrajectoryLayers")
            return
        }

        print("🎯 Setting up current location layer")

        // 先移除已存在的图层和数据源（避免重复添加）
        try? mapView.mapboxMap.removeLayer(withId: currentLocationLayerId)
        try? mapView.mapboxMap.removeSource(withId: currentLocationSourceId)

        // 只添加当前位置点数据源和图层
        // 历史路线会在解析历史文件后单独绘制
        var currentLocationSource = GeoJSONSource(id: currentLocationSourceId)
        currentLocationSource.data = .featureCollection(FeatureCollection(features: []))

        do {
            try mapView.mapboxMap.addSource(currentLocationSource)
            print("✅ Current location source added")
        } catch {
            print("❌ Failed to add current location source: \(error)")
            return
        }

        // 添加当前位置点图层
        var currentLocationLayer = CircleLayer(id: currentLocationLayerId, source: currentLocationSourceId)
        currentLocationLayer.circleRadius = .constant(10.0)
        currentLocationLayer.circleColor = .constant(StyleColor(.systemRed))
        currentLocationLayer.circleStrokeWidth = .constant(3.0)
        currentLocationLayer.circleStrokeColor = .constant(StyleColor(.white))

        do {
            try mapView.mapboxMap.addLayer(currentLocationLayer)
            print("✅ Current location layer added")
        } catch {
            print("❌ Failed to add current location layer: \(error)")
        }

        print("✅ Current location layer setup completed")
    }

    private func updateCurrentLocation(_ location: CLLocation) {
        // 更新当前回放位置点
        print("Updating current location: \(location.coordinate)")

        // 更新当前位置点在地图上的显示
        updateCurrentLocationPoint(location.coordinate)

        // 更新地图相机位置跟随当前位置
        let cameraOptions = CameraOptions(
            center: location.coordinate,
            zoom: 15.0,
            bearing: location.course >= 0 ? location.course : nil
        )

        mapView?.camera.ease(to: cameraOptions, duration: 0.3)
    }

    private func updateCurrentLocationPoint(_ coordinate: CLLocationCoordinate2D) {
        guard let mapView = mapView else { return }

        // 创建当前位置点
        let point = Point(coordinate)
        let feature = Feature(geometry: .point(point))
        let featureCollection = FeatureCollection(features: [feature])

        // 更新当前位置点数据源
        try? mapView.mapboxMap.updateGeoJSONSource(withId: currentLocationSourceId, geoJSON: .featureCollection(featureCollection))
    }

    private func setupNavigationBar() {
        // 设置导航栏标题
        title = "历史轨迹回放"

        // 创建返回按钮
        let backButton = UIBarButtonItem(
            title: "返回",
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )

        // 设置导航栏左侧按钮
        navigationItem.leftBarButtonItem = backButton

        // 设置导航栏样式
        navigationController?.navigationBar.isHidden = false
        navigationController?.navigationBar.backgroundColor = UIColor.systemBackground
        navigationController?.navigationBar.tintColor = UIColor.systemBlue
    }

    @objc private func backButtonTapped() {
        // 清理资源
        cleanupReplay()

        // 由于页面是通过 present 方式展示的，需要 dismiss 整个导航控制器
        // 而不是 pop 当前视图控制器
        if let navigationController = navigationController {
            navigationController.dismiss(animated: true, completion: nil)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

    private func setupMapView() {
        mapView.translatesAutoresizingMaskIntoConstraints = false

        view.insertSubview(mapView, at: 0)

        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // 移除导航界面相关方法，因为我们只做轨迹回放，不启动导航界面
    // private func presentNavigationController(with navigationRoutes: NavigationRoutes) - 已移除
    // private func presentAndRemoveNavigationMapView() - 已移除

    private func cleanupReplay() {
        print("Cleaning up history trajectory replay")

        // 停止位置订阅
        locationSubscription?.cancel()
        locationSubscription = nil

        // 清理所有地图事件订阅
        cancelables.removeAll()

        // 停止历史回放
        historyReplayController.pause()

        // 清理历史数据
        historyLocations.removeAll()

        // 清理地图图层和数据源
        if let mapView = mapView {
            try? mapView.mapboxMap.removeLayer(withId: historyRouteLayerId)
            try? mapView.mapboxMap.removeLayer(withId: currentLocationLayerId)
            try? mapView.mapboxMap.removeSource(withId: historyRouteSourceId)
            try? mapView.mapboxMap.removeSource(withId: currentLocationSourceId)
        }

        // 清理地图视图
        mapView?.removeFromSuperview()
        mapView = nil

        print("History replay stopped and cleaned up")
    }
}

// MARK: - HistoryReplayDelegate (following official example)

extension HistoryReplayViewController: HistoryReplayDelegate {
    func historyReplayController(
        _: MapboxNavigationCore.HistoryReplayController,
        didReplayEvent event: any MapboxNavigationCore.HistoryEvent
    ) {
        // Monitor all incoming events as they come (following official example)
        // In this simplified version we don't need to handle specific events
    }

    func historyReplayController(
        _: MapboxNavigationCore.HistoryReplayController,
        wantsToSetRoutes routes: MapboxNavigationCore.NavigationRoutes
    ) {
        // 按照官方建议：不启动导航相关组件，仅记录路线信息
        print("History replay controller detected routes - trajectory replay only, no navigation UI")

        // 可以选择在地图上显示路线轮廓，但不启动导航
        // 这里我们选择仅记录，让位置流自然显示轨迹
        print("Routes detected but not starting navigation - letting location stream show trajectory")

        // 不调用任何导航相关方法：
        // - 不调用 presentNavigationController
        // - 不调用 startActiveGuidance
        // - 不使用 NavigationMapView 的导航功能
    }

    func historyReplayControllerDidFinishReplay(_: HistoryReplayController) {
        // 历史轨迹回放结束，直接关闭页面
        print("History trajectory replay finished via locations stream, closing replay view")

        // 清理资源并关闭页面
        cleanupReplay()

        // 关闭历史回放页面 - 由于是通过 present 方式展示的，需要 dismiss
        if let navigationController = self.navigationController {
            navigationController.dismiss(animated: true, completion: nil)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
}

// MARK: - NavigationViewControllerDelegate (following official example)

extension HistoryReplayViewController: NavigationViewControllerDelegate {
    func navigationViewControllerDidDismiss(
        _ navigationViewController: NavigationViewController,
        byCanceling canceled: Bool
    ) {
        // 注意：由于我们不启动导航界面，这个方法实际上不会被调用
        // 保留此方法仅为了协议完整性
        print("Navigation dismissed (this should not be called in trajectory-only replay)")

        cleanupReplay()

        if let navigationController = self.navigationController {
            navigationController.dismiss(animated: true, completion: nil)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
}