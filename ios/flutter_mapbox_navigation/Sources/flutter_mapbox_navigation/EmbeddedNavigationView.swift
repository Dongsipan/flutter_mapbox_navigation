import Flutter
import UIKit
import MapboxMaps
import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit
import Combine

public class FlutterMapboxNavigationView : NavigationFactory, FlutterPlatformView
{
    let frame: CGRect
    let viewId: Int64

    let messenger: FlutterBinaryMessenger
    let channel: FlutterMethodChannel
    let eventChannel: FlutterEventChannel

    var navigationMapView: NavigationMapView?
    // Persistent container view returned to Flutter; we add subviews into this
    var containerView: UIView = UIView()
    var arguments: NSDictionary?

    var navigationRoutes: NavigationRoutes?
    var routeResponse: RouteResponse?
    var selectedRouteIndex = 0
    var routeOptions: NavigationRouteOptions?

    var _mapInitialized = false;
    var locationManager = CLLocationManager()

    init(messenger: FlutterBinaryMessenger, frame: CGRect, viewId: Int64, args: Any?)
    {
        self.frame = frame
        self.viewId = viewId
        self.arguments = args as! NSDictionary?

        // Initialize persistent container
        self.containerView = UIView(frame: frame)
        self.containerView.backgroundColor = UIColor.lightGray

        self.messenger = messenger
        self.channel = FlutterMethodChannel(name: "flutter_mapbox_navigation/\(viewId)", binaryMessenger: messenger)
        self.eventChannel = FlutterEventChannel(name: "flutter_mapbox_navigation/\(viewId)/events", binaryMessenger: messenger)

        super.init()

        self.eventChannel.setStreamHandler(self)

        self.channel.setMethodCallHandler { [weak self](call, result) in

            guard let strongSelf = self else { return }

            let arguments = call.arguments as? NSDictionary

            if(call.method == "getPlatformVersion")
            {
                result("iOS " + UIDevice.current.systemVersion)
            }
            else if(call.method == "buildRoute")
            {
                strongSelf.buildRoute(arguments: arguments, flutterResult: result)
            }
            else if(call.method == "clearRoute")
            {
                strongSelf.clearRoute(arguments: arguments, result: result)
            }
            else if(call.method == "getDistanceRemaining")
            {
                result(strongSelf._distanceRemaining)
            }
            else if(call.method == "getDurationRemaining")
            {
                result(strongSelf._durationRemaining)
            }
            else if(call.method == "finishNavigation")
            {
                strongSelf.endNavigation(result: result)
            }
            else if(call.method == "startFreeDrive")
            {
                strongSelf.startEmbeddedFreeDrive(arguments: arguments, result: result)
            }
            else if(call.method == "startNavigation")
            {
                strongSelf.startEmbeddedNavigation(arguments: arguments, result: result)
            }
            else if(call.method == "reCenter"){
                //used to recenter map from user action during navigation
                Task { @MainActor in
                    // Use direct camera control instead of moveToFollowPuck
                    guard let mapView = strongSelf.navigationMapView else { return }
                    let cameraOptions = CameraOptions(
                        center: mapView.mapView.cameraState.center,
                        zoom: 15.0,
                        pitch: 15
                    )
                    mapView.mapView.camera.ease(to: cameraOptions, duration: 1.0)
                }
            }
            else
            {
                result("method is not implemented");
            }

        }
    }

    public func view() -> UIView
    {
        if !_mapInitialized {
            // Setup map view on main actor asynchronously (only once)
            Task { @MainActor in
                await setupMapViewAsync()
            }
        }
        return containerView
    }

    
    @MainActor
    private func setupMapView()
    {
        // Create publishers for location and route progress
        let locationProvider = AppleLocationProvider()
        let locationPublisher = locationProvider.onLocationUpdate
            .compactMap { locations -> CLLocation? in
                guard let location = locations.first else { return nil }
                return CLLocation(
                    coordinate: location.coordinate,
                    altitude: location.altitude ?? 0.0,
                    horizontalAccuracy: location.horizontalAccuracy ?? 0.0,
                    verticalAccuracy: location.verticalAccuracy ?? 0.0,
                    course: location.bearing ?? -1.0,
                    speed: location.speed ?? 0.0,
                    timestamp: location.timestamp
                )
            }
            .eraseToAnyPublisher()

        let routeProgressPublisher = Just<RouteProgress?>(nil)
            .eraseToAnyPublisher()

        // Initialize NavigationMapView with required publishers synchronously
        navigationMapView = NavigationMapView(
            location: locationPublisher,
            routeProgress: routeProgressPublisher
        )
        navigationMapView?.delegate = self
    }

    @MainActor
    private func setupMapViewAsync() async {
        setupMapView()

        if(self.arguments != nil)
        {

            parseFlutterArguments(arguments: arguments)

            if(_mapStyleUrlDay != nil)
            {
                navigationMapView?.mapView.mapboxMap.style.uri = StyleURI.init(url: URL(string: _mapStyleUrlDay!)!)
            }

            var currentLocation: CLLocation!

            locationManager.requestWhenInUseAuthorization()

            if(CLLocationManager.authorizationStatus() == .authorizedWhenInUse ||
                CLLocationManager.authorizationStatus() == .authorizedAlways) {
                currentLocation = locationManager.location

            }

            let initialLatitude = arguments?["initialLatitude"] as? Double ?? currentLocation?.coordinate.latitude
            let initialLongitude = arguments?["initialLongitude"] as? Double ?? currentLocation?.coordinate.longitude
            if(initialLatitude != nil && initialLongitude != nil)
            {
                moveCameraToCoordinates(latitude: initialLatitude!, longitude: initialLongitude!)
            }

        }

        if _longPressDestinationEnabled
        {
            let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            gesture.delegate = self
            navigationMapView?.addGestureRecognizer(gesture)
        }
        
        if _enableOnMapTapCallback {
            let onTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            onTapGesture.numberOfTapsRequired = 1
            onTapGesture.delegate = self
            navigationMapView?.addGestureRecognizer(onTapGesture)
        }

        // Add the map view into the persistent container and pin constraints
        if let mapView = navigationMapView, !_mapInitialized {
            mapView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(mapView)
            constraintsWithPaddingBetween(holderView: containerView, topView: mapView, padding: 0.0)
            _mapInitialized = true
        }
    }

    func clearRoute(arguments: NSDictionary?, result: @escaping FlutterResult)
    {
        if navigationRoutes == nil
        {
            return
        }
        if (mapboxNavigation != nil) {
            // In v3, navigation is stopped differently
            Task { @MainActor in
                // In v3, we use setToIdle to stop navigation
                mapboxNavigation?.tripSession().setToIdle()
            }
        }
        Task { @MainActor in
            navigationMapView?.removeRoutes()
        }
        navigationRoutes = nil
        sendEvent(eventType: MapBoxEventType.navigation_cancelled)
    }

    func buildRoute(arguments: NSDictionary?, flutterResult: @escaping FlutterResult)
    {
        _wayPoints.removeAll()
        isEmbeddedNavigation = true
        sendEvent(eventType: MapBoxEventType.route_building)

        guard let oWayPoints = arguments?["wayPoints"] as? NSDictionary else {return}

        var locations = [Location]()

        for item in oWayPoints as NSDictionary
        {
            let point = item.value as! NSDictionary
            guard let oName = point["Name"] as? String else {return}
            guard let oLatitude = point["Latitude"] as? Double else {return}
            guard let oLongitude = point["Longitude"] as? Double else {return}
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


        for loc in locations
        {
            var location = Waypoint(coordinate: CLLocationCoordinate2D(latitude: loc.latitude!, longitude: loc.longitude!),
                                    coordinateAccuracy: -1, name: loc.name)
            location.separatesLegs = !loc.isSilent
            _wayPoints.append(location)
        }

        parseFlutterArguments(arguments: arguments)
        
        if(_wayPoints.count > 3 && arguments?["mode"] == nil)
        {
            _navigationMode = "driving"
        }

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

        let routeOptions = NavigationRouteOptions(waypoints: _wayPoints, profileIdentifier: mode)

        if (_allowsUTurnAtWayPoints != nil)
        {
            routeOptions.allowsUTurnAtWaypoint = _allowsUTurnAtWayPoints!
        }

        routeOptions.distanceMeasurementSystem = _voiceUnits == "imperial" ? .imperial : .metric
        routeOptions.locale = Locale(identifier: _language)
        routeOptions.includesAlternativeRoutes = _alternatives
        self.routeOptions = routeOptions

        // Generate the route object and draw it on the map using v3 API
        _ = Directions.shared.calculate(routeOptions) { [weak self] (result: Result<RouteResponse, DirectionsError>) in

            guard case let .success(response) = result, let strongSelf = self else {
                flutterResult(false)
                self?.sendEvent(eventType: MapBoxEventType.route_build_failed)
                return
            }

            // Convert RouteResponse to NavigationRoutes for v3
            Task {
                do {
                    // Create NavigationRoutes from the first route in the response
                    guard let firstRoute = response.routes?.first else {
                        DispatchQueue.main.async {
                            flutterResult(false)
                            strongSelf.sendEvent(eventType: MapBoxEventType.route_build_failed)
                        }
                        return
                    }

                    // Store the response for later use
                    strongSelf.routeResponse = response
                    DispatchQueue.main.async {
                        // Store the response for later use
                        strongSelf.routeResponse = response
                        strongSelf.sendEvent(eventType: MapBoxEventType.route_built, data: strongSelf.encodeRouteResponse(response: response))

                        // In v3, we need to use RoutingProvider to get NavigationRoutes
                        if let routes = response.routes, !routes.isEmpty {
                            Task { @MainActor in
                                // Initialize MapboxNavigation if not already done
                                if strongSelf.mapboxNavigation == nil {
                                    let locationSource: LocationSource = strongSelf._simulateRoute ? .simulation() : .live
                                    let coreConfig = CoreConfig(locationSource: locationSource)
                                    // 使用全局单例管理器，避免重复实例化
                                    let mapboxNavigationProvider = MapboxNavigationManager.shared.getOrCreateProvider(coreConfig: coreConfig)
                                    strongSelf.mapboxNavigation = mapboxNavigationProvider.mapboxNavigation
                                    strongSelf.mapboxNavigationProvider = mapboxNavigationProvider
                                }

                                // Use RoutingProvider to get NavigationRoutes
                                if let mapboxNavigation = strongSelf.mapboxNavigation,
                                   let routeOptions = strongSelf.routeOptions {
                                    let request = mapboxNavigation.routingProvider().calculateRoutes(options: routeOptions)

                                    switch await request.result {
                                    case .success(let navigationRoutes):
                                        // Save for starting embedded navigation later
                                        strongSelf.navigationRoutes = navigationRoutes
                                        strongSelf.navigationMapView?.showcase(
                                            navigationRoutes,
                                            routesPresentationStyle: .all(shouldFit: true),
                                            routeAnnotationKinds: [.relativeDurationsOnAlternative],
                                            animated: true,
                                            duration: 1.0
                                        )
                                    case .failure(_):
                                        // Fallback: just show the routes without showcase
                                        break
                                    }
                                }
                            }
                        }
                        flutterResult(true)
                    }
                } catch {
                    DispatchQueue.main.async {
                        flutterResult(false)
                        strongSelf.sendEvent(eventType: MapBoxEventType.route_build_failed)
                    }
                }
            }
        }
    }

    func startEmbeddedFreeDrive(arguments: NSDictionary?, result: @escaping FlutterResult) {
        Task { @MainActor in
            // In v3, we use AppleLocationProvider for free drive mode
            let locationProvider = AppleLocationProvider()
            navigationMapView?.mapView.location.override(locationProvider: locationProvider)

            navigationMapView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            navigationMapView?.puckType = .puck2D()

            // Use direct camera control instead of viewport data source
            guard let mapView = navigationMapView else {
                result(false)
                return
            }
            let cameraOptions = CameraOptions(
                center: mapView.mapView.cameraState.center,
                zoom: _zoom,
                pitch: 15
            )
            mapView.mapView.camera.ease(to: cameraOptions, duration: 1.0)
            result(true)
        }
    }

    func startEmbeddedNavigation(arguments: NSDictionary?, result: @escaping FlutterResult) {
        guard let navigationRoutes = self.navigationRoutes else {
            result(false)
            return
        }

        // Initialize MapboxNavigation with v3 API using singleton manager
        let locationSource: LocationSource = _simulateRoute ? .simulation() : .live
        let coreConfig = CoreConfig(locationSource: locationSource)
        // 使用全局单例管理器，避免重复实例化
        let mapboxNavigationProvider = MapboxNavigationManager.shared.getOrCreateProvider(coreConfig: coreConfig)
        self.mapboxNavigationProvider = mapboxNavigationProvider

        Task { @MainActor in
            mapboxNavigation = mapboxNavigationProvider.mapboxNavigation
            guard let mapboxNavigation = mapboxNavigation else {
                result(false)
                return
            }

            // Start navigation session with routes
            mapboxNavigation.tripSession().startActiveGuidance(with: navigationRoutes, startLegIndex: 0)
        }

        // Set up navigation event listeners
        setupNavigationEventListeners()

        // Remove previous navigation view and controller if any
        if(_navigationViewController?.view != nil){
            _navigationViewController!.view.removeFromSuperview()
            _navigationViewController?.removeFromParent()
        }

        // In v3, NavigationViewController initialization is different
        var dayStyle = CustomDayStyle()
        if(_mapStyleUrlDay != nil){
            dayStyle = CustomDayStyle(url: _mapStyleUrlDay)
        }
        var nightStyle = CustomNightStyle()
        if(_mapStyleUrlNight != nil){
            nightStyle = CustomNightStyle(url: _mapStyleUrlNight)
        }

        // Create NavigationViewController with v3 API and embed it into mapView
        Task { @MainActor in
            // 确保使用现有的 mapboxNavigation 实例，避免创建新的 provider
            guard let mapboxNavigation = self.mapboxNavigation,
                  let mapboxNavigationProvider = self.mapboxNavigationProvider else {
                print("❌ Error: mapboxNavigation or mapboxNavigationProvider is nil")
                result(false)
                return
            }
            
            let navigationOptions = NavigationOptions(
                mapboxNavigation: mapboxNavigation,
                voiceController: mapboxNavigationProvider.routeVoiceController,
                eventsManager: mapboxNavigation.eventsManager()
            )
            _navigationViewController = NavigationViewController(
                navigationRoutes: navigationRoutes,
                navigationOptions: navigationOptions
            )
            _navigationViewController!.delegate = self

            // Add as child to Flutter root and embed into our map view
            let flutterViewController = UIApplication.shared.delegate?.window?!.rootViewController as! FlutterViewController
            flutterViewController.addChild(_navigationViewController!)

            guard let mapView = self.navigationMapView else {
                result(false)
                return
            }
            mapView.addSubview(_navigationViewController!.view)
            _navigationViewController!.view.translatesAutoresizingMaskIntoConstraints = false
            constraintsWithPaddingBetween(holderView: mapView, topView: _navigationViewController!.view, padding: 0.0)
            // Notify child controller moved to parent
            _navigationViewController!.didMove(toParent: flutterViewController)
            result(true)
        }

    }

    func constraintsWithPaddingBetween(holderView: UIView, topView: UIView, padding: CGFloat) {
        guard holderView.subviews.contains(topView) else {
            return
        }
        topView.translatesAutoresizingMaskIntoConstraints = false
        let pinTop = NSLayoutConstraint(item: topView, attribute: .top, relatedBy: .equal,
                                        toItem: holderView, attribute: .top, multiplier: 1.0, constant: padding)
        let pinBottom = NSLayoutConstraint(item: topView, attribute: .bottom, relatedBy: .equal,
                                           toItem: holderView, attribute: .bottom, multiplier: 1.0, constant: padding)
        let pinLeft = NSLayoutConstraint(item: topView, attribute: .left, relatedBy: .equal,
                                         toItem: holderView, attribute: .left, multiplier: 1.0, constant: padding)
        let pinRight = NSLayoutConstraint(item: topView, attribute: .right, relatedBy: .equal,
                                          toItem: holderView, attribute: .right, multiplier: 1.0, constant: padding)
        holderView.addConstraints([pinTop, pinBottom, pinLeft, pinRight])
    }

    func moveCameraToCoordinates(latitude: Double, longitude: Double) {
        Task { @MainActor in
            guard let mapView = navigationMapView else { return }
            let cameraOptions = CameraOptions(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                zoom: _zoom,
                bearing: _bearing,
                pitch: 15
            )
            mapView.mapView.camera.ease(to: cameraOptions, duration: 1.0)
        }
    }

    func moveCameraToCenter()
    {
        var duration = 5.0
        if(!_animateBuildRoute)
        {
            duration = 0.0
        }

        Task { @MainActor [duration] in
            guard let mapView = navigationMapView else { return }
            let cameraOptions = CameraOptions(
                center: mapView.mapView.cameraState.center,
                zoom: 13.0,
                pitch: 15
            )
            mapView.mapView.camera.ease(to: cameraOptions, duration: duration)
        }

        // Create a camera that rotates around the same center point, rotating 180°.
        // `fromDistance:` is meters above mean sea level that an eye would have to be in order to see what the map view is showing.
        //let camera = NavigationCamera( Camera(lookingAtCenter: mapView.centerCoordinate, altitude: 2500, pitch: 15, heading: 180)

        // Animate the camera movement over 5 seconds.
        //navigationMapView.mapView.mapboxMap.setCamera(to: CameraOptions(center: navigationMapView.mapView.ma, zoom: 13.0))
                                       //(camera, withDuration: duration, animationTimingFunction: CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut))
    }

}

// NavigationServiceDelegate has been removed in v3
// Navigation events are now handled through Combine publishers
extension FlutterMapboxNavigationView {

    // This method will be called to set up navigation event listeners using v3 API
    func setupNavigationEventListeners() {
        guard let mapboxNavigation = mapboxNavigation else { return }

        // In v3, we subscribe to navigation events using Combine
        // This is a placeholder - actual implementation would use Combine publishers
        // mapboxNavigation.tripSession().routeProgress
        //     .sink { [weak self] progress in
        //         self?.handleRouteProgress(progress)
        //     }
        //     .store(in: &cancellables)
    }

    private func handleRouteProgress(_ progress: RouteProgress) {
        // Handle route progress updates
        _distanceRemaining = progress.distanceRemaining
        _durationRemaining = progress.durationRemaining
        sendEvent(eventType: MapBoxEventType.navigation_running)

        if(_eventSink != nil)
        {
            let jsonEncoder = JSONEncoder()

            let progressEvent = MapBoxRouteProgressEvent(progress: progress)
            let progressEventJsonData = try! jsonEncoder.encode(progressEvent)
            let progressEventJson = String(data: progressEventJsonData, encoding: String.Encoding.ascii)

            _eventSink!(progressEventJson)

            if(progress.isFinalLeg && progress.currentLegProgress.userHasArrivedAtWaypoint)
            {
                _eventSink = nil
            }
        }
    }
}

extension FlutterMapboxNavigationView : NavigationMapViewDelegate {

//    public func mapView(_ mapView: NavigationMapView, didFinishLoading style: Style) {
//        _mapInitialized = true
//        sendEvent(eventType: MapBoxEventType.map_ready)
//    }

    public func navigationMapView(_ mapView: NavigationMapView, didSelect route: Route) {
        // In v3, we need to find the route index from NavigationRoutes
        if let navigationRoutes = self.navigationRoutes {
            // For now, we'll use the main route index
            self.selectedRouteIndex = 0
            // TODO: Implement proper route selection logic for v3
            Task { @MainActor in
                mapView.show(navigationRoutes, routeAnnotationKinds: [])
            }
        }
    }

    public func mapViewDidFinishLoadingMap(_ mapView: NavigationMapView) {
        // Wait for the map to load before initiating the first camera movement.
        moveCameraToCenter()
    }

}

extension FlutterMapboxNavigationView : UIGestureRecognizerDelegate {
            
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .ended else { return }
        Task { @MainActor in
            guard let mapView = navigationMapView else { return }
            let location = mapView.mapView.mapboxMap.coordinate(for: gesture.location(in: mapView.mapView))
            requestRoute(destination: location)
        }
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else {return}
        Task { @MainActor in
            guard let mapView = navigationMapView else { return }
            let location = mapView.mapView.mapboxMap.coordinate(for: gesture.location(in: mapView.mapView))
        let waypoint: Encodable = [
            "latitude" : location.latitude,
            "longitude" : location.longitude,
        ]
        do {
            let encodedData = try JSONEncoder().encode(waypoint)
            let jsonString = String(data: encodedData,
                                    encoding: .utf8)
            
            if (jsonString?.isEmpty ?? true) {
                return
            }
            
            sendEvent(eventType: .on_map_tap,data: jsonString!)
        } catch {
            return
        }
        }
    }

    func requestRoute(destination: CLLocationCoordinate2D) {
        isEmbeddedNavigation = true
        sendEvent(eventType: MapBoxEventType.route_building)

        Task { @MainActor in
            guard let mapView = navigationMapView,
                  let userLocation = mapView.mapView.location.latestLocation else { return }
        let location = CLLocation(latitude: userLocation.coordinate.latitude,
                                  longitude: userLocation.coordinate.longitude)
        let userWaypoint = Waypoint(location: location, name: "Current Location")
        let destinationWaypoint = Waypoint(coordinate: destination)

        let routeOptions = NavigationRouteOptions(waypoints: [userWaypoint, destinationWaypoint])

        Directions.shared.calculate(routeOptions) { [weak self] (result: Result<RouteResponse, DirectionsError>) in

            if let strongSelf = self {

                switch result {
                case .failure(let error):
                    print(error.localizedDescription)
                    strongSelf.sendEvent(eventType: MapBoxEventType.route_build_failed)
                case .success(let response):
                    guard let routes = response.routes, let route = response.routes?.first else {
                        strongSelf.sendEvent(eventType: MapBoxEventType.route_build_failed)
                        return
                    }

                    // Convert RouteResponse to NavigationRoutes for v3
                    Task {
                        do {
                            // Store the response for later use
                            strongSelf.routeResponse = response
                            DispatchQueue.main.async {
                                // Store the response for later use
                                strongSelf.routeResponse = response
                                strongSelf.sendEvent(eventType: MapBoxEventType.route_built, data: strongSelf.encodeRouteResponse(response: response))
                                strongSelf.routeOptions = routeOptions

                                // Show routes using the response
                                if let routes = response.routes, !routes.isEmpty {
                                    Task { @MainActor in
                                        // Initialize MapboxNavigation if not already done
                                        if strongSelf.mapboxNavigation == nil {
                                            let locationSource: LocationSource = strongSelf._simulateRoute ? .simulation() : .live
                                            let coreConfig = CoreConfig(locationSource: locationSource)
                                            // 使用全局单例管理器，避免重复实例化
                                            let mapboxNavigationProvider = MapboxNavigationManager.shared.getOrCreateProvider(coreConfig: coreConfig)
                                            strongSelf.mapboxNavigation = mapboxNavigationProvider.mapboxNavigation
                                            strongSelf.mapboxNavigationProvider = mapboxNavigationProvider
                                        }

                                        // Use RoutingProvider to get NavigationRoutes
                                        if let mapboxNavigation = strongSelf.mapboxNavigation {
                                            let request = mapboxNavigation.routingProvider().calculateRoutes(options: routeOptions)

                                            switch await request.result {
                                            case .success(let navigationRoutes):
                                                // Save for starting embedded navigation later
                                                strongSelf.navigationRoutes = navigationRoutes
                                                strongSelf.navigationMapView?.showcase(
                                                    navigationRoutes,
                                                    routesPresentationStyle: .all(shouldFit: true),
                                                    routeAnnotationKinds: [.relativeDurationsOnAlternative],
                                                    animated: true,
                                                    duration: 1.0
                                                )
                                            case .failure(_):
                                                // Fallback: just show the routes without showcase
                                                break
                                            }
                                        }
                                    }
                                }
                            }
                        } catch {
                            DispatchQueue.main.async {
                                strongSelf.sendEvent(eventType: MapBoxEventType.route_build_failed)
                            }
                        }
                    }
                }

            }


        }
        }
    }

}
