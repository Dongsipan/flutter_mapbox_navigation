import UIKit
import MapboxMaps
import CoreLocation

/// 地图样式选择器视图控制器（现代卡片风格）
class StylePickerViewController: UIViewController {
    
    // MARK: - Properties
    
    private var selectedStyle: String = "standard"
    private var selectedLightPreset: String = "day"
    private var lightPresetMode: String = "manual"  // manual, automatic
    
    private var completion: ((StylePickerResult?) -> Void)?
    
    // 支持 Light Preset 的样式
    private let stylesWithLightPreset: Set<String> = ["standard", "standardSatellite", "faded", "monochrome"]
    
    // Map Components
    private var mapView: MapView?
    private let locationManager = CLLocationManager()
    
    // UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 地图预览卡片
    private let mapPreviewCard = UIView()
    private let mapContainerView = UIView()
    
    // 说明卡片
    private let infoCard = UIView()
    
    // 样式选择卡片
    private let styleCard = UIView()
    private let stylePickerView = UIPickerView()
    
    // Light Preset 卡片
    private let lightPresetCard = UIView()
    private let lightPresetPickerView = UIPickerView()
    
    // 自动调整卡片
    private let autoAdjustCard = UIView()
    private let autoAdjustSwitch = UISwitch()
    
    // 底部按钮容器
    private let bottomButtonContainer = UIView()
    private let cancelButton = UIButton(type: .system)
    private let applyButton = UIButton(type: .system)
    
    // Style data
    private let styles: [(value: String, title: String, description: String)] = [
        ("standard", "Standard", "Default map style"),
        ("standardSatellite", "Satellite", "Satellite imagery view"),
        ("faded", "Faded", "Soft color tones"),
        ("monochrome", "Monochrome", "Black and white style"),
        ("light", "Light", "Bright background"),
        ("dark", "Dark", "Dark background"),
        ("outdoors", "Outdoors", "Terrain display")
    ]
    
    private let lightPresets: [(value: String, title: String, time: String)] = [
        ("dawn", "Dawn", "5:00-7:00 AM"),
        ("day", "Day", "7:00 AM-5:00 PM"),
        ("dusk", "Dusk", "5:00-7:00 PM"),
        ("night", "Night", "7:00 PM-5:00 AM")
    ]
    
    // MARK: - Initialization
    
    init(currentStyle: String? = nil, 
         currentLightPreset: String? = nil,
         lightPresetMode: String = "manual",
         completion: @escaping (StylePickerResult?) -> Void) {
        
        self.selectedStyle = currentStyle ?? "standard"
        self.selectedLightPreset = currentLightPreset ?? "day"
        // 兼容旧的 realTime 和 demo，统一映射为 automatic
        if lightPresetMode == "realTime" || lightPresetMode == "demo" {
            self.lightPresetMode = "automatic"
        } else {
            self.lightPresetMode = lightPresetMode
        }
        self.completion = completion
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationBar()
        setupUI()
        setupMapView()
        updateLightPresetVisibility()
    }
    
    // MARK: - Navigation Bar Setup
    
    private func setupNavigationBar() {
        title = "Map Style Settings"
        navigationItem.largeTitleDisplayMode = .never
        
        // 设置导航栏主题色
        if let navigationBar = navigationController?.navigationBar {
            navigationBar.tintColor = .appPrimary
            navigationBar.titleTextAttributes = [
                .foregroundColor: UIColor.white
            ]
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .appBackground
            appearance.titleTextAttributes = [
                .foregroundColor: UIColor.white
            ]
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        }
        
        // 取消按钮
        let cancelBarButton = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        cancelBarButton.tintColor = .appPrimary
        navigationItem.leftBarButtonItem = cancelBarButton
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .appBackground
        
        // ========== ScrollView ==========
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // ========== 地图预览卡片 ==========
        setupMapPreviewCard()
        
        // ========== 说明卡片 ==========
        setupInfoCard()
        
        // ========== 样式选择卡片 ==========
        setupStyleCard()
        
        // ========== Light Preset 卡片 ==========
        setupLightPresetCard()
        
        // ========== 自动调整卡片 ==========
        setupAutoAdjustCard()
        
        // ========== 底部按钮容器 ==========
        setupBottomButtons()
        
        // ========== 布局约束 ==========
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 地图预览卡片
            mapPreviewCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            mapPreviewCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mapPreviewCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mapPreviewCard.heightAnchor.constraint(equalToConstant: 200),
            
            // 说明卡片
            infoCard.topAnchor.constraint(equalTo: mapPreviewCard.bottomAnchor, constant: 16),
            infoCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            infoCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // 样式选择卡片
            styleCard.topAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: 12),
            styleCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            styleCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Light Preset 卡片
            lightPresetCard.topAnchor.constraint(equalTo: styleCard.bottomAnchor, constant: 12),
            lightPresetCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            lightPresetCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // 自动调整卡片
            autoAdjustCard.topAnchor.constraint(equalTo: lightPresetCard.bottomAnchor, constant: 12),
            autoAdjustCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            autoAdjustCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            autoAdjustCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            // 底部按钮容器
            bottomButtonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomButtonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomButtonContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomButtonContainer.heightAnchor.constraint(equalToConstant: 90)
        ])
    }
    
    // MARK: - Card Setup Methods
    
    private func setupMapPreviewCard() {
        mapPreviewCard.translatesAutoresizingMaskIntoConstraints = false
        mapPreviewCard.backgroundColor = .appCardBackground
        mapPreviewCard.layer.cornerRadius = 12
        mapPreviewCard.layer.masksToBounds = true
        contentView.addSubview(mapPreviewCard)
        
        mapContainerView.translatesAutoresizingMaskIntoConstraints = false
        mapPreviewCard.addSubview(mapContainerView)
        
        NSLayoutConstraint.activate([
            mapContainerView.topAnchor.constraint(equalTo: mapPreviewCard.topAnchor),
            mapContainerView.leadingAnchor.constraint(equalTo: mapPreviewCard.leadingAnchor),
            mapContainerView.trailingAnchor.constraint(equalTo: mapPreviewCard.trailingAnchor),
            mapContainerView.bottomAnchor.constraint(equalTo: mapPreviewCard.bottomAnchor)
        ])
    }
    
    private func setupInfoCard() {
        infoCard.translatesAutoresizingMaskIntoConstraints = false
        infoCard.backgroundColor = .appCardBackground
        infoCard.layer.cornerRadius = 12
        contentView.addSubview(infoCard)
        
        let iconView = UIImageView(image: UIImage(systemName: "paintpalette"))
        iconView.tintColor = .appPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Customize Map Appearance"
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        
        let descLabel = UILabel()
        descLabel.text = "Adjust map style and lighting effects to create a personalized navigation experience"
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        descLabel.numberOfLines = 0
        
        let textStack = UIStackView(arrangedSubviews: [titleLabel, descLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        infoCard.addSubview(iconView)
        infoCard.addSubview(textStack)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: infoCard.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -16),
            textStack.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 16),
            textStack.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupStyleCard() {
        styleCard.translatesAutoresizingMaskIntoConstraints = false
        styleCard.backgroundColor = .appCardBackground
        styleCard.layer.cornerRadius = 12
        contentView.addSubview(styleCard)
        
        let titleLabel = UILabel()
        titleLabel.text = "Map Style"
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        stylePickerView.delegate = self
        stylePickerView.dataSource = self
        stylePickerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置初始选中项
        if let index = styles.firstIndex(where: { $0.value == selectedStyle }) {
            stylePickerView.selectRow(index, inComponent: 0, animated: false)
        }
        
        styleCard.addSubview(titleLabel)
        styleCard.addSubview(stylePickerView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: styleCard.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: styleCard.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: styleCard.trailingAnchor, constant: -16),
            
            stylePickerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            stylePickerView.leadingAnchor.constraint(equalTo: styleCard.leadingAnchor),
            stylePickerView.trailingAnchor.constraint(equalTo: styleCard.trailingAnchor),
            stylePickerView.bottomAnchor.constraint(equalTo: styleCard.bottomAnchor, constant: -8),
            stylePickerView.heightAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    private func setupLightPresetCard() {
        lightPresetCard.translatesAutoresizingMaskIntoConstraints = false
        lightPresetCard.backgroundColor = .appCardBackground
        lightPresetCard.layer.cornerRadius = 12
        contentView.addSubview(lightPresetCard)
        
        let titleLabel = UILabel()
        titleLabel.text = "Light Preset"
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descLabel = UILabel()
        descLabel.text = "Select lighting effects for different times of day"
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        
        lightPresetPickerView.delegate = self
        lightPresetPickerView.dataSource = self
        lightPresetPickerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置初始选中项
        if let index = lightPresets.firstIndex(where: { $0.value == selectedLightPreset }) {
            lightPresetPickerView.selectRow(index, inComponent: 0, animated: false)
        }
        
        lightPresetCard.addSubview(titleLabel)
        lightPresetCard.addSubview(descLabel)
        lightPresetCard.addSubview(lightPresetPickerView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: lightPresetCard.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: lightPresetCard.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: lightPresetCard.trailingAnchor, constant: -16),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: lightPresetCard.leadingAnchor, constant: 16),
            descLabel.trailingAnchor.constraint(equalTo: lightPresetCard.trailingAnchor, constant: -16),
            
            lightPresetPickerView.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 8),
            lightPresetPickerView.leadingAnchor.constraint(equalTo: lightPresetCard.leadingAnchor),
            lightPresetPickerView.trailingAnchor.constraint(equalTo: lightPresetCard.trailingAnchor),
            lightPresetPickerView.bottomAnchor.constraint(equalTo: lightPresetCard.bottomAnchor, constant: -8),
            lightPresetPickerView.heightAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    private func setupAutoAdjustCard() {
        autoAdjustCard.translatesAutoresizingMaskIntoConstraints = false
        autoAdjustCard.backgroundColor = .appCardBackground
        autoAdjustCard.layer.cornerRadius = 12
        contentView.addSubview(autoAdjustCard)
        
        let titleLabel = UILabel()
        titleLabel.text = "Auto-Adjust Based on Sunrise/Sunset"
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descLabel = UILabel()
        descLabel.text = "Automatically switch lighting effects based on time"
        descLabel.font = .systemFont(ofSize: 14)
        descLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let textStack = UIStackView(arrangedSubviews: [titleLabel, descLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        autoAdjustSwitch.onTintColor = .appPrimary
        autoAdjustSwitch.isOn = lightPresetMode == "automatic"
        autoAdjustSwitch.addTarget(self, action: #selector(autoAdjustSwitchChanged(_:)), for: .valueChanged)
        autoAdjustSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        autoAdjustCard.addSubview(textStack)
        autoAdjustCard.addSubview(autoAdjustSwitch)
        
        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: autoAdjustCard.leadingAnchor, constant: 16),
            textStack.centerYAnchor.constraint(equalTo: autoAdjustCard.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: autoAdjustSwitch.leadingAnchor, constant: -16),
            
            autoAdjustSwitch.trailingAnchor.constraint(equalTo: autoAdjustCard.trailingAnchor, constant: -16),
            autoAdjustSwitch.centerYAnchor.constraint(equalTo: autoAdjustCard.centerYAnchor),
            
            autoAdjustCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])
    }
    
    private func setupBottomButtons() {
        bottomButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomButtonContainer.backgroundColor = .appBackground
        
        let separatorLine = UIView()
        separatorLine.backgroundColor = UIColor.appPrimary.withAlphaComponent(0.2)
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        bottomButtonContainer.addSubview(separatorLine)
        
        // Cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cancelButton.setTitleColor(UIColor(white: 0.7, alpha: 1.0), for: .normal)
        cancelButton.backgroundColor = .clear
        cancelButton.layer.cornerRadius = 8
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.borderColor = UIColor(white: 0.7, alpha: 1.0).cgColor
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        bottomButtonContainer.addSubview(cancelButton)
        
        // Apply button
        applyButton.setTitle("Apply", for: .normal)
        applyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        applyButton.backgroundColor = .appPrimary
        applyButton.setTitleColor(.appBackground, for: .normal)
        applyButton.layer.cornerRadius = 8
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        bottomButtonContainer.addSubview(applyButton)
        
        view.addSubview(bottomButtonContainer)
        
        NSLayoutConstraint.activate([
            separatorLine.topAnchor.constraint(equalTo: bottomButtonContainer.topAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: bottomButtonContainer.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: bottomButtonContainer.trailingAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 1),
            
            cancelButton.topAnchor.constraint(equalTo: bottomButtonContainer.topAnchor, constant: 12),
            cancelButton.leadingAnchor.constraint(equalTo: bottomButtonContainer.leadingAnchor, constant: 16),
            cancelButton.heightAnchor.constraint(equalToConstant: 50),
            cancelButton.widthAnchor.constraint(equalTo: applyButton.widthAnchor),
            
            applyButton.topAnchor.constraint(equalTo: bottomButtonContainer.topAnchor, constant: 12),
            applyButton.leadingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 8),
            applyButton.trailingAnchor.constraint(equalTo: bottomButtonContainer.trailingAnchor, constant: -16),
            applyButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Map Setup
    
    private func setupMapView() {
        let userLocation = getUserLocation()
        
        let cameraOptions = CameraOptions(
            center: userLocation,
            zoom: 13,
            pitch: 45
        )
        
        let mapInitOptions = MapInitOptions(
            cameraOptions: cameraOptions,
            styleURI: getStyleURI(for: selectedStyle)
        )
        
        let mapView = MapView(frame: mapContainerView.bounds, mapInitOptions: mapInitOptions)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        mapView.ornaments.logoView.isHidden = true
        mapView.ornaments.attributionButton.isHidden = true
        mapView.ornaments.compassView.isHidden = true
        mapView.ornaments.scaleBarView.isHidden = true
        
        mapContainerView.addSubview(mapView)
        self.mapView = mapView
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.applyLightPresetToMap()
        }
    }
    
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
    
    // MARK: - Actions
    
    @objc private func applyTapped() {
        let lightPreset = stylesWithLightPreset.contains(selectedStyle) ? selectedLightPreset : nil
        
        let result = StylePickerResult(
            mapStyle: selectedStyle,
            lightPreset: lightPreset,
            lightPresetMode: lightPresetMode
        )
        completion?(result)
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        completion?(nil)
        dismiss(animated: true)
    }
    
    @objc private func autoAdjustSwitchChanged(_ sender: UISwitch) {
        lightPresetMode = sender.isOn ? "automatic" : "manual"
        lightPresetPickerView.isUserInteractionEnabled = !sender.isOn
        lightPresetPickerView.alpha = sender.isOn ? 0.5 : 1.0
        applyLightPresetToMap()
    }
    
    // MARK: - Helper Methods
    
    private func updateMapStyle() {
        guard let mapView = mapView else { return }
        mapView.mapboxMap.styleURI = getStyleURI(for: selectedStyle)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.applyLightPresetToMap()
        }
    }
    
    private func updateLightPresetVisibility() {
        let supportsLightPreset = stylesWithLightPreset.contains(selectedStyle)
        lightPresetCard.isHidden = !supportsLightPreset
        autoAdjustCard.isHidden = !supportsLightPreset
    }
    
    // MARK: - Location
    
    private func getUserLocation() -> CLLocationCoordinate2D {
        let authStatus = locationManager.authorizationStatus
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            if let location = locationManager.location {
                return location.coordinate
            }
        }
        
        return CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
    }
}

// MARK: - UIPickerViewDelegate & UIPickerViewDataSource

extension StylePickerViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == stylePickerView {
            return styles.count
        } else {
            return lightPresets.count
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == stylePickerView {
            let style = styles[row]
            return "\(style.title) - \(style.description)"
        } else {
            let preset = lightPresets[row]
            return "\(preset.title) (\(preset.time))"
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let title: String
        if pickerView == stylePickerView {
            let style = styles[row]
            title = "\(style.title) - \(style.description)"
        } else {
            let preset = lightPresets[row]
            title = "\(preset.title) (\(preset.time))"
        }
        
        return NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 16)
            ]
        )
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == stylePickerView {
            selectedStyle = styles[row].value
            updateLightPresetVisibility()
            updateMapStyle()
        } else {
            selectedLightPreset = lightPresets[row].value
            applyLightPresetToMap()
        }
    }
}

// MARK: - Result Model

struct StylePickerResult {
    let mapStyle: String
    let lightPreset: String?
    let lightPresetMode: String  // "manual", "automatic"
}
