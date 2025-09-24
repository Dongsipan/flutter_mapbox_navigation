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
        let config = Configuration(hideCategorySlots: true)
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
        view.backgroundColor = .white
        title = "搜索地点"
        
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
        
        // 创建注释管理器
        annotationsManager = mapView.annotations.makePointAnnotationManager()

        // 添加点击手势来隐藏抽屉
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(mapViewTapped))
        mapView.addGestureRecognizer(tapGesture)
    }
    
    private func setupSearchController() {
        searchController.delegate = self
        
        // 添加 MapboxSearchUI 到地图上方
        let panelController = MapboxPanelController(rootViewController: searchController)
        addChild(panelController)
        
        // 请求位置权限
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
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
        bottomDrawerView.backgroundColor = UIColor.systemBackground
        bottomDrawerView.layer.cornerRadius = 16
        bottomDrawerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomDrawerView.layer.shadowColor = UIColor.black.cgColor
        bottomDrawerView.layer.shadowOffset = CGSize(width: 0, height: -2)
        bottomDrawerView.layer.shadowOpacity = 0.1
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
        // 拖拽指示器
        let dragIndicator = UIView()
        dragIndicator.backgroundColor = UIColor.systemGray3
        dragIndicator.layer.cornerRadius = 2
        dragIndicator.translatesAutoresizingMaskIntoConstraints = false
        bottomDrawerView.addSubview(dragIndicator)

        // 位置名称标签
        let nameLabel = UILabel()
        nameLabel.font = UIFont.boldSystemFont(ofSize: 18)
        nameLabel.numberOfLines = 2
        nameLabel.textColor = UIColor.label
        nameLabel.tag = 100 // 用于后续更新内容
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomDrawerView.addSubview(nameLabel)

        // 地址标签
        let addressLabel = UILabel()
        addressLabel.font = UIFont.systemFont(ofSize: 14)
        addressLabel.textColor = UIColor.secondaryLabel
        addressLabel.numberOfLines = 3
        addressLabel.tag = 101 // 用于后续更新内容
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomDrawerView.addSubview(addressLabel)

        // 分隔线
        let separatorLine = UIView()
        separatorLine.backgroundColor = UIColor.separator
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        bottomDrawerView.addSubview(separatorLine)

        // 前往此处按钮
        let goToButton = UIButton(type: .system)
        goToButton.setTitle("🧭 前往此处", for: .normal)
        goToButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        goToButton.backgroundColor = UIColor.systemBlue
        goToButton.setTitleColor(UIColor.white, for: .normal)
        goToButton.layer.cornerRadius = 12
        goToButton.layer.shadowColor = UIColor.black.cgColor
        goToButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        goToButton.layer.shadowOpacity = 0.1
        goToButton.layer.shadowRadius = 4
        goToButton.addTarget(self, action: #selector(goToButtonTapped), for: .touchUpInside)
        goToButton.translatesAutoresizingMaskIntoConstraints = false

        bottomDrawerView.addSubview(goToButton)

        // 设置约束
        NSLayoutConstraint.activate([
            // 拖拽指示器
            dragIndicator.topAnchor.constraint(equalTo: bottomDrawerView.topAnchor, constant: 8),
            dragIndicator.centerXAnchor.constraint(equalTo: bottomDrawerView.centerXAnchor),
            dragIndicator.widthAnchor.constraint(equalToConstant: 36),
            dragIndicator.heightAnchor.constraint(equalToConstant: 4),

            // 位置名称
            nameLabel.topAnchor.constraint(equalTo: dragIndicator.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: bottomDrawerView.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: bottomDrawerView.trailingAnchor, constant: -20),

            // 地址
            addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            addressLabel.leadingAnchor.constraint(equalTo: bottomDrawerView.leadingAnchor, constant: 20),
            addressLabel.trailingAnchor.constraint(equalTo: bottomDrawerView.trailingAnchor, constant: -20),

            // 分隔线
            separatorLine.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 16),
            separatorLine.leadingAnchor.constraint(equalTo: bottomDrawerView.leadingAnchor, constant: 20),
            separatorLine.trailingAnchor.constraint(equalTo: bottomDrawerView.trailingAnchor, constant: -20),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5),

            // 前往此处按钮
            goToButton.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: 16),
            goToButton.leadingAnchor.constraint(equalTo: bottomDrawerView.leadingAnchor, constant: 20),
            goToButton.trailingAnchor.constraint(equalTo: bottomDrawerView.trailingAnchor, constant: -20),
            goToButton.heightAnchor.constraint(equalToConstant: 50),
            goToButton.bottomAnchor.constraint(lessThanOrEqualTo: bottomDrawerView.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - 抽屉控制方法

    private func showBottomDrawer(with searchResult: SearchResult) {
        selectedSearchResult = searchResult

        // 更新抽屉内容
        if let nameLabel = bottomDrawerView.viewWithTag(100) as? UILabel {
            nameLabel.text = "📍 \(searchResult.name)"
        }

        if let addressLabel = bottomDrawerView.viewWithTag(101) as? UILabel {
            let address = searchResult.address?.formattedAddress(style: .medium) ?? "地址信息不可用"
            addressLabel.text = "🏠 \(address)"
        }



        // 显示抽屉
        bottomDrawerHeightConstraint.constant = 220
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
            self.view.layoutIfNeeded()
        }

        isDrawerVisible = true
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
                    // 优先使用地点名称，然后是街道地址，最后是城市
                    let locationName = placemark.name ??
                                     placemark.thoroughfare ??
                                     placemark.locality ??
                                     "当前位置"
                    completion(locationName)
                } else {
                    completion("当前位置")
                }
            }
        }
    }

    func showAnnotations(results: [SearchResult], cameraShouldFollow: Bool = true) {
        annotationsManager.annotations = results.map { result in
            var point = PointAnnotation.pointAnnotation(result)
            
            // 点击标注时的处理
            point.tapHandler = { [weak self] _ in
                return self?.handleAnnotationTap(result: result) ?? false
            }
            return point
        }
        
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
    }

    /// 当用户选择搜索结果时显示标注
    func searchResultSelected(_ searchResult: SearchResult) {
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
    }
}

// MARK: - PointAnnotation Extension

extension PointAnnotation {
    static func pointAnnotation(_ searchResult: SearchResult) -> PointAnnotation {
        var annotation = PointAnnotation(coordinate: searchResult.coordinate)
        annotation.textField = searchResult.name
        annotation.textColor = StyleColor(.black)
        annotation.textSize = 16
        return annotation
    }
}
