import Flutter
import UIKit

/// 处理地图样式选择器的方法调用
/// 新逻辑：用户选择后自动存储到 UserDefaults，后续导航自动应用
class StylePickerHandler: NSObject {
    private let channel: FlutterMethodChannel
    
    // UserDefaults keys
    private static let keyMapStyle = "mapbox_map_style"
    private static let keyLightPreset = "mapbox_light_preset"
    private static let keyEnableDynamic = "mapbox_enable_dynamic_light_preset"
    
    init(messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(
            name: "flutter_mapbox_navigation/style_picker",
            binaryMessenger: messenger
        )
        super.init()
        
        channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "showStylePicker":
            showStylePicker(result: result)
        case "getStoredStyle":
            getStoredStyle(result: result)
        case "clearStoredStyle":
            clearStoredStyle(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /// 显示样式选择器（自动读取和保存设置）
    private func showStylePicker(result: @escaping FlutterResult) {
        // 从 UserDefaults 读取当前设置
        let defaults = UserDefaults.standard
        let currentStyle = defaults.string(forKey: Self.keyMapStyle) ?? "standard"
        let currentLightPreset = defaults.string(forKey: Self.keyLightPreset) ?? "day"
        let enableDynamicLightPreset = defaults.bool(forKey: Self.keyEnableDynamic)
        
        DispatchQueue.main.async {
            self.presentStylePicker(
                currentStyle: currentStyle,
                currentLightPreset: currentLightPreset,
                enableDynamicLightPreset: enableDynamicLightPreset,
                completion: { pickerResult in
                    if let pickerResult = pickerResult {
                        // 自动保存到 UserDefaults
                        self.saveStyleSettings(pickerResult)
                        
                        // 通知 Flutter 设置已更新（不返回具体值）
                        result(true)
                    } else {
                        // 用户取消
                        result(false)
                    }
                }
            )
        }
    }
    
    /// 获取存储的样式设置
    private func getStoredStyle(result: @escaping FlutterResult) {
        let defaults = UserDefaults.standard
        let mapStyle = defaults.string(forKey: Self.keyMapStyle) ?? "standard"
        let lightPreset = defaults.string(forKey: Self.keyLightPreset) ?? "day"
        let enableDynamic = defaults.bool(forKey: Self.keyEnableDynamic)
        
        result([
            "mapStyle": mapStyle,
            "lightPreset": lightPreset,
            "enableDynamicLightPreset": enableDynamic
        ])
    }
    
    /// 清除存储的样式设置
    private func clearStoredStyle(result: @escaping FlutterResult) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.keyMapStyle)
        defaults.removeObject(forKey: Self.keyLightPreset)
        defaults.removeObject(forKey: Self.keyEnableDynamic)
        defaults.synchronize()
        
        result(true)
    }
    
    /// 保存样式设置到 UserDefaults
    private func saveStyleSettings(_ pickerResult: StylePickerResult) {
        let defaults = UserDefaults.standard
        defaults.set(pickerResult.mapStyle, forKey: Self.keyMapStyle)
        
        if let preset = pickerResult.lightPreset {
            defaults.set(preset, forKey: Self.keyLightPreset)
        }
        
        defaults.set(pickerResult.enableDynamicLightPreset, forKey: Self.keyEnableDynamic)
        defaults.synchronize()
        
        print("✅ 样式设置已保存: \(pickerResult.mapStyle), \(pickerResult.lightPreset ?? "nil"), dynamic: \(pickerResult.enableDynamicLightPreset)")
    }
    
    /// 静态方法：供 NavigationFactory 读取存储的样式
    static func loadStoredStyleSettings() -> (mapStyle: String?, lightPreset: String?, enableDynamic: Bool) {
        let defaults = UserDefaults.standard
        let mapStyle = defaults.string(forKey: keyMapStyle)
        let lightPreset = defaults.string(forKey: keyLightPreset)
        let enableDynamic = defaults.bool(forKey: keyEnableDynamic)
        
        return (mapStyle, lightPreset, enableDynamic)
    }
    
    /// 弹出样式选择器
    private func presentStylePicker(
        currentStyle: String,
        currentLightPreset: String,
        enableDynamicLightPreset: Bool,
        completion: @escaping (StylePickerResult?) -> Void
    ) {
        guard let rootVC = getRootViewController() else {
            completion(nil)
            return
        }
        
        let picker = StylePickerViewController(
            currentStyle: currentStyle,
            currentLightPreset: currentLightPreset,
            enableDynamicLightPreset: enableDynamicLightPreset,
            completion: completion
        )
        
        // 包装在 UINavigationController 中以显示导航栏
        let navigationController = UINavigationController(rootViewController: picker)
        
        // 配置为 sheet 样式（符合 iOS 设计规范）
        if #available(iOS 15.0, *) {
            if let sheet = navigationController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
        }
        
        rootVC.present(navigationController, animated: true)
    }
    
    /// 获取根视图控制器
    private func getRootViewController() -> UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = window.rootViewController {
            return rootViewController
        }
        return nil
    }
}
