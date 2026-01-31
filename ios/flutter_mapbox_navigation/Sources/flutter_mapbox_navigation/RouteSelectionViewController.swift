import UIKit
import MapboxMaps
import MapboxNavigationCore
import MapboxNavigationUIKit
import Combine

/// Route Selection View Controller
/// Displays multiple route options, users can tap to select a route, then tap the bottom button to start navigation
class RouteSelectionViewController: UIViewController {
    
    // MARK: - Properties
    
    private var navigationMapView: NavigationMapView!
    private var navigationRoutes: NavigationRoutes
    private let mapboxNavigation: MapboxNavigation
    private let mapboxNavigationProvider: MapboxNavigationProvider
    
    // Style settings
    private let mapStyle: String?
    private let lightPreset: String?
    private let lightPresetMode: LightPresetMode
    
    private var startNavigationButton: UIButton!
    private var cancelButton: UIButton!
    private var backButton: UIButton!
    private var overviewButton: UIButton!
    
    /// Route selection callback
    var onRouteSelected: ((NavigationRoutes) -> Void)?
    
    // Style loading event subscriptions
    private var cancelables = Set<AnyCancellable>()
    
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
        // displayRoutes() will be called after style loading completes
    }
    
    // MARK: - Setup
    
    private func setupMapView() {
        // Use navigation() method to access publishers
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
        
        // Adjust compass position to avoid being covered by top bar
        let compassOptions = CompassViewOptions(
            position: .topTrailing, // Top right
            margins: CGPoint(x: 16, y: 60) // Leave space for top bar
        )
        navigationMapView.mapView.ornaments.options.compass = compassOptions
        
        // Apply style settings
        applyMapStyle()
    }
    
    private func setupTopBar() {
        // Create top bar
        let topBar = UIView()
        topBar.backgroundColor = .appBackground.withAlphaComponent(0.95)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)
        
        // Back button
        backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.setTitle(" Back", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 17)
        backButton.tintColor = .appPrimary
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        topBar.addSubview(backButton)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Select Route"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(titleLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Top bar
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            
            // Back button
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            backButton.centerYAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -22),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Title
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -22),
        ])
    }
    
    private func setupOverviewButton() {
        // Create overview button (similar to map app's overview button)
        overviewButton = UIButton(type: .system)
        overviewButton.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right"), for: .normal)
        overviewButton.backgroundColor = .appCardBackground
        overviewButton.tintColor = .appPrimary
        overviewButton.layer.cornerRadius = 8
        overviewButton.layer.shadowColor = UIColor.black.cgColor
        overviewButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        overviewButton.layer.shadowOpacity = 0.3
        overviewButton.layer.shadowRadius = 4
        overviewButton.translatesAutoresizingMaskIntoConstraints = false
        overviewButton.addTarget(self, action: #selector(overviewTapped), for: .touchUpInside)
        view.addSubview(overviewButton)
        
        // Layout constraints - place in bottom right, avoiding compass
        NSLayoutConstraint.activate([
            overviewButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            overviewButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            overviewButton.widthAnchor.constraint(equalToConstant: 44),
            overviewButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }
    
    private func setupButtons() {
        // Create bottom button container, extending to screen bottom (no gap)
        let buttonContainer = UIView()
        buttonContainer.backgroundColor = .appBackground
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonContainer)
        
        // Cancel button
        cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.appTextSecondary, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        buttonContainer.addSubview(cancelButton)
        
        // Start navigation button
        startNavigationButton = UIButton(type: .system)
        startNavigationButton.setTitle("Start Navigation", for: .normal)
        startNavigationButton.setTitleColor(.white, for: .normal)
        startNavigationButton.backgroundColor = .appPrimary
        startNavigationButton.layer.cornerRadius = 12
        startNavigationButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        startNavigationButton.translatesAutoresizingMaskIntoConstraints = false
        startNavigationButton.addTarget(self, action: #selector(startNavigationTapped), for: .touchUpInside)
        buttonContainer.addSubview(startNavigationButton)
        
        // Layout constraints - extend to screen bottom
        NSLayoutConstraint.activate([
            // Container constraints - extend to view bottom
            buttonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Cancel button
            cancelButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor, constant: 20),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Start navigation button
            startNavigationButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -20),
            startNavigationButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            startNavigationButton.leadingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 20),
            startNavigationButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Container top constraint - leave enough space for buttons
            buttonContainer.topAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -16),
        ])
    }
    
    private func displayRoutes() {
        // Display all routes on the map
        Task { @MainActor in
            print("📍 RouteSelection: Starting to showcase routes to best view")
            print("📍   Number of alternative routes: \(navigationRoutes.alternativeRoutes.count)")
            
            // Use showcase method to display routes with animation
            navigationMapView.showcase(navigationRoutes, animated: true)
            
            // If there are multiple routes, update UI prompt
            if navigationRoutes.alternativeRoutes.count > 0 {
                updateRouteSelectionUI()
            }
            
            print("✅ RouteSelection: Route showcase completed")
        }
    }
    
    private func updateRouteSelectionUI() {
        // Can add route info labels to display current selected route info
        // For example: distance, estimated time, etc.
        let routeCount = navigationRoutes.alternativeRoutes.count + 1
        print("📍 Total \(routeCount) routes available")
    }
    
    // MARK: - Actions
    
    @objc private func backTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func overviewTapped() {
        // Show complete route overview
        Task { @MainActor in
            print("📍 User tapped overview button")
            navigationMapView.showcase(navigationRoutes, animated: true)
        }
    }
    
    @objc private func startNavigationTapped() {
        // Trigger callback to notify route selection
        onRouteSelected?(navigationRoutes)
        // Close current view
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Style Management
    
    /// 应用地图样式
    private func applyMapStyle() {
        let mapView = navigationMapView.mapView
        
        guard let mapStyle = mapStyle else {
            print("⚙️ RouteSelection: 未设置地图样式，使用默认样式")
            // 没有自定义样式，等待默认样式加载完成后展示路线
            mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    print("⚙️ RouteSelection: 默认样式加载完成，开始展示路线")
                    self.displayRoutes()
                }
            }.store(in: &cancelables)
            return
        }
        
        print("⚙️ RouteSelection: 应用地图样式: \(mapStyle), lightPreset: \(lightPreset ?? "nil"), mode: \(lightPresetMode)")
        
        // 1. 设置地图样式 URI
        let styleURI = getStyleURI(for: mapStyle)
        mapView.mapboxMap.style.uri = styleURI
        print("⚙️ RouteSelection: 已设置地图样式: \(styleURI.rawValue)")
        
        // 2. 监听样式加载完成事件（替代固定延时）
        mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                // 3. 应用 Light Preset 和 Theme（如果有）
                if let preset = self.lightPreset {
                    self.applyLightPreset(preset, mapStyle: mapStyle, to: mapView)
                }
                
                // 4. 样式加载完成后，展示路线到最佳视野
                print("⚙️ RouteSelection: 样式加载完成，开始展示路线")
                self.displayRoutes()
            }
        }.store(in: &cancelables)
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
        // User tapped an alternative route
        print("📍 User selected alternative route: Route ID \(alternativeRoute.id)")
        
        // Switch to the selected alternative route
        Task { @MainActor in
            if let newNavigationRoutes = await navigationRoutes.selecting(alternativeRoute: alternativeRoute) {
                // Update navigationRoutes
                navigationRoutes = newNavigationRoutes
                
                // Update map display
                navigationMapView.showcase(newNavigationRoutes)
                
                print("✅ Route switched to alternative route")
            } else {
                print("❌ Unable to switch to alternative route")
            }
        }
    }
}

