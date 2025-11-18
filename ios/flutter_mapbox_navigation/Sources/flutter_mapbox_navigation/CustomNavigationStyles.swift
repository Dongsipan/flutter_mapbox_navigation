import UIKit
import MapboxMaps
import MapboxNavigationUIKit
import MapboxNavigationCore

// MARK: - CustomStyleFactory

/// 自定义样式工厂，根据用户设置创建 DayStyle 和 NightStyle
/// CustomDayStyle 和 CustomNightStyle 的实现位于 styles/Day.swift 和 styles/Night.swift
class CustomStyleFactory {
    
    /// 根据用户设置创建自定义样式数组
    static func createStyles(
        mapStyle: String?,
        lightPreset: String?,
        lightPresetMode: LightPresetMode
    ) -> [Style] {
        let dayStyle = CustomDayStyle(
            mapStyle: mapStyle,
            lightPreset: lightPreset,
            lightPresetMode: lightPresetMode
        )
        
        let nightStyle = CustomNightStyle(
            mapStyle: mapStyle,
            lightPreset: lightPreset,
            lightPresetMode: lightPresetMode
        )
        
        return [dayStyle, nightStyle]
    }
}

// MARK: - NavigationViewController Extension for Light Preset

extension NavigationViewController {
    
    /// 设置 Light Preset 和样式（同步方式，避免时序问题）
    func setupLightPresetAndStyle(
        mapStyle: String?,
        lightPreset: String?,
        lightPresetMode: LightPresetMode
    ) {
        print("🟣 setupLightPresetAndStyle() 开始")
        print("🟣   mapStyle=\(mapStyle ?? "nil"), lightPreset=\(lightPreset ?? "nil"), mode=\(lightPresetMode)")
        
        // 等待视图加载
        Task { @MainActor in
            // 等待 navigationMapView 初始化
            var retries = 0
            while self.navigationMapView == nil && retries < 10 {
                print("🟣 等待 navigationMapView 初始化... (\(retries + 1)/10)")
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                retries += 1
            }
            
            guard let navigationMapView = self.navigationMapView else {
                print("❌ navigationMapView 初始化超时")
                return
            }
            
            let mapView = navigationMapView.mapView
            
            print("🟣 navigationMapView 已就绪，开始应用样式")
            
            // 1. 设置地图样式 URI
            if let mapStyle = mapStyle {
                let styleURI = self.getStyleURI(for: mapStyle)
                mapView.mapboxMap.style.uri = styleURI
                print("🟣 已设置地图样式: \(styleURI.rawValue)")
                
                // 等待样式加载
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                
                // 2. 应用 Light Preset 和 Theme
                if let preset = lightPreset {
                    switch lightPresetMode {
                    case .manual:
                        self.automaticallyAdjustsStyleForTimeOfDay = false
                        print("🟣 已禁用自动调整")
                        self.applyLightPreset(preset, mapStyle: mapStyle, to: mapView)
                        
                    case .automatic:
                        // 自动模式：先应用初始配置（包括 theme），然后启用自动调整
                        self.applyLightPreset(preset, mapStyle: mapStyle, to: mapView)
                        self.automaticallyAdjustsStyleForTimeOfDay = true
                        print("🟣 已启用自动调整（已应用初始配置）")
                    }
                }
            }
            
            print("🟣 setupLightPresetAndStyle() 完成")
        }
    }
    
    /// 获取 StyleURI
    private func getStyleURI(for mapStyle: String) -> MapboxMaps.StyleURI {
        switch mapStyle {
        case "standard", "faded", "monochrome":
            return .standard
        case "standardSatellite":
            return .standardSatellite
        case "light":
            return .light
        case "dark":
            return .dark
        case "outdoors":
            return .outdoors
        default:
            return .standard
        }
    }
    
    /// 监听样式应用通知并设置 light preset（旧方法，保留兼容性）
    func setupLightPresetObserver() {
        print("🟡 NavigationViewController: setupLightPresetObserver() 被调用")
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CustomStyleDidApply"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🟡 NavigationViewController: 收到 CustomStyleDidApply 通知")
            
            guard let self = self,
                  let userInfo = notification.userInfo else {
                print("⚠️ NavigationViewController: self 或 userInfo 为 nil")
                return
            }
            
            print("🟡 NavigationViewController: userInfo = \(userInfo)")
            
            guard let mapStyle = userInfo["mapStyle"] as? String,
                  let lightPreset = userInfo["lightPreset"] as? String,
                  let lightPresetModeString = userInfo["lightPresetMode"] as? String else {
                print("⚠️ NavigationViewController: 无法获取 mapStyle/lightPreset/lightPresetMode")
                print("⚠️  - mapStyle: \(userInfo["mapStyle"] as? String ?? "nil")")
                print("⚠️  - lightPreset: \(userInfo["lightPreset"] as? String ?? "nil")")
                print("⚠️  - lightPresetMode: \(userInfo["lightPresetMode"] as? String ?? "nil")")
                return
            }
            
            print("🟡 NavigationViewController: mapStyle=\(mapStyle), lightPreset=\(lightPreset), mode=\(lightPresetModeString)")
            
            let lightPresetMode = LightPresetMode.from(lightPresetModeString)
            
            // 延迟应用 light preset，确保地图样式已加载
            Task { @MainActor in
                print("🟡 NavigationViewController: 开始延迟 300ms...")
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                
                guard let navigationMapView = self.navigationMapView else {
                    print("❌ navigationMapView 未初始化")
                    return
                }
                
                print("🟡 NavigationViewController: navigationMapView 已就绪")
                
                let mapView = navigationMapView.mapView
                
                // 根据模式应用 light preset
                print("🟡 NavigationViewController: 开始应用 Light Preset, 模式=\(lightPresetMode)")
                
                switch lightPresetMode {
                case .manual:
                    // 手动模式：禁用自动调整，使用固定 preset
                    self.automaticallyAdjustsStyleForTimeOfDay = false
                    print("🟡 NavigationViewController: 已禁用自动调整 (automaticallyAdjustsStyleForTimeOfDay = false)")
                    self.applyLightPreset(lightPreset, mapStyle: mapStyle, to: mapView)
                    print("✅ Light Preset 模式：手动 (\(lightPreset))")
                    
                case .automatic:
                    // 自动模式：先应用初始配置（包括 theme），然后启用自动调整
                    self.applyLightPreset(lightPreset, mapStyle: mapStyle, to: mapView)
                    self.automaticallyAdjustsStyleForTimeOfDay = true
                    print("🟡 NavigationViewController: 已启用自动调整 (automaticallyAdjustsStyleForTimeOfDay = true)")
                    print("✅ Light Preset 模式：自动（基于真实日出日落，已应用初始配置）")
                }
            }
        }
    }
    
    /// 应用 light preset 和 theme
    private func applyLightPreset(_ preset: String, mapStyle: String, to mapView: MapView) {
        print("🔵 applyLightPreset() 开始: preset=\(preset), mapStyle=\(mapStyle)")
        
        // 检查是否支持 light preset
        let supportedStyles = ["standard", "standardSatellite", "faded", "monochrome"]
        guard supportedStyles.contains(mapStyle) else {
            print("⚠️ 样式 '\(mapStyle)' 不支持 Light Preset，跳过")
            return
        }
        
        print("🔵 applyLightPreset: 样式 '\(mapStyle)' 支持 Light Preset")
        
        do {
            // 1. 应用 light preset
            print("🔵 applyLightPreset: 开始设置 lightPreset = \(preset)")
            try mapView.mapboxMap.setStyleImportConfigProperty(
                for: "basemap",
                config: "lightPreset",
                value: preset
            )
            print("✅ Light preset 已应用: \(preset)")
            
            // 2. 应用 theme（如果是 faded 或 monochrome）
            if mapStyle == "faded" {
                print("🔵 applyLightPreset: 开始设置 theme = faded")
                try mapView.mapboxMap.setStyleImportConfigProperty(
                    for: "basemap",
                    config: "theme",
                    value: "faded"
                )
                print("✅ Theme 已应用: faded")
            } else if mapStyle == "monochrome" {
                print("🔵 applyLightPreset: 开始设置 theme = monochrome")
                try mapView.mapboxMap.setStyleImportConfigProperty(
                    for: "basemap",
                    config: "theme",
                    value: "monochrome"
                )
                print("✅ Theme 已应用: monochrome")
            } else if mapStyle == "standard" {
                print("🔵 applyLightPreset: 开始设置 theme = default")
                try mapView.mapboxMap.setStyleImportConfigProperty(
                    for: "basemap",
                    config: "theme",
                    value: "default"
                )
                print("✅ Theme 已重置: default")
            }
            
            print("🔵 applyLightPreset: 完成")
        } catch {
            print("❌ 应用样式配置失败: \(error)")
            print("❌ 错误详情: \(error.localizedDescription)")
        }
    }
}
