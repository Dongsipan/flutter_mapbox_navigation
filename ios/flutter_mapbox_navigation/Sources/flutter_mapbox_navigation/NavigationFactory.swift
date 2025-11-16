import Flutter
import UIKit
import MapboxMaps
import MapboxNavigationCore
import MapboxNavigationUIKit
import MapboxDirections
import CoreLocation
import Foundation

// Type alias to avoid conflicts with Mapbox's Location type
typealias FlutterLocation = flutter_mapbox_navigation.Location

// MARK: - History Directory Helper (following official example pattern)
func defaultHistoryDirectoryURL() -> URL {
    let basePath: String = if let applicationSupportPath =
        NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first
    {
        applicationSupportPath
    } else {
        NSTemporaryDirectory()
    }
    let historyDirectoryURL = URL(fileURLWithPath: basePath, isDirectory: true)
        .appendingPathComponent("com.mapbox.FlutterMapboxNavigation")
        .appendingPathComponent("NavigationHistory")

    if !FileManager.default.fileExists(atPath: historyDirectoryURL.path) {
        try? FileManager.default.createDirectory(
            at: historyDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    return historyDirectoryURL
}

public class NavigationFactory : NSObject, FlutterStreamHandler
{
    var _navigationViewController: NavigationViewController? = nil
    var _eventSink: FlutterEventSink? = nil
    
    let ALLOW_ROUTE_SELECTION = false
    let IsMultipleUniqueRoutes = false
    var isEmbeddedNavigation = false
    
    var _distanceRemaining: Double?
    var _durationRemaining: Double?
    var _navigationMode: String?
    var _navigationRoutes: NavigationRoutes?
    var _wayPointOrder: [Int: Waypoint] = [:]
    var _wayPoints: [Waypoint] = []
    var _lastKnownLocation: CLLocation?
    
    var _options: NavigationRouteOptions?
    var _simulateRoute = false
    var _allowsUTurnAtWayPoints: Bool?
    var _isOptimized = false
    var _language = "en"
    var _voiceUnits = "imperial"
    var _mapStyleUrlDay: String?
    var _mapStyleUrlNight: String?
    var _mapStyle: String?  // MapStyle 枚举值
    var _lightPreset: String?  // LightPreset 枚举值
    var _enableDynamicLightPreset: Bool = false  // 是否启用动态 light preset 切换
    var _currentLightPresetIndex: Int = 1  // 当前 light preset 索引（0=dawn, 1=day, 2=dusk, 3=night）
    var _lightPresetTimer: Timer?  // 用于动态切换的定时器
    var _zoom: Double = 13.0
    var _tilt: Double = 0.0
    var _bearing: Double = 0.0
    var _animateBuildRoute = true
    var _longPressDestinationEnabled = true
    var _alternatives = true
    var _shouldReRoute = true
    var _showReportFeedbackButton = true
    var _showEndOfRouteFeedback = true
    var _enableOnMapTapCallback = false
    var _enableHistoryRecording = false
    var _isHistoryRecording = false
    var _currentHistoryId: String?
    var _historyStartTime: Date?
    var _autoBuildRoute = true
    
    // Mapbox Navigation v3 components
    var mapboxNavigationProvider: MapboxNavigationProvider?
    var mapboxNavigation: MapboxNavigation?
    var historyManager: HistoryManager?  // Changed from private to internal for cover update access

    // History Replay components
    private var historyReplayController: HistoryReplayController?
    private var replayNavigationProvider: MapboxNavigationProvider?
    private var replayMapboxNavigation: MapboxNavigation?
    private var isHistoryReplaying: Bool = false
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // 自动加载存储的样式设置
        loadStoredStyleSettings()
    }
    
    /// 从 UserDefaults 加载存储的样式设置
    private func loadStoredStyleSettings() {
        let settings = StylePickerHandler.loadStoredStyleSettings()
        
        if let mapStyle = settings.mapStyle {
            _mapStyle = mapStyle
            print("✅ NavigationFactory: 已加载存储的地图样式: \(mapStyle)")
        }
        
        if let lightPreset = settings.lightPreset {
            _lightPreset = lightPreset
            print("✅ NavigationFactory: 已加载存储的 Light Preset: \(lightPreset)")
        }
        
        _enableDynamicLightPreset = settings.enableDynamic
        if settings.enableDynamic {
            print("✅ NavigationFactory: 已启用动态 Light Preset 切换")
        }
    }
    
    func addWayPoints(arguments: NSDictionary?, result: @escaping FlutterResult)
    {
        
        guard let locations = getLocationsFromFlutterArgument(arguments: arguments) else { return }
        
        var nextIndex = 1
        for loc in locations
        {
            var wayPoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: loc.latitude!, longitude: loc.longitude!), name: loc.name)
            wayPoint.separatesLegs = !loc.isSilent
            if (_wayPoints.count >= nextIndex) {
                _wayPoints.insert(wayPoint, at: nextIndex)
            }
            else {
                _wayPoints.append(wayPoint)
            }
            nextIndex += 1
        }
        
        startNavigationWithWayPoints(wayPoints: _wayPoints, flutterResult: result, isUpdatingWaypoints: true)
    }
    
    func startFreeDrive(arguments: NSDictionary?, result: @escaping FlutterResult)
    {
        // 在启动新功能前，先结束可能存在的导航会话
        if _navigationViewController != nil {
            print("⚠️ 检测到活动导航会话，先结束它")
            endNavigation(result: nil)
        }
        
        let freeDriveViewController = FreeDriveViewController()
        let flutterViewController = UIApplication.shared.delegate?.window??.rootViewController as! FlutterViewController
        flutterViewController.present(freeDriveViewController, animated: true, completion: nil)
    }
    
    func startNavigation(arguments: NSDictionary?, result: @escaping FlutterResult)
    {
        _wayPoints.removeAll()
        _wayPointOrder.removeAll()
        
        guard let locations = getLocationsFromFlutterArgument(arguments: arguments) else { return }
        
        for loc in locations
        {
            var location = Waypoint(coordinate: CLLocationCoordinate2D(latitude: loc.latitude!, longitude: loc.longitude!), name: loc.name)
            
            location.separatesLegs = !loc.isSilent
            
            _wayPoints.append(location)
            _wayPointOrder[loc.order!] = location
        }
        
        parseFlutterArguments(arguments: arguments)
        
        _options?.includesAlternativeRoutes = _alternatives
        
        if(_wayPoints.count > 3 && arguments?["mode"] == nil)
        {
            _navigationMode = "driving"
        }
        
        if(_wayPoints.count > 0)
        {
            if(IsMultipleUniqueRoutes)
            {
                startNavigationWithWayPoints(wayPoints: [_wayPoints.remove(at: 0), _wayPoints.remove(at: 0)], flutterResult: result, isUpdatingWaypoints: false)
            }
            else
            {
                startNavigationWithWayPoints(wayPoints: _wayPoints, flutterResult: result, isUpdatingWaypoints: false)
            }
            
        }
    }
    
    
    func startNavigationWithWayPoints(wayPoints: [Waypoint], flutterResult: @escaping FlutterResult, isUpdatingWaypoints: Bool)
    {
        // End any existing navigation first
        if _navigationViewController != nil {
            endNavigation(result: nil)
        }
        
        // 重置历史记录状态
        print("Resetting history recording state before starting new navigation")
        print("Before reset - isHistoryRecording: \(_isHistoryRecording), currentHistoryId: \(_currentHistoryId ?? "nil")")
        _isHistoryRecording = false
        _currentHistoryId = nil
        _historyStartTime = nil
        print("After reset - isHistoryRecording: \(_isHistoryRecording), currentHistoryId: \(_currentHistoryId ?? "nil")")
        
        setNavigationOptions(wayPoints: wayPoints)
        
        // Initialize MapboxNavigationProvider with v3 API using singleton manager
        if mapboxNavigationProvider == nil {
            let locationSource: LocationSource = _simulateRoute ? .simulation(initialLocation: nil) : .live

            // Configure history recording directory using official pattern
            let historyDirectoryURL = defaultHistoryDirectoryURL()

            let historyRecordingConfig = _enableHistoryRecording ?
                HistoryRecordingConfig(historyDirectoryURL: historyDirectoryURL) : nil

            let coreConfig = CoreConfig(
                locationSource: locationSource,
                historyRecordingConfig: historyRecordingConfig
            )
            // 使用全局单例管理器获取 provider，避免重复实例化
            mapboxNavigationProvider = MapboxNavigationManager.shared.getOrCreateProvider(coreConfig: coreConfig)
        }
        
        Task { @MainActor in
            mapboxNavigation = mapboxNavigationProvider?.mapboxNavigation
            
            guard let mapboxNavigation = mapboxNavigation else {
                flutterResult("Failed to initialize Mapbox Navigation")
                return
            }
            
            // Calculate routes using v3 API
            let request = mapboxNavigation.routingProvider().calculateRoutes(options: _options!)
            
            switch await request.result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.sendEvent(eventType: MapBoxEventType.route_build_failed)
                    flutterResult("An error occurred while calculating the route: \(error.localizedDescription)")
                }
            case .success(let navigationRoutes):
                DispatchQueue.main.async {
                    self._navigationRoutes = navigationRoutes
                    
                    if (isUpdatingWaypoints) {
                        // Update existing navigation with new routes
                        if let navigationViewController = self._navigationViewController {
                            // In v3, we need to start active guidance with new routes
                            Task { @MainActor in
                                mapboxNavigation.tripSession().startActiveGuidance(with: navigationRoutes, startLegIndex: 0)
                            }
                            flutterResult("true")
                        } else {
                            flutterResult("failed to add stop - no active navigation")
                        }
                    } else {
                        // 检查是否需要显示路线选择界面
                        if self._autoBuildRoute {
                            // 直接开始导航（默认行为）
                            self.startNavigation(navigationRoutes: navigationRoutes, mapboxNavigation: mapboxNavigation)
                            flutterResult("Navigation started successfully")
                        } else {
                            // 显示路线选择界面
                            self.showRouteSelectionView(navigationRoutes: navigationRoutes, mapboxNavigation: mapboxNavigation)
                            flutterResult("Route selection view presented")
                        }
                    }
                }
            }
        }
    }
    
    func startNavigation(navigationRoutes: NavigationRoutes, mapboxNavigation: MapboxNavigation)
    {
        isEmbeddedNavigation = false
        if(self._navigationViewController == nil)
        {
            Task { @MainActor in
                // Create NavigationOptions for v3
                let navigationOptions = NavigationOptions(
                    mapboxNavigation: mapboxNavigation,
                    voiceController: mapboxNavigationProvider!.routeVoiceController,
                    eventsManager: mapboxNavigation.eventsManager()
                )
                
                // Create NavigationViewController with v3 API
                self._navigationViewController = NavigationViewController(
                    navigationRoutes: navigationRoutes,
                    navigationOptions: navigationOptions
                )
                
                self._navigationViewController!.modalPresentationStyle = .fullScreen
                self._navigationViewController!.delegate = self
                self._navigationViewController!.routeLineTracksTraversal = true
                
                // Configure feedback options
                // Note: v3 API may have different properties for feedback
                // self._navigationViewController!.showsReportFeedback = _showReportFeedbackButton
                // self._navigationViewController!.showsEndOfRouteFeedback = _showEndOfRouteFeedback
                
                let flutterViewController = UIApplication.shared.delegate?.window??.rootViewController as! FlutterViewController
                flutterViewController.present(self._navigationViewController!, animated: true, completion: {
                    // 导航界面显示后启动历史记录
                    self.startHistoryRecording()
                })
            }
        }
    }
    
    /// 显示路线选择界面
    /// 用户可以在地图上查看多条路线并选择其中一条
    func showRouteSelectionView(navigationRoutes: NavigationRoutes, mapboxNavigation: MapboxNavigation) {
        Task { @MainActor in
            // 创建路线选择视图控制器
            let routeSelectionVC = RouteSelectionViewController(
                navigationRoutes: navigationRoutes,
                mapboxNavigation: mapboxNavigation,
                mapboxNavigationProvider: mapboxNavigationProvider!
            )
            
            // 设置回调
            routeSelectionVC.onRouteSelected = { [weak self] selectedRoute in
                guard let self = self else { return }
                // 用户选择路线后，开始导航
                self.startNavigation(navigationRoutes: selectedRoute, mapboxNavigation: mapboxNavigation)
            }
            
            routeSelectionVC.modalPresentationStyle = .fullScreen
            
            let flutterViewController = UIApplication.shared.delegate?.window??.rootViewController as! FlutterViewController
            flutterViewController.present(routeSelectionVC, animated: true, completion: nil)
        }
    }
    
    func setNavigationOptions(wayPoints: [Waypoint]) {
        var mode: ProfileIdentifier = .automobileAvoidingTraffic
        
        if (_navigationMode == "cycling")
        {
            mode = .cycling
        }
        else if(_navigationMode == "driving")
        {
            mode = .automobile
        }
        else if(_navigationMode == "walking")
        {
            mode = .walking
        }
        let options = NavigationRouteOptions(waypoints: wayPoints, profileIdentifier: mode)
        
        if (_allowsUTurnAtWayPoints != nil)
        {
            options.allowsUTurnAtWaypoint = _allowsUTurnAtWayPoints!
        }
        
        options.distanceMeasurementSystem = _voiceUnits == "imperial" ? .imperial : .metric
        options.locale = Locale(identifier: _language)
        _options = options
    }
    
    func parseFlutterArguments(arguments: NSDictionary?) {
        _language = arguments?["language"] as? String ?? _language
        _voiceUnits = arguments?["units"] as? String ?? _voiceUnits
        _simulateRoute = arguments?["simulateRoute"] as? Bool ?? _simulateRoute
        _isOptimized = arguments?["isOptimized"] as? Bool ?? _isOptimized
        _allowsUTurnAtWayPoints = arguments?["allowsUTurnAtWayPoints"] as? Bool
        _navigationMode = arguments?["mode"] as? String ?? "drivingWithTraffic"
        _showReportFeedbackButton = arguments?["showReportFeedbackButton"] as? Bool ?? _showReportFeedbackButton
        _showEndOfRouteFeedback = arguments?["showEndOfRouteFeedback"] as? Bool ?? _showEndOfRouteFeedback
        _enableOnMapTapCallback = arguments?["enableOnMapTapCallback"] as? Bool ?? _enableOnMapTapCallback
        _enableHistoryRecording = arguments?["enableHistoryRecording"] as? Bool ?? _enableHistoryRecording
        _mapStyleUrlDay = arguments?["mapStyleUrlDay"] as? String
        _mapStyleUrlNight = arguments?["mapStyleUrlNight"] as? String
        
        // ⚠️ 重要：只有当 Flutter 端明确传入参数时才覆盖
        // 否则使用从 UserDefaults 加载的存储值（在 init() 中加载）
        if let mapStyle = arguments?["mapStyle"] as? String {
            _mapStyle = mapStyle
            print("⚙️ 使用 Flutter 传入的样式: \(mapStyle)")
        } else {
            print("⚙️ 使用存储的样式: \(_mapStyle ?? "nil")")
        }
        
        if let lightPreset = arguments?["lightPreset"] as? String {
            _lightPreset = lightPreset
            print("⚙️ 使用 Flutter 传入的 Light Preset: \(lightPreset)")
        } else {
            print("⚙️ 使用存储的 Light Preset: \(_lightPreset ?? "nil")")
        }
        
        if let enableDynamic = arguments?["enableDynamicLightPreset"] as? Bool {
            _enableDynamicLightPreset = enableDynamic
            print("⚙️ 使用 Flutter 传入的动态切换: \(enableDynamic)")
        } else {
            print("⚙️ 使用存储的动态切换: \(_enableDynamicLightPreset)")
        }
        
        _zoom = arguments?["zoom"] as? Double ?? _zoom
        _bearing = arguments?["bearing"] as? Double ?? _bearing
        _tilt = arguments?["tilt"] as? Double ?? _tilt
        _animateBuildRoute = arguments?["animateBuildRoute"] as? Bool ?? _animateBuildRoute
        _longPressDestinationEnabled = arguments?["longPressDestinationEnabled"] as? Bool ?? _longPressDestinationEnabled
        _alternatives = arguments?["alternatives"] as? Bool ?? _alternatives
        _autoBuildRoute = arguments?["autoBuildRoute"] as? Bool ?? _autoBuildRoute
    }
    
    
    func continueNavigationWithWayPoints(wayPoints: [Waypoint])
    {
        _options?.waypoints = wayPoints
        
        guard let mapboxNavigation = mapboxNavigation else { return }
        
        Task { @MainActor in
            let request = mapboxNavigation.routingProvider().calculateRoutes(options: _options!)
            
            switch await request.result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.sendEvent(eventType: MapBoxEventType.route_build_failed, data: error.localizedDescription)
                }
            case .success(let navigationRoutes):
                DispatchQueue.main.async {
                    self.sendEvent(eventType: MapBoxEventType.route_built, data: self.encodeNavigationRoutes(navigationRoutes: navigationRoutes))
                    
                    // Update the navigation session with new routes
                    Task { @MainActor in
                        mapboxNavigation.tripSession().startActiveGuidance(with: navigationRoutes, startLegIndex: 0)
                    }
                }
            }
        }
    }
    
    func endNavigation(result: FlutterResult?)
    {
        // 先停止历史记录
        stopHistoryRecording()
        
        // 停止 light preset 定时器
        stopDynamicLightPresetSwitch()

        // 尽快将会话置为 Idle，避免残留活跃状态
        Task { @MainActor in
            self.mapboxNavigation?.tripSession().setToIdle()
        }

        sendEvent(eventType: MapBoxEventType.navigation_finished)

        if let navigationVC = self._navigationViewController {
            // In v3, navigation is ended by dismissing the NavigationViewController
            if isEmbeddedNavigation {
                navigationVC.view.removeFromSuperview()
                navigationVC.removeFromParent()
                self._navigationViewController = nil
                // 嵌入式：移除后立刻清理核心
                self.resetNavigationCore()
                if let result = result { result(true) }
            } else {
                Task { @MainActor in
                    navigationVC.dismiss(animated: true) {
                        self._navigationViewController = nil
                        // 全屏：关闭完成后清理核心
                        self.resetNavigationCore()
                        if let result = result { result(true) }
                    }
                }
            }
        } else {
            // 没有控制器也进行核心清理
            self.resetNavigationCore()
            if let result = result { result(true) }
        }
    }

    // 统一核心清理：会话、全局 Provider、缓存状态
    private func resetNavigationCore() {
        Task { @MainActor in
            self.mapboxNavigation?.tripSession().setToIdle()
        }

        // 强制重置全局 Provider，释放内部订阅与状态
        MapboxNavigationManager.shared.forceReset()

        // 释放本地引用与缓存状态
        self.mapboxNavigationProvider = nil
        self.mapboxNavigation = nil
        self._navigationRoutes = nil
        self._wayPointOrder.removeAll()
        self._wayPoints.removeAll()

        // 重置历史记录相关标志
        self._isHistoryRecording = false
        self._currentHistoryId = nil
        self._historyStartTime = nil
    }
    
    func getLocationsFromFlutterArgument(arguments: NSDictionary?) -> [FlutterLocation]? {
        
        var locations = [FlutterLocation]()
        guard let oWayPoints = arguments?["wayPoints"] as? NSDictionary else {return nil}
        for item in oWayPoints as NSDictionary
        {
            let point = item.value as! NSDictionary
            guard let oName = point["Name"] as? String else {return nil }
            guard let oLatitude = point["Latitude"] as? Double else {return nil}
            guard let oLongitude = point["Longitude"] as? Double else {return nil}
            let oIsSilent = point["IsSilent"] as? Bool ?? false
            let order = point["Order"] as? Int
            let location = FlutterLocation(name: oName, latitude: oLatitude, longitude: oLongitude, order: order,isSilent: oIsSilent)
            locations.append(location)
        }
        if(!_isOptimized)
        {
            //waypoints must be in the right order
            locations.sort(by: {$0.order ?? 0 < $1.order ?? 0})
        }
        return locations
    }
    
    func getLastKnownLocation() -> Waypoint
    {
        return Waypoint(coordinate: CLLocationCoordinate2D(latitude: _lastKnownLocation!.coordinate.latitude, longitude: _lastKnownLocation!.coordinate.longitude))
    }
    
    
    
    func sendEvent(eventType: MapBoxEventType, data: String = "")
    {
        let routeEvent = MapBoxRouteEvent(eventType: eventType, data: data)

        let jsonEncoder = JSONEncoder()
        let jsonData = try! jsonEncoder.encode(routeEvent)
        let eventJson = String(data: jsonData, encoding: String.Encoding.utf8)

        if(_eventSink != nil){
            if let json = eventJson {
                _eventSink!(json)
            } else {
                // 如果编码失败，发送一个简单的错误事件
                print("Failed to encode event to JSON string: \(eventType)")
                let fallbackJson = "{\"eventType\":\"\(eventType.rawValue)\",\"data\":\"encoding_failed\"}"
                _eventSink!(fallbackJson)
            }
        }

    }
    
    func downloadOfflineRoute(arguments: NSDictionary?, flutterResult: @escaping FlutterResult)
    {
        /*
         // Create a directions client and store it as a property on the view controller.
         self.navigationDirections = NavigationDirections(credentials: Directions.shared.credentials)
         
         // Fetch available routing tile versions.
         _ = self.navigationDirections!.fetchAvailableOfflineVersions { (versions, error) in
         guard let version = versions?.first else { return }
         
         let coordinateBounds = CoordinateBounds(southWest: CLLocationCoordinate2DMake(0, 0), northEast: CLLocationCoordinate2DMake(1, 1))
         
         // Download tiles using the most recent version.
         _ = self.navigationDirections!.downloadTiles(in: coordinateBounds, version: version) { (url, response, error) in
         guard let url = url else {
         flutterResult(false)
         preconditionFailure("Unable to locate temporary file.")
         }
         
         guard let outputDirectoryURL = Bundle.mapboxCoreNavigation.suggestedTileURL(version: version) else {
         flutterResult(false)
         preconditionFailure("No suggested tile URL.")
         }
         try? FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true, attributes: nil)
         
         // Unpack downloaded routing tiles.
         NavigationDirections.unpackTilePack(at: url, outputDirectoryURL: outputDirectoryURL, progressHandler: { (totalBytes, bytesRemaining) in
         // Show unpacking progress.
         }, completionHandler: { (result, error) in
         // Configure the offline router with the output directory where the tiles have been unpacked.
         self.navigationDirections!.configureRouter(tilesURL: outputDirectoryURL) { (numberOfTiles) in
         // Completed, dismiss UI
         flutterResult(true)
         }
         })
         }
         }
         */
    }
    
    func encodeRouteResponse(response: RouteResponse) -> String {
        let routes = response.routes
        
        if routes != nil && !routes!.isEmpty {
            let jsonEncoder = JSONEncoder()
            let jsonData = try! jsonEncoder.encode(response.routes!)
            return String(data: jsonData, encoding: String.Encoding.utf8) ?? "{}"
        }
        
        return "{}"
    }
    
    func encodeNavigationRoutes(navigationRoutes: NavigationRoutes) -> String {
        // For v3, we need to encode the routes from NavigationRoutes
        let routes = navigationRoutes.mainRoute.route
        
        do {
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode([routes])
            return String(data: jsonData, encoding: String.Encoding.utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
    
    
    
    //MARK: EventListener Delegates
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        _eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        _eventSink = nil
        return nil
    }
    
    // MARK: - Navigation History Methods
    
    func getNavigationHistoryList(result: @escaping FlutterResult) {
        print("getNavigationHistoryList called")

        if historyManager == nil {
            print("Creating new HistoryManager instance")
            historyManager = HistoryManager()
        }

        do {
            let historyList = historyManager!.getHistoryList()
            print("Retrieved \(historyList.count) history records")

            let historyMaps = historyList.map { $0.toFlutterMap() }
            
            // 调试：打印每条记录
            historyMaps.forEach { print("History map: \($0)") }

            print("Returning \(historyMaps.count) history maps to Flutter")
            result(historyMaps)
        } catch {
            print("Error in getNavigationHistoryList: \(error)")
            result(FlutterError(code: "HISTORY_ERROR", message: "Failed to get history list: \(error.localizedDescription)", details: nil))
        }
    }
    
    func deleteNavigationHistory(arguments: NSDictionary?, result: @escaping FlutterResult) {
        guard let historyId = arguments?["historyId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "historyId is required", details: nil))
            return
        }
        
        if historyManager == nil {
            historyManager = HistoryManager()
        }
        
        do {
            let success = historyManager!.deleteHistoryRecord(historyId: historyId)
            result(success)
        } catch {
            result(FlutterError(code: "HISTORY_ERROR", message: "Failed to delete history: \(error.localizedDescription)", details: nil))
        }
    }
    
    func clearAllNavigationHistory(result: @escaping FlutterResult) {
        if historyManager == nil {
            historyManager = HistoryManager()
        }
        
        do {
            let success = historyManager!.clearAllHistory()
            result(success)
        } catch {
            result(FlutterError(code: "HISTORY_ERROR", message: "Failed to clear history: \(error.localizedDescription)", details: nil))
        }
    }
    
    // MARK: - History Recording Methods
    
    /**
     * 启动导航历史记录
     */
    private func startHistoryRecording() {
        print("startHistoryRecording called - enableHistoryRecording: \(_enableHistoryRecording), isHistoryRecording: \(_isHistoryRecording)")
        
        if _enableHistoryRecording && !_isHistoryRecording {
            // 使用 Mapbox Navigation SDK 的历史记录功能
            // 在 v3 中，使用 MapboxNavigation 的 historyRecorder
            guard let mapboxNavigation = mapboxNavigation else {
                print("mapboxNavigation is nil, cannot start history recording")
                return
            }
            
            Task { @MainActor in
                let historyRecorder = mapboxNavigation.historyRecorder()
                print("historyRecorder: \(String(describing: historyRecorder))")
                
                // 根据官方示例，直接调用 startRecordingHistory()，不需要 try-catch
                historyRecorder?.startRecordingHistory()
                _isHistoryRecording = true
                _currentHistoryId = UUID().uuidString
                _historyStartTime = Date()
                print("History recording started successfully with ID: \(_currentHistoryId ?? "unknown")")
                sendEvent(eventType: MapBoxEventType.history_recording_started, data: _currentHistoryId ?? "")
            }
        } else {
            print("History recording not started - enableHistoryRecording: \(_enableHistoryRecording), isHistoryRecording: \(_isHistoryRecording)")
        }
    }
    
    /**
     * 停止导航历史记录
     */
    private func stopHistoryRecording() {
        print("stopHistoryRecording called - isHistoryRecording: \(_isHistoryRecording)")
        print("Current historyId: \(_currentHistoryId ?? "nil"), startTime: \(_historyStartTime?.description ?? "nil")")
        
        // 防止重复调用
        guard _isHistoryRecording else {
            print("History recording already stopped or not started")
            return
        }
        
        // 立即设置为false，防止重复调用
        _isHistoryRecording = false
        
        // 在 v3 中，使用 MapboxNavigation 的 historyRecorder
        guard let mapboxNavigation = mapboxNavigation else {
            print("mapboxNavigation is nil, cannot stop history recording")
            return
        }
        
        Task { @MainActor in
            // 根据官方示例使用回调版本的 stopRecordingHistory
            let historyRecorder = mapboxNavigation.historyRecorder()
            print("Attempting to stop history recording...")
            print("historyRecorder: \(String(describing: historyRecorder))")
            
            // 使用官方示例的回调版本
            historyRecorder?.stopRecordingHistory { [weak self] historyFileUrl in
                guard let self = self else { return }
                guard let historyFileUrl = historyFileUrl else {
                    print("Failed to stop history recording: No file URL returned")
                    return
                }

                print("History recording stopped successfully, file saved to: \(historyFileUrl.path)")

                // 验证文件路径是否在我们配置的目录中
                let expectedDirectory = "NavigationHistory"
                if historyFileUrl.path.contains(expectedDirectory) {
                    print("✅ File saved in correct directory: NavigationHistory")
                } else {
                    print("⚠️ File saved in unexpected directory. Expected to contain: \(expectedDirectory)")
                    print("Actual path: \(historyFileUrl.path)")
                }

                // 先生成封面，再保存历史记录信息
                let historyId = self._currentHistoryId ?? UUID().uuidString
                HistoryCoverGenerator.shared.generateHistoryCover(filePath: historyFileUrl.path, historyId: historyId) { coverPath in
                    self.saveHistoryRecord(filePath: historyFileUrl.path, coverPath: coverPath)
                }
            }
        }
    }

    // MARK: - History Replay Methods

    /**
     * 开始历史记录回放 - 使用简化的历史回放控制器
     */
    func startHistoryReplay(arguments: NSDictionary?, result: @escaping FlutterResult) {
        guard let arguments = arguments,
              let historyFilePath = arguments["historyFilePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing historyFilePath", details: nil))
            return
        }
        print("开始历史记录回放，文件路径: \(historyFilePath)")

        Task { @MainActor in
            // 使用简化的历史回放控制器
            let historyReplayViewController = HistoryReplayViewController(historyFilePath: historyFilePath)

            // 创建导航控制器包装
            let navigationController = UINavigationController(rootViewController: historyReplayViewController)
            navigationController.modalPresentationStyle = .fullScreen

            // 获取当前的视图控制器并展示历史回放
            if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                var presentingViewController = rootViewController
                while let presented = presentingViewController.presentedViewController {
                    presentingViewController = presented
                }

                presentingViewController.present(navigationController, animated: true) {
                    print("历史回放控制器已展示")
                    result(true)
                }
            } else {
                print("无法获取当前视图控制器")
                result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Cannot get current view controller", details: nil))
            }
        }
    }



    // 注意：旧的startReplayWithUI和startReplayWithoutUI方法已被删除
    // 现在使用HistoryReplayViewController来处理所有历史回放功能

    /**
     * 保存历史记录信息
     */
    private func saveHistoryRecord(filePath: String, coverPath: String? = nil) {
        print("saveHistoryRecord called with filePath: \(filePath)")
        do {
            let fileManager = FileManager.default
            print("Checking if file exists at path: \(filePath)")
            if fileManager.fileExists(atPath: filePath) {
                print("History file exists, proceeding with save")
                let fileAttributes = try fileManager.attributesOfItem(atPath: filePath)
                let fileSize = fileAttributes[.size] as? Int64 ?? 0
                
                let duration = _historyStartTime != nil ? Date().timeIntervalSince(_historyStartTime!) : 0
                
                var historyData: [String: Any] = [
                    "id": _currentHistoryId ?? UUID().uuidString,
                    "filePath": filePath,
                    "startTime": _historyStartTime?.timeIntervalSince1970 ?? 0,
                    "duration": Int(duration),
                    "fileSize": fileSize,
                    "startPointName": _wayPoints.first?.name ?? "未知起点",
                    "endPointName": _wayPoints.last?.name ?? "未知终点",
                    "navigationMode": _navigationMode ?? "driving"
                ]

                if let coverPath = coverPath {
                    historyData["cover"] = coverPath
                }
                
                // 使用历史记录管理器保存
                if historyManager == nil {
                    historyManager = HistoryManager()
                }
                
                print("Attempting to save history record: \(historyData)")
                let success = historyManager!.saveHistoryRecord(historyData: historyData)
                if !success {
                    print("Failed to save history record to database")
                    sendEvent(eventType: MapBoxEventType.history_recording_error, data: "Failed to save history record to database")
                } else {
                    print("History record saved successfully: \(historyData)")
                    sendEvent(eventType: MapBoxEventType.history_recording_stopped, data: filePath)
                }
            } else {
                print("History file does not exist at path: \(filePath)")
                sendEvent(eventType: MapBoxEventType.history_recording_error, data: "History file does not exist")
            }
        } catch {
            print("Error saving history record: \(error.localizedDescription)")
            sendEvent(eventType: MapBoxEventType.history_recording_error, data: "Failed to save history record: \(error.localizedDescription)")
        }
    }
}

extension NavigationFactory : NavigationViewControllerDelegate {
    //MARK: NavigationViewController Delegates
    public func navigationViewController(_ navigationViewController: NavigationViewController, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        _lastKnownLocation = location
        _distanceRemaining = progress.distanceRemaining
        _durationRemaining = progress.durationRemaining
        
        // 启动历史记录（仅在第一次更新时）
        if !_isHistoryRecording {
            startHistoryRecording()
        }
        
        sendEvent(eventType: MapBoxEventType.navigation_running)
        //_currentLegDescription =  progress.currentLeg.description
        if(_eventSink != nil)
        {
            let jsonEncoder = JSONEncoder()

            let progressEvent = MapBoxRouteProgressEvent(progress: progress)
            let progressEventJsonData = try! jsonEncoder.encode(progressEvent)
            // 使用 UTF-8 编码而不是 ASCII，避免编码失败返回 nil
            let progressEventJson = String(data: progressEventJsonData, encoding: String.Encoding.utf8)

            // 检查编码是否成功
            if let eventJson = progressEventJson {
                // 发送标准格式的进度事件，包含eventType和data字段
                sendEvent(eventType: MapBoxEventType.progress_change, data: eventJson)
            } else {
                // 如果编码失败，发送一个错误事件
                print("Failed to encode progress event to JSON string")
                sendEvent(eventType: MapBoxEventType.progress_change, data: "encoding_failed")
            }

            if(progress.isFinalLeg && progress.currentLegProgress.userHasArrivedAtWaypoint && !_showEndOfRouteFeedback)
            {
                _eventSink = nil
            }
        }
    }
    
    public func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
        sendEvent(eventType: MapBoxEventType.on_arrival, data: "true")
        
        // 如果是最后一个航点，停止历史记录
        if _wayPoints.isEmpty || waypoint == _wayPoints.last {
            stopHistoryRecording()
        }
        
        if(!_wayPoints.isEmpty && IsMultipleUniqueRoutes)
        {
            continueNavigationWithWayPoints(wayPoints: [getLastKnownLocation(), _wayPoints.remove(at: 0)])
            return false
        }
        
        return true
    }
    
    
    public func navigationViewController(_ navigationViewController: NavigationViewController, shouldRerouteFrom location: CLLocation) -> Bool {
        return _shouldReRoute
    }

    // 当用户手势关闭/系统关闭导航控制器时，兜底做核心清理（唯一实现）
    public func navigationViewControllerDidDismiss(
        _ navigationViewController: NavigationViewController,
        byCanceling canceled: Bool
    ) {
        if canceled {
            stopHistoryRecording()
            sendEvent(eventType: MapBoxEventType.navigation_cancelled)
        }
        Task { @MainActor in
            self.mapboxNavigation?.tripSession().setToIdle()
        }
        self._navigationViewController = nil
        self.resetNavigationCore()
    }
    
    // EndOfRouteFeedback has been removed in v3
    // This delegate method is no longer available
    /*
    public func navigationViewController(_ navigationViewController: NavigationViewController, didSubmitArrivalFeedback feedback: EndOfRouteFeedback) {

        if(_eventSink != nil)
        {
            let jsonEncoder = JSONEncoder()

            let localFeedback = Feedback(rating: feedback.rating, comment: feedback.comment)
            let feedbackJsonData = try! jsonEncoder.encode(localFeedback)
            let feedbackJson = String(data: feedbackJsonData, encoding: String.Encoding.ascii)

            sendEvent(eventType: MapBoxEventType.navigation_finished, data: feedbackJson ?? "")

            _eventSink = nil

        }
    }
    */
}

// MARK: - HistoryReplayDelegate

extension NavigationFactory: HistoryReplayDelegate {
    public func historyReplayController(
        _ historyReplayController: HistoryReplayController,
        didReplayEvent event: any HistoryEvent
    ) {
        // 监控所有传入的事件
        print("History replay event received: \(type(of: event)) - \(event)")

        // 发送事件给Flutter端
        sendEvent(eventType: MapBoxEventType.navigation_running)
    }

    public func historyReplayController(
        _ historyReplayController: HistoryReplayController,
        wantsToSetRoutes routes: NavigationRoutes
    ) {
        print("🚀 History replay wants to set routes!")
        print("Main route available: \(routes.mainRoute)")
        print("Navigation controller exists: \(_navigationViewController != nil)")

        // 当历史文件中有更新的路由时，我们需要相应地设置路由
        Task { @MainActor in
            if let replayMapboxNavigation = replayMapboxNavigation {
                if _navigationViewController == nil {
                    // 如果没有导航控制器，创建一个
                    print("Creating new navigation controller for replay")
                    presentReplayNavigationController(with: routes)
                } else {
                    // 如果已经有导航控制器，更新路由
                    print("Updating existing navigation controller with new routes")
                    replayMapboxNavigation.tripSession().startActiveGuidance(
                        with: routes,
                        startLegIndex: 0
                    )
                }
            } else {
                print("❌ Error: replayMapboxNavigation is nil in wantsToSetRoutes")
            }
        }
    }

    public func historyReplayControllerDidFinishReplay(_ historyReplayController: HistoryReplayController) {
        print("History replay finished")

        // 回放完成，清理资源
        Task { @MainActor in
            _navigationViewController?.dismiss(animated: true) {
                self.replayMapboxNavigation?.tripSession().setToIdle()
                self.isHistoryReplaying = false
            }
        }

        // 发送回放完成事件给Flutter端
        sendEvent(eventType: MapBoxEventType.navigation_finished)
    }

    /**
     * 展示回放导航控制器
     */
    private func presentReplayNavigationController(with navigationRoutes: NavigationRoutes) {
        print("📱 Presenting replay navigation controller")

        guard let replayMapboxNavigation = replayMapboxNavigation,
              let replayNavigationProvider = replayNavigationProvider else {
            print("❌ Error: replay navigation components are nil")
            print("replayMapboxNavigation: \(replayMapboxNavigation != nil)")
            print("replayNavigationProvider: \(replayNavigationProvider != nil)")
            return
        }

        Task { @MainActor in
            print("Creating NavigationOptions...")
            let navigationOptions = NavigationOptions(
                mapboxNavigation: replayMapboxNavigation,
                voiceController: replayNavigationProvider.routeVoiceController,
                eventsManager: replayMapboxNavigation.eventsManager()
            )

            print("Creating NavigationViewController...")
            let navigationViewController = NavigationViewController(
                navigationRoutes: navigationRoutes,
                navigationOptions: navigationOptions
            )

            navigationViewController.delegate = self
            navigationViewController.modalPresentationStyle = .fullScreen
            navigationViewController.routeLineTracksTraversal = true

            print("Looking for root view controller...")
            // 获取当前的视图控制器来展示导航
            if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                var presentingViewController = rootViewController
                while let presented = presentingViewController.presentedViewController {
                    presentingViewController = presented
                }

                print("Presenting navigation controller...")
                presentingViewController.present(navigationViewController, animated: true) {
                    print("✅ Navigation controller presented successfully!")
                    self._navigationViewController = navigationViewController
                }
            } else {
                print("❌ Error: Could not find root view controller")
            }
        }
    }
}

// MARK: - HistoryManager 内嵌类
/**
 * 导航历史记录管理器
 */
class HistoryManager {
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "navigation_history_list"
    
    init() {}
    
    /**
     * 保存历史记录
     */
    func saveHistoryRecord(historyData: [String: Any]) -> Bool {
        do {
            print("HistoryManager.saveHistoryRecord called with data: \(historyData)")
            var historyList = getHistoryList()
            print("Current history list count before adding: \(historyList.count)")

            let historyRecord = HistoryRecord(
                id: historyData["id"] as? String ?? UUID().uuidString,
                historyFilePath: historyData["filePath"] as? String ?? "",
                startTime: Date(timeIntervalSince1970: historyData["startTime"] as? TimeInterval ?? 0),
                duration: historyData["duration"] as? Int ?? 0,
                startPointName: historyData["startPointName"] as? String,
                endPointName: historyData["endPointName"] as? String,
                navigationMode: historyData["navigationMode"] as? String,
                cover: historyData["cover"] as? String
            )

            print("Created history record: \(historyRecord)")
            historyList.append(historyRecord)
            print("History list count after adding: \(historyList.count)")

            let success = saveHistoryList(historyList)
            print("saveHistoryList result: \(success)")
            return success
        } catch {
            print("Error in saveHistoryRecord: \(error)")
            return false
        }
    }
    
    /**
     * 获取历史记录列表
     */
    func getHistoryList() -> [HistoryRecord] {
        print("HistoryManager.getHistoryList called")
        print("Looking for key: \(historyKey)")

        guard let data = userDefaults.data(forKey: historyKey) else {
            print("No data found for key: \(historyKey)")
            return []
        }

        print("Found data, size: \(data.count) bytes")

        guard let historyList = try? JSONDecoder().decode([HistoryRecord].self, from: data) else {
            print("Failed to decode history list from data")
            return []
        }

        print("Successfully decoded \(historyList.count) history records")
        
        // 🔍 调试：打印每条记录的 cover 字段
        for (index, record) in historyList.enumerated() {
            print("🔍 记录 \(index): ID=\(record.id), cover=\(record.cover ?? "nil")")
        }
        
        return historyList
    }
    
    /**
     * 删除指定的历史记录
     */
    func deleteHistoryRecord(historyId: String) -> Bool {
        var historyList = getHistoryList()
        if let index = historyList.firstIndex(where: { $0.id == historyId }) {
            let record = historyList[index]
            
            // 删除历史文件
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: record.historyFilePath) {
                try? fileManager.removeItem(atPath: record.historyFilePath)
                print("✅ 已删除历史文件: \(record.historyFilePath)")
            }
            
            // 删除封面文件
            if let coverPath = record.cover, fileManager.fileExists(atPath: coverPath) {
                try? fileManager.removeItem(atPath: coverPath)
                print("✅ 已删除封面文件: \(coverPath)")
            }
            
            // 从列表中移除
            historyList.remove(at: index)
            return saveHistoryList(historyList)
        }
        return false
    }
    
    /**
     * 清除所有历史记录
     */
    func clearAllHistory() -> Bool {
        let historyList = getHistoryList()
        
        // 删除所有文件
        let fileManager = FileManager.default
        for record in historyList {
            // 删除历史文件
            if fileManager.fileExists(atPath: record.historyFilePath) {
                try? fileManager.removeItem(atPath: record.historyFilePath)
                print("✅ 已删除历史文件: \(record.historyFilePath)")
            }
            
            // 删除封面文件
            if let coverPath = record.cover, fileManager.fileExists(atPath: coverPath) {
                try? fileManager.removeItem(atPath: coverPath)
                print("✅ 已删除封面文件: \(coverPath)")
            }
        }
        
        // 清空列表
        return saveHistoryList([])
    }
    
    /**
     * 更新指定历史记录的封面路径
     */
    func updateHistoryCover(historyId: String, coverPath: String) -> Bool {
        var historyList = getHistoryList()
        
        print("🔍 更新封面 - 当前历史记录总数: \(historyList.count)")
        
        if let index = historyList.firstIndex(where: { $0.id == historyId }) {
            let oldRecord = historyList[index]
            print("🔍 找到记录:")
            print("   ID: \(oldRecord.id)")
            print("   旧封面: \(oldRecord.cover ?? "nil")")
            print("   新封面: \(coverPath)")
            
            let newRecord = HistoryRecord(
                id: oldRecord.id,
                historyFilePath: oldRecord.historyFilePath,
                startTime: oldRecord.startTime,
                duration: oldRecord.duration,
                startPointName: oldRecord.startPointName,
                endPointName: oldRecord.endPointName,
                navigationMode: oldRecord.navigationMode,
                cover: coverPath
            )
            
            print("🔍 新记录创建完成，cover = \(newRecord.cover ?? "nil")")
            
            historyList[index] = newRecord
            
            print("🔍 列表中第 \(index) 条记录的 cover = \(historyList[index].cover ?? "nil")")
            
            let success = saveHistoryList(historyList)
            
            if success {
                print("✅ 历史记录封面已更新: \(historyId)")
                print("   封面路径: \(coverPath)")
            } else {
                print("❌ 更新历史记录封面失败")
            }
            
            return success
        } else {
            print("⚠️ 未找到历史记录: \(historyId)")
            return false
        }
    }
    
    /**
     * 获取历史记录存储目录
     */
    func getHistoryDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let historyDir = documentsPath.appendingPathComponent("navigation_history")
        
        // 创建目录（如果不存在）
        if !FileManager.default.fileExists(atPath: historyDir.path) {
            try? FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        return historyDir
    }
    
    /**
     * 生成历史记录文件路径（注意：实际文件由 Mapbox SDK 生成，格式为 .pbf.gz）
     */
    func generateHistoryFilePath(historyId: String) -> String {
        let historyDir = getHistoryDirectory()
        let fileName = "navigation_history_\(historyId).pbf.gz"
        return historyDir.appendingPathComponent(fileName).path
    }
    
    private func saveHistoryList(_ historyList: [HistoryRecord]) -> Bool {
        do {
            print("HistoryManager.saveHistoryList called with \(historyList.count) records")
            let data = try JSONEncoder().encode(historyList)
            print("Encoded data size: \(data.count) bytes")
            userDefaults.set(data, forKey: historyKey)
            print("Data saved to UserDefaults with key: \(historyKey)")

            // 验证保存是否成功
            if let savedData = userDefaults.data(forKey: historyKey) {
                print("Verification: Data successfully saved, size: \(savedData.count) bytes")
            } else {
                print("Verification: Failed to save data to UserDefaults")
            }

            return true
        } catch {
            print("Error in saveHistoryList: \(error)")
            return false
        }
    }
}

/**
 * 历史记录数据类
 */
struct HistoryRecord: Codable {
    let id: String
    let historyFilePath: String
    let startTime: Date
    let duration: Int
    let startPointName: String?
    let endPointName: String?
    let navigationMode: String?
    let cover: String?
    
    /**
     * 转换为 Flutter 可用的 Map 格式
     * 统一管理字段映射，避免多处维护
     */
    func toFlutterMap() -> [String: Any] {
        let startTimeMillis = Int64(startTime.timeIntervalSince1970 * 1000)
        
        var map: [String: Any] = [
            "id": id,
            "historyFilePath": resolveCurrentPath(historyFilePath),  // 🆕 动态解析路径
            "startTime": startTimeMillis,
            "duration": duration,
            "startPointName": startPointName ?? "",
            "endPointName": endPointName ?? "",
            "navigationMode": navigationMode ?? ""
        ]
        
        // 可选字段：只在有值时添加
        if let cover = cover {
            map["cover"] = resolveCurrentPath(cover)  // 🆕 动态解析封面路径
        }
        
        return map
    }
    
    /**
     * 将存储的路径解析为当前沙箱的实际路径
     * iOS 最佳实践：处理沙箱路径变化问题
     *
     * 策略：
     * 1. 如果路径已经在当前沙箱中，直接返回
     * 2. 如果路径在旧沙箱中，提取文件名并重建当前路径
     * 3. 如果文件不存在，返回原路径（让调用方处理）
     */
    private func resolveCurrentPath(_ storedPath: String) -> String {
        // 1. 检查存储的路径是否仍然有效
        if FileManager.default.fileExists(atPath: storedPath) {
            return storedPath
        }
        
        // 2. 路径失效，尝试在当前沙箱中重建路径
        let fileURL = URL(fileURLWithPath: storedPath)
        let fileName = fileURL.lastPathComponent
        
        // 3. 判断文件类型，构建正确的目标目录
        let currentPath: String
        if storedPath.contains("NavigationHistory") {
            // 历史文件和封面文件都在 NavigationHistory 目录
            currentPath = defaultHistoryDirectoryURL().appendingPathComponent(fileName).path
        } else if storedPath.contains("Documents/navigation_history") {
            // 兼容旧版本可能的路径
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            currentPath = documentsPath.appendingPathComponent("navigation_history")
                .appendingPathComponent(fileName).path
        } else {
            // 未知路径模式，返回原路径
            return storedPath
        }
        
        // 4. 验证重建的路径是否存在
        if FileManager.default.fileExists(atPath: currentPath) {
            print("✅ 路径已更新: \(fileName)")
            print("   旧路径: \(storedPath)")
            print("   新路径: \(currentPath)")
            return currentPath
        }
        
        // 5. 文件确实不存在，返回原路径
        print("⚠️ 文件不存在: \(fileName)")
        return storedPath
    }
}

// MARK: - NavigationFactory Light Preset Extension
extension NavigationFactory {
    
    /**
     * 获取当前应该使用的 StyleURI
     * 根据 mapStyle 参数返回对应的 StyleURI
     */
    func getCurrentStyleURI() -> MapboxMaps.StyleURI {
        guard let mapStyle = _mapStyle else {
            return MapboxMaps.StyleURI.standard
        }
        
        switch mapStyle {
        case "standard", "faded", "monochrome":
            // faded 和 monochrome 是 standard 的主题变体
            return MapboxMaps.StyleURI.standard
        case "standardSatellite":
            return MapboxMaps.StyleURI.standardSatellite
        case "light":
            return MapboxMaps.StyleURI.light
        case "dark":
            return MapboxMaps.StyleURI.dark
        case "outdoors":
            return MapboxMaps.StyleURI.outdoors
        default:
            return MapboxMaps.StyleURI.standard
        }
    }
    
    /**
     * 应用 light preset 和 theme 到地图
     * 支持的样式: standard, standardSatellite, faded, monochrome
     * 其他样式: light, dark, outdoors 不支持 Light Preset
     */
    func applyLightPreset(_ preset: String, to mapView: MapboxMaps.MapView?) {
        guard let mapView = mapView else { return }
        
        // 检查当前样式是否支持 Light Preset
        let supportedStyles = ["standard", "standardSatellite", "faded", "monochrome"]
        if let currentStyle = _mapStyle, !supportedStyles.contains(currentStyle) {
            print("ℹ️ 样式 '\(currentStyle)' 不支持 Light Preset，已跳过")
            return
        }
        
        do {
            // 1. 应用 Light Preset
            try mapView.mapboxMap.setStyleImportConfigProperty(
                for: "basemap",
                config: "lightPreset",
                value: preset
            )
            print("✅ Light preset 已应用: \(preset)")
            
            // 2. 如果是 faded 或 monochrome，应用对应的 theme
            if let currentStyle = _mapStyle {
                if currentStyle == "faded" {
                    try mapView.mapboxMap.setStyleImportConfigProperty(
                        for: "basemap",
                        config: "theme",
                        value: "faded"
                    )
                    print("✅ Theme 已应用: faded")
                } else if currentStyle == "monochrome" {
                    try mapView.mapboxMap.setStyleImportConfigProperty(
                        for: "basemap",
                        config: "theme",
                        value: "monochrome"
                    )
                    print("✅ Theme 已应用: monochrome")
                } else if currentStyle == "standard" {
                    // 确保使用默认 theme
                    try mapView.mapboxMap.setStyleImportConfigProperty(
                        for: "basemap",
                        config: "theme",
                        value: "default"
                    )
                    print("✅ Theme 已重置: default")
                }
            }
        } catch {
            print("⚠️ 应用样式配置失败: \(error)")
        }
    }
    
    /**
     * 启动动态 light preset 切换
     * 每隔一定时间自动切换到下一个 preset
     * 支持的样式: standard, standardSatellite, faded, monochrome
     */
    func startDynamicLightPresetSwitch(mapView: MapboxMaps.MapView?) {
        // 先停止已有的定时器
        stopDynamicLightPresetSwitch()
        
        guard _enableDynamicLightPreset else { return }
        
        let presets = ["dawn", "day", "dusk", "night"]
        
        // 如果设置了初始 lightPreset，找到对应的索引
        if let initialPreset = _lightPreset,
           let index = presets.firstIndex(of: initialPreset) {
            _currentLightPresetIndex = index
        }
        
        // 应用初始 preset
        applyLightPreset(presets[_currentLightPresetIndex], to: mapView)
        
        // 创建定时器，每 5 秒切换一次
        _lightPresetTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 切换到下一个 preset
            self._currentLightPresetIndex = (self._currentLightPresetIndex + 1) % presets.count
            let nextPreset = presets[self._currentLightPresetIndex]
            
            self.applyLightPreset(nextPreset, to: mapView)
            
            // 发送事件通知 Flutter 层
            self.sendEvent(eventType: .light_preset_changed, data: nextPreset)
        }
    }
    
    /**
     * 停止动态 light preset 切换
     */
    func stopDynamicLightPresetSwitch() {
        _lightPresetTimer?.invalidate()
        _lightPresetTimer = nil
    }
}
