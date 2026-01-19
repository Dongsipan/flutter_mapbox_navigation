import UIKit

/// 应用主题颜色配置
/// 与 Flutter 主题保持一致：
/// - Primary: #01E47C (绿色)
/// - Background: #040608 (深色)
/// - Brightness: Dark
extension UIColor {
    
    // MARK: - 主题色
    
    /// 主题色 - 对应 Flutter 的 primary/seedColor (#01E47C)
    static let appPrimary = UIColor(hex: "#01E47C")
    
    /// 主题色深色版本 - 对应 Flutter 的 colorPrimaryDark
    static let appPrimaryDark = UIColor(hex: "#00B35F")
    
    /// 强调色 - 对应 Flutter 的 accent
    static let appAccent = UIColor(hex: "#01E47C")
    
    // MARK: - 背景色
    
    /// 主背景色 - 对应 Flutter 的 surface/scaffoldBackgroundColor (#040608)
    static let appBackground = UIColor(hex: "#040608")
    
    /// 表面颜色 - 对应 Flutter 的 surface
    static let appSurface = UIColor(hex: "#040608")
    
    /// 卡片背景色（稍亮一点）
    static let appCardBackground = UIColor(hex: "#191A21")
    
    // MARK: - 文字颜色
    
    /// 主文字颜色 - 白色
    static let appTextPrimary = UIColor.white
    
    /// 次要文字颜色 - 54% 不透明度的白色
    static let appTextSecondary = UIColor.white.withAlphaComponent(0.54)
    
    /// 禁用文字颜色 - 38% 不透明度的白色
    static let appTextDisabled = UIColor.white.withAlphaComponent(0.38)
    
    // MARK: - 辅助方法
    
    /// 从十六进制字符串创建颜色
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
    
    /// 将颜色转换为十六进制字符串
    var hexString: String {
        guard let components = cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}
