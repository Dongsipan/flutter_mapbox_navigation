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
            
            // 配置历史记录目录（根据官方示例）
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let historyDirectoryURL = documentsPath.appendingPathComponent("NavigationHistory")
            
            // 确保目录存在
            if !FileManager.default.fileExists(atPath: historyDirectoryURL.path) {
                try? FileManager.default.createDirectory(
                    at: historyDirectoryURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            
            let coreConfig = CoreConfig(
                locationSource: locationSource,
                historyRecordingConfig: HistoryRecordingConfig(historyDirectoryURL: historyDirectoryURL)
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
                // 保存历史记录信息
                self.saveHistoryRecord(filePath: historyFileUrl.path)
            }
        }
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
     * 生成历史记录文件路径
     */
    func generateHistoryFilePath(historyId: String) -> String {
        let historyDir = getHistoryDirectory()
        let fileName = "navigation_history_\(historyId).json"
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
