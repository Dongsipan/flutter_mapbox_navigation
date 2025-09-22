import Flutter
import UIKit
import MapboxNavigationCore
import MapboxNavigationUIKit
import MapboxDirections
import CoreLocation
import Foundation

// Type alias to avoid conflicts with Mapbox's Location type
typealias FlutterLocation = flutter_mapbox_navigation.Location

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
    
    // Mapbox Navigation v3 components
    var mapboxNavigationProvider: MapboxNavigationProvider?
    var mapboxNavigation: MapboxNavigation?
    private var historyManager: HistoryManager?

    // History Replay components
    private var historyReplayController: HistoryReplayController?
    private var replayNavigationProvider: MapboxNavigationProvider?
    private var replayMapboxNavigation: MapboxNavigation?
    private var isHistoryReplaying: Bool = false
    
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
        
        // Initialize MapboxNavigationProvider with v3 API only if not already initialized
        if mapboxNavigationProvider == nil {
            let locationSource: LocationSource = _simulateRoute ? .simulation(initialLocation: nil) : .live

            // Configure history recording directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let historyDirectory = documentsPath.appendingPathComponent("NavigationHistory")
            let historyRecordingConfig = HistoryRecordingConfig(historyDirectoryURL: historyDirectory)

            let coreConfig = CoreConfig(
                locationSource: locationSource,
                historyRecordingConfig: historyRecordingConfig
            )
            mapboxNavigationProvider = MapboxNavigationProvider(coreConfig: coreConfig)
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
                        self.startNavigation(navigationRoutes: navigationRoutes, mapboxNavigation: mapboxNavigation)
                        flutterResult("Navigation started successfully")
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
        _zoom = arguments?["zoom"] as? Double ?? _zoom
        _bearing = arguments?["bearing"] as? Double ?? _bearing
        _tilt = arguments?["tilt"] as? Double ?? _tilt
        _animateBuildRoute = arguments?["animateBuildRoute"] as? Bool ?? _animateBuildRoute
        _longPressDestinationEnabled = arguments?["longPressDestinationEnabled"] as? Bool ?? _longPressDestinationEnabled
        _alternatives = arguments?["alternatives"] as? Bool ?? _alternatives
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
        
        sendEvent(eventType: MapBoxEventType.navigation_finished)
        if(self._navigationViewController != nil)
        {
            // In v3, navigation is ended by dismissing the NavigationViewController
            // The MapboxNavigation instance handles the session cleanup
            if(isEmbeddedNavigation)
            {
                self._navigationViewController?.view.removeFromSuperview()
                self._navigationViewController?.removeFromParent()
                self._navigationViewController = nil
            }
            else
            {
                Task { @MainActor in
                    self._navigationViewController?.dismiss(animated: true, completion: {
                        self._navigationViewController = nil
                        if(result != nil)
                        {
                            result!(true)
                        }
                    })
                }
            }
        }
        
        // Clean up MapboxNavigation provider
        mapboxNavigationProvider = nil
        mapboxNavigation = nil
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
            _eventSink!(eventJson)
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

            let historyMaps = historyList.map { history in
                let startTimeMillis = Int64(history.startTime.timeIntervalSince1970 * 1000)
                let historyMap: [String: Any] = [
                    "id": history.id,
                    "historyFilePath": history.historyFilePath,
                    "startTime": startTimeMillis, // 确保是整数类型
                    "duration": history.duration,
                    "startPointName": history.startPointName ?? "",
                    "endPointName": history.endPointName ?? "",
                    "navigationMode": history.navigationMode ?? ""
                ]
                print("History map: \(historyMap)")
                return historyMap
            }

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
        
        // 创建历史文件 URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let historyFileName = "navigation_history_\(_currentHistoryId ?? UUID().uuidString).json"
        let historyFileURL = documentsPath.appendingPathComponent(historyFileName)
        
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

                // 直接保存历史记录信息，使用原始文件路径
                self.saveHistoryRecord(filePath: historyFileUrl.path)
            }
        }
    }

    // MARK: - History Replay Methods

    /**
     * 开始历史记录回放
     */
    func startHistoryReplay(arguments: NSDictionary?, result: @escaping FlutterResult) {
        guard let arguments = arguments,
              let historyFilePath = arguments["historyFilePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing historyFilePath", details: nil))
            return
        }

        let enableReplayUI = arguments["enableReplayUI"] as? Bool ?? true

        print("Starting history replay with file: \(historyFilePath)")
        print("Enable replay UI: \(enableReplayUI)")

        // 检查文件是否存在
        let fileManager = FileManager.default
        print("Checking if history file exists at path: \(historyFilePath)")

        // 列出目录内容以便调试
        let parentDir = URL(fileURLWithPath: historyFilePath).deletingLastPathComponent()
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: parentDir.path)
            print("Contents of parent directory \(parentDir.path): \(contents)")
        } catch {
            print("Error listing directory contents: \(error)")

            // 如果目录不存在，尝试查找文件在其他可能的位置
            print("Searching for history files in Documents directory...")
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileName = URL(fileURLWithPath: historyFilePath).lastPathComponent

            // 搜索可能的目录
            let possiblePaths = [
                documentsPath.appendingPathComponent("historyRecordings"),
                documentsPath.appendingPathComponent("NavigationHistory"),
                documentsPath
            ]

            for searchPath in possiblePaths {
                if fileManager.fileExists(atPath: searchPath.path) {
                    do {
                        let contents = try fileManager.contentsOfDirectory(atPath: searchPath.path)
                        print("Contents of \(searchPath.path): \(contents)")

                        // 查找匹配的文件
                        if contents.contains(fileName) {
                            let actualFilePath = searchPath.appendingPathComponent(fileName).path
                            print("Found history file at: \(actualFilePath)")
                            // 更新文件路径并继续
                            return startHistoryReplayWithActualPath(actualFilePath, enableReplayUI: enableReplayUI, result: result)
                        }
                    } catch {
                        print("Error listing contents of \(searchPath.path): \(error)")
                    }
                }
            }
        }

        guard fileManager.fileExists(atPath: historyFilePath) else {
            print("History file not found at path: \(historyFilePath)")
            result(FlutterError(code: "FILE_NOT_FOUND", message: "History file not found at path: \(historyFilePath)", details: nil))
            return
        }

        print("History file found, proceeding with replay")
        startHistoryReplayWithActualPath(historyFilePath, enableReplayUI: enableReplayUI, result: result)
    }

    /**
     * 使用实际文件路径开始历史记录回放
     */
    private func startHistoryReplayWithActualPath(_ historyFilePath: String, enableReplayUI: Bool, result: @escaping FlutterResult) {
        print("Starting history replay with actual path: \(historyFilePath)")

        // 按照 Mapbox SDK 正确方式：先用 HistoryReader 读取历史文件
        let fileUrl = URL(fileURLWithPath: historyFilePath)
        guard let historyReader = HistoryReader(fileUrl: fileUrl) else {
            result(FlutterError(code: "HISTORY_READER_ERROR", message: "Failed to create HistoryReader", details: nil))
            return
        }

        // 使用 Task 包装异步操作
        Task {
            do {
                // 解析历史文件获取 History 实例
                let history = try await historyReader.parse()
                print("History parsed successfully, events count: \(history.events.count)")

                // 使用 History 实例创建回放控制器
                historyReplayController = HistoryReplayController(history: history)
                historyReplayController?.delegate = self

                print("HistoryReplayController created successfully with History instance")
                print("Delegate set to: \(String(describing: historyReplayController?.delegate))")

                // 创建用于回放的导航提供者
                let coreConfig = CoreConfig(
                    routingConfig: RoutingConfig(
                        rerouteConfig: RerouteConfig(
                            detectsReroute: false // 禁用重新路由检测，因为我们要手动设置新路由
                        )
                    ),
                    locationSource: .custom(
                        .historyReplayingValue(with: historyReplayController!)
                    )
                )

                replayNavigationProvider = MapboxNavigationProvider(coreConfig: coreConfig)

                Task { @MainActor in
                    replayMapboxNavigation = replayNavigationProvider?.mapboxNavigation
                    isHistoryReplaying = true

                    print("ReplayMapboxNavigation initialized: \(replayMapboxNavigation != nil)")

                    // 开始历史记录回放
                    historyReplayController?.play()
                    print("History replay started with play() method")

                    if enableReplayUI {
                        // 启动带UI的回放
                        print("Starting replay with UI")
                        startReplayWithUI()
                    } else {
                        // 启动无UI的回放（仅数据回放）
                        print("Starting replay without UI")
                        startReplayWithoutUI()
                    }

                    result(true)
                }
            } catch {
                print("Error starting history replay: \(error)")
                result(FlutterError(code: "REPLAY_START_ERROR", message: "Failed to start history replay: \(error.localizedDescription)", details: nil))
            }
        }
    }

    /**
     * 停止历史记录回放
     */
    func stopHistoryReplay(result: @escaping FlutterResult) {
        print("Stopping history replay")

        guard isHistoryReplaying else {
            result(FlutterError(code: "NOT_REPLAYING", message: "History replay is not active", details: nil))
            return
        }

        // 停止回放
        historyReplayController?.pause() // 先暂停回放

        Task { @MainActor in
            replayMapboxNavigation?.tripSession().setToIdle()

            // 如果有导航控制器，关闭它
            if let navigationViewController = _navigationViewController {
                navigationViewController.dismiss(animated: true)
                _navigationViewController = nil
            }
        }

        // 清理资源
        historyReplayController = nil
        replayNavigationProvider = nil
        replayMapboxNavigation = nil
        isHistoryReplaying = false

        result(true)
    }

    /**
     * 暂停历史记录回放
     */
    func pauseHistoryReplay(result: @escaping FlutterResult) {
        print("Pausing history replay")

        guard isHistoryReplaying, let historyReplayController = historyReplayController else {
            result(FlutterError(code: "NOT_REPLAYING", message: "History replay is not active", details: nil))
            return
        }

        // 使用 Mapbox SDK 的 pause() 方法
        historyReplayController.pause()
        print("History replay paused")
        result(true)
    }

    /**
     * 恢复历史记录回放
     */
    func resumeHistoryReplay(result: @escaping FlutterResult) {
        print("Resuming history replay")

        guard isHistoryReplaying, let historyReplayController = historyReplayController else {
            result(FlutterError(code: "NOT_REPLAYING", message: "History replay is not active", details: nil))
            return
        }

        // 使用 Mapbox SDK 的 play() 方法恢复回放
        historyReplayController.play()
        print("History replay resumed")
        result(true)
    }

    /**
     * 设置历史记录回放速度
     */
    func setHistoryReplaySpeed(arguments: NSDictionary?, result: @escaping FlutterResult) {
        guard let arguments = arguments,
              let speed = arguments["speed"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing speed parameter", details: nil))
            return
        }

        print("Setting history replay speed to: \(speed)")

        guard isHistoryReplaying, let historyReplayController = historyReplayController else {
            result(FlutterError(code: "NOT_REPLAYING", message: "History replay is not active", details: nil))
            return
        }

        // 使用 Mapbox SDK 的 speedMultiplier 属性设置回放速度
        historyReplayController.speedMultiplier = speed
        print("History replay speed set to: \(speed)")
        result(true)
    }

    /**
     * 启动带UI的历史记录回放
     */
    @MainActor
    private func startReplayWithUI() {
        print("Starting history replay with UI")

        guard let replayMapboxNavigation = replayMapboxNavigation else {
            print("Error: replayMapboxNavigation is nil")
            return
        }

        print("About to start free drive mode for replay")
        // 启动自由驾驶模式，等待历史记录中的路由
        replayMapboxNavigation.tripSession().startFreeDrive()
        print("Free drive mode started, waiting for route callbacks...")
    }

    /**
     * 启动无UI的历史记录回放
     */
    @MainActor
    private func startReplayWithoutUI() {
        print("Starting history replay without UI")

        guard let replayMapboxNavigation = replayMapboxNavigation else {
            print("Error: replayMapboxNavigation is nil")
            return
        }

        // 启动自由驾驶模式进行数据回放
        replayMapboxNavigation.tripSession().startFreeDrive()
    }

    /**
     * 保存历史记录信息
     */
    private func saveHistoryRecord(filePath: String) {
        print("saveHistoryRecord called with filePath: \(filePath)")
        do {
            let fileManager = FileManager.default
            print("Checking if file exists at path: \(filePath)")
            if fileManager.fileExists(atPath: filePath) {
                print("History file exists, proceeding with save")
                let fileAttributes = try fileManager.attributesOfItem(atPath: filePath)
                let fileSize = fileAttributes[.size] as? Int64 ?? 0
                
                let duration = _historyStartTime != nil ? Date().timeIntervalSince(_historyStartTime!) : 0
                
                let historyData: [String: Any] = [
                    "id": _currentHistoryId ?? UUID().uuidString,
                    "filePath": filePath,
                    "startTime": _historyStartTime?.timeIntervalSince1970 ?? 0,
                    "duration": Int(duration),
                    "fileSize": fileSize,
                    "startPointName": _wayPoints.first?.name ?? "未知起点",
                    "endPointName": _wayPoints.last?.name ?? "未知终点",
                    "navigationMode": _navigationMode ?? "driving"
                ]
                
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
            let progressEventJson = String(data: progressEventJsonData, encoding: String.Encoding.ascii)
            
            _eventSink!(progressEventJson)
            
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
    
    
    
    public func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        if(canceled)
        {
            stopHistoryRecording()
            sendEvent(eventType: MapBoxEventType.navigation_cancelled)
        }
        endNavigation(result: nil)
    }
    
    public func navigationViewController(_ navigationViewController: NavigationViewController, shouldRerouteFrom location: CLLocation) -> Bool {
        return _shouldReRoute
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
                navigationMode: historyData["navigationMode"] as? String
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
        return historyList
    }
    
    /**
     * 删除指定的历史记录
     */
    func deleteHistoryRecord(historyId: String) -> Bool {
        var historyList = getHistoryList()
        if let index = historyList.firstIndex(where: { $0.id == historyId }) {
            let record = historyList[index]
            
            // 删除文件
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: record.historyFilePath) {
                try? fileManager.removeItem(atPath: record.historyFilePath)
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
            if fileManager.fileExists(atPath: record.historyFilePath) {
                try? fileManager.removeItem(atPath: record.historyFilePath)
            }
        }
        
        // 清空列表
        return saveHistoryList([])
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
}
