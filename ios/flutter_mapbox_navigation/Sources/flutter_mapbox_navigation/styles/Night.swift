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
        let whiteColor = UIColor.white
        
        // 夜间模式的关键配置
        BottomBannerView.appearance(for: traitCollection).backgroundColor = backgroundColor
        BottomPaddingView.appearance(for: traitCollection).backgroundColor = backgroundColor
        FloatingButton.appearance(for: traitCollection).backgroundColor = UIColor(hex: "#0A0C0E")
        FloatingButton.appearance(for: traitCollection).tintColor = primaryColor
        ResumeButton.appearance(for: traitCollection).backgroundColor = UIColor(hex: "#0A0C0E")
        ResumeButton.appearance(for: traitCollection).tintColor = primaryColor
        
        // 时间和距离标签 - 改为白色
        TimeRemainingLabel.appearance(for: traitCollection).textColor = whiteColor
        TimeRemainingLabel.appearance(for: traitCollection).trafficLowColor = whiteColor
        TimeRemainingLabel.appearance(for: traitCollection).trafficUnknownColor = whiteColor.withAlphaComponent(0.8)
        ArrivalTimeLabel.appearance(for: traitCollection).textColor = whiteColor
        DistanceRemainingLabel.appearance(for: traitCollection).textColor = whiteColor
        
        // NextInstructionLabel - 改为白色
        NextInstructionLabel.appearance(for: traitCollection).textColor = whiteColor
        NextInstructionLabel.appearance(for: traitCollection).normalTextColor = whiteColor
        NextInstructionLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [NextBannerView.self]).textColor = whiteColor
        NextInstructionLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [NextBannerView.self]).normalTextColor = whiteColor
        
        // 文字标签颜色 - 改为白色
        PrimaryLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self]).normalTextColor = whiteColor
        PrimaryLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self]).normalTextColor = whiteColor
        SecondaryLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self]).normalTextColor = whiteColor.withAlphaComponent(0.8)
        SecondaryLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self]).normalTextColor = whiteColor.withAlphaComponent(0.8)
        DistanceLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self]).unitTextColor = whiteColor.withAlphaComponent(0.8)
        DistanceLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self]).valueTextColor = whiteColor
        DistanceLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self]).unitTextColor = whiteColor.withAlphaComponent(0.8)
        DistanceLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self]).valueTextColor = whiteColor
        
        // 道路名称 - 改为白色
        WayNameLabel.appearance(for: traitCollection).normalTextColor = whiteColor
        
        // 转向图标 - 保持主题色
        ManeuverView.appearance(for: traitCollection).backgroundColor = backgroundColor
        ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self]).primaryColor = primaryColor
        ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self]).secondaryColor = primaryColor.withAlphaComponent(0.8)
        ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [NextBannerView.self]).primaryColor = primaryColor
        ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [NextBannerView.self]).secondaryColor = primaryColor.withAlphaComponent(0.8)
        ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self]).primaryColor = primaryColor
        ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self]).secondaryColor = primaryColor.withAlphaComponent(0.8)
        
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
