import MapboxDirections
import MapboxMaps
import MapboxNavigationCore
import MapboxNavigationUIKit
import UIKit

// MARK: - Double Extension for Range Clamping

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - UIColor Extension for Speed-based Colors

extension UIColor {
    /// 根据十六进制字符串创建颜色
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }

    /// 根据速度获取对应的颜色
    static func colorForSpeed(_ speedKmh: Double) -> UIColor {
        switch speedKmh {
        case ..<5.0:   return UIColor(hex: "#2E7DFF")  // 蓝色 - 很慢
        case ..<10.0:  return UIColor(hex: "#00E5FF")  // 青色 - 慢
        case ..<15.0:  return UIColor(hex: "#00E676")  // 绿色 - 中等偏慢
        case ..<20.0:  return UIColor(hex: "#C6FF00")  // 黄绿色 - 中等
        case ..<25.0:  return UIColor(hex: "#FFD600")  // 黄色 - 中等偏快
        case ..<30.0:  return UIColor(hex: "#FF9100")  // 橙色 - 快
        default:       return UIColor(hex: "#FF1744")  // 红色 - 很快
        }
    }
}
import Combine



/// 自定义位置提供者，将历史回放位置流提供给地图的内置 puck
class ReplayLocationProvider: LocationProvider {
    private var observers = NSHashTable<AnyObject>.weakObjects()
    private var lastLocation: MapboxCommon.Location?
    private var cancellable: AnyCancellable?

    func startReplay(with publisher: AnyPublisher<CLLocation, Never>) {
        cancellable = publisher.sink { [weak self] clLocation in
            guard let self = self else { return }
            let location = MapboxCommon.Location(
                coordinate: clLocation.coordinate,
                timestamp: clLocation.timestamp,
                altitude: clLocation.altitude,
                horizontalAccuracy: clLocation.horizontalAccuracy,
                verticalAccuracy: clLocation.verticalAccuracy,
                speed: clLocation.speed >= 0 ? clLocation.speed : nil,
                bearing: clLocation.course >= 0 ? clLocation.course : nil
            )
            self.lastLocation = location
            for observer in self.observers.allObjects {
                (observer as? LocationObserver)?.onLocationUpdateReceived(for: [location])
            }
        }
    }

    func getLastObservedLocation() -> MapboxCommon.Location? {
        return lastLocation
    }

    func addLocationObserver(for observer: any LocationObserver) {
        observers.add(observer)
        if let lastLocation = lastLocation {
            observer.onLocationUpdateReceived(for: [lastLocation])
        }
    }

    func removeLocationObserver(for observer: any LocationObserver) {
        observers.remove(observer)
    }

    deinit {
        cancellable?.cancel()
    }
}

/// 历史轨迹回放视图控制器
/// 按照官方最新建议：使用自定义 LocationProvider 将历史位置流提供给内置 puck
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
        // Smart path resolution for iOS sandbox changes
        let currentHistoryDir = defaultHistoryDirectoryURL()
        let fileURL = URL(fileURLWithPath: historyFilePath)
        var finalFileURL = fileURL

        // Check if file exists, if not try to find it in current directory
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            // Extract filename and try to find it in current directory
            let filename = fileURL.lastPathComponent
            let currentDirFileURL = currentHistoryDir.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: currentDirFileURL.path) {
                finalFileURL = currentDirFileURL
            }
        }

        guard let historyReader = HistoryReader(fileUrl: finalFileURL, readOptions: nil) else {
            fatalError("Failed to create HistoryReader with file: \(finalFileURL.path)")
        }

        var historyReplayController = HistoryReplayController(historyReader: historyReader)
        historyReplayController.delegate = self
        return historyReplayController
    }()

    // 按照官方最新建议：使用自定义 LocationProvider 将历史位置流提供给内置 puck
    private let replayLocationProvider = ReplayLocationProvider()
    private var locationSubscription: AnyCancellable?

    // 管理地图事件订阅的生命周期
    private var cancelables = Set<AnyCancellable>()

    // 轨迹绘制相关属性
    private var historyLocations: [CLLocation] = []
    private let historyRouteSourceId = "history-route-source"
    private let historyRouteLayerId = "history-route-layer"
    private let startPointSourceId = "start-point-source"
    private let endPointSourceId = "end-point-source"
    private let startPointLayerId = "start-point-layer"
    private let endPointLayerId = "end-point-layer"

    // 简化的速度数据存储（仅用于渐变显示）
    private var locationSpeeds: [Double] = []
    
    // 全览/跟随模式
    private var isOverviewMode = false
    private var overviewButton: UIButton?
    
    // 回放控制
    private var recommendedSpeed: Double = 16.0

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

            // 启用位置显示 - 使用带箭头的默认配置
            let configuration = Puck2DConfiguration.makeDefault(showBearing: true)
            mapView.location.options.puckType = .puck2D(configuration)
            // 设置箭头方向跟随 course（行进方向）而不是 heading（设备朝向）
            mapView.location.options.puckBearing = .course
            // 关键：在 v11 中需要手动启用 puck 方向旋转（默认为 false）
            mapView.location.options.puckBearingEnabled = true

            // 设置地图样式加载完成后的回调
            mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
                self?.setupTrajectoryLayers()
            }.store(in: &cancelables)


        }
    }

    private func configure() {
        setupMapView()
    }

    private func startHistoryReplay() {
        // 按照官方建议：先解析历史文件获取完整轨迹
        Task {
            await parseHistoryFileAndDrawRoute()

            // 然后订阅位置流用于当前位置更新
            await MainActor.run {
                // 将历史位置流连接到自定义 LocationProvider
                // 这样内置的 puck 会自动显示和跟随历史轨迹
                replayLocationProvider.startReplay(with: historyReplayController.locations.eraseToAnyPublisher())

                locationSubscription = historyReplayController.locations
                    .receive(on: RunLoop.main)
                    .sink { [weak self] location in
                        self?.updateCurrentLocation(location)
                    }

                // 设置推荐回放速度
                historyReplayController.playbackSpeed = recommendedSpeed
                print("🎯 设置回放速度为 \(recommendedSpeed)x")

                // 开始回放
                historyReplayController.play()
            }
        }
    }

    private func parseHistoryFileAndDrawRoute() async {
        // 智能路径解析 - 参照 Android 端逻辑
        let currentHistoryDir = defaultHistoryDirectoryURL()
        let fileURL = URL(fileURLWithPath: historyFilePath)
        var finalFileURL = fileURL
        
        // 检查文件是否存在，如果不存在则尝试在当前目录中查找
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let filename = fileURL.lastPathComponent
            let currentDirFileURL = currentHistoryDir.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: currentDirFileURL.path) {
                finalFileURL = currentDirFileURL
            }
        }

        print("🔍 解析历史文件: \(finalFileURL.path)")
        print("🔍 文件是否存在: \(FileManager.default.fileExists(atPath: finalFileURL.path))")

        do {
            // 使用 HistoryReader 解析历史文件
            guard let reader = HistoryReader(fileUrl: finalFileURL, readOptions: nil) else {
                print("❌ 无法创建 HistoryReader")
                return
            }
            print("✅ HistoryReader 创建成功")

            // 预解析所有历史事件，类似 Android 端的 preDrawCompleteRoute
            await preParseCompleteRoute(reader: reader)
            
            // 设置固定回放速度
            recommendedSpeed = 16.0
            print("🎯 设置回放速度: \(recommendedSpeed)x")

            // 在主线程绘制完整路线
            await MainActor.run {
                drawCompleteHistoryRoute()
                setupOverviewButton()
            }

        } catch {
            print("❌ 解析历史文件失败: \(error)")
        }
    }

    /// 预解析所有历史事件中的位置数据，类似 Android 端的 preDrawCompleteRoute
    private func preParseCompleteRoute(reader: HistoryReader) async {
        do {
            print("🔍 开始预解析历史事件中的位置数据...")
            
            let history = try await reader.parse()
            let allEvents = history.events
            print("📊 总事件数: \(allEvents.count)")
            
            var allLocations: [CLLocation] = []
            
            // 遍历所有事件，提取位置信息
            for event in allEvents {
                if let locationEvent = event as? LocationUpdateHistoryEvent {
                    let location = CLLocation(
                        coordinate: locationEvent.location.coordinate,
                        altitude: locationEvent.location.altitude ?? 0,
                        horizontalAccuracy: locationEvent.location.horizontalAccuracy ?? 0,
                        verticalAccuracy: locationEvent.location.verticalAccuracy ?? 0,
                        course: locationEvent.location.bearing ?? -1,
                        speed: locationEvent.location.speed ?? -1,
                        timestamp: locationEvent.location.timestamp
                    )
                    
                    // 过滤过近的点，类似 Android 端的逻辑
                    if allLocations.isEmpty {
                        allLocations.append(location)
                        print("📍 添加起点: lat=\(location.coordinate.latitude), lng=\(location.coordinate.longitude)")
                    } else {
                        let lastLocation = allLocations.last!
                        let distance = location.distance(from: lastLocation)
                        if distance > 0.5 { // 过滤0.5米内的点
                            allLocations.append(location)
                            if allLocations.count <= 5 {
                                print("📍 添加轨迹点\(allLocations.count): lat=\(location.coordinate.latitude), lng=\(location.coordinate.longitude), 距离上点=\(Int(distance))m")
                            }
                        }
                    }
                }
            }
            
            historyLocations = allLocations
            print("✅ 预解析完成: 总点数=\(historyLocations.count)")
            
            // 计算基础速度数据
            if !historyLocations.isEmpty {
                calculateLocationSpeeds()
            }
            
        } catch {
            print("❌ 预解析历史事件失败: \(error)")
            // 回退到原始方法
            let history = try await reader.parse()
            historyLocations = history.rawLocations
            calculateLocationSpeeds()
        }
    }

    /// 计算轨迹点的基础速度数据（仅用于渐变显示）
    private func calculateLocationSpeeds() {
        guard !historyLocations.isEmpty else { return }

        locationSpeeds.removeAll()

        for location in historyLocations {
            // 计算速度（从 m/s 转换为 km/h）
            let speedKmh = location.speed >= 0 ? location.speed * 3.6 : 0.0
            locationSpeeds.append(speedKmh)
        }

        print("计算完成 - 轨迹点数: \(historyLocations.count)")
    }
    
    

    /// 构建基于速度的渐变表达式
    private func buildSpeedGradientExpression() -> Exp {
        guard !locationSpeeds.isEmpty else {
            // 如果没有有效数据，返回默认颜色
            return Exp(.literal, UIColor.systemBlue)
        }

        var stops: [(Double, UIColor)] = []

        // 起点
        stops.append((0.0, UIColor.colorForSpeed(locationSpeeds.first ?? 0.0)))

        // 中间节点（每隔几个点采样，避免节点过多影响性能）
        let step = max(1, locationSpeeds.count / 20)
        for i in stride(from: step, to: locationSpeeds.count, by: step) {
            let progress = Double(i) / Double(locationSpeeds.count - 1)
            let color = UIColor.colorForSpeed(locationSpeeds[i])

            // 确保进度值递增
            if stops.isEmpty || progress > stops.last!.0 {
                stops.append((progress, color))
            }
        }

        // 终点
        if stops.last?.0 ?? 0 < 1.0 {
            stops.append((1.0, UIColor.colorForSpeed(locationSpeeds.last ?? 0.0)))
        }

        // 构建参数数组 - 按照官方文档的正确写法
        var args: [Any] = [Exp(.linear), Exp(.lineProgress)]
        for (progress, color) in stops {
            args.append(progress)
            args.append(color)
        }

        // 用参数数组初始化表达式 - 这是唯一正确的方式
        return Exp(.interpolate, args)
    }

    /// 一次性绘制完整历史路线，类似 Android 端的 drawCompleteRoute
    private func drawCompleteHistoryRoute() {
        guard !historyLocations.isEmpty else {
            print("⚠️ 历史位置数据为空，无法绘制路线")
            return
        }

        guard let mapView = mapView else {
            print("⚠️ MapView 未初始化")
            return
        }

        print("🎨 开始绘制完整历史路线，轨迹点数: \(historyLocations.count)")

        // 提取坐标数组
        let coordinates = historyLocations.map { $0.coordinate }

        // 清理现有图层和数据源
        cleanupExistingLayers()

        // 1. 绘制轨迹线
        drawTrajectoryLine(coordinates: coordinates)
        
        // 2. 绘制起终点标记
        drawStartEndMarkers(coordinates: coordinates)

        // 3. 设置地图视角以显示完整路线
        setOverviewCamera(coordinates: coordinates)
        
        print("✅ 完整历史路线绘制完成")
    }
    
    /// 清理现有的图层和数据源
    private func cleanupExistingLayers() {
        guard let mapView = mapView else { return }
        
        let layersToRemove = [historyRouteLayerId, startPointLayerId, endPointLayerId]
        let sourcesToRemove = [historyRouteSourceId, startPointSourceId, endPointSourceId]
        
        for layerId in layersToRemove {
            try? mapView.mapboxMap.removeLayer(withId: layerId)
        }
        
        for sourceId in sourcesToRemove {
            try? mapView.mapboxMap.removeSource(withId: sourceId)
        }
    }
    
    /// 绘制轨迹线
    private func drawTrajectoryLine(coordinates: [CLLocationCoordinate2D]) {
        guard let mapView = mapView else { return }
        
        // 创建 LineString
        let lineString = LineString(coordinates)

        // 创建并添加数据源
        var routeLineSource = GeoJSONSource(id: historyRouteSourceId)
        routeLineSource.data = .geometry(Geometry(lineString))
        routeLineSource.lineMetrics = true  // 启用线条度量，用于渐变

        do {
            try mapView.mapboxMap.addSource(routeLineSource)
            print("✅ 轨迹线数据源添加成功")
        } catch {
            print("❌ 添加轨迹线数据源失败: \(error)")
            return
        }

        // 创建并添加线条图层
        var lineLayer = LineLayer(id: historyRouteLayerId, source: historyRouteSourceId)

        // 根据是否有速度数据决定使用渐变还是单色
        if !locationSpeeds.isEmpty {
            // 使用速度渐变
            lineLayer.lineGradient = .expression(buildSpeedGradientExpression())
            print("✅ 使用速度渐变绘制轨迹线")
        } else {
            // 使用默认单色
            lineLayer.lineColor = .constant(StyleColor(.systemBlue))
            print("⚠️ 使用默认蓝色绘制轨迹线")
        }

        lineLayer.lineWidth = .constant(8.0)
        lineLayer.lineCap = .constant(.round)
        lineLayer.lineJoin = .constant(.round)

        do {
            try mapView.mapboxMap.addPersistentLayer(lineLayer)
            print("✅ 轨迹线图层添加成功")
        } catch {
            print("❌ 添加轨迹线图层失败: \(error)")
        }
    }
    
    /// 绘制起终点标记
    private func drawStartEndMarkers(coordinates: [CLLocationCoordinate2D]) {
        guard let mapView = mapView, !coordinates.isEmpty else { return }
        
        // 起点标记
        let startPoint = coordinates.first!
        var startSource = GeoJSONSource(id: startPointSourceId)
        startSource.data = .geometry(Geometry(.point(Point(startPoint))))
        
        do {
            try mapView.mapboxMap.addSource(startSource)
            
            var startLayer = CircleLayer(id: startPointLayerId, source: startPointSourceId)
            startLayer.circleColor = .constant(StyleColor(UIColor(hex: "#00E676"))) // 绿色起点
            startLayer.circleRadius = .constant(6.0)
            startLayer.circleStrokeColor = .constant(StyleColor(.white))
            startLayer.circleStrokeWidth = .constant(2.0)
            
            try mapView.mapboxMap.addPersistentLayer(startLayer)
            print("✅ 起点标记添加成功")
        } catch {
            print("❌ 添加起点标记失败: \(error)")
        }
        
        // 终点标记
        if coordinates.count > 1 {
            let endPoint = coordinates.last!
            var endSource = GeoJSONSource(id: endPointSourceId)
            endSource.data = .geometry(Geometry(.point(Point(endPoint))))
            
            do {
                try mapView.mapboxMap.addSource(endSource)
                
                var endLayer = CircleLayer(id: endPointLayerId, source: endPointSourceId)
                endLayer.circleColor = .constant(StyleColor(UIColor(hex: "#FF5252"))) // 红色终点
                endLayer.circleRadius = .constant(6.0)
                endLayer.circleStrokeColor = .constant(StyleColor(.white))
                endLayer.circleStrokeWidth = .constant(2.0)
                
                try mapView.mapboxMap.addPersistentLayer(endLayer)
                print("✅ 终点标记添加成功")
            } catch {
                print("❌ 添加终点标记失败: \(error)")
            }
        }
    }
    
    /// 设置全览相机视角
    private func setOverviewCamera(coordinates: [CLLocationCoordinate2D]) {
        guard let mapView = mapView, !coordinates.isEmpty else { return }
        
        // 计算边界框
            let minLat = coordinates.map { $0.latitude }.min() ?? 0
            let maxLat = coordinates.map { $0.latitude }.max() ?? 0
            let minLng = coordinates.map { $0.longitude }.min() ?? 0
            let maxLng = coordinates.map { $0.longitude }.max() ?? 0
        
        // 添加边距
        let latPadding = (maxLat - minLat) * 0.3
        let lngPadding = (maxLng - minLng) * 0.3

            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )

        // 计算合适的缩放级别
        let latDiff = maxLat - minLat + latPadding * 2
        let lngDiff = maxLng - minLng + lngPadding * 2
        let maxDiff = max(latDiff, lngDiff)
        
        let zoom: Double
        switch maxDiff {
        case ..<0.005: zoom = 17.0
        case ..<0.01:  zoom = 16.0
        case ..<0.02:  zoom = 14.0
        case ..<0.05:  zoom = 12.0
        case ..<0.1:   zoom = 10.0
        default:       zoom = 8.0
        }
        
        print("🔍 设置全览视角:")
            print("  - 中心点: lat=\(center.latitude), lng=\(center.longitude)")
        print("  - 边界差值: lat=\(latDiff), lng=\(lngDiff)")
        print("  - 计算缩放级别: \(zoom)")
        
        let cameraOptions = CameraOptions(center: center, zoom: zoom)
        mapView.camera.ease(to: cameraOptions, duration: 1.0)
        
        isOverviewMode = true
    }
    
    /// 设置全览按钮
    private func setupOverviewButton() {
        guard let mapView = mapView else { return }
        
        // 创建全览按钮
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "viewfinder"), for: .normal)
        button.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        button.tintColor = .systemBlue
        button.layer.cornerRadius = 8
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.1
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加点击事件
        button.addTarget(self, action: #selector(overviewButtonTapped), for: .touchUpInside)
        
        mapView.addSubview(button)
        overviewButton = button
        
        // 设置约束
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
            button.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -16),
            button.topAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
        
        // 设置初始状态
        updateOverviewButtonState()
        print("✅ 全览按钮设置完成")
    }
    
    @objc private func overviewButtonTapped() {
        print("🔄 全览按钮被点击，当前模式: \(isOverviewMode ? "全览" : "跟随")")
        
        if isOverviewMode {
            switchToFollowingMode()
        } else {
            switchToOverviewMode()
        }
    }
    
    /// 切换到全览模式
    private func switchToOverviewMode() {
        guard !historyLocations.isEmpty else {
            print("⚠️ 轨迹数据为空，无法切换到全览模式")
            return
        }
        
        let coordinates = historyLocations.map { $0.coordinate }
        setOverviewCamera(coordinates: coordinates)
        isOverviewMode = true
        updateOverviewButtonState()
        print("🔄 已切换到全览模式")
    }
    
    /// 切换到跟随模式
    private func switchToFollowingMode() {
        guard let currentLocation = replayLocationProvider.getLastObservedLocation() else {
            print("⚠️ 当前位置为空，无法切换到跟随模式")
            return
        }
        
        let coordinate = CLLocationCoordinate2D(
            latitude: currentLocation.coordinate.latitude,
            longitude: currentLocation.coordinate.longitude
        )

            let cameraOptions = CameraOptions(
            center: coordinate,
            zoom: 16.0,
            bearing: currentLocation.bearing
        )
        
        mapView?.camera.ease(to: cameraOptions, duration: 1.0)
        isOverviewMode = false
        updateOverviewButtonState()
        print("🔄 已切换到跟随模式")
    }
    
    /// 更新全览按钮的状态显示
    private func updateOverviewButtonState() {
        guard let button = overviewButton else { return }
        
        if isOverviewMode {
            // 全览模式：按钮高亮显示
            button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
            button.tintColor = .white
        } else {
            // 跟随模式：按钮普通显示
            button.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
            button.tintColor = .systemBlue
        }
    }

    private func setupTrajectoryLayers() {
        // 不需要设置自定义位置图层
        // HistoryReplayController 会自动提供位置流给内置的 puck
        // 我们已经设置了 puckType 为带箭头的配置
    }

    private func updateCurrentLocation(_ location: CLLocation) {
        // 更新当前回放位置
        // ReplayLocationProvider 会将位置流提供给内置的 puck
        // 内置的 puck（箭头）会自动显示和更新

        // 只在跟随模式下更新相机
        if !isOverviewMode {
        let cameraOptions = CameraOptions(
            center: location.coordinate,
                zoom: 16.0,
            bearing: location.course >= 0 ? location.course : nil
        )
        mapView?.camera.ease(to: cameraOptions, duration: 0.3)
        }
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

        // 使用自定义 LocationProvider 将历史位置流提供给内置 puck
        mapView.location.override(locationProvider: replayLocationProvider)
    }

    // 移除导航界面相关方法，因为我们只做轨迹回放，不启动导航界面
    // private func presentNavigationController(with navigationRoutes: NavigationRoutes) - 已移除
    // private func presentAndRemoveNavigationMapView() - 已移除

    private func cleanupReplay() {
        // 停止位置订阅
        locationSubscription?.cancel()
        locationSubscription = nil

        // 清理所有地图事件订阅
        cancelables.removeAll()

        // 停止历史回放
        historyReplayController.pause()

        // 清理历史数据
        historyLocations.removeAll()
        locationSpeeds.removeAll()

        // 清理地图图层和数据源
        if let mapView = mapView {
            cleanupExistingLayers()
        }
        
        // 清理全览按钮
        overviewButton?.removeFromSuperview()
        overviewButton = nil

        // 清理地图视图
        mapView?.removeFromSuperview()
        mapView = nil
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
        // 可以选择在地图上显示路线轮廓，但不启动导航
        // 这里我们选择仅记录，让位置流自然显示轨迹

        // 不调用任何导航相关方法：
        // - 不调用 presentNavigationController
        // - 不调用 startActiveGuidance
        // - 不使用 NavigationMapView 的导航功能
    }

    func historyReplayControllerDidFinishReplay(_: HistoryReplayController) {
        // 历史轨迹回放结束，直接关闭页面
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
        cleanupReplay()

        if let navigationController = self.navigationController {
            navigationController.dismiss(animated: true, completion: nil)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
}