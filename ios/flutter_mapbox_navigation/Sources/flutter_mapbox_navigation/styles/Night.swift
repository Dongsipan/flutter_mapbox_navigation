import MapboxMaps
import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit

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
