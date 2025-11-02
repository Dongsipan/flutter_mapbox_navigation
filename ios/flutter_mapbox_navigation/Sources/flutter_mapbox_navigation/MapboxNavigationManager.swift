import Foundation
import MapboxNavigationCore

/// 全局单例管理器，确保 MapboxNavigationProvider 只被实例化一次
/// 
/// Mapbox Navigation SDK 要求全局只能有一个 MapboxNavigationProvider 实例。
/// 这个管理器确保在整个应用生命周期中只创建一个实例，并在不同的视图和控制器之间共享。
class MapboxNavigationManager {
    /// 单例实例
    static let shared = MapboxNavigationManager()
    
    /// MapboxNavigationProvider 实例（全局唯一）
    private(set) var navigationProvider: MapboxNavigationProvider?
    
    /// 当前使用 provider 的组件数量（用于引用计数）
    private var referenceCount: Int = 0
    
    /// 记录第一次创建时的配置信息（用于调试）
    private var initialConfig: String?
    
    /// 锁，确保线程安全
    private let lock = NSLock()
    
    /// 私有初始化方法，防止外部创建实例
    private init() {
        print("📍 MapboxNavigationManager 初始化")
    }
    
    /// 获取或创建 MapboxNavigationProvider
    ///
    /// - Parameter coreConfig: 核心配置（仅在首次创建时使用）
    /// - Returns: MapboxNavigationProvider 实例
    func getOrCreateProvider(coreConfig: CoreConfig) -> MapboxNavigationProvider {
        lock.lock()
        defer { lock.unlock() }
        
        if let existingProvider = navigationProvider {
            referenceCount += 1
            print("📍 MapboxNavigationManager: 复用现有 provider (引用计数: \(referenceCount))")
            print("   ⚠️ 注意：传入的 coreConfig 将被忽略，使用已创建的 provider")
            return existingProvider
        }
        
        let configDescription = "locationSource=\(coreConfig.locationSource), historyRecording=\(coreConfig.historyRecordingConfig != nil)"
        print("📍 MapboxNavigationManager: 创建新的 MapboxNavigationProvider")
        print("   配置: \(configDescription)")
        print("   调用栈:")
        Thread.callStackSymbols.prefix(5).forEach { print("     \($0)") }
        
        let provider = MapboxNavigationProvider(coreConfig: coreConfig)
        navigationProvider = provider
        referenceCount = 1
        initialConfig = configDescription
        return provider
    }
    
    /// 释放 provider 引用
    ///
    /// 当组件不再需要 provider 时调用此方法。
    /// 当引用计数为 0 时，provider 将被清除（但实际实例由 SDK 管理）
    func releaseProvider() {
        lock.lock()
        defer { lock.unlock() }
        
        guard referenceCount > 0 else {
            print("⚠️ MapboxNavigationManager: 引用计数已为 0，无法再释放")
            return
        }
        
        referenceCount -= 1
        print("📍 MapboxNavigationManager: 释放 provider 引用 (引用计数: \(referenceCount))")
        
        if referenceCount == 0 {
            print("📍 MapboxNavigationManager: 所有引用已释放，清除 provider")
            navigationProvider = nil
        }
    }
    
    /// 强制重置 provider（谨慎使用）
    ///
    /// 这会清除现有的 provider 并重置引用计数。
    /// 仅在必要时使用（例如重大配置变更）
    func forceReset() {
        lock.lock()
        defer { lock.unlock() }
        
        print("⚠️ MapboxNavigationManager: 强制重置 provider")
        navigationProvider = nil
        referenceCount = 0
    }
    
    /// 获取当前引用计数（用于调试）
    var currentReferenceCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return referenceCount
    }
}

