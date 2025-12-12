import Foundation
import MapboxNavigationCore
import MapboxDirections
import CoreLocation

/// 历史事件解析器
/// 负责解析 Mapbox 历史文件并提取事件数据
class HistoryEventsParser {
    
    /// 解析历史文件并返回序列化的事件数据
    /// - Parameters:
    ///   - filePath: 历史文件路径
    ///   - historyId: 历史记录 ID
    /// - Returns: 包含所有事件和位置数据的字典
    /// - Throws: 解析过程中的错误
    func parseHistoryFile(filePath: String, historyId: String) async throws -> [String: Any] {
        print("📖 [HistoryEventsParser] 开始解析历史文件: \(filePath)")
        print("📖 [HistoryEventsParser] 历史记录 ID: \(historyId)")
        
        // 验证文件存在
        guard FileManager.default.fileExists(atPath: filePath) else {
            let error = HistoryParseError.fileNotFound(path: filePath)
            print("❌ [HistoryEventsParser] FILE_NOT_FOUND: \(error.errorDescription ?? "")")
            throw error
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        
        // 创建 HistoryReader
        guard let reader = HistoryReader(fileUrl: fileURL, readOptions: nil) else {
            let error = HistoryParseError.readerCreationFailed(path: filePath)
            print("❌ [HistoryEventsParser] READER_CREATION_FAILED: \(error.errorDescription ?? "")")
            throw error
        }
        
        // 解析历史数据
        let history: History
        do {
            history = try await reader.parse()
            print("✅ [HistoryEventsParser] 历史文件解析成功")
        } catch {
            let parseError = HistoryParseError.parseFailed(error: error)
            print("❌ [HistoryEventsParser] PARSE_ERROR: \(parseError.errorDescription ?? "")")
            print("❌ [HistoryEventsParser] 底层错误: \(error)")
            throw parseError
        }
        
        // 提取事件
        let events: [[String: Any]]
        do {
            events = try extractEvents(from: history)
            print("📊 [HistoryEventsParser] 提取了 \(events.count) 个事件")
        } catch {
            let serializationError = HistoryParseError.serializationFailed(message: "Failed to extract events: \(error.localizedDescription)")
            print("❌ [HistoryEventsParser] SERIALIZATION_ERROR (events): \(serializationError.errorDescription ?? "")")
            throw serializationError
        }
        
        // 提取原始位置数据
        let rawLocations: [[String: Any]]
        do {
            rawLocations = try extractRawLocations(from: history)
            print("📍 [HistoryEventsParser] 提取了 \(rawLocations.count) 个原始位置点")
        } catch {
            let serializationError = HistoryParseError.serializationFailed(message: "Failed to extract raw locations: \(error.localizedDescription)")
            print("❌ [HistoryEventsParser] SERIALIZATION_ERROR (locations): \(serializationError.errorDescription ?? "")")
            throw serializationError
        }
        
        // 构建返回数据
        var result: [String: Any] = [
            "historyId": historyId,
            "events": events,
            "rawLocations": rawLocations
        ]
        
        // 提取初始路线信息（如果存在）
        if let navigationRoutes = history.initialRoute {
            do {
                // 从 NavigationRoutes 中提取主路线的 Route 对象
                let mainRoute = navigationRoutes.mainRoute.route
                result["initialRoute"] = serializeRoute(mainRoute)
                print("🛣️ [HistoryEventsParser] 提取了初始路线信息")
            } catch {
                print("⚠️ [HistoryEventsParser] 无法序列化初始路线: \(error.localizedDescription)")
                // 初始路线是可选的，不抛出错误
            }
        }
        
        print("✅ [HistoryEventsParser] 解析完成，返回数据")
        return result
    }
    
    // MARK: - Event Extraction Methods
    
    /// 从 History 对象中提取所有事件
    private func extractEvents(from history: History) throws -> [[String: Any]] {
        var events: [[String: Any]] = []
        
        print("🔄 [HistoryEventsParser] 开始提取 \(history.events.count) 个事件")
        
        for (index, event) in history.events.enumerated() {
            // 添加详细的类型检查日志
            print("🔍 [HistoryEventsParser] 事件 #\(index): 类型 = \(type(of: event))")
            
            do {
                if let locationEvent = event as? LocationUpdateHistoryEvent {
                    print("✅ [HistoryEventsParser] 事件 #\(index): 识别为 LocationUpdateHistoryEvent")
                    events.append(serializeLocationEvent(locationEvent))
                } else if let routeEvent = event as? RouteAssignmentHistoryEvent {
                    print("✅ [HistoryEventsParser] 事件 #\(index): 识别为 RouteAssignmentHistoryEvent")
                    events.append(serializeRouteEvent(routeEvent))
                } else if let userEvent = event as? UserPushedHistoryEvent {
                    print("✅ [HistoryEventsParser] 事件 #\(index): 识别为 UserPushedHistoryEvent")
                    events.append(try serializeUserEvent(userEvent))
                } else {
                    // 未知事件类型
                    print("⚠️ [HistoryEventsParser] 事件 #\(index): 未知事件类型 = \(type(of: event))")
                    events.append(serializeUnknownEvent(event))
                }
            } catch {
                print("❌ [HistoryEventsParser] 事件 #\(index) 序列化失败: \(error.localizedDescription)")
                throw HistoryParseError.serializationFailed(message: "Failed to serialize event #\(index): \(error.localizedDescription)")
            }
        }
        
        print("✅ [HistoryEventsParser] 成功提取 \(events.count) 个事件")
        return events
    }
    
    /// 序列化位置更新事件
    private func serializeLocationEvent(_ event: LocationUpdateHistoryEvent) -> [String: Any] {
        let location = event.location
        
        var data: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "timestamp": Int(location.timestamp.timeIntervalSince1970 * 1000) // 转换为毫秒
        ]
        
        // 添加可选字段 - CLLocation 的这些属性不是 Optional，但有特殊值表示无效
        // altitude: 0 表示无效
        if location.altitude != 0 {
            data["altitude"] = location.altitude
        }
        
        // horizontalAccuracy: 负值表示无效
        if location.horizontalAccuracy >= 0 {
            data["horizontalAccuracy"] = location.horizontalAccuracy
        }
        
        // verticalAccuracy: 负值表示无效
        if location.verticalAccuracy >= 0 {
            data["verticalAccuracy"] = location.verticalAccuracy
        }
        
        // speed: 负值表示无效
        if location.speed >= 0 {
            data["speed"] = location.speed
        }
        
        // course: 负值表示无效
        if location.course >= 0 {
            data["course"] = location.course
        }
        
        return [
            "eventType": "location_update",
            "data": data
        ]
    }
    
    /// 序列化路线分配事件
    private func serializeRouteEvent(_ event: RouteAssignmentHistoryEvent) -> [String: Any] {
        var data: [String: Any] = [:]
        
        // RouteAssignmentHistoryEvent 可能不直接暴露路线详情
        // 我们只记录事件类型，具体路线信息可以从 initialRoute 获取
        data["eventOccurred"] = true
        
        return [
            "eventType": "route_assignment",
            "data": data
        ]
    }
    
    /// 序列化用户推送事件
    private func serializeUserEvent(_ event: UserPushedHistoryEvent) throws -> [String: Any] {
        var data: [String: Any] = [
            "type": event.type
        ]
        
        // 解析 properties JSON 字符串
        // event.properties 是 String 类型，不是 Optional
        let propertiesString = event.properties
        if !propertiesString.isEmpty,
           let propertiesData = propertiesString.data(using: .utf8) {
            do {
                if let propertiesJson = try JSONSerialization.jsonObject(with: propertiesData) as? [String: Any] {
                    data["properties"] = propertiesJson
                    print("✅ [HistoryEventsParser] 成功解析用户事件 properties JSON")
                }
            } catch {
                print("⚠️ [HistoryEventsParser] 无法解析用户事件的 properties JSON: \(error)")
                print("⚠️ [HistoryEventsParser] 原始 properties 字符串: \(propertiesString)")
                // 如果解析失败，保留原始字符串
                data["properties"] = propertiesString
            }
        }
        
        return [
            "eventType": "user_pushed",
            "data": data
        ]
    }
    
    /// 序列化未知事件
    private func serializeUnknownEvent(_ event: HistoryEvent) -> [String: Any] {
        return [
            "eventType": "unknown",
            "data": [
                "type": String(describing: type(of: event))
            ]
        ]
    }
    
    // MARK: - Raw Location Extraction
    
    /// 从 History 对象中提取原始位置数据
    private func extractRawLocations(from history: History) throws -> [[String: Any]] {
        var locations: [[String: Any]] = []
        
        print("🔄 [HistoryEventsParser] 开始提取原始位置数据，总数: \(history.rawLocations.count)")
        
        // 过滤无效坐标
        let invalidCount = history.rawLocations.filter { !isValidCoordinate($0.coordinate) }.count
        if invalidCount > 0 {
            print("⚠️ [HistoryEventsParser] 过滤了 \(invalidCount) 个无效坐标")
        }
        
        // 过滤无效坐标并按时间排序
        let validLocations = history.rawLocations
            .filter { isValidCoordinate($0.coordinate) }
            .sorted { $0.timestamp < $1.timestamp }
        
        print("✅ [HistoryEventsParser] 有效位置数: \(validLocations.count)")
        
        // 检查位置点数量（警告但不阻止）
        if validLocations.count < 2 {
            print("⚠️ [HistoryEventsParser] 原始位置数据不足（少于2个点），实际: \(validLocations.count)")
        }
        
        for (index, location) in validLocations.enumerated() {
            do {
                locations.append(serializeLocation(location))
            } catch {
                print("❌ [HistoryEventsParser] 位置 #\(index) 序列化失败: \(error.localizedDescription)")
                throw HistoryParseError.serializationFailed(message: "Failed to serialize location #\(index): \(error.localizedDescription)")
            }
        }
        
        print("✅ [HistoryEventsParser] 成功序列化 \(locations.count) 个位置点")
        return locations
    }
    
    /// 序列化位置数据
    private func serializeLocation(_ location: CLLocation) -> [String: Any] {
        var data: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "timestamp": Int(location.timestamp.timeIntervalSince1970 * 1000)
        ]
        
        // 添加可选字段
        if location.altitude != 0 {
            data["altitude"] = location.altitude
        }
        
        if location.horizontalAccuracy >= 0 {
            data["horizontalAccuracy"] = location.horizontalAccuracy
        }
        
        if location.verticalAccuracy >= 0 {
            data["verticalAccuracy"] = location.verticalAccuracy
        }
        
        if location.speed >= 0 {
            data["speed"] = location.speed
        }
        
        if location.course >= 0 {
            data["course"] = location.course
        }
        
        return data
    }
    
    /// 验证坐标是否有效
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
               coordinate.longitude >= -180 && coordinate.longitude <= 180
    }
    
    // MARK: - Route Serialization
    
    /// 序列化路线信息
    private func serializeRoute(_ route: Route) -> [String: Any] {
        var data: [String: Any] = [
            "distance": route.distance,
            "duration": route.expectedTravelTime
        ]
        
        // 序列化路线几何
        if let shape = route.shape {
            let coordinates = shape.coordinates.map { coord in
                return [coord.latitude, coord.longitude]
            }
            data["geometry"] = coordinates
        }
        
        return data
    }
}

// MARK: - Error Types

/// 历史解析错误类型
enum HistoryParseError: Error, LocalizedError {
    case fileNotFound(path: String)
    case readerCreationFailed(path: String)
    case parseFailed(error: Error)
    case serializationFailed(message: String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "History file not found at path: \(path)"
        case .readerCreationFailed(let path):
            return "Failed to create HistoryReader for file: \(path)"
        case .parseFailed(let error):
            return "Failed to parse history file: \(error.localizedDescription)"
        case .serializationFailed(let message):
            return "Failed to serialize event data: \(message)"
        }
    }
}
