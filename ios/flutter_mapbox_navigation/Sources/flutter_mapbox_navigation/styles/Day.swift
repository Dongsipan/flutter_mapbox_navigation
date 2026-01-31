import MapboxMaps
import MapboxNavigationUIKit
import UIKit

class CustomDayStyle: StandardDayStyle {
    
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
        print("🔵 CustomDayStyle.init() 开始: mapStyle=\(mapStyle ?? "nil"), lightPreset=\(lightPreset ?? "nil"), mode=\(lightPresetMode.rawValue)")
        
        self.customMapStyle = mapStyle
        self.customLightPreset = lightPreset
        self.customLightPresetMode = lightPresetMode
        super.init()
        
        // 设置地图样式 URL
        if let styleURL = Self.getStyleURL(for: mapStyle) {
            self.mapStyleURL = styleURL
            self.previewMapStyleURL = styleURL
            print("🔵 CustomDayStyle: 设置 mapStyleURL = \(styleURL)")
        } else {
            initStyle()
            print("🔵 CustomDayStyle: 使用默认样式")
        }
        
        self.styleType = .day
        
        print("✅ CustomDayStyle 初始化完成")
    }

    func initStyle()
    {
        // Use a custom map style.
        mapStyleURL = URL(string: StyleURI.standard.rawValue)!
        previewMapStyleURL = mapStyleURL

        // Specify that the style should be used during the day.
        styleType = .day
    }

    override func apply() {
        super.apply()
        
        print("✅ CustomDayStyle.apply() 被调用")
        
        // ============================================
        // 核心配置：tintColor 统一控制所有蓝色元素
        // ============================================
        tintColor = UIColor(hex: "#01E47C")  // #01E47C 亮绿色 - 统一替换所有蓝色！
        
        let traitCollection = UIScreen.main.traitCollection
        let backgroundColor = UIColor(hex: "#040608")           // 深色背景
        let darkBackgroundColor = UIColor(hex: "#0A0C0E")      // 稍亮于主背景
        let primaryColor = UIColor(hex: "#01E47C")             // 亮绿色
        let secondaryColor = UIColor(hex: "#00B85F")           // 稍暗的绿色
        let lightGrayColor = UIColor(hex: "#808080")           // 浅灰色
        let primaryLabelColor = UIColor(hex: "#01E47C")        // 亮绿色
        let secondaryLabelColor = UIColor(hex: "#01E47C", alpha: 0.8) // 半透明亮绿色
        
        // Banner 背景色
        TopBannerView.appearance(for: traitCollection).backgroundColor = backgroundColor
        InstructionsBannerView.appearance(for: traitCollection).backgroundColor = backgroundColor
        NextBannerView.appearance(for: traitCollection).backgroundColor = backgroundColor
        BottomBannerView.appearance(for: traitCollection).backgroundColor = backgroundColor
        BottomPaddingView.appearance(for: traitCollection).backgroundColor = backgroundColor
        
        // 文字标签颜色
        PrimaryLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self]).normalTextColor = primaryLabelColor
        PrimaryLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self]).normalTextColor = primaryLabelColor
        SecondaryLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self]).normalTextColor = secondaryLabelColor
        SecondaryLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self]).normalTextColor = secondaryLabelColor
        DistanceLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self]).unitTextColor = secondaryLabelColor
        DistanceLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self]).valueTextColor = primaryLabelColor
        DistanceLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self]).unitTextColor = secondaryLabelColor
        DistanceLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self]).valueTextColor = primaryLabelColor
        
        // NextInstructionLabel - 设置多个属性确保生效
        NextInstructionLabel.appearance(for: traitCollection).textColor = primaryLabelColor
        NextInstructionLabel.appearance(for: traitCollection).normalTextColor = primaryLabelColor
        NextInstructionLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [NextBannerView.self]).textColor = primaryLabelColor
        NextInstructionLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [NextBannerView.self]).normalTextColor = primaryLabelColor
        
        // Step Instructions View
        StepInstructionsView.appearance(for: traitCollection).backgroundColor = backgroundColor
        if let stepsViewControllerClass = NSClassFromString("MapboxNavigationUIKit.StepsViewController") as? UIViewController.Type {
            UITableView.appearance(for: traitCollection, whenContainedInInstancesOf: [stepsViewControllerClass]).backgroundColor = backgroundColor
            UITableViewCell.appearance(for: traitCollection, whenContainedInInstancesOf: [stepsViewControllerClass]).backgroundColor = backgroundColor
            NextInstructionLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [stepsViewControllerClass]).textColor = lightGrayColor
        }
        if let stepsBackgroundViewClass = NSClassFromString("MapboxNavigationUIKit.StepsBackgroundView") as? UIView.Type {
            stepsBackgroundViewClass.appearance(for: traitCollection).backgroundColor = backgroundColor
        }
        if let dismissButtonClass = NSClassFromString("MBDismissButton") as? UIButton.Type {
            dismissButtonClass.appearance(for: traitCollection).backgroundColor = backgroundColor
        }
        
        // 转向图标
        ManeuverView.appearance(for: traitCollection).backgroundColor = backgroundColor
        ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self]).primaryColor = primaryColor
        ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self]).secondaryColor = secondaryColor
        ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [NextBannerView.self]).primaryColor = primaryColor
        ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [NextBannerView.self]).secondaryColor = secondaryColor
        ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self]).primaryColor = primaryColor
        ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self]).secondaryColor = secondaryColor
        
        // 车道指示
        LanesView.appearance(for: traitCollection).backgroundColor = darkBackgroundColor
        LaneView.appearance(for: traitCollection).primaryColor = primaryColor
        
        // 按钮
        Button.appearance(for: traitCollection).textColor = primaryColor
        CancelButton.appearance(for: traitCollection).tintColor = primaryColor
        DismissButton.appearance(for: traitCollection).textColor = primaryColor
        FloatingButton.appearance(for: traitCollection).backgroundColor = darkBackgroundColor
        FloatingButton.appearance(for: traitCollection).tintColor = primaryColor
        ResumeButton.appearance(for: traitCollection).backgroundColor = darkBackgroundColor
        ResumeButton.appearance(for: traitCollection).tintColor = primaryColor
        
        // 时间和距离标签
        ArrivalTimeLabel.appearance(for: traitCollection).textColor = primaryColor
        DistanceRemainingLabel.appearance(for: traitCollection).textColor = primaryColor
        TimeRemainingLabel.appearance(for: traitCollection).textColor = primaryColor
        TimeRemainingLabel.appearance(for: traitCollection).trafficLowColor = secondaryColor
        TimeRemainingLabel.appearance(for: traitCollection).trafficUnknownColor = lightGrayColor
        
        // 道路名称
        WayNameLabel.appearance(for: traitCollection).normalTextColor = primaryColor
        WayNameView.appearance(for: traitCollection).backgroundColor = darkBackgroundColor
        
        print("🎨 CustomDayStyle: 已应用主题色 #01E47C")
        
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


// MARK: - UIColor Hex Extension

extension UIColor {
    /// 从十六进制字符串创建 UIColor
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    // MARK: - App Theme Colors
    
    /// 应用背景色 (深色背景)
    static var appBackground: UIColor {
        return UIColor(hex: "#040608")
    }
    
    /// 应用主色调 (亮绿色)
    static var appPrimary: UIColor {
        return UIColor(hex: "#01E47C")
    }
    
    /// 应用次要色调 (稍暗的绿色)
    static var appSecondary: UIColor {
        return UIColor(hex: "#00B85F")
    }
    
    /// 主要文字颜色 (亮绿色)
    static var appTextPrimary: UIColor {
        return UIColor(hex: "#01E47C")
    }
    
    /// 次要文字颜色 (稍暗的绿色)
    static var appTextSecondary: UIColor {
        return UIColor(hex: "#00B85F")
    }
    
    /// 卡片背景色 (稍亮于主背景)
    static var appCardBackground: UIColor {
        return UIColor(hex: "#0A0C0E")
    }
    
    /// 将 UIColor 转换为十六进制字符串
    /// - Returns: 十六进制颜色字符串 (例如: "#01E47C")
    var hexString: String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        
        let r = Int(red * 255.0)
        let g = Int(green * 255.0)
        let b = Int(blue * 255.0)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
