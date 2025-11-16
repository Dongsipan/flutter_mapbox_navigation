import UIKit
import MapboxMaps
import CoreLocation

/// 地图样式选择器视图控制器（符合 iOS 设计规范）
class StylePickerViewController: UIViewController {
    
    // MARK: - Properties
    
    private var selectedStyle: String = "standard"
    private var selectedLightPreset: String = "day"
    private var enableDynamicLightPreset: Bool = false
    
    private var completion: ((StylePickerResult?) -> Void)?
    
    // Map Components
    private var mapView: MapView?
    private let locationManager = CLLocationManager()
    
    // UI Components
    private let mapContainerView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let styleStackView = UIStackView()
    private let lightPresetSection = UIView()
    private let lightPresetStackView = UIStackView()
    private let dynamicSwitch = UISwitch()
    private let autoTimeSwitch = UISwitch()
    
    // 底部按钮容器（固定在底部）
    private let bottomButtonContainer = UIView()
    private let applyButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    // MARK: - Initialization
    
    init(currentStyle: String? = nil, 
         currentLightPreset: String? = nil,
         enableDynamicLightPreset: Bool = false,
         completion: @escaping (StylePickerResult?) -> Void) {
        
        self.selectedStyle = currentStyle ?? "standard"
        self.selectedLightPreset = currentLightPreset ?? "day"
        self.enableDynamicLightPreset = enableDynamicLightPreset
        self.completion = completion
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 根据当前时间自动选择 Light Preset
        selectedLightPreset = getCurrentTimeBasedLightPreset()
        
        setupNavigationBar()
        setupUI()
        setupMapView()
    }
    
    /// 根据当前时间获取合适的 Light Preset
    private func getCurrentTimeBasedLightPreset() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<7:
            return "dawn"       // 5:00-7:00 黎明
        case 7..<17:
            return "day"        // 7:00-17:00 白天
        case 17..<19:
            return "dusk"       // 17:00-19:00 黄昏
        default:
            return "night"      // 19:00-5:00 夜晚
        }
    }
    
    // MARK: - Navigation Bar Setup
    
    private func setupNavigationBar() {
        // 设置导航栏标题
        title = "地图样式"
        
        // 配置导航栏外观
        navigationItem.largeTitleDisplayMode = .never
        
        // 添加取消按钮到导航栏（符合 iOS 规范）
        let cancelBarButton = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.leftBarButtonItem = cancelBarButton
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        // ========== 地图容器 ==========
        mapContainerView.translatesAutoresizingMaskIntoConstraints = false
        mapContainerView.backgroundColor = .systemGray6
        mapContainerView.layer.cornerRadius = 16
        mapContainerView.layer.masksToBounds = true
        // iOS 风格阴影
        mapContainerView.layer.shadowColor = UIColor.black.cgColor
        mapContainerView.layer.shadowOpacity = 0.1
        mapContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        mapContainerView.layer.shadowRadius = 8
        view.addSubview(mapContainerView)
        
        // ========== ScrollView ==========
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // ========== 样式选择区域 ==========
        styleStackView.axis = .vertical
        styleStackView.spacing = 12
        styleStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(styleStackView)
        
        setupStyleButtons()
        
        // ========== Light Preset 区域 ==========
        lightPresetSection.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(lightPresetSection)
        setupLightPresetSection()
        
        // ========== 底部按钮容器（固定在底部）==========
        bottomButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomButtonContainer.backgroundColor = .systemBackground
        // 顶部添加细线分隔
        let separatorLine = UIView()
        separatorLine.backgroundColor = .separator
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        bottomButtonContainer.addSubview(separatorLine)
        view.addSubview(bottomButtonContainer)
        
        setupActionButtons()
        
        // ========== 布局约束 ==========
        NSLayoutConstraint.activate([
            // 分隔线
            separatorLine.topAnchor.constraint(equalTo: bottomButtonContainer.topAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: bottomButtonContainer.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: bottomButtonContainer.trailingAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5),
            
            // 地图容器 - 固定在顶部
            mapContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            mapContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            mapContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            mapContainerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3),
            
            // 底部按钮容器 - 固定在底部
            bottomButtonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomButtonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomButtonContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomButtonContainer.heightAnchor.constraint(equalToConstant: 90), // 足够容纳按钮和 safe area
            
            // ScrollView - 在地图和按钮之间
            scrollView.topAnchor.constraint(equalTo: mapContainerView.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomButtonContainer.topAnchor),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 样式列表
            styleStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            styleStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            styleStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Light Preset 区域
            lightPresetSection.topAnchor.constraint(equalTo: styleStackView.bottomAnchor, constant: 24),
            lightPresetSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            lightPresetSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            lightPresetSection.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
        ])
    }
    
    // MARK: - Map Setup
    
    /// 初始化并配置地图视图
    private func setupMapView() {
        // 获取用户当前位置
        let userLocation = getUserLocation()
        
        // 创建相机配置（优先使用用户位置，否则使用默认位置）
        let cameraOptions = CameraOptions(
            center: userLocation,
            zoom: 13,
            pitch: 45
        )
        
        // 创建地图配置
        let mapInitOptions = MapInitOptions(
            cameraOptions: cameraOptions,
            styleURI: getStyleURI(for: selectedStyle)
        )
        
        // 创建地图视图
        let mapView = MapView(frame: mapContainerView.bounds, mapInitOptions: mapInitOptions)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 隐藏地图装饰物
        mapView.ornaments.logoView.isHidden = true
        mapView.ornaments.attributionButton.isHidden = true
        mapView.ornaments.compassView.isHidden = true
        mapView.ornaments.scaleBarView.isHidden = true
        
        mapContainerView.addSubview(mapView)
        self.mapView = mapView
        
        // 等待地图加载完成后应用 Light Preset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.applyLightPresetToMap()
        }
    }
    
    /// 获取样式 URI
    private func getStyleURI(for style: String) -> StyleURI {
        switch style {
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
    
    /// 应用样式配置
    private func applyLightPresetToMap() {
        guard let mapView = mapView else { return }
        
        do {
            try mapView.mapboxMap.setStyleImportConfigProperty(
                for: "basemap",
                config: "lightPreset",
                value: selectedLightPreset
            )
            
            if selectedStyle == "faded" {
                try mapView.mapboxMap.setStyleImportConfigProperty(
                    for: "basemap",
                    config: "theme",
                    value: "faded"
                )
            } else if selectedStyle == "monochrome" {
                try mapView.mapboxMap.setStyleImportConfigProperty(
                    for: "basemap",
                    config: "theme",
                    value: "monochrome"
                )
            } else if selectedStyle == "standard" {
                try mapView.mapboxMap.setStyleImportConfigProperty(
                    for: "basemap",
                    config: "theme",
                    value: "default"
                )
            }
        } catch {
            print("⚠️ 应用样式配置失败: \(error)")
        }
    }
    
    // MARK: - Style Buttons Setup
    
    private func setupStyleButtons() {
        let styles = [
            ("standard", "Standard", "默认样式 - 支持 Light Preset ✨"),
            ("standardSatellite", "Standard Satellite", "卫星图像 - 支持 Light Preset ✨"),
            ("faded", "Faded", "褪色主题 - 支持 Light Preset ✨"),
            ("monochrome", "Monochrome", "单色主题 - 支持 Light Preset ✨"),
            ("light", "Light", "浅色背景"),
            ("dark", "Dark", "深色背景"),
            ("outdoors", "Outdoors", "户外地形")
        ]
        
        for (value, title, description) in styles {
            let button = createStyleButton(value: value, title: title, description: description)
            styleStackView.addArrangedSubview(button)
        }
    }
    
    /// 创建样式选择按钮（iOS 标准卡片样式）
    private func createStyleButton(value: String, title: String, description: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemGroupedBackground
        container.layer.cornerRadius = 12
        container.layer.masksToBounds = true
        
        // 选中状态边框
        if value == selectedStyle {
            container.layer.borderWidth = 2
            container.layer.borderColor = UIColor.systemBlue.cgColor
        }
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        
        let descLabel = UILabel()
        descLabel.text = description
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 0
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(descLabel)
        
        // 选中指示器
        if value == selectedStyle {
            let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
            checkmark.tintColor = .systemBlue
            checkmark.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(checkmark)
            
            NSLayoutConstraint.activate([
                checkmark.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                checkmark.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                checkmark.widthAnchor.constraint(equalToConstant: 24),
                checkmark.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -52),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 70)
        ])
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(styleButtonTapped(_:)))
        container.addGestureRecognizer(tapGesture)
        container.tag = styles.firstIndex(where: { $0.0 == value }) ?? 0
        container.isUserInteractionEnabled = true
        
        return container
    }
    
    private var styles: [(String, String, String)] {
        return [
            ("standard", "Standard", "默认样式 - 支持 Light Preset ✨"),
            ("standardSatellite", "Standard Satellite", "卫星图像 - 支持 Light Preset ✨"),
            ("faded", "Faded", "褪色主题 - 支持 Light Preset ✨"),
            ("monochrome", "Monochrome", "单色主题 - 支持 Light Preset ✨"),
            ("light", "Light", "浅色背景"),
            ("dark", "Dark", "深色背景"),
            ("outdoors", "Outdoors", "户外地形")
        ]
    }
    
    @objc private func styleButtonTapped(_ gesture: UITapGestureRecognizer) {
        guard let container = gesture.view else { return }
        let index = container.tag
        let style = styles[index].0
        
        selectedStyle = style
        
        // 重新生成按钮
        styleStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        setupStyleButtons()
        
        // 更新地图
        updateMapStyle()
    }
    
    // MARK: - Light Preset Section Setup
    
    private func setupLightPresetSection() {
        // Section 标题
        let titleLabel = UILabel()
        titleLabel.text = "Light Preset（光照状态）"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        lightPresetSection.addSubview(titleLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "仅标有 ✨ 的样式支持，已根据时间自动选择"
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        lightPresetSection.addSubview(subtitleLabel)
        
        // Light Preset 按钮
        lightPresetStackView.axis = .vertical
        lightPresetStackView.spacing = 12
        lightPresetStackView.translatesAutoresizingMaskIntoConstraints = false
        lightPresetSection.addSubview(lightPresetStackView)
        
        let presets = [
            ("dawn", "🌅 Dawn", "黎明 5:00-7:00"),
            ("day", "☀️ Day", "白天 7:00-17:00"),
            ("dusk", "🌇 Dusk", "黄昏 17:00-19:00"),
            ("night", "🌙 Night", "夜晚 19:00-5:00")
        ]
        
        for (value, title, time) in presets {
            let button = createLightPresetButton(value: value, title: title, time: time)
            lightPresetStackView.addArrangedSubview(button)
        }
        
        // 动态切换选项
        let dynamicContainer = createDynamicSwitchContainer()
        lightPresetSection.addSubview(dynamicContainer)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: lightPresetSection.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: lightPresetSection.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: lightPresetSection.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: lightPresetSection.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: lightPresetSection.trailingAnchor),
            
            lightPresetStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            lightPresetStackView.leadingAnchor.constraint(equalTo: lightPresetSection.leadingAnchor),
            lightPresetStackView.trailingAnchor.constraint(equalTo: lightPresetSection.trailingAnchor),
            
            dynamicContainer.topAnchor.constraint(equalTo: lightPresetStackView.bottomAnchor, constant: 16),
            dynamicContainer.leadingAnchor.constraint(equalTo: lightPresetSection.leadingAnchor),
            dynamicContainer.trailingAnchor.constraint(equalTo: lightPresetSection.trailingAnchor),
            dynamicContainer.bottomAnchor.constraint(equalTo: lightPresetSection.bottomAnchor)
        ])
    }
    
    private func createLightPresetButton(value: String, title: String, time: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemGroupedBackground
        container.layer.cornerRadius = 12
        
        if value == selectedLightPreset {
            container.layer.borderWidth = 2
            container.layer.borderColor = UIColor.systemBlue.cgColor
        }
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let timeLabel = UILabel()
        timeLabel.text = time
        timeLabel.font = .systemFont(ofSize: 13)
        timeLabel.textColor = .secondaryLabel
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(timeLabel)
        
        if value == selectedLightPreset {
            let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
            checkmark.tintColor = .systemBlue
            checkmark.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(checkmark)
            
            NSLayoutConstraint.activate([
                checkmark.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                checkmark.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                checkmark.widthAnchor.constraint(equalToConstant: 24),
                checkmark.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            
            timeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            timeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            timeLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            
            container.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(lightPresetTapped(_:)))
        container.addGestureRecognizer(tapGesture)
        container.tag = ["dawn", "day", "dusk", "night"].firstIndex(of: value) ?? 0
        container.isUserInteractionEnabled = true
        
        return container
    }
    
    @objc private func lightPresetTapped(_ gesture: UITapGestureRecognizer) {
        let presets = ["dawn", "day", "dusk", "night"]
        guard let container = gesture.view else { return }
        selectedLightPreset = presets[container.tag]
        
        // 重新生成按钮
        lightPresetStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let presetData = [
            ("dawn", "🌅 Dawn", "黎明 5:00-7:00"),
            ("day", "☀️ Day", "白天 7:00-17:00"),
            ("dusk", "🌇 Dusk", "黄昏 17:00-19:00"),
            ("night", "🌙 Night", "夜晚 19:00-5:00")
        ]
        for (value, title, time) in presetData {
            let button = createLightPresetButton(value: value, title: title, time: time)
            lightPresetStackView.addArrangedSubview(button)
        }
        
        applyLightPresetToMap()
    }
    
    private func createDynamicSwitchContainer() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemGroupedBackground
        container.layer.cornerRadius = 12
        
        let label = UILabel()
        label.text = "启用动态切换（每5秒自动循环）"
        label.font = .systemFont(ofSize: 15)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        dynamicSwitch.isOn = enableDynamicLightPreset
        dynamicSwitch.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dynamicSwitch)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            dynamicSwitch.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            dynamicSwitch.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        return container
    }
    
    // MARK: - Action Buttons Setup
    
    private func setupActionButtons() {
        // 应用按钮 - iOS 标准蓝色
        applyButton.setTitle("应用", for: .normal)
        applyButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        applyButton.backgroundColor = .systemBlue
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.layer.cornerRadius = 12
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        bottomButtonContainer.addSubview(applyButton)
        
        NSLayoutConstraint.activate([
            applyButton.topAnchor.constraint(equalTo: bottomButtonContainer.topAnchor, constant: 12),
            applyButton.leadingAnchor.constraint(equalTo: bottomButtonContainer.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: bottomButtonContainer.trailingAnchor, constant: -16),
            applyButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func applyTapped() {
        // 只有支持 Light Preset 的样式才传递 lightPreset
        let supportedStyles = ["standard", "standardSatellite", "faded", "monochrome"]
        let lightPreset = supportedStyles.contains(selectedStyle) ? selectedLightPreset : nil
        
        let result = StylePickerResult(
            mapStyle: selectedStyle,
            lightPreset: lightPreset,
            enableDynamicLightPreset: dynamicSwitch.isOn
        )
        completion?(result)
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        completion?(nil)
        dismiss(animated: true)
    }
    
    private func updateMapStyle() {
        guard let mapView = mapView else { return }
        mapView.mapboxMap.styleURI = getStyleURI(for: selectedStyle)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.applyLightPresetToMap()
        }
    }
    
    // MARK: - Location
    
    /// 获取用户当前位置
    private func getUserLocation() -> CLLocationCoordinate2D {
        // 请求位置权限（如果需要）
        let authStatus = locationManager.authorizationStatus
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        // 尝试获取当前位置
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            if let location = locationManager.location {
                print("✅ 使用用户当前位置: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                return location.coordinate
            }
        }
        
        // 如果无法获取用户位置，返回默认位置（北京）
        print("⚠️ 无法获取用户位置，使用默认位置（北京）")
        return CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
    }
}

// MARK: - Result Model

struct StylePickerResult {
    let mapStyle: String
    let lightPreset: String?
    let enableDynamicLightPreset: Bool
}
