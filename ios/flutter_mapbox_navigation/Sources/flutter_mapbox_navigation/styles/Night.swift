import MapboxMaps
import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit

class CustomNightStyle: NightStyle {

    private var lightPreset: String?
    
    required init() {
        super.init()
        initStyle()
    }

    init(url: String?, lightPreset: String? = nil) {
        super.init()
        self.lightPreset = lightPreset
        initStyle()
        if let url = url {
            mapStyleURL = URL(string: url) ?? URL(string: StyleURI.standard.rawValue)!
            previewMapStyleURL = mapStyleURL
        }
    }

    func initStyle() {
        // Use a custom map style.
        mapStyleURL = URL(string: StyleURI.standard.rawValue)!
        previewMapStyleURL = mapStyleURL

        // Specify that the style should be used during the night.
        styleType = .night
    }

    override func apply() {
        super.apply()
        // Begin styling the UI
        //BottomBannerView.appearance().backgroundColor = .orange
        
        // Apply lightPreset for standard style if specified
        if let preset = lightPreset, mapStyleURL.absoluteString.contains("standard") {
            // Note: In production, you would apply the lightPreset to the mapView
            // This is a placeholder for the lightPreset application logic
            print("Applying lightPreset: \(preset) for night style")
        }
    }
    
    /// 更新lightPreset
    func updateLightPreset(_ preset: String) {
        self.lightPreset = preset
        // Reapply the style with new preset
        apply()
    }
}
