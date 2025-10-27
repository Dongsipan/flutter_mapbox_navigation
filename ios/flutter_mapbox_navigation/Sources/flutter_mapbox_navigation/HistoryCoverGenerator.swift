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

    /// 根据历史文件生成封面，完成后返回图片路径
    func generateHistoryCover(filePath: String, historyId: String, completion: @escaping (String?) -> Void) {
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

                let coords = locations.map { $0.coordinate }
                let lats = coords.map { $0.latitude }
                let lngs = coords.map { $0.longitude }
                guard let minLat = lats.min(), let maxLat = lats.max(), 
                      let minLng = lngs.min(), let maxLng = lngs.max(), 
                      maxLat > minLat, maxLng > minLng else {
                    await MainActor.run { completion(nil) }
                    return
                }

                // 计算相机参数
                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2.0, 
                    longitude: (minLng + maxLng) / 2.0
                )
                let latDiff = maxLat - minLat
                let lngDiff = maxLng - minLng
                let maxDiff = max(latDiff, lngDiff)
                let zoom: Double = {
                    switch maxDiff {
                    case ..<0.005: return 17.0
                    case ..<0.01:  return 16.0
                    case ..<0.02:  return 14.0
                    case ..<0.05:  return 12.0
                    case ..<0.1:   return 10.0
                    default:       return 8.0
                    }
                }()

                // 在主线程创建和使用 Snapshotter
                await MainActor.run {
                    self.createSnapshot(
                        coords: coords,
                        center: center,
                        zoom: zoom,
                        historyId: historyId,
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
        coords: [CLLocationCoordinate2D],
        center: CLLocationCoordinate2D,
        zoom: Double,
        historyId: String,
        completion: @escaping (String?) -> Void
    ) {
        // 清理之前的资源
        cancelables.removeAll()
        currentSnapshotter = nil

        let size = CGSize(width: 720, height: 405) // 16:9 封面
        let pixelRatio = CGFloat(UIScreen.main.scale)

        // 使用 MapSnapshotOptions
        let options = MapSnapshotOptions(size: size, pixelRatio: pixelRatio)
        let snapshotter = Snapshotter(options: options)
        
        // 持有 snapshotter 引用，防止过早释放
        self.currentSnapshotter = snapshotter

        snapshotter.styleURI = .streets
        snapshotter.setCamera(to: CameraOptions(center: center, zoom: zoom))

        // 等待样式加载完成再开始生成快照
        snapshotter.onStyleLoaded.observeNext { [weak self] _ in
            guard let self = self else { return }
            self.performSnapshot(
                snapshotter: snapshotter,
                coords: coords,
                historyId: historyId,
                completion: completion
            )
        }.store(in: &cancelables)
    }

    /// 执行快照生成
    @MainActor
    private func performSnapshot(
        snapshotter: Snapshotter,
        coords: [CLLocationCoordinate2D],
        historyId: String,
        completion: @escaping (String?) -> Void
    ) {
        snapshotter.start(overlayHandler: { overlay in
            // 使用 overlay 提供的投影将经纬度转换为像素点
            let ctx = overlay.context
            ctx.setLineWidth(6)
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)
            ctx.setStrokeColor(UIColor.systemBlue.cgColor)

            // 绘制轨迹线
            if let first = coords.first {
                let p0 = overlay.pointForCoordinate(first)
                ctx.move(to: p0)
                for c in coords.dropFirst() {
                    let p = overlay.pointForCoordinate(c)
                    ctx.addLine(to: p)
                }
                ctx.strokePath()
            }

            // 绘制起点（绿色）
            if let startCoord = coords.first {
                let p = overlay.pointForCoordinate(startCoord)
                let r: CGFloat = 5
                ctx.setFillColor(UIColor.systemGreen.cgColor)
                ctx.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                ctx.fillPath()
            }

            // 绘制终点（红色）
            if let endCoord = coords.last {
                let p = overlay.pointForCoordinate(endCoord)
                let r: CGFloat = 5
                ctx.setFillColor(UIColor.systemRed.cgColor)
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
}
