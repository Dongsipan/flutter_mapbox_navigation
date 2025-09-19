import Flutter
import UIKit
import MapboxMaps
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation
import MapboxNavigationCore
import Foundation

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
    var _routes: [Route]?
    var _wayPointOrder = [Int:Waypoint]()
    var _wayPoints = [Waypoint]()
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
    var navigationDirections: Directions?
    private var historyManager: HistoryManager?
    
    func addWayPoints(arguments: NSDictionary?, result: @escaping FlutterResult)
    {

        guard var locations = getLocationsFromFlutterArgument(arguments: arguments) else { return }

        var nextIndex = 1
        for loc in locations
        {
            let wayPoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: loc.latitude!, longitude: loc.longitude!), name: loc.name)
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
        
        guard var locations = getLocationsFromFlutterArgument(arguments: arguments) else { return }
        
        for loc in locations
        {
            let location = Waypoint(coordinate: CLLocationCoordinate2D(latitude: loc.latitude!, longitude: loc.longitude!), name: loc.name)
            
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
        let simulationMode: SimulationMode = _simulateRoute ? .always : .never
        setNavigationOptions(wayPoints: wayPoints)
        
        Directions.shared.calculate(_options!) { [weak self](session, result) in
            guard let strongSelf = self else { return }
            switch result {
            case .failure(let error):
                strongSelf.sendEvent(eventType: MapBoxEventType.route_build_failed)
                flutterResult("An error occured while calculating the route \(error.localizedDescription)")
            case .success(let response):
                guard let routes = response.routes else { return }
                //TODO: if more than one route found, give user option to select one: DOES NOT WORK
                if(routes.count > 1 && strongSelf.ALLOW_ROUTE_SELECTION)
                {
                    //show map to select a specific route
                    strongSelf._routes = routes
                    let routeOptionsView = RouteOptionsViewController(routes: routes, options: strongSelf._options!)
                    
                    let flutterViewController = UIApplication.shared.delegate?.window??.rootViewController as! FlutterViewController
                    flutterViewController.present(routeOptionsView, animated: true, completion: nil)
                }
                else
                {
                    let navigationService = MapboxNavigationService(routeResponse: response, routeIndex: 0, routeOptions: strongSelf._options!, simulating: simulationMode)
                    var dayStyle = CustomDayStyle()
                    if(strongSelf._mapStyleUrlDay != nil){
                        dayStyle = CustomDayStyle(url: strongSelf._mapStyleUrlDay)
                    }
                    let nightStyle = CustomNightStyle()
                    if(strongSelf._mapStyleUrlNight != nil){
                        nightStyle.mapStyleURL = URL(string: strongSelf._mapStyleUrlNight!)!
                    }
                    let navigationOptions = NavigationOptions(styles: [dayStyle, nightStyle], navigationService: navigationService)
                    if (isUpdatingWaypoints) {
                        strongSelf._navigationViewController?.navigationService.router.updateRoute(with: IndexedRouteResponse(routeResponse: response, routeIndex: 0), routeOptions: strongSelf._options) { success in
                            if (success) {
                                flutterResult("true")
                            } else {
                                flutterResult("failed to add stop")
                            }
                        }
                    }
                    else {
                        strongSelf.startNavigation(routeResponse: response, options: strongSelf._options!, navOptions: navigationOptions)
                    }
                }
            }
        }
        
    }
    
    func startNavigation(routeResponse: RouteResponse, options: NavigationRouteOptions, navOptions: NavigationOptions)
    {
        isEmbeddedNavigation = false
        if(self._navigationViewController == nil)
        {
            self._navigationViewController = NavigationViewController(for: routeResponse, routeIndex: 0, routeOptions: options, navigationOptions: navOptions)
            self._navigationViewController!.modalPresentationStyle = .fullScreen
            self._navigationViewController!.delegate = self
            self._navigationViewController!.navigationMapView!.localizeLabels()
            self._navigationViewController!.showsReportFeedback = _showReportFeedbackButton
            self._navigationViewController!.showsEndOfRouteFeedback = _showEndOfRouteFeedback
        }
        let flutterViewController = UIApplication.shared.delegate?.window??.rootViewController as! FlutterViewController
        flutterViewController.present(self._navigationViewController!, animated: true, completion: nil)
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
        Directions.shared.calculate(_options!) { [weak self](session, result) in
            guard let strongSelf = self else { return }
            switch result {
            case .failure(let error):
                strongSelf.sendEvent(eventType: MapBoxEventType.route_build_failed, data: error.localizedDescription)
            case .success(let response):
                strongSelf.sendEvent(eventType: MapBoxEventType.route_built, data: strongSelf.encodeRouteResponse(response: response))
                guard let routes = response.routes else { return }
                //TODO: if more than one route found, give user option to select one: DOES NOT WORK
                if(routes.count > 1 && strongSelf.ALLOW_ROUTE_SELECTION)
                {
                    //TODO: show map to select a specific route
                    
                }
                else
                {
                    strongSelf._navigationViewController?.navigationService.start()
                }
            }
        }
        
    }
    
    func endNavigation(result: FlutterResult?)
    {
        sendEvent(eventType: MapBoxEventType.navigation_finished)
        if(self._navigationViewController != nil)
        {
            self._navigationViewController?.navigationService.endNavigation(feedback: nil)
            if(isEmbeddedNavigation)
            {
                self._navigationViewController?.view.removeFromSuperview()
                self._navigationViewController?.removeFromParent()
                self._navigationViewController = nil
            }
            else
            {
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
    
    func getLocationsFromFlutterArgument(arguments: NSDictionary?) -> [Location]? {
        
        var locations = [Location]()
        guard let oWayPoints = arguments?["wayPoints"] as? NSDictionary else {return nil}
        for item in oWayPoints as NSDictionary
        {
            let point = item.value as! NSDictionary
            guard let oName = point["Name"] as? String else {return nil }
            guard let oLatitude = point["Latitude"] as? Double else {return nil}
            guard let oLongitude = point["Longitude"] as? Double else {return nil}
            let oIsSilent = point["IsSilent"] as? Bool ?? false
            let order = point["Order"] as? Int
            let location = Location(name: oName, latitude: oLatitude, longitude: oLongitude, order: order,isSilent: oIsSilent)
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
        if historyManager == nil {
            historyManager = HistoryManager()
        }
        
        do {
            let historyList = historyManager!.getHistoryList()
            let historyMaps = historyList.map { history in
                [
                    "id": history.id,
                    "historyFilePath": history.historyFilePath,
                    "startTime": history.startTime.timeIntervalSince1970 * 1000, // 转换为毫秒
                    "duration": history.duration,
                    "startPointName": history.startPointName ?? "",
                    "endPointName": history.endPointName ?? "",
                    "navigationMode": history.navigationMode ?? ""
                ]
            }
            result(historyMaps)
        } catch {
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
        if _enableHistoryRecording && !_isHistoryRecording {
            // 使用 Mapbox Navigation SDK 的历史记录功能
            // 根据官方示例，使用 HistoryRecording 类
            do {
                // 启动历史记录
                try HistoryRecording.startRecordingHistory()
                _isHistoryRecording = true
                _currentHistoryId = UUID().uuidString
                _historyStartTime = Date()
                print("History recording started successfully")
                sendEvent(eventType: MapBoxEventType.history_recording_started)
            } catch {
                print("Failed to start history recording: \(error.localizedDescription)")
                sendEvent(eventType: MapBoxEventType.history_recording_error, data: "Failed to start history recording: \(error.localizedDescription)")
            }
        }
    }
    
    /**
     * 停止导航历史记录
     */
    private func stopHistoryRecording() {
        if _isHistoryRecording {
            do {
                // 创建历史文件 URL
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let historyFileName = "navigation_history_\(_currentHistoryId ?? UUID().uuidString).json"
                let historyFileURL = documentsPath.appendingPathComponent(historyFileName)
                
                // 停止记录并写入文件
                try HistoryRecording.stopRecordingHistory(writingFileWith: historyFileURL)
                
                print("History recording stopped successfully, file saved to: \(historyFileURL.path)")
                // 保存历史记录信息
                saveHistoryRecord(filePath: historyFileURL.path)
                sendEvent(eventType: MapBoxEventType.history_recording_stopped, data: historyFileURL.path)
                
                _isHistoryRecording = false
                _currentHistoryId = nil
                _historyStartTime = nil
            } catch {
                print("Failed to stop history recording: \(error.localizedDescription)")
                sendEvent(eventType: MapBoxEventType.history_recording_error, data: "Failed to stop history recording: \(error.localizedDescription)")
                _isHistoryRecording = false
                _currentHistoryId = nil
                _historyStartTime = nil
            }
        }
    }
    
    /**
     * 保存历史记录信息
     */
    private func saveHistoryRecord(filePath: String) {
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filePath) {
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
                
                let success = historyManager!.saveHistoryRecord(historyData: historyData)
                if !success {
                    sendEvent(eventType: MapBoxEventType.history_recording_error, data: "Failed to save history record to database")
                } else {
                    print("History record saved successfully: \(historyData)")
                }
            }
        } catch {
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
            var historyList = getHistoryList()
            let historyRecord = HistoryRecord(
                id: historyData["id"] as? String ?? UUID().uuidString,
                historyFilePath: historyData["filePath"] as? String ?? "",
                startTime: Date(timeIntervalSince1970: historyData["startTime"] as? TimeInterval ?? 0),
                duration: historyData["duration"] as? Int ?? 0,
                startPointName: historyData["startPointName"] as? String,
                endPointName: historyData["endPointName"] as? String,
                navigationMode: historyData["navigationMode"] as? String
            )
            
            historyList.append(historyRecord)
            return saveHistoryList(historyList)
        } catch {
            return false
        }
    }
    
    /**
     * 获取历史记录列表
     */
    func getHistoryList() -> [HistoryRecord] {
        guard let data = userDefaults.data(forKey: historyKey),
              let historyList = try? JSONDecoder().decode([HistoryRecord].self, from: data) else {
            return []
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
            let data = try JSONEncoder().encode(historyList)
            userDefaults.set(data, forKey: historyKey)
            return true
        } catch {
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
