import UIKit
import CoreLocation
import MapboxMaps
import MapboxNavigationCore
import MapboxDirections
import Combine

final class HistoryCoverGenerator {

    static let shared = HistoryCoverGenerator()

    // 资源管理：持有 snapshotter 和 cancelables
    private var currentSnapshotter: Snapshotter?
    private var cancelables = Set<AnyCancellable>()

    private init() {}

    /// 根据速度获取对应的颜色（与 HistoryReplayViewController 保持一致）
    private func colorForSpeed(_ speedKmh: Double) -> UIColor {
        switch speedKmh {
        case ..<5.0:   return UIColor(hex: "#2E7DFF")  // 蓝色 - 很慢
        case ..<10.0:  return UIColor(hex: "#00E5FF")  // 青色 - 慢
        case ..<15.0:  return UIColor(hex: "#00E676")  // 绿色 - 中等偏慢
        case ..<20.0:  return UIColor(hex: "#C6FF00")  // 黄绿色 - 中等
        case ..<25.0:  return UIColor(hex: "#FFD600")  // 黄色 - 中等偏快
        case ..<30.0:  return UIColor(hex: "#FF9100")  // 橙色 - 快
        default:       return UIColor(hex: "#FF1744")  // 红色 - 很快
        }
    }

    /// 根据历史文件生成封面，完成后返回图片路径
    func generateHistoryCover(
        filePath: String, 
        historyId: String, 
        mapStyle: String? = nil,
        lightPreset: String? = nil,
        completion: @escaping (String?) -> Void
    ) {
        Task {
            // Smart path resolution for iOS sandbox changes
            let currentHistoryDir = defaultHistoryDirectoryURL()
            let fileURL = URL(fileURLWithPath: filePath)
            var finalFileURL = fileURL
            
            print("🔍 开始解析历史文件路径...")
            print("   原始路径: \(filePath)")
            print("   当前历史目录: \(currentHistoryDir.path)")
            
            // 文件路径智能解析：如果文件不存在，尝试在当前历史目录中查找
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                print("⚠️ 原始路径文件不存在，尝试智能查找...")
                let filename = fileURL.lastPathComponent
                let currentDirFileURL = currentHistoryDir.appendingPathComponent(filename)
                print("   尝试路径: \(currentDirFileURL.path)")
                
                if FileManager.default.fileExists(atPath: currentDirFileURL.path) {
                    finalFileURL = currentDirFileURL
                    print("✅ 在当前目录找到历史文件: \(finalFileURL.path)")
                } else {
                    print("❌ 智能查找也未找到文件")
                    // 列出当前目录的文件以便调试
                    if let files = try? FileManager.default.contentsOfDirectory(atPath: currentHistoryDir.path) {
                        print("   当前目录文件列表:")
                        for file in files {
                            print("   - \(file)")
                        }
                    }
                }
            } else {
                print("✅ 文件存在: \(fileURL.path)")
            }
            
            guard let reader = HistoryReader(fileUrl: finalFileURL, readOptions: nil) else {
                print("❌ 无法创建 HistoryReader")
                print("   最终尝试路径: \(finalFileURL.path)")
                print("   文件是否存在: \(FileManager.default.fileExists(atPath: finalFileURL.path))")
                await MainActor.run { completion(nil) }
                return
            }
            
            print("✅ HistoryReader 创建成功")

            do {
                let history = try await reader.parse()

                // 提取位置信息（尽量过滤过近的点）
                var locations: [CLLocation] = []
                for event in history.events {
                    if let locationEvent = event as? LocationUpdateHistoryEvent {
                        let loc = CLLocation(
                            coordinate: locationEvent.location.coordinate,
                            altitude: locationEvent.location.altitude ?? 0,
                            horizontalAccuracy: locationEvent.location.horizontalAccuracy ?? 0,
                            verticalAccuracy: locationEvent.location.verticalAccuracy ?? 0,
                            course: locationEvent.location.course ?? -1,
                            speed: locationEvent.location.speed ?? -1,
                            timestamp: locationEvent.location.timestamp
                        )
                        if let last = locations.last {
                            if loc.distance(from: last) > 0.5 { locations.append(loc) }
                        } else {
                            locations.append(loc)
                        }
                    }
                }

                if locations.count < 2 {
                    print("⚠️ 轨迹点过少，跳过封面生成")
                    await MainActor.run { completion(nil) }
                    return
                }

                // 提取坐标和速度信息（避免并发问题）
                let coordsWithSpeed = locations.map { loc -> (coord: CLLocationCoordinate2D, speed: Double) in
                    return (coord: loc.coordinate, speed: loc.speed >= 0 ? loc.speed * 3.6 : 0.0)
                }
                let coords = coordsWithSpeed.map { $0.coord }

                // 在主线程创建和使用 Snapshotter
                await MainActor.run {
                    self.createSnapshot(
                        coordsWithSpeed: coordsWithSpeed,
                        coordinates: coords,
                        historyId: historyId,
                        mapStyle: mapStyle,
                        lightPreset: lightPreset,
                        completion: completion
                    )
                }
            } catch {
                print("❌ 解析历史文件失败: \(error)")
                await MainActor.run { completion(nil) }
            }
        }
    }

    /// 在主线程创建快照（确保线程安全）
    @MainActor
    private func createSnapshot(
        coordsWithSpeed: [(coord: CLLocationCoordinate2D, speed: Double)],
        coordinates: [CLLocationCoordinate2D],
        historyId: String,
        mapStyle: String?,
        lightPreset: String?,
        completion: @escaping (String?) -> Void
    ) {
        // 清理之前的资源
        cancelables.removeAll()
        currentSnapshotter = nil

        // 使用更高的比例以包含底部水印区域
        // 生成比例约 1.69:1 (720:426)
        // 显示时使用 2.2:1 和 1.91:1，会自动裁剪底部水印
        let size = CGSize(width: 720, height: 426)
        let pixelRatio = CGFloat(UIScreen.main.scale)

        // 使用 MapSnapshotOptions
        let options = MapSnapshotOptions(size: size, pixelRatio: pixelRatio)
        let snapshotter = Snapshotter(options: options)
        
        // 持有 snapshotter 引用，防止过早释放
        self.currentSnapshotter = snapshotter

        // 使用用户选择的样式或默认 streets 样式
        let styleURI = getStyleURI(for: mapStyle)
        snapshotter.styleURI = styleURI
        
        // 调整边距：
        // - top: 增加，确保轨迹不会太靠上
        // - bottom: 大幅增加，确保轨迹不会延伸到会被裁剪的区域
        //   (2.2:1会裁剪底部99px，1.91:1会裁剪底部49px)
        // - left/right: 保持，确保宽屏下轨迹完整
        let padding = UIEdgeInsets(top: 50, left: 50, bottom: 110, right: 50)
        let camera = snapshotter.camera(
            for: coordinates,
            padding: padding,
            bearing: nil,
            pitch: nil
        )
        snapshotter.setCamera(to: camera)
        
        print("📸 封面生成: 使用样式 \(mapStyle ?? "streets"), lightPreset: \(lightPreset ?? "nil")")
        print("📸 尺寸: \(size.width)x\(size.height) (约1.69:1 比例，包含底部水印区域)")
        print("📸 边距: top=\(padding.top), left=\(padding.left), bottom=\(padding.bottom), right=\(padding.right)")
        print("📸 说明: 底部padding=110px，确保轨迹不会延伸到裁剪区域(99px)")

        // 等待样式加载完成再开始生成快照
        snapshotter.onStyleLoaded.observeNext { [weak self] _ in
            guard let self = self else { return }
            
            // 应用 light preset 和 theme（如果适用）
            if let mapStyle = mapStyle, let preset = lightPreset {
                self.applyStyleConfig(to: snapshotter, mapStyle: mapStyle, lightPreset: preset)
            }
            
            // 等待样式配置应用后再生成快照
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                
                self.performSnapshot(
                    snapshotter: snapshotter,
                    coordsWithSpeed: coordsWithSpeed,
                    historyId: historyId,
                    completion: completion
                )
            }
        }.store(in: &cancelables)
    }

    /// 执行快照生成
    @MainActor
    private func performSnapshot(
        snapshotter: Snapshotter,
        coordsWithSpeed: [(coord: CLLocationCoordinate2D, speed: Double)],
        historyId: String,
        completion: @escaping (String?) -> Void
    ) {
        snapshotter.start(overlayHandler: { overlay in
            let ctx = overlay.context
            ctx.setLineWidth(6)
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)

            // 🎨 使用 Core Graphics 渐变绘制平滑过渡的速度轨迹
            if coordsWithSpeed.count >= 2 {
                // 1. 创建路径
                let path = CGMutablePath()
                let firstPoint = overlay.pointForCoordinate(coordsWithSpeed[0].coord)
                path.move(to: firstPoint)
                
                for i in 1..<coordsWithSpeed.count {
                    let point = overlay.pointForCoordinate(coordsWithSpeed[i].coord)
                    path.addLine(to: point)
                }
                
                // 2. 构建颜色数组和位置数组
                var colors: [CGColor] = []
                var colorLocations: [CGFloat] = []
                
                for (index, item) in coordsWithSpeed.enumerated() {
                    let color = self.colorForSpeed(item.speed)
                    colors.append(color.cgColor)
                    
                    // 计算归一化位置 [0.0, 1.0]
                    let normalizedLocation = CGFloat(index) / CGFloat(coordsWithSpeed.count - 1)
                    colorLocations.append(normalizedLocation)
                }
                
                // 3. 创建线性渐变
                if let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors as CFArray,
                    locations: colorLocations
                ) {
                    let startPoint = overlay.pointForCoordinate(coordsWithSpeed.first!.coord)
                    let endPoint = overlay.pointForCoordinate(coordsWithSpeed.last!.coord)
                    
                    // 4. 使用渐变绘制路径
                    ctx.saveGState()
                    ctx.addPath(path)
                    ctx.replacePathWithStrokedPath()  // 将路径转换为描边路径
                    ctx.clip()  // 使用描边路径作为裁剪区域
                    
                    // 绘制线性渐变
                    ctx.drawLinearGradient(
                        gradient,
                        start: startPoint,
                        end: endPoint,
                        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                    )
                    
                    ctx.restoreGState()
                }
            } else if coordsWithSpeed.count == 1 {
                // 只有一个点，绘制为圆点
                let point = overlay.pointForCoordinate(coordsWithSpeed[0].coord)
                let color = self.colorForSpeed(coordsWithSpeed[0].speed)
                ctx.setFillColor(color.cgColor)
                ctx.fillEllipse(in: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
            }

            // 绘制起点（绿色）
            if let startCoord = coordsWithSpeed.first?.coord {
                let p = overlay.pointForCoordinate(startCoord)
                let r: CGFloat = 6
                ctx.setFillColor(UIColor(hex: "#00E676").cgColor)  // 使用与回放页面一致的绿色
                ctx.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                ctx.fillPath()
            }

            // 绘制终点（红色）
            if let endCoord = coordsWithSpeed.last?.coord, coordsWithSpeed.count > 1 {
                let p = overlay.pointForCoordinate(endCoord)
                let r: CGFloat = 6
                ctx.setFillColor(UIColor(hex: "#FF5252").cgColor)  // 使用与回放页面一致的红色
                ctx.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                ctx.fillPath()
            }
        }, completion: { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let image):
                self.saveSnapshot(image: image, historyId: historyId, completion: completion)
            case .failure(let error):
                print("❌ Snapshotter 生成失败: \(error)")
                completion(nil)
            }
            
            // 清理资源
            self.currentSnapshotter = nil
            self.cancelables.removeAll()
        })
    }

    /// 保存快照图片到文件
    @MainActor
    private func saveSnapshot(
        image: UIImage,
        historyId: String,
        completion: @escaping (String?) -> Void
    ) {
        // 改进的错误处理
        guard let data = image.pngData() else {
            print("❌ 无法将图片转换为 PNG 数据")
                    completion(nil)
                    return
                }

                let coverURL = defaultHistoryDirectoryURL().appendingPathComponent("\(historyId)_cover.png")
        
        // 确保目录存在
        let directory = coverURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                print("❌ 无法创建目录: \(error)")
                completion(nil)
                return
            }
        }

        // 检查写入权限并保存文件
        do {
            try data.write(to: coverURL, options: .atomic)
            print("✅ 封面已保存: \(coverURL.path)")
            completion(coverURL.path)
        } catch {
            print("❌ 封面保存失败: \(error)")
            completion(nil)
        }
    }
    
    // MARK: - Style Helpers
    
    /// 获取 StyleURI
    private func getStyleURI(for mapStyle: String?) -> MapboxMaps.StyleURI {
        guard let mapStyle = mapStyle else { return .streets }
        
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
            return .streets
        }
    }
    
    /// 应用样式配置（light preset 和 theme）
    @MainActor
    private func applyStyleConfig(to snapshotter: Snapshotter, mapStyle: String, lightPreset: String) {
        let supportedStyles = ["standard", "standardSatellite", "faded", "monochrome"]
        guard supportedStyles.contains(mapStyle) else {
            print("📸 封面: 样式 '\(mapStyle)' 不支持 Light Preset")
            return
        }
        
        do {
            // 1. 应用 light preset
            try snapshotter.setStyleImportConfigProperty(
                for: "basemap",
                config: "lightPreset",
                value: lightPreset
            )
            print("📸 封面: Light preset 已应用: \(lightPreset)")
            
            // 2. 应用 theme
            if mapStyle == "faded" {
                try snapshotter.setStyleImportConfigProperty(
                    for: "basemap",
                    config: "theme",
                    value: "faded"
                )
                print("📸 封面: Theme 已应用: faded")
            } else if mapStyle == "monochrome" {
                try snapshotter.setStyleImportConfigProperty(
                    for: "basemap",
                    config: "theme",
                    value: "monochrome"
                )
                print("📸 封面: Theme 已应用: monochrome")
            } else if mapStyle == "standard" {
                try snapshotter.setStyleImportConfigProperty(
                    for: "basemap",
                    config: "theme",
                    value: "default"
                )
                print("📸 封面: Theme 已重置: default")
            }
        } catch {
            print("📸 封面: 应用样式配置失败: \(error)")
        }
    }
}
