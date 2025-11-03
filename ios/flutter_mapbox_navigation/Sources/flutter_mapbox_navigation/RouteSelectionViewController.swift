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
    
    private var startNavigationButton: UIButton!
    private var cancelButton: UIButton!
    
    /// 路线选择回调
    var onRouteSelected: ((NavigationRoutes) -> Void)?
    
    // MARK: - Initialization
    
    init(navigationRoutes: NavigationRoutes,
         mapboxNavigation: MapboxNavigation,
         mapboxNavigationProvider: MapboxNavigationProvider) {
        self.navigationRoutes = navigationRoutes
        self.mapboxNavigation = mapboxNavigation
        self.mapboxNavigationProvider = mapboxNavigationProvider
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
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
    }
    
    private func setupButtons() {
        // 创建底部按钮容器
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
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 容器约束
            buttonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            buttonContainer.heightAnchor.constraint(equalToConstant: 100),
            
            // 取消按钮
            cancelButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor, constant: 20),
            cancelButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 开始导航按钮
            startNavigationButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -20),
            startNavigationButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            startNavigationButton.leadingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 20),
            startNavigationButton.heightAnchor.constraint(equalToConstant: 50),
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
    
    @objc private func cancelTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func startNavigationTapped() {
        // 触发回调，通知选择了路线
        onRouteSelected?(navigationRoutes)
        // 关闭当前视图
        dismiss(animated: true, completion: nil)
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

