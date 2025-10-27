import UIKit
import CoreLocation
import MapboxMaps
import MapboxNavigationCore
import MapboxDirections

final class HistoryCoverGenerator {

    static let shared = HistoryCoverGenerator()

    private init() {}

    // 读取 Mapbox Access Token（从 Info.plist 的 MBXAccessToken）
    private func getMapboxAccessToken() -> String? {
        if let infoDict = Bundle.main.infoDictionary {
            if let token = infoDict["MBXAccessToken"] as? String, !token.isEmpty {
                return token
            }
        }
        return nil
    }

    /// 根据历史文件生成封面，完成后返回图片路径
    func generateHistoryCover(filePath: String, historyId: String, completion: @escaping (String?) -> Void) {
        Task {
            let fileURL = URL(fileURLWithPath: filePath)
            guard let reader = HistoryReader(fileUrl: fileURL, readOptions: nil) else {
                print("❌ 无法创建 HistoryReader: \(filePath)")
                completion(nil)
                return
            }

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
                    completion(nil)
                    return
                }

                let size = CGSize(width: 720, height: 405) // 16:9 封面
                let pixelRatio = CGFloat(UIScreen.main.scale)

                let coords = locations.map { $0.coordinate }
                let lats = coords.map { $0.latitude }
                let lngs = coords.map { $0.longitude }
                guard let minLat = lats.min(), let maxLat = lats.max(), let minLng = lngs.min(), let maxLng = lngs.max(), maxLat > minLat, maxLng > minLng else {
                    completion(nil)
                    return
                }

                // 相机参数
                let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0, longitude: (minLng + maxLng) / 2.0)
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

                guard let token = getMapboxAccessToken() else {
                    print("❌ 未找到 MBXAccessToken，无法生成真实地图封面")
                    completion(nil)
                    return
                }

                // v11: 使用全局 MapboxOptions 设置 token；使用 MapSnapshotOptions
                MapboxOptions.accessToken = token
                let options = MapSnapshotOptions(size: size, pixelRatio: pixelRatio)
                let snapshotter = Snapshotter(options: options)

                snapshotter.styleURI = .streets
                snapshotter.setCamera(to: CameraOptions(center: center, zoom: zoom))

                snapshotter.start { overlay in
                    // 使用 overlay 提供的投影将经纬度转换为像素点
                    let ctx = overlay.context
                    ctx.setLineWidth(6)
                    ctx.setLineJoin(.round)
                    ctx.setLineCap(.round)
                    ctx.setStrokeColor(UIColor.systemBlue.cgColor)

                    if let first = coords.first {
                        let p0 = overlay.pointForCoordinate(first)
                        ctx.move(to: p0)
                        for c in coords.dropFirst() {
                            let p = overlay.pointForCoordinate(c)
                            ctx.addLine(to: p)
                        }
                        ctx.strokePath()
                    }

                    // 起点
                    if let startCoord = coords.first {
                        let p = overlay.pointForCoordinate(startCoord)
                        let r: CGFloat = 5
                        ctx.setFillColor(UIColor.systemGreen.cgColor)
                        ctx.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                        ctx.fillPath()
                    }

                    // 终点
                    if let endCoord = coords.last {
                        let p = overlay.pointForCoordinate(endCoord)
                        let r: CGFloat = 5
                        ctx.setFillColor(UIColor.systemRed.cgColor)
                        ctx.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                        ctx.fillPath()
                    }
                } completion: { result in
                    switch result {
                    case .success(let image):
                        if let data = image.pngData() {
                            let coverURL = defaultHistoryDirectoryURL().appendingPathComponent("\(historyId)_cover.png")
                            do {
                                try data.write(to: coverURL)
                                completion(coverURL.path)
                            } catch {
                                print("❌ 封面保存失败: \(error)")
                                completion(nil)
                            }
                        } else {
                            completion(nil)
                        }
                    case .failure(let error):
                        print("❌ Snapshotter 失败: \(error)")
                        completion(nil)
                    }
                }
            } catch {
                print("❌ 解析历史文件失败: \(error)")
                completion(nil)
            }
        }
    }
}


