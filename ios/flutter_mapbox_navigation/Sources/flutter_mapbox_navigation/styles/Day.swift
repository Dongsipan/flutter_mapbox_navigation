import MapboxMaps
import MapboxNavigationUIKit

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
