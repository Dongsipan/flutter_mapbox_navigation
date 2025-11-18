import UIKit
import MapboxMaps
import MapboxNavigationCore
import MapboxNavigationUIKit
import Combine

/// 路线选择视图控制器
/// 显示多条可选路线，用户可以点击选择路线，然后点击底部按钮开始导航
class RouteSelectionViewController: UIViewController {
    
    // MARK: - Properties
    
    private var navigationMapView: NavigationMapView!
    private var navigationRoutes: NavigationRoutes
    private let mapboxNavigation: MapboxNavigation
    private let mapboxNavigationProvider: MapboxNavigationProvider
    
    // 样式设置
    private let mapStyle: String?
    private let lightPreset: String?
    private let lightPresetMode: LightPresetMode
    
    private var startNavigationButton: UIButton!
    private var cancelButton: UIButton!
    private var backButton: UIButton!
    private var overviewButton: UIButton!
    
    /// 路线选择回调
    var onRouteSelected: ((NavigationRoutes) -> Void)?
    
    // MARK: - Initialization
    
    init(navigationRoutes: NavigationRoutes,
         mapboxNavigation: MapboxNavigation,
         mapboxNavigationProvider: MapboxNavigationProvider,
         mapStyle: String? = nil,
         lightPreset: String? = nil,
         lightPresetMode: LightPresetMode = .manual) {
        self.navigationRoutes = navigationRoutes
        self.mapboxNavigation = mapboxNavigation
        self.mapboxNavigationProvider = mapboxNavigationProvider
        self.mapStyle = mapStyle
        self.lightPreset = lightPreset
        self.lightPresetMode = lightPresetMode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupTopBar()
        setupOverviewButton()
        setupButtons()
        displayRoutes()
    }
    
    // MARK: - Setup
    
    private func setupMapView() {
        // 使用 navigation() 方法访问 publishers
        navigationMapView = NavigationMapView(
            location: mapboxNavigationProvider.navigation().locationMatching
                .map(\.mapMatchingResult.enhancedLocation)
                .eraseToAnyPublisher(),
            routeProgress: mapboxNavigationProvider.navigation().routeProgress
                .map(\.?.routeProgress)
                .eraseToAnyPublisher(),
            heading: mapboxNavigationProvider.navigation().heading,
            predictiveCacheManager: mapboxNavigationProvider.predictiveCacheManager
        )
        
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationMapView.delegate = self
        navigationMapView.frame = view.bounds
        view.addSubview(navigationMapView)
        
        // 调整指南针位置，避免被顶部栏遮挡
        let compassOptions = CompassViewOptions(
            position: .topTrailing, // 右上角
            margins: CGPoint(x: 16, y: 60) // 留出顶部栏的空间
        )
        navigationMapView.mapView.ornaments.options.compass = compassOptions
        
        // 应用样式设置
        applyMapStyle()
    }
    
    private func setupTopBar() {
        // 创建顶部栏
        let topBar = UIView()
        topBar.backgroundColor = .white.withAlphaComponent(0.95)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)
        
        // 返回按钮
        backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.setTitle(" 返回", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 17)
        backButton.tintColor = .systemBlue
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        topBar.addSubview(backButton)
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "选择路线"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(titleLabel)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 顶部栏
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            
            // 返回按钮
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            backButton.centerYAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -22),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            // 标题
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -22),
        ])
    }
    
    private func setupOverviewButton() {
        // 创建全览按钮（类似地图应用的全览按钮）
        overviewButton = UIButton(type: .system)
        overviewButton.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right"), for: .normal)
        overviewButton.backgroundColor = .white
        overviewButton.tintColor = .systemBlue
        overviewButton.layer.cornerRadius = 8
        overviewButton.layer.shadowColor = UIColor.black.cgColor
        overviewButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        overviewButton.layer.shadowOpacity = 0.1
        overviewButton.layer.shadowRadius = 4
        overviewButton.translatesAutoresizingMaskIntoConstraints = false
        overviewButton.addTarget(self, action: #selector(overviewTapped), for: .touchUpInside)
        view.addSubview(overviewButton)
        
        // 布局约束 - 放在右下角，避开指南针
        NSLayoutConstraint.activate([
            overviewButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            overviewButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            overviewButton.widthAnchor.constraint(equalToConstant: 44),
            overviewButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }
    
    private func setupButtons() {
        // 创建底部按钮容器，扩展到屏幕底部（无间隙）
        let buttonContainer = UIView()
        buttonContainer.backgroundColor = .white
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonContainer)
        
        // 取消按钮
        cancelButton = UIButton(type: .system)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.setTitleColor(.systemGray, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        buttonContainer.addSubview(cancelButton)
        
        // 开始导航按钮
        startNavigationButton = UIButton(type: .system)
        startNavigationButton.setTitle("开始导航", for: .normal)
        startNavigationButton.setTitleColor(.white, for: .normal)
        startNavigationButton.backgroundColor = .systemBlue
        startNavigationButton.layer.cornerRadius = 12
        startNavigationButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        startNavigationButton.translatesAutoresizingMaskIntoConstraints = false
        startNavigationButton.addTarget(self, action: #selector(startNavigationTapped), for: .touchUpInside)
        buttonContainer.addSubview(startNavigationButton)
        
        // 布局约束 - 扩展到屏幕底部
        NSLayoutConstraint.activate([
            // 容器约束 - 扩展到view底部
            buttonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 取消按钮
            cancelButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor, constant: 20),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 开始导航按钮
            startNavigationButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -20),
            startNavigationButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            startNavigationButton.leadingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 20),
            startNavigationButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 容器顶部约束 - 给按钮留足够空间
            buttonContainer.topAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -16),
        ])
    }
    
    private func displayRoutes() {
        // 在地图上显示所有路线
        Task { @MainActor in
            // 使用 showcase 方法展示路线
            navigationMapView.showcase(navigationRoutes)
            
            // 如果有多条路线，更新界面提示
            if navigationRoutes.alternativeRoutes.count > 0 {
                updateRouteSelectionUI()
            }
        }
    }
    
    private func updateRouteSelectionUI() {
        // 可以添加路线信息标签，显示当前选中的路线信息
        // 例如：距离、预计时间等
        let routeCount = navigationRoutes.alternativeRoutes.count + 1
        print("📍 共有 \(routeCount) 条可选路线")
    }
    
    // MARK: - Actions
    
    @objc private func backTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func overviewTapped() {
        // 显示完整路线全览
        Task { @MainActor in
            print("📍 用户点击全览按钮")
            navigationMapView.showcase(navigationRoutes, animated: true)
        }
    }
    
    @objc private func startNavigationTapped() {
        // 触发回调，通知选择了路线
        onRouteSelected?(navigationRoutes)
        // 关闭当前视图
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Style Management
    
    /// 应用地图样式
    private func applyMapStyle() {
        guard let mapStyle = mapStyle else {
            print("⚙️ RouteSelection: 未设置地图样式，使用默认样式")
            return
        }
        
        print("⚙️ RouteSelection: 应用地图样式: \(mapStyle), lightPreset: \(lightPreset ?? "nil"), mode: \(lightPresetMode)")
        
        let mapView = navigationMapView.mapView
        
        Task { @MainActor in
            // 等待地图初始化
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            
            // 1. 设置地图样式 URI
            let styleURI = getStyleURI(for: mapStyle)
            mapView.mapboxMap.style.uri = styleURI
            print("⚙️ RouteSelection: 已设置地图样式: \(styleURI.rawValue)")
            
            // 等待样式加载
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // 2. 应用 Light Preset 和 Theme（如果有）
            if let preset = lightPreset {
                applyLightPreset(preset, mapStyle: mapStyle, to: mapView)
            }
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
    
    /// 应用 light preset 和 theme
    private func applyLightPreset(_ preset: String, mapStyle: String, to mapView: MapView) {
        // 检查是否支持 light preset
        let supportedStyles = ["standard", "standardSatellite", "faded", "monochrome"]
        guard supportedStyles.contains(mapStyle) else {
            print("⚙️ RouteSelection: 样式 '\(mapStyle)' 不支持 Light Preset")
            return
        }
        
        do {
            // 1. 应用 light preset
            try mapView.mapboxMap.setStyleImportConfigProperty(
                for: "basemap",
                config: "lightPreset",
                value: preset
            )
            print("✅ RouteSelection: Light preset 已应用: \(preset)")
            
            // 2. 应用 theme（如果是 faded 或 monochrome）
            if mapStyle == "faded" {
                try mapView.mapboxMap.setStyleImportConfigProperty(
                    for: "basemap",
                    config: "theme",
                    value: "faded"
                )
                print("✅ RouteSelection: Theme 已应用: faded")
            } else if mapStyle == "monochrome" {
                try mapView.mapboxMap.setStyleImportConfigProperty(
                    for: "basemap",
                    config: "theme",
                    value: "monochrome"
                )
                print("✅ RouteSelection: Theme 已应用: monochrome")
            } else if mapStyle == "standard" {
                try mapView.mapboxMap.setStyleImportConfigProperty(
                    for: "basemap",
                    config: "theme",
                    value: "default"
                )
                print("✅ RouteSelection: Theme 已重置: default")
            }
            
            print("✅ RouteSelection: Light Preset 模式：\(lightPresetMode == .manual ? "手动" : "自动") (\(preset))")
        } catch {
            print("❌ RouteSelection: 应用样式配置失败: \(error)")
        }
    }
}

// MARK: - NavigationMapViewDelegate

extension RouteSelectionViewController: NavigationMapViewDelegate {
    func navigationMapView(_ navigationMapView: NavigationMapView, didSelect alternativeRoute: AlternativeRoute) {
        // 用户点击了备选路线
        print("📍 用户选择了备选路线：路线 ID \(alternativeRoute.id)")
        
        // 切换到选中的备选路线
        Task { @MainActor in
            if let newNavigationRoutes = await navigationRoutes.selecting(alternativeRoute: alternativeRoute) {
                // 更新 navigationRoutes
                navigationRoutes = newNavigationRoutes
                
                // 更新地图显示
                navigationMapView.showcase(newNavigationRoutes)
                
                print("✅ 路线已切换为备选路线")
            } else {
                print("❌ 无法切换到备选路线")
            }
        }
    }
}

