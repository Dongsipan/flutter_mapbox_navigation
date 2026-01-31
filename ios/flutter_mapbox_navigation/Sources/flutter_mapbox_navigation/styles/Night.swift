import MapboxMaps
import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit
import UIKit

class CustomNightStyle: StandardNightStyle {
    
    private let customMapStyle: String?
    private let customLightPreset: String?
    private let customLightPresetMode: LightPresetMode

    required init() {
        self.customMapStyle = nil
        self.customLightPreset = nil
        self.customLightPresetMode = .manual
        super.init()
        initStyle()
    }
    
    // 旧的 URL 方式（兼容性）
    init(url: String?){
        self.customMapStyle = nil
        self.customLightPreset = nil
        self.customLightPresetMode = .manual
        super.init()
        initStyle()
        if(url != nil)
        {
            mapStyleURL = URL(string: url!) ?? URL(string: StyleURI.standard.rawValue)!
            previewMapStyleURL = mapStyleURL
        }
    }
    
    // 新的样式配置方式（推荐）
    init(mapStyle: String?, lightPreset: String?, lightPresetMode: LightPresetMode) {
        self.customMapStyle = mapStyle
        self.customLightPreset = lightPreset
        self.customLightPresetMode = lightPresetMode
        super.init()
        
        // 设置地图样式 URL
        if let styleURL = Self.getStyleURL(for: mapStyle) {
            self.mapStyleURL = styleURL
            self.previewMapStyleURL = styleURL
        } else {
            initStyle()
        }
        
        self.styleType = .night
        
        print("✅ CustomNightStyle 初始化: mapStyle=\(mapStyle ?? "nil"), lightPreset=\(lightPreset ?? "nil"), mode=\(lightPresetMode.rawValue)")
    }

    func initStyle()
    {
        // Use a custom map style.
        mapStyleURL = URL(string: StyleURI.standard.rawValue)!
        previewMapStyleURL = mapStyleURL

        // Specify that the style should be used during the night.
        styleType = .night
    }

    override func apply() {
        super.apply()
        
        print("✅ CustomNightStyle.apply() 被调用")
        
        // 夜间模式使用相同的主题色
        tintColor = UIColor(hex: "#01E47C")  // #01E47C 亮绿色
        
        let traitCollection = UIScreen.main.traitCollection
        let backgroundColor = UIColor(hex: "#040608")
        let primaryColor = UIColor(hex: "#01E47C")
        
        // 夜间模式的关键配置
        BottomBannerView.appearance(for: traitCollection).backgroundColor = backgroundColor
        BottomPaddingView.appearance(for: traitCollection).backgroundColor = backgroundColor
        FloatingButton.appearance(for: traitCollection).backgroundColor = UIColor(hex: "#0A0C0E")
        FloatingButton.appearance(for: traitCollection).tintColor = primaryColor
        ResumeButton.appearance(for: traitCollection).backgroundColor = UIColor(hex: "#0A0C0E")
        ResumeButton.appearance(for: traitCollection).tintColor = primaryColor
        TimeRemainingLabel.appearance(for: traitCollection).textColor = primaryColor
        TimeRemainingLabel.appearance(for: traitCollection).trafficLowColor = primaryColor
        TimeRemainingLabel.appearance(for: traitCollection).trafficUnknownColor = primaryColor
        
        // NextInstructionLabel - 设置多个属性确保生效
        NextInstructionLabel.appearance(for: traitCollection).textColor = primaryColor
        NextInstructionLabel.appearance(for: traitCollection).normalTextColor = primaryColor
        NextInstructionLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [NextBannerView.self]).textColor = primaryColor
        NextInstructionLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [NextBannerView.self]).normalTextColor = primaryColor
        
        print("🎨 CustomNightStyle: 已应用主题色 #01E47C")
        
        // 通过通知中心发送自定义配置
        NotificationCenter.default.post(
            name: NSNotification.Name("CustomStyleDidApply"),
            object: nil,
            userInfo: [
                "mapStyle": customMapStyle as Any,
                "lightPreset": customLightPreset as Any,
                "lightPresetMode": customLightPresetMode.rawValue
            ]
        )
    }
    
    /// 将 mapStyle 字符串转换为 StyleURI URL
    private static func getStyleURL(for mapStyle: String?) -> URL? {
        guard let mapStyle = mapStyle else { return nil }
        
        let styleURI: StyleURI
        switch mapStyle {
        case "standard", "faded", "monochrome":
            styleURI = .standard
        case "standardSatellite":
            styleURI = .standardSatellite
        case "light":
            styleURI = .light
        case "dark":
            styleURI = .dark
        case "outdoors":
            styleURI = .outdoors
        default:
            styleURI = .standard
        }
        
        return URL(string: styleURI.rawValue)
    }
}
