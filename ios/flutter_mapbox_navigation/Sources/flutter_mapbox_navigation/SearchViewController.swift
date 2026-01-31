import Flutter
import UIKit
import MapboxSearch
import MapboxSearchUI
import MapboxMaps
import CoreLocation

public class SearchViewController: NSObject, FlutterPlugin {

    private var methodChannel: FlutterMethodChannel?
    private var currentResultCallback: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        // This method is required by FlutterPlugin but not used in our case
        // since we register manually in the main plugin
    }

    public init(methodChannel: FlutterMethodChannel) {
        super.init()
        self.methodChannel = methodChannel
    }
    
    private func getMapboxAccessToken() -> String? {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let token = plist["MBXAccessToken"] as? String {
            return token
        }
        return nil
    }

    // MARK: - Flutter Method Handlers

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "showSearchView":
            showSearchView(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Search Methods
    
    private func showSearchView(call: FlutterMethodCall, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
                result(FlutterError(code: "NO_ROOT_CONTROLLER", message: "No root view controller found", details: nil))
                return
            }
            
            let searchMapViewController = SearchMapViewController()
            searchMapViewController.onLocationSelected = { [weak self] location in
                // 返回wayPoints数组数据
                if let wayPoints = location.wayPoints as? [[String: Any]] {
                    result(wayPoints)
                } else {
                    // 兜底：返回单个waypoint格式的数据
                    let waypointData: [String: Any] = [
                        "name": location.name,
                        "latitude": location.coordinate.latitude,
                        "longitude": location.coordinate.longitude,
                        "isSilent": false,
                        "address": location.address ?? ""
                    ]
                    result([waypointData])
                }
            }
            
            let navController = UINavigationController(rootViewController: searchMapViewController)
            rootViewController.present(navController, animated: true)
        }
    }
}

// MARK: - SearchMapViewController

class SearchMapViewController: UIViewController {

    private lazy var searchController: MapboxSearchController = {
        // Create custom theme
        let customStyle = Style(
            primaryTextColor: UIColor(hex: "#01E47C"),
            primaryBackgroundColor: UIColor(hex: "#040608"),
            secondaryBackgroundColor: UIColor(hex: "#0A0C0E"),
            separatorColor: UIColor(hex: "#01E47C", alpha: 0.2),
            primaryAccentColor: UIColor(hex: "#01E47C"),
            primaryInactiveElementColor: UIColor(hex: "#A0A0A0"),
            panelShadowColor: UIColor.black.withAlphaComponent(0.3),
            panelHandlerColor: UIColor(hex: "#01E47C", alpha: 0.5),
            iconTintColor: UIColor(hex: "#01E47C"),
            activeSegmentTitleColor: UIColor(hex: "#01E47C")
        )
        
        // Create Configuration with custom style
        var config = Configuration()
        config.style = customStyle
        
        print("🎨 Search UI: Applied custom theme #01E47C")
        
        return MapboxSearchController(apiType: .searchBox, configuration: config)
    }()
    private var mapView = MapView(frame: .zero)
    lazy var annotationsManager = mapView.annotations.makePointAnnotationManager()

    // 底部抽屉相关属性
    private var bottomDrawerView: UIView!
    private var bottomDrawerHeightConstraint: NSLayoutConstraint!
    private var isDrawerVisible = false
    private var selectedSearchResult: SearchResult?

    var onLocationSelected: ((SelectedLocation) -> Void)?
    
    struct SelectedLocation {
        let name: String
        let address: String?
        let coordinate: CLLocationCoordinate2D
        let wayPoints: Any?

        init(name: String, address: String?, coordinate: CLLocationCoordinate2D, wayPoints: Any? = nil) {
            self.name = name
            self.address = address
            self.coordinate = coordinate
            self.wayPoints = wayPoints
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupMapView()
        setupSearchController()
        setupBottomDrawer()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(hex: "#040608")
        title = "Search Location"
        
        // 设置导航栏主题色
        if let navigationBar = navigationController?.navigationBar {
            navigationBar.tintColor = UIColor(hex: "#01E47C")
            navigationBar.titleTextAttributes = [
                .foregroundColor: UIColor(hex: "#01E47C")
            ]
        }
        
        // 添加取消按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        // 添加位置按钮
        let locationButton = UIBarButtonItem(
            image: UIImage(systemName: "location"),
            style: .plain,
            target: self,
            action: #selector(locationTapped)
        )
        navigationItem.rightBarButtonItem = locationButton
    }
    
    private func setupMapView() {
        // 设置地图视图
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        
        // 显示用户位置
        mapView.location.options.puckType = .puck2D()
        mapView.viewport.transition(to: mapView.viewport.makeFollowPuckViewportState())

        // 注释管理器已经通过lazy var创建，这里不需要重新创建
        print("📍 Using existing annotations manager: \(annotationsManager)")

        // 添加点击手势来隐藏抽屉
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(mapViewTapped))
        mapView.addGestureRecognizer(tapGesture)
    }
    
    private func setupSearchController() {
        searchController.delegate = self
        
        // 添加 MapboxSearchUI 到地图上方
        let panelController = MapboxPanelController(rootViewController: searchController)
        addChild(panelController)
        
        // 使用 UIAppearance 强制设置主题色（备用方案）
        applySearchUITheme()
        
        // 请求位置权限
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func applySearchUITheme() {
        // 设置全局 tintColor 为主题色
        if let searchView = searchController.view {
            searchView.tintColor = UIColor(hex: "#01E47C")
        }
        
        // 使用 UIAppearance 设置 Search UI 内部控件的颜色
        UISegmentedControl.appearance(whenContainedInInstancesOf: [MapboxSearchController.self]).selectedSegmentTintColor = UIColor(hex: "#01E47C")
        UISegmentedControl.appearance(whenContainedInInstancesOf: [MapboxSearchController.self]).setTitleTextAttributes([
            .foregroundColor: UIColor.white  // 选中状态文字改为白色
        ], for: .selected)
        UISegmentedControl.appearance(whenContainedInInstancesOf: [MapboxSearchController.self]).setTitleTextAttributes([
            .foregroundColor: UIColor(hex: "#01E47C")
        ], for: .normal)
        
        // 设置搜索结果列表中的距离标签颜色（次要信息）
        UILabel.appearance(whenContainedInInstancesOf: [MapboxSearchController.self]).textColor = UIColor(hex: "#A0A0A0")
        
        // 设置搜索结果列表中的图标颜色（次要信息）
        UIImageView.appearance(whenContainedInInstancesOf: [MapboxSearchController.self]).tintColor = UIColor(hex: "#A0A0A0")
        
        // 延迟执行，确保视图已加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateSearchResultsTextColor()
        }
        
        print("🎨 Search UI: 应用 UIAppearance 主题色")
    }
    
    private func updateSearchResultsTextColor() {
        // 递归遍历 searchController 的所有子视图，找到距离标签、图标并设置颜色
        func updateLabels(in view: UIView) {
            for subview in view.subviews {
                if let label = subview as? UILabel {
                    // 检查是否是距离标签（包含 "mi" 或 "km"）
                    if let text = label.text, (text.contains("mi") || text.contains("km")) {
                        label.textColor = UIColor(hex: "#A0A0A0")
                        print("🎨 更新距离标签颜色: \(text)")
                    }
                    // 检查是否是地址标签（通常字体较小）
                    else if let font = label.font, font.pointSize < 15 {
                        label.textColor = UIColor(hex: "#A0A0A0")
                    }
                }
                // 处理图标 - 设置为浅灰色
                else if let imageView = subview as? UIImageView {
                    // 检查是否是搜索结果的图标（通常是 24x24 或类似尺寸）
                    if imageView.frame.width <= 30 && imageView.frame.height <= 30 {
                        imageView.tintColor = UIColor(hex: "#A0A0A0")
                        print("🎨 更新图标颜色: \(imageView.frame.size)")
                    }
                }
                // 递归处理子视图
                updateLabels(in: subview)
            }
        }
        
        updateLabels(in: searchController.view)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func locationTapped() {
        // 重新启用位置跟踪
        mapView.viewport.transition(to: mapView.viewport.makeFollowPuckViewportState())
    }

    @objc private func mapViewTapped() {
        // 点击地图时隐藏抽屉
        if isDrawerVisible {
            hideBottomDrawer()
        }
    }

    // MARK: - 底部抽屉设置

    private func setupBottomDrawer() {
        // 创建底部抽屉容器
        bottomDrawerView = UIView()
        bottomDrawerView.backgroundColor = UIColor(hex: "#0A0C0E")  // 使用主题背景色
        bottomDrawerView.layer.cornerRadius = 16
        bottomDrawerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomDrawerView.layer.shadowColor = UIColor.black.cgColor
        bottomDrawerView.layer.shadowOffset = CGSize(width: 0, height: -2)
        bottomDrawerView.layer.shadowOpacity = 0.3
        bottomDrawerView.layer.shadowRadius = 8
        bottomDrawerView.clipsToBounds = true // 关键：裁剪子视图
        bottomDrawerView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(bottomDrawerView)

        // 设置约束
        bottomDrawerHeightConstraint = bottomDrawerView.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            bottomDrawerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomDrawerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomDrawerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomDrawerHeightConstraint
        ])

        setupDrawerContent()
    }

    private func setupDrawerContent() {
        // Drag indicator
        let dragIndicator = UIView()
        dragIndicator.backgroundColor = UIColor(hex: "#01E47C", alpha: 0.5)
        dragIndicator.layer.cornerRadius = 2.5
        dragIndicator.translatesAutoresizingMaskIntoConstraints = false
        bottomDrawerView.addSubview(dragIndicator)

        // Main content stack
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        bottomDrawerView.addSubview(contentStack)

        // Top container (icon + name + distance)
        let topContainer = UIView()
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Location icon
        let locationIcon = UIImageView(image: UIImage(systemName: "mappin.circle.fill"))
        locationIcon.tintColor = UIColor(hex: "#01E47C")
        locationIcon.contentMode = .scaleAspectFit
        locationIcon.translatesAutoresizingMaskIntoConstraints = false
        topContainer.addSubview(locationIcon)
        
        // Location name label
        let nameLabel = UILabel()
        nameLabel.font = UIFont.boldSystemFont(ofSize: 20)
        nameLabel.numberOfLines = 2
        nameLabel.textColor = UIColor(hex: "#01E47C")
        nameLabel.tag = 100
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        topContainer.addSubview(nameLabel)
        
        // Distance label with cycling icon
        let distanceContainer = UIStackView()
        distanceContainer.axis = .horizontal
        distanceContainer.spacing = 4
        distanceContainer.alignment = .center
        distanceContainer.tag = 102
        distanceContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let bikeIcon = UIImageView(image: UIImage(systemName: "bicycle"))
        bikeIcon.tintColor = UIColor(hex: "#01E47C")
        bikeIcon.contentMode = .scaleAspectFit
        bikeIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bikeIcon.widthAnchor.constraint(equalToConstant: 16),
            bikeIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        let distanceLabel = UILabel()
        distanceLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        distanceLabel.textColor = UIColor(hex: "#01E47C")
        distanceLabel.tag = 103
        
        distanceContainer.addArrangedSubview(bikeIcon)
        distanceContainer.addArrangedSubview(distanceLabel)
        topContainer.addSubview(distanceContainer)
        
        NSLayoutConstraint.activate([
            locationIcon.leadingAnchor.constraint(equalTo: topContainer.leadingAnchor),
            locationIcon.topAnchor.constraint(equalTo: topContainer.topAnchor),
            locationIcon.widthAnchor.constraint(equalToConstant: 28),
            locationIcon.heightAnchor.constraint(equalToConstant: 28),
            
            nameLabel.leadingAnchor.constraint(equalTo: locationIcon.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: topContainer.topAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: distanceContainer.leadingAnchor, constant: -8),
            
            distanceContainer.trailingAnchor.constraint(equalTo: topContainer.trailingAnchor),
            distanceContainer.centerYAnchor.constraint(equalTo: nameLabel.firstBaselineAnchor),
            
            topContainer.bottomAnchor.constraint(equalTo: nameLabel.bottomAnchor)
        ])
        
        contentStack.addArrangedSubview(topContainer)

        // Address container (icon + address)
        let addressContainer = UIView()
        addressContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let addressIcon = UIImageView(image: UIImage(systemName: "location.fill"))
        addressIcon.tintColor = UIColor(hex: "#A0A0A0")
        addressIcon.contentMode = .scaleAspectFit
        addressIcon.translatesAutoresizingMaskIntoConstraints = false
        addressContainer.addSubview(addressIcon)
        
        let addressLabel = UILabel()
        addressLabel.font = UIFont.systemFont(ofSize: 14)
        addressLabel.textColor = UIColor(hex: "#A0A0A0")
        addressLabel.numberOfLines = 2
        addressLabel.tag = 101
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        addressContainer.addSubview(addressLabel)
        
        NSLayoutConstraint.activate([
            addressIcon.leadingAnchor.constraint(equalTo: addressContainer.leadingAnchor),
            addressIcon.topAnchor.constraint(equalTo: addressContainer.topAnchor, constant: 2),
            addressIcon.widthAnchor.constraint(equalToConstant: 16),
            addressIcon.heightAnchor.constraint(equalToConstant: 16),
            
            addressLabel.leadingAnchor.constraint(equalTo: addressIcon.trailingAnchor, constant: 8),
            addressLabel.topAnchor.constraint(equalTo: addressContainer.topAnchor),
            addressLabel.trailingAnchor.constraint(equalTo: addressContainer.trailingAnchor),
            addressLabel.bottomAnchor.constraint(equalTo: addressContainer.bottomAnchor)
        ])
        
        contentStack.addArrangedSubview(addressContainer)

        // Estimated time container (for cycling)
        let timeContainer = UIView()
        timeContainer.backgroundColor = UIColor(hex: "#01E47C", alpha: 0.1)
        timeContainer.layer.cornerRadius = 8
        timeContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let timeStack = UIStackView()
        timeStack.axis = .horizontal
        timeStack.spacing = 8
        timeStack.alignment = .center
        timeStack.translatesAutoresizingMaskIntoConstraints = false
        
        let clockIcon = UIImageView(image: UIImage(systemName: "clock.fill"))
        clockIcon.tintColor = UIColor(hex: "#01E47C")
        clockIcon.contentMode = .scaleAspectFit
        clockIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            clockIcon.widthAnchor.constraint(equalToConstant: 18),
            clockIcon.heightAnchor.constraint(equalToConstant: 18)
        ])
        
        let timeLabel = UILabel()
        timeLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        timeLabel.textColor = UIColor(hex: "#01E47C")
        timeLabel.tag = 104
        timeLabel.text = "Est. time: --"
        
        timeStack.addArrangedSubview(clockIcon)
        timeStack.addArrangedSubview(timeLabel)
        
        timeContainer.addSubview(timeStack)
        NSLayoutConstraint.activate([
            timeStack.topAnchor.constraint(equalTo: timeContainer.topAnchor, constant: 8),
            timeStack.leadingAnchor.constraint(equalTo: timeContainer.leadingAnchor, constant: 12),
            timeStack.trailingAnchor.constraint(equalTo: timeContainer.trailingAnchor, constant: -12),
            timeStack.bottomAnchor.constraint(equalTo: timeContainer.bottomAnchor, constant: -8)
        ])
        
        contentStack.addArrangedSubview(timeContainer)

        // Separator line
        let separatorLine = UIView()
        separatorLine.backgroundColor = UIColor(hex: "#01E47C", alpha: 0.15)
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(separatorLine)
        NSLayoutConstraint.activate([
            separatorLine.heightAnchor.constraint(equalToConstant: 1)
        ])

        // Start Ride button (full width)
        let startRideButton = createActionButton(
            title: "Start Ride",
            icon: "bicycle.circle.fill",
            isPrimary: true
        )
        startRideButton.addTarget(self, action: #selector(goToButtonTapped), for: .touchUpInside)
        
        contentStack.addArrangedSubview(startRideButton)
        NSLayoutConstraint.activate([
            startRideButton.heightAnchor.constraint(equalToConstant: 54)
        ])

        // Set constraints
        NSLayoutConstraint.activate([
            dragIndicator.topAnchor.constraint(equalTo: bottomDrawerView.topAnchor, constant: 8),
            dragIndicator.centerXAnchor.constraint(equalTo: bottomDrawerView.centerXAnchor),
            dragIndicator.widthAnchor.constraint(equalToConstant: 40),
            dragIndicator.heightAnchor.constraint(equalToConstant: 5),

            contentStack.topAnchor.constraint(equalTo: dragIndicator.bottomAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: bottomDrawerView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: bottomDrawerView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomDrawerView.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    // Create action button helper method
    private func createActionButton(title: String, icon: String, isPrimary: Bool) -> UIButton {
        let button = UIButton(type: .system)
        
        // Set title and icon
        button.setTitle(title, for: .normal)
        if let iconImage = UIImage(systemName: icon) {
            button.setImage(iconImage, for: .normal)
        }
        
        // Icon on left, text on right
        button.semanticContentAttribute = .forceLeftToRight
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        
        // Set corner radius
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = false
        
        if isPrimary {
            // Primary button - green background
            button.backgroundColor = UIColor(hex: "#01E47C")
            button.setTitleColor(UIColor(hex: "#040608"), for: .normal)
            button.tintColor = UIColor(hex: "#040608")
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
            
            // Add shadow
            button.layer.shadowColor = UIColor(hex: "#01E47C").cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 4)
            button.layer.shadowOpacity = 0.3
            button.layer.shadowRadius = 8
        } else {
            // Secondary button - transparent background with green border
            button.backgroundColor = UIColor.clear
            button.setTitleColor(UIColor(hex: "#01E47C"), for: .normal)
            button.tintColor = UIColor(hex: "#01E47C")
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            button.layer.borderColor = UIColor(hex: "#01E47C").cgColor
            button.layer.borderWidth = 1.5
        }
        
        button.translatesAutoresizingMaskIntoConstraints = false
        
        return button
    }

    // MARK: - 抽屉控制方法

    private func showBottomDrawer(with searchResult: SearchResult) {
        selectedSearchResult = searchResult

        // Update location name
        if let nameLabel = bottomDrawerView.viewWithTag(100) as? UILabel {
            nameLabel.text = searchResult.name
        }

        // Update address
        if let addressLabel = bottomDrawerView.viewWithTag(101) as? UILabel {
            let address = searchResult.address?.formattedAddress(style: .medium) ?? "Address unavailable"
            addressLabel.text = address
        }
        
        // Update distance (if user location available)
        let userLocation = mapView.location.latestLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let distanceInMeters = calculateDistanceInMeters(from: userLocation, to: searchResult.coordinate)
        let distanceText = formatDistance(distanceInMeters)
        
        if let distanceLabel = bottomDrawerView.viewWithTag(103) as? UILabel {
            distanceLabel.text = distanceText
        }
        
        // Calculate and update estimated cycling time
        if let timeLabel = bottomDrawerView.viewWithTag(104) as? UILabel {
            let estimatedTime = calculateCyclingTime(distanceInMeters: distanceInMeters)
            timeLabel.text = "Est. time: \(estimatedTime)"
        }

        // Show drawer - adjust height for new layout
        bottomDrawerHeightConstraint.constant = 280
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
            self.view.layoutIfNeeded()
        }

        isDrawerVisible = true
    }
    
    // Calculate distance in meters
    private func calculateDistanceInMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    // Format distance for display
    private func formatDistance(_ distanceInMeters: Double) -> String {
        let distanceInMiles = distanceInMeters / 1609.34
        if distanceInMiles < 0.1 {
            return String(format: "%.0f ft", distanceInMeters * 3.28084)
        } else {
            return String(format: "%.1f mi", distanceInMiles)
        }
    }
    
    // Calculate estimated cycling time (assuming average speed of 12 mph / 19 km/h)
    private func calculateCyclingTime(distanceInMeters: Double) -> String {
        let averageSpeedMph = 12.0
        let distanceInMiles = distanceInMeters / 1609.34
        let timeInHours = distanceInMiles / averageSpeedMph
        let timeInMinutes = timeInHours * 60
        
        if timeInMinutes < 1 {
            return "< 1 min"
        } else if timeInMinutes < 60 {
            return String(format: "%.0f min", timeInMinutes)
        } else {
            let hours = Int(timeInMinutes / 60)
            let minutes = Int(timeInMinutes.truncatingRemainder(dividingBy: 60))
            return String(format: "%dh %dm", hours, minutes)
        }
    }

    private func hideBottomDrawer() {

        bottomDrawerHeightConstraint.constant = 0
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
            self.view.layoutIfNeeded()
        }

        isDrawerVisible = false
        selectedSearchResult = nil
    }

    @objc private func goToButtonTapped() {
        guard let searchResult = selectedSearchResult else { return }

        // 添加按钮点击反馈效果
        if let button = bottomDrawerView.subviews.first(where: { $0 is UIButton }) as? UIButton {
            UIView.animate(withDuration: 0.1, animations: {
                button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    button.transform = CGAffineTransform.identity
                }
            }
        }

        // 获取用户当前位置
        let currentLocation = mapView.location.latestLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)

        // 使用反向地理编码获取当前位置名称
        self.getCurrentLocationName(coordinate: currentLocation) { [weak self] currentLocationName in
            guard let self = self else { return }

            // 组装wayPoints数组，包含起点和终点
            let wayPoints: [[String: Any]] = [
                // 起点 - 用户当前位置
                [
                    "name": currentLocationName,
                    "latitude": currentLocation.latitude,
                    "longitude": currentLocation.longitude,
                    "isSilent": false,
                    "address": ""
                ],
                // 终点 - 用户选择的位置
                [
                    "name": searchResult.name,
                    "latitude": searchResult.coordinate.latitude,
                    "longitude": searchResult.coordinate.longitude,
                    "isSilent": false,
                    "address": searchResult.address?.formattedAddress(style: .medium) ?? ""
                ]
            ]

            // 创建SelectedLocation对象
            let selectedLocation = SelectedLocation(
                name: searchResult.name,
                address: searchResult.address?.formattedAddress(style: .medium),
                coordinate: searchResult.coordinate,
                wayPoints: wayPoints
            )

            // 延迟一点时间再执行操作，让用户看到反馈效果
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // 调用回调，传递waypoint格式的数据
                self.onLocationSelected?(selectedLocation)

                // 关闭整个搜索界面
                self.dismiss(animated: true)
            }
        }
    }

    // MARK: - 地理编码方法

    private func getCurrentLocationName(coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    // Prioritize location name, then street address, then city
                    let locationName = placemark.name ??
                                     placemark.thoroughfare ??
                                     placemark.locality ??
                                     "Current Location"
                    completion(locationName)
                } else {
                    completion("Current Location")
                }
            }
        }
    }

    func showAnnotations(results: [SearchResult], cameraShouldFollow: Bool = true) {
        print("🔍 showAnnotations called with \(results.count) results")

        let annotations = results.map { result in
            var point = PointAnnotation.pointAnnotation(result)
            print("📍 Creating annotation for: \(result.name) at \(result.coordinate)")

            // 点击标注时的处理
            point.tapHandler = { [weak self] _ in
                return self?.handleAnnotationTap(result: result) ?? false
            }
            return point
        }

        annotationsManager.annotations = annotations
        print("📍 Set \(annotations.count) annotations to manager")

        if cameraShouldFollow {
            cameraToAnnotations(annotationsManager.annotations)
        }
    }
    
    func cameraToAnnotations(_ annotations: [PointAnnotation]) {
        if annotations.count == 1, let annotation = annotations.first {
            mapView.camera.fly(
                to: .init(center: annotation.point.coordinates, zoom: 15),
                duration: 0.25,
                completion: nil
            )
        } else {
            do {
                let cameraState = mapView.mapboxMap.cameraState
                let coordinatesCamera = try mapView.mapboxMap.camera(
                    for: annotations.map(\.point.coordinates),
                    camera: CameraOptions(cameraState: cameraState),
                    coordinatesPadding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
                    maxZoom: nil,
                    offset: nil
                )
                
                mapView.camera.fly(to: coordinatesCamera, duration: 0.25, completion: nil)
            } catch {
                print("Camera error: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleAnnotationTap(result: SearchResult) -> Bool {
        // 显示底部抽屉而不是直接选择位置
        showBottomDrawer(with: result)
        return true
    }
}

// MARK: - SearchControllerDelegate

extension SearchMapViewController: SearchControllerDelegate {
    func categorySearchResultsReceived(category: SearchCategory, results: [SearchResult]) {
        // 停止跟随用户位置
        mapView.viewport.idle()
        showAnnotations(results: results)
        
        // 更新搜索结果的文字颜色
        updateSearchResultsTextColor()
    }

    /// 当用户选择搜索结果时显示标注
    func searchResultSelected(_ searchResult: SearchResult) {
        print("🔍 Search result selected: \(searchResult.name) at \(searchResult.coordinate)")

        // 停止跟随用户位置
        mapView.viewport.idle()

        showAnnotations(results: [searchResult])

        // 只显示底部抽屉，不立即调用回调
        // 等用户点击"前往此处"按钮时才调用回调
        showBottomDrawer(with: searchResult)
    }

    func userFavoriteSelected(_ userFavorite: FavoriteRecord) {
        // 停止跟随用户位置
        mapView.viewport.idle()
        showAnnotations(results: [userFavorite])
        
        // 更新搜索结果的文字颜色
        updateSearchResultsTextColor()
    }
}

// MARK: - PointAnnotation Extension

extension PointAnnotation {
    static func pointAnnotation(_ searchResult: SearchResult) -> PointAnnotation {
        var annotation = PointAnnotation(coordinate: searchResult.coordinate)

        // 设置文本标签
        annotation.textField = searchResult.name
        annotation.textSize = 16
        annotation.textColor = StyleColor(UIColor(hex: "#01E47C"))  // 使用主题色
        annotation.textOffset = [0, -2] // 文本偏移，避免与图标重叠

        // 关键：设置标记图片 - 使用系统默认的红色标记
        if let markerImage = UIImage(systemName: "mappin.circle.fill") {
            annotation.image = .init(image: markerImage, name: "search-marker")
        }

        print("📍 Created annotation: \(searchResult.name) at \(searchResult.coordinate)")
        return annotation
    }
}
