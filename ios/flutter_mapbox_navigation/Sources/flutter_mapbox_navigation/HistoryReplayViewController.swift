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

    /// 获取颜色的十六进制字符串表示（用于Mapbox表达式）
    var hexString: String {
        guard let components = self.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
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
/// 实现位置插值，在两个位置点之间生成多个中间点，确保高倍速下转弯平滑
class ReplayLocationProvider: LocationProvider {
    private var observers = NSHashTable<AnyObject>.weakObjects()
    private var lastLocation: MapboxCommon.Location?
    private var cancellable: AnyCancellable?
    private var previousCLLocation: CLLocation?  // 上一个原始位置
    private var interpolationTimer: Timer?
    private var interpolationQueue: [MapboxCommon.Location] = []  // 插值位置队列
    private let maxQueueSize = 100  // 队列最大长度，防止内存无限增长

    func startReplay(with publisher: AnyPublisher<CLLocation, Never>) {
        cancellable = publisher.sink { [weak self] newLocation in
            guard let self = self else { return }
            
            // 如果有上一个位置，则在两点之间插值
            if let previousLocation = self.previousCLLocation {
                self.interpolateLocations(from: previousLocation, to: newLocation)
            } else {
                // 第一个位置，直接发送
                self.publishLocation(newLocation)
            }
            
            self.previousCLLocation = newLocation
        }
        
        // 启动定时器，以固定频率发送插值位置
        startInterpolationTimer()
    }
    
    /// 在两个位置之间插值生成多个中间点
    private func interpolateLocations(from start: CLLocation, to end: CLLocation) {
        // 如果队列已满，跳过插值（防止内存无限增长）
        guard interpolationQueue.count < maxQueueSize else {
            print("⚠️ 插值队列已满，跳过插值")
            return
        }
        
        let steps = 5  // 在两点之间生成5个中间点
        
        for i in 0...steps {
            let ratio = Double(i) / Double(steps)
            
            // 位置插值（线性插值）
            let lat = start.coordinate.latitude + (end.coordinate.latitude - start.coordinate.latitude) * ratio
            let lon = start.coordinate.longitude + (end.coordinate.longitude - start.coordinate.longitude) * ratio
            
            // 方向插值（考虑角度跨越0/360度）
            var bearing: Double?
            if start.course >= 0 && end.course >= 0 {
                var delta = end.course - start.course
                if delta > 180 {
                    delta -= 360
                } else if delta < -180 {
                    delta += 360
                }
                bearing = start.course + delta * ratio
                if bearing! < 0 {
                    bearing! += 360
                } else if bearing! >= 360 {
                    bearing! -= 360
                }
            } else if end.course >= 0 {
                bearing = end.course
            }
            
            // 速度插值
            let speed = start.speed >= 0 && end.speed >= 0 
                ? start.speed + (end.speed - start.speed) * ratio
                : (end.speed >= 0 ? end.speed : nil)
            
            // 时间戳插值
            let timestamp = start.timestamp.addingTimeInterval(
                end.timestamp.timeIntervalSince(start.timestamp) * ratio
            )
            
            let location = MapboxCommon.Location(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                timestamp: timestamp,
                altitude: start.altitude + (end.altitude - start.altitude) * ratio,
                horizontalAccuracy: end.horizontalAccuracy,
                verticalAccuracy: end.verticalAccuracy,
                speed: speed,
                bearing: bearing
            )
            
            interpolationQueue.append(location)
        }
    }
    
    /// 启动定时器，以固定频率发送插值位置
    private func startInterpolationTimer() {
        interpolationTimer?.invalidate()
        // 60 FPS = 16.67ms per frame
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.sendNextInterpolatedLocation()
        }
    }
    
    /// 发送队列中的下一个插值位置
    private func sendNextInterpolatedLocation() {
        guard !interpolationQueue.isEmpty else { return }
        
        // 如果队列过长，一次发送多个以快速消费（性能优化）
        let batchSize = min(interpolationQueue.count > 50 ? 2 : 1, interpolationQueue.count)
        
        for _ in 0..<batchSize {
            guard !interpolationQueue.isEmpty else { break }
            let location = interpolationQueue.removeFirst()
            
            lastLocation = location
            for observer in observers.allObjects {
                (observer as? LocationObserver)?.onLocationUpdateReceived(for: [location])
            }
        }
    }
    
    /// 直接发送位置（用于第一个位置）
    private func publishLocation(_ clLocation: CLLocation) {
        let location = MapboxCommon.Location(
            coordinate: clLocation.coordinate,
            timestamp: clLocation.timestamp,
            altitude: clLocation.altitude,
            horizontalAccuracy: clLocation.horizontalAccuracy,
            verticalAccuracy: clLocation.verticalAccuracy,
            speed: clLocation.speed >= 0 ? clLocation.speed : nil,
            bearing: clLocation.course >= 0 ? clLocation.course : nil
        )
        interpolationQueue.append(location)
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
        interpolationTimer?.invalidate()
        interpolationQueue.removeAll()
    }
}

/// 历史轨迹回放视图控制器
/// 按照官方最新建议：使用自定义 LocationProvider 将历史位置流提供给内置 puck
/// 将位置更新到自定义 MapView，不启动导航相关组件
final class HistoryReplayViewController: UIViewController {

    // MARK: - Properties (following official example pattern)

    private let historyFilePath: String
    private let mapStyle: String?
    private let lightPreset: String?

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

        // 文件路径智能解析
        if !FileManager.default.fileExists(atPath: fileURL.path) {
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
    private let historyRouteOutlineLayerId = "history-route-outline-layer"  // 轨迹轮廓层
    private let startPointSourceId = "start-point-source"
    private let endPointSourceId = "end-point-source"
    private let startPointLayerId = "start-point-layer"
    private let endPointLayerId = "end-point-layer"

    // 简化的速度数据存储（仅用于渐变显示）
    private var locationSpeeds: [Double] = []
    private var cumulativeDistances: [Double] = []
    
    // 全览/跟随模式
    private var isOverviewMode = false
    private var overviewButton: UIButton?
    
    // 回放控制
    private var recommendedSpeed: Double = 8.0  // 降低回放速度，避免转弯时图标飞跃


    // MARK: - Initialization

    init(historyFilePath: String, mapStyle: String? = nil, lightPreset: String? = nil) {
        self.historyFilePath = historyFilePath
        self.mapStyle = mapStyle
        self.lightPreset = lightPreset
        super.init(nibName: nil, bundle: nil)
        
        print("🎬🎬🎬 历史回放: 初始化")
        print("🎬 mapStyle = \(mapStyle ?? "nil")")
        print("🎬 lightPreset = \(lightPreset ?? "nil")")
        print("🎬 historyFilePath = \(historyFilePath)")
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
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    // MARK: - Private Methods

    private func loadMapViewIfNeeded() {
        if mapView == nil {
            // 创建地图视图
            mapView = MapView(frame: view.bounds)
            mapView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            // 按照官方文档设置样式
            if let mapStyle = mapStyle, let preset = lightPreset {
                applyMapStyleWithPreset(mapStyle: mapStyle, lightPreset: preset)
            } else if let mapStyle = mapStyle {
                // 只有样式没有 preset
                let styleURI = getStyleURI(for: mapStyle)
                mapView?.mapboxMap.style.uri = styleURI
                print("🎬 历史回放: 设置样式 URI: \(styleURI.rawValue)")
            } else {
                // 使用默认样式
                mapView?.mapboxMap.mapStyle = .standard()
                print("🎬 历史回放: 使用默认样式")
            }

            // 启用位置显示 - 使用带箭头的默认配置
            let configuration = Puck2DConfiguration.makeDefault(showBearing: true)
            mapView.location.options.puckType = .puck2D(configuration)
            // 设置箭头方向跟随 course（行进方向）而不是 heading（设备朝向）
            mapView.location.options.puckBearing = .course
            // 关键：在 v11 中需要手动启用 puck 方向旋转（默认为 false）
            mapView.location.options.puckBearingEnabled = true

            // 设置样式加载完成后的回调
            mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
                guard let self = self else { return }
                
                print("🎬 历史回放: 样式已加载完成，开始绘制轨迹")
                
                self.setupTrajectoryLayers()
                
                // 如果历史数据已准备好，立即绘制路线
                if !self.historyLocations.isEmpty {
                    self.drawCompleteHistoryRoute()
                }
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
                historyReplayController.speedMultiplier = recommendedSpeed

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

        do {
            // 使用 HistoryReader 解析历史文件
            guard let reader = HistoryReader(fileUrl: finalFileURL, readOptions: nil) else {
                print("❌ 无法创建 HistoryReader: \(finalFileURL.path)")
                return
            }

            // 预解析所有历史事件，类似 Android 端的 preDrawCompleteRoute
            await preParseCompleteRoute(reader: reader)
            
            // 设置固定回放速度
            recommendedSpeed = 8.0  // 使用适中的回放速度，确保转弯平滑

            // 在主线程创建按钮，但不立即绘制路线
            await MainActor.run {
                setupOverviewButton()
                // 如果地图已加载完成则立即绘制，否则等待地图加载回调
                if mapView?.mapboxMap.isStyleLoaded == true {
                    drawCompleteHistoryRoute()
                }
            }

        } catch {
            print("❌ 解析历史文件失败: \(error)")
        }
    }

    /// 预解析所有历史事件中的位置数据，类似 Android 端的 preDrawCompleteRoute
    private func preParseCompleteRoute(reader: HistoryReader) async {
        do {
            let history = try await reader.parse()
            let allEvents = history.events
            
            var allLocations: [CLLocation] = []
            
            // 遍历所有事件，提取位置信息
            for event in allEvents {
                if let locationEvent = event as? LocationUpdateHistoryEvent {
                    let location = CLLocation(
                        coordinate: locationEvent.location.coordinate,
                        altitude: locationEvent.location.altitude ?? 0,
                        horizontalAccuracy: locationEvent.location.horizontalAccuracy ?? 0,
                        verticalAccuracy: locationEvent.location.verticalAccuracy ?? 0,
                        course: locationEvent.location.course ?? -1,
                        speed: locationEvent.location.speed ?? -1,
                        timestamp: locationEvent.location.timestamp
                    )
                    
                    // 过滤过近的点，类似 Android 端的逻辑
                    if allLocations.isEmpty {
                        allLocations.append(location)
                    } else {
                        let lastLocation = allLocations.last!
                        let distance = location.distance(from: lastLocation)
                        if distance > 0.5 { // 过滤0.5米内的点
                            allLocations.append(location)
                        }
                    }
                }
            }
            
            historyLocations = allLocations
            
            // 计算基础速度数据
            if !historyLocations.isEmpty {
                calculateLocationSpeeds()
            }
            
        } catch {
            print("❌ 预解析历史事件失败: \(error)")
            // 回退到原始方法
            if let history = try? await reader.parse() {
                historyLocations = history.rawLocations
                calculateLocationSpeeds()
            } else {
                print("❌ 无法解析历史位置数据")
            }
        }
    }

    /// 计算轨迹点的基础速度数据和累计距离（用于渐变显示）
    private func calculateLocationSpeeds() {
        guard !historyLocations.isEmpty else { return }

        locationSpeeds.removeAll()
        cumulativeDistances.removeAll()

        var cumulativeDistance: Double = 0.0

        for (index, location) in historyLocations.enumerated() {
            // 计算累计距离
            cumulativeDistances.append(cumulativeDistance)
            
            // 计算速度（从 m/s 转换为 km/h）
            let speedKmh = location.speed >= 0 ? location.speed * 3.6 : 0.0
            locationSpeeds.append(speedKmh)
            
            // 为下一个点计算距离增量
            if index < historyLocations.count - 1 {
                let nextLocation = historyLocations[index + 1]
                cumulativeDistance += location.distance(from: nextLocation)
            }
        }

        // 计算完成
    }
    
    

    /// 构建基于速度的渐变表达式
    private func buildSpeedGradientExpression() -> Exp {
        guard !locationSpeeds.isEmpty, !cumulativeDistances.isEmpty else {
            // 如果没有有效数据，返回默认颜色
            return Exp(.literal, UIColor.systemBlue.hexString)
        }

        var stops: [(Double, UIColor)] = []

        // 总距离
        let totalDistance = cumulativeDistances.last ?? 1.0
        guard totalDistance > 0 else {
            return Exp(.literal, UIColor.systemBlue.hexString)
        }

        // 起点
        stops.append((0.0, UIColor.colorForSpeed(locationSpeeds.first ?? 0.0)))

        // 中间节点（增加采样密度，使渐变更平滑、颜色更鲜亮）
        // 根据轨迹长度动态调整采样数量：短轨迹用所有点，长轨迹采样至少50个点
        let maxSamples = 50  // 最大采样点数（从20增加到50）
        let step = locationSpeeds.count <= maxSamples ? 1 : max(1, locationSpeeds.count / maxSamples)
        
        for i in stride(from: step, to: locationSpeeds.count, by: step) {
            let progress = cumulativeDistances[i] / totalDistance
            let color = UIColor.colorForSpeed(locationSpeeds[i])

            // 确保进度值递增且在[0,1]范围内
            let clampedProgress = max(0.0, min(1.0, progress))
            if clampedProgress > stops.last!.0 {
                stops.append((clampedProgress, color))
            }
        }

        // 终点
        if stops.last?.0 ?? 0 < 1.0 {
            stops.append((1.0, UIColor.colorForSpeed(locationSpeeds.last ?? 0.0)))
        }

        // 根据文档中的实现，严格按照 SPEED_GRADIENT_IMPLEMENTATION.md 指导
        guard stops.count >= 2 else {
            // 至少需要两个停止点才能创建插值
            let fallbackColor = stops.first?.1 ?? UIColor.systemBlue
            return Exp(.literal, fallbackColor.hexString)
        }
        
        // 构建 Mapbox表达式 - 使用字典格式停止点
        var stopsDict: [Double: UIColor] = [:]
        for (progress, color) in stops {
            stopsDict[progress] = color
        }
        
        return Exp(.interpolate) {
            Exp(.linear)
            Exp(.lineProgress)
            stopsDict
        }
    }

    /// 一次性绘制完整历史路线，类似 Android 端的 drawCompleteRoute
    private func drawCompleteHistoryRoute() {
        guard !historyLocations.isEmpty else {
            return
        }

        guard let mapView = mapView else {
            return
        }

        // 提取坐标数组
        let coordinates = historyLocations.map { $0.coordinate }

        // 检查地图是否已加载完成
        guard mapView.mapboxMap.isStyleLoaded else {
            return
        }

        // 清理现有图层和数据源
        cleanupExistingLayers()

        // 1. 绘制轨迹线
        drawTrajectoryLine(coordinates: coordinates)
        
        // 2. 绘制起终点标记
        drawStartEndMarkers(coordinates: coordinates)

        // 3. 设置地图视角以显示完整路线
        setOverviewCamera(coordinates: coordinates)
    }
    
    /// 清理现有的图层和数据源
    private func cleanupExistingLayers() {
        guard let mapView = mapView else { return }
        
        let layersToRemove = [historyRouteLayerId, historyRouteOutlineLayerId, startPointLayerId, endPointLayerId]
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
        guard let mapView = mapView else { 
            return 
        }
        
        // 验证坐标数据
        guard !coordinates.isEmpty else {
            return
        }
        
        // 需要至少两个点才能绘制线
        guard coordinates.count >= 2 else {
            return
        }
        
        // 创建 LineString
        let lineString = LineString(coordinates)

        // 创建并添加数据源
        var routeLineSource = GeoJSONSource(id: historyRouteSourceId)
        routeLineSource.data = .geometry(Geometry(lineString))
        routeLineSource.lineMetrics = true  // 启用线条度量，用于渐变

        do {
            try mapView.mapboxMap.addSource(routeLineSource)
        } catch {
            print("❌ 添加轨迹线数据源失败: \(error)")
            return
        }

        // 1. 先添加轨迹外层描边（增强对比度）
        var outlineLayer = LineLayer(id: historyRouteOutlineLayerId, source: historyRouteSourceId)
        outlineLayer.lineColor = .constant(StyleColor(UIColor.white))
        outlineLayer.lineWidth = .constant(12.0)  // 增加描边宽度
        outlineLayer.lineCap = .constant(.round)
        outlineLayer.lineJoin = .constant(.round)
        outlineLayer.lineOpacity = .constant(0.6)  // 提高不透明度
        
        do {
            try mapView.mapboxMap.addLayer(outlineLayer)
        } catch {
            print("⚠️ 轨迹描边层添加失败: \(error)")
        }

        // 2. 再添加主轨迹线条图层（带渐变颜色）
        var lineLayer = LineLayer(id: historyRouteLayerId, source: historyRouteSourceId)

        // 使用速度渐变功能
        if !locationSpeeds.isEmpty {
            let gradientExpression = buildSpeedGradientExpression()
            lineLayer.lineGradient = .expression(gradientExpression)
        } else {
            lineLayer.lineColor = .constant(StyleColor(UIColor.systemBlue))
        }

        lineLayer.lineWidth = .constant(8.0)
        lineLayer.lineCap = .constant(.round)
        lineLayer.lineJoin = .constant(.round)
        
        // 使用完全不透明，确保颜色不受 light preset 影响
        lineLayer.lineOpacity = .constant(1.0)
        
        // 添加轻微发光效果，增强在暗色地图上的可见性
        lineLayer.lineBlur = .constant(0.5)
        
        // 🔑 关键：设置自发光强度，让轨迹完全不受地图光照影响
        lineLayer.lineEmissiveStrength = .constant(1.0)

        do {
            // 优先使用 addLayer
            try mapView.mapboxMap.addLayer(lineLayer)
        } catch {
            // 回退使用 addPersistentLayer
            do {
                try mapView.mapboxMap.addPersistentLayer(lineLayer)
            } catch {
                print("❌ 轨迹线图层添加失败: \(error)")
            }
        }
    }
    
    /// 绘制起终点标记
    private func drawStartEndMarkers(coordinates: [CLLocationCoordinate2D]) {
        guard let mapView = mapView, !coordinates.isEmpty else { return }
        
        // 起点标记
        let startPoint = coordinates.first!
        var startSource = GeoJSONSource(id: startPointSourceId)
        startSource.data = .geometry(Geometry.point(Point(startPoint)))
        
        do {
            try mapView.mapboxMap.addSource(startSource)
            
            var startLayer = CircleLayer(id: startPointLayerId, source: startPointSourceId)
            startLayer.circleColor = .constant(StyleColor(UIColor(hex: "#00E676"))) // 绿色起点
            startLayer.circleRadius = .constant(6.0)
            startLayer.circleStrokeColor = .constant(StyleColor(.white))
            startLayer.circleStrokeWidth = .constant(2.0)
            
            try mapView.mapboxMap.addPersistentLayer(startLayer)
        } catch {
            print("❌ 添加起点标记失败: \(error)")
        }
        
        // 终点标记
        if coordinates.count > 1 {
            let endPoint = coordinates.last!
            var endSource = GeoJSONSource(id: endPointSourceId)
            endSource.data = .geometry(Geometry.point(Point(endPoint)))
            
            do {
                try mapView.mapboxMap.addSource(endSource)
                
                var endLayer = CircleLayer(id: endPointLayerId, source: endPointSourceId)
                endLayer.circleColor = .constant(StyleColor(UIColor(hex: "#FF5252"))) // 红色终点
                endLayer.circleRadius = .constant(6.0)
                endLayer.circleStrokeColor = .constant(StyleColor(.white))
                endLayer.circleStrokeWidth = .constant(2.0)
                
                try mapView.mapboxMap.addPersistentLayer(endLayer)
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
    }
    
    @objc private func overviewButtonTapped() {
        
        if isOverviewMode {
            switchToFollowingMode()
        } else {
            switchToOverviewMode()
        }
    }
    
    /// 切换到全览模式
    private func switchToOverviewMode() {
        guard !historyLocations.isEmpty else {
            return
        }
        
        let coordinates = historyLocations.map { $0.coordinate }
        setOverviewCamera(coordinates: coordinates)
        isOverviewMode = true
        updateOverviewButtonState()
    }
    
    /// 切换到跟随模式
    private func switchToFollowingMode() {
        guard let currentLocation = replayLocationProvider.getLastObservedLocation() else {
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

        // 设置导航栏样式 - 确保状态栏与导航栏一体化
        guard let navigationController = navigationController else { return }
        
        navigationController.navigationBar.isHidden = false
        
        // 设置导航栏外观，让状态栏区域与导航栏一体
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        // 移除导航栏底部的分隔线
        appearance.shadowColor = .clear
        
        // 应用外观配置
        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.compactAppearance = appearance
        
        // 设置按钮颜色
        navigationController.navigationBar.tintColor = UIColor.systemBlue
        
        // 确保状态栏样式正确
        navigationController.navigationBar.barStyle = .default
        
        // 让导航栏延伸到状态栏区域
        navigationController.navigationBar.prefersLargeTitles = false
        extendedLayoutIncludesOpaqueBars = true
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
        cumulativeDistances.removeAll()

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
    
    // MARK: - Style Management
    
    /// 按照官方文档设置样式和 light preset
    private func applyMapStyleWithPreset(mapStyle: String, lightPreset: String) {
        guard let mapView = mapView else { return }
        
        print("🎬🎬🎬 applyMapStyleWithPreset 被调用")
        print("🎬 mapStyle = \(mapStyle)")
        print("🎬 lightPreset = \(lightPreset)")
        
        // 对于 standard 系列样式，使用官方推荐的 .standard(theme:lightPreset:) 方式
        if mapStyle == "standard" || mapStyle == "faded" || mapStyle == "monochrome" {
            // 转换 lightPreset 字符串为枚举
            switch lightPreset {
            case "dawn":
                if mapStyle == "faded" {
                    mapView.mapboxMap.mapStyle = .standard(theme: .faded, lightPreset: .dawn)
                    print("✅ 已设置: .standard(theme: .faded, lightPreset: .dawn)")
                } else if mapStyle == "monochrome" {
                    mapView.mapboxMap.mapStyle = .standard(theme: .monochrome, lightPreset: .dawn)
                    print("✅ 已设置: .standard(theme: .monochrome, lightPreset: .dawn)")
                } else {
                    mapView.mapboxMap.mapStyle = .standard(theme: .default, lightPreset: .dawn)
                    print("✅ 已设置: .standard(theme: .default, lightPreset: .dawn)")
                }
            case "day":
                if mapStyle == "faded" {
                    mapView.mapboxMap.mapStyle = .standard(theme: .faded, lightPreset: .day)
                    print("✅ 已设置: .standard(theme: .faded, lightPreset: .day)")
                } else if mapStyle == "monochrome" {
                    mapView.mapboxMap.mapStyle = .standard(theme: .monochrome, lightPreset: .day)
                    print("✅ 已设置: .standard(theme: .monochrome, lightPreset: .day)")
                } else {
                    mapView.mapboxMap.mapStyle = .standard(theme: .default, lightPreset: .day)
                    print("✅ 已设置: .standard(theme: .default, lightPreset: .day)")
                }
            case "dusk":
                if mapStyle == "faded" {
                    mapView.mapboxMap.mapStyle = .standard(theme: .faded, lightPreset: .dusk)
                    print("✅ 已设置: .standard(theme: .faded, lightPreset: .dusk)")
                } else if mapStyle == "monochrome" {
                    mapView.mapboxMap.mapStyle = .standard(theme: .monochrome, lightPreset: .dusk)
                    print("✅ 已设置: .standard(theme: .monochrome, lightPreset: .dusk)")
                } else {
                    mapView.mapboxMap.mapStyle = .standard(theme: .default, lightPreset: .dusk)
                    print("✅ 已设置: .standard(theme: .default, lightPreset: .dusk)")
                }
            case "night":
                print("🎬🎬🎬 lightPreset 匹配到 'night'")
                if mapStyle == "faded" {
                    print("🎬 设置: .standard(theme: .faded, lightPreset: .night)")
                    mapView.mapboxMap.mapStyle = .standard(theme: .faded, lightPreset: .night)
                    print("✅✅✅ 已成功设置: .standard(theme: .faded, lightPreset: .night)")
                } else if mapStyle == "monochrome" {
                    print("🎬 设置: .standard(theme: .monochrome, lightPreset: .night)")
                    mapView.mapboxMap.mapStyle = .standard(theme: .monochrome, lightPreset: .night)
                    print("✅✅✅ 已成功设置: .standard(theme: .monochrome, lightPreset: .night)")
                } else {
                    print("🎬 设置: .standard(theme: .default, lightPreset: .night)")
                    mapView.mapboxMap.mapStyle = .standard(theme: .default, lightPreset: .night)
                    print("✅✅✅ 已成功设置: .standard(theme: .default, lightPreset: .night)")
                }
            default:
                // 默认使用 day
                if mapStyle == "faded" {
                    mapView.mapboxMap.mapStyle = .standard(theme: .faded, lightPreset: .day)
                } else if mapStyle == "monochrome" {
                    mapView.mapboxMap.mapStyle = .standard(theme: .monochrome, lightPreset: .day)
                } else {
                    mapView.mapboxMap.mapStyle = .standard(theme: .default, lightPreset: .day)
                }
                print("⚠️ 未知 lightPreset '\(lightPreset)'，使用默认 .day")
            }
        } else if mapStyle == "standardSatellite" {
            // standardSatellite 也支持 lightPreset
            switch lightPreset {
            case "dawn":
                mapView.mapboxMap.mapStyle = .standardSatellite(lightPreset: .dawn)
            case "day":
                mapView.mapboxMap.mapStyle = .standardSatellite(lightPreset: .day)
            case "dusk":
                mapView.mapboxMap.mapStyle = .standardSatellite(lightPreset: .dusk)
            case "night":
                mapView.mapboxMap.mapStyle = .standardSatellite(lightPreset: .night)
            default:
                mapView.mapboxMap.mapStyle = .standardSatellite(lightPreset: .day)
            }
            print("✅ 已设置: .standardSatellite(lightPreset: \(lightPreset))")
        } else {
            // 其他样式不支持 theme 和 lightPreset
            let styleURI = getStyleURI(for: mapStyle)
            mapView.mapboxMap.style.uri = styleURI
            print("✅ 已设置: StyleURI \(styleURI.rawValue)")
        }
    }
    
    /// 获取 StyleURI
    private func getStyleURI(for mapStyle: String) -> MapboxMaps.StyleURI {
        switch mapStyle {
        case "standard", "faded", "monochrome":
            return .standard
        case "standardSatellite":
            return .standardSatellite
        case "light":
            return .light
        case "dark":
            return .dark
        case "outdoors":
            return .outdoors
        default:
            return .standard
        }
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
        // 不启动导航相关组件，仅显示轨迹
    }

    func historyReplayControllerDidFinishReplay(_: HistoryReplayController) {
        // 历史轨迹回放结束，停留在最后位置
        print("✅ 历史轨迹回放结束")
        
        // 不关闭页面，用户可以继续查看轨迹
        // 可以选择切换到全览模式以显示完整轨迹
        if !isOverviewMode {
            switchToOverviewMode()
        }
    }
}

// MARK: - NavigationViewControllerDelegate (following official example)

extension HistoryReplayViewController: NavigationViewControllerDelegate {
    func navigationViewControllerDidDismiss(
        _ navigationViewController: NavigationViewController,
        byCanceling canceled: Bool
    ) {
        // 协议完整性方法
        cleanupReplay()

        if let navigationController = self.navigationController {
            navigationController.dismiss(animated: true, completion: nil)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
}