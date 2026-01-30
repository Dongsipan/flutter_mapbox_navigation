import UIKit
import MapboxNavigationUIKit

/// 自定义主题颜色配置
/// 参考官方示例: https://github.com/mapbox/mapbox-navigation-ios/blob/main/Examples/AdditionalExamples/Examples/Styled-UI-Elements.swift
extension NavigationViewController {
    
    /// 应用自定义主题颜色
    /// - 背景色: #040608 (深色背景)
    /// - 主文字颜色: #01E47C (亮绿色)
    /// - 次文字颜色: #00B85F (稍暗的绿色)
    func applyCustomTheme() {
        print("🎨 应用自定义主题颜色")
        
        // 自定义颜色定义
        let backgroundColor = UIColor(hex: "#040608")      // 深色背景
        let primaryTextColor = UIColor(hex: "#01E47C")    // 主文字颜色（亮绿色）
        let secondaryTextColor = UIColor(hex: "#00B85F")  // 次文字颜色（稍暗）
        
        // 1. 自定义 Top Banner (InstructionsBannerView) - 只设置背景色
        let topBannerAppearance = InstructionsBannerView.appearance(whenContainedInInstancesOf: [NavigationViewController.self])
        topBannerAppearance.backgroundColor = backgroundColor
        
        // 2. 自定义 Primary Label (主要指示文字)
        let primaryLabelAppearance = PrimaryLabel.appearance(whenContainedInInstancesOf: [InstructionsBannerView.self])
        primaryLabelAppearance.textColor = primaryTextColor
        
        // 3. 自定义 Secondary Label (次要指示文字)
        let secondaryLabelAppearance = SecondaryLabel.appearance(whenContainedInInstancesOf: [InstructionsBannerView.self])
        secondaryLabelAppearance.textColor = secondaryTextColor
        
        // 4. 自定义 Distance Label (距离标签)
        let distanceLabelAppearance = DistanceLabel.appearance(whenContainedInInstancesOf: [InstructionsBannerView.self])
        distanceLabelAppearance.textColor = primaryTextColor
        
        // 5. 自定义 Maneuver View (转向图标)
        let maneuverViewAppearance = ManeuverView.appearance(whenContainedInInstancesOf: [InstructionsBannerView.self])
        maneuverViewAppearance.backgroundColor = backgroundColor
        maneuverViewAppearance.primaryColor = primaryTextColor
        maneuverViewAppearance.secondaryColor = secondaryTextColor
        
        // 6. 自定义 Bottom Banner (底部信息栏)
        let bottomBannerAppearance = BottomBannerView.appearance(whenContainedInInstancesOf: [NavigationViewController.self])
        bottomBannerAppearance.backgroundColor = backgroundColor
        
        // 7. 自定义 Next Banner (下一步指示)
        let nextBannerAppearance = NextBannerView.appearance(whenContainedInInstancesOf: [NavigationViewController.self])
        nextBannerAppearance.backgroundColor = backgroundColor
        
        // 8. 自定义 Lane View (车道指示)
        let laneViewAppearance = LaneView.appearance(whenContainedInInstancesOf: [LanesView.self])
        laneViewAppearance.primaryColor = primaryTextColor
        laneViewAppearance.secondaryColor = secondaryTextColor
        
        print("✅ 自定义主题颜色应用完成")
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    /// 从十六进制字符串创建 UIColor
    /// - Parameter hex: 十六进制颜色字符串 (例如: "#01E47C" 或 "01E47C")
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
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
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = Int(red * 255.0)
        let g = Int(green * 255.0)
        let b = Int(blue * 255.0)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
