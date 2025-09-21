import MapboxMaps
import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit

class CustomNightStyle: NightStyle {

    required init() {
        super.init()
        initStyle()
    }

    init(url: String?){
        super.init()
        initStyle()
        if(url != nil)
        {
            mapStyleURL = URL(string: url!) ?? URL(string: StyleURI.standard.rawValue)!
            previewMapStyleURL = mapStyleURL
        }
    }

    func initStyle()
    {
        // Use a custom map style.
        mapStyleURL = URL(string: StyleURI.standard.rawValue)!
        previewMapStyleURL = mapStyleURL

        // Specify that the style should be used during the day.
        styleType = .night
    }

    override func apply() {
        super.apply()
        // Begin styling the UI
        //BottomBannerView.appearance().backgroundColor = .orange
    }
}
