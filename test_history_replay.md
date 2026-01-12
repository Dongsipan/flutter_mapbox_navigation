# 历史回放功能测试指南

## 🎯 更新后的功能特性

基于官方 Mapbox Navigation iOS SDK 示例，我们已经完全重新实现了历史回放功能：

### ✅ 官方示例模式实现

1. **HistoryReplayController**: 完全按照官方示例创建，使用 `HistoryReader` 初始化
2. **MapboxNavigationProvider**: 使用 `.custom(.historyReplayingValue(with: historyReplayController))` 作为位置源
3. **HistoryReplayDelegate**: 实现三个关键委托方法处理回放事件
4. **NavigationViewControllerDelegate**: 处理导航控制器的生命周期
5. **智能路径解析**: 自动处理 iOS 沙盒路径变化问题

### 🔧 核心改进

#### 1. **官方目录结构**
```swift
func defaultHistoryDirectoryURL() -> URL {
    let basePath: String = if let applicationSupportPath =
        NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first
    {
        applicationSupportPath
    } else {
        NSTemporaryDirectory()
    }
    let historyDirectoryURL = URL(fileURLWithPath: basePath, isDirectory: true)
        .appendingPathComponent("com.mapbox.FlutterMapboxNavigation")
        .appendingPathComponent("NavigationHistory")
    // ...
}
```

#### 2. **智能文件查找**
- 检查原始路径是否存在
- 如果不存在，在当前应用目录中查找同名文件
- 提供详细的调试信息

#### 3. **完整的委托实现**
```swift
extension HistoryReplayViewController: HistoryReplayDelegate {
    func historyReplayController(_:, didReplayEvent event:) { }
    func historyReplayController(_:, wantsToSetRoutes routes:) { }
    func historyReplayControllerDidFinishReplay(_:) { }
}
```

## 🧪 测试步骤

### 1. **准备历史文件**
确保您有一个有效的 `.pbf.gz` 历史文件，例如：
```
/var/mobile/Containers/Data/Application/5C7AEF3E-006E-453D-A9CF-75A64633CD99/Documents/NavigationHistory/2025-09-22T14-05-05Z_fffea1e8-2fa4-4456-a1ae-575dd5c4fbe0.pbf.gz
```

### 2. **调用回放**
```dart
final success = await MapBoxNavigation.instance.startHistoryReplay(
  historyFilePath: '/path/to/your/history/file.pbf.gz',
  enableReplayUI: true,
);
```

### 3. **预期行为**
1. **自动路径解析**: 如果原始路径不存在，会自动在当前目录中查找同名文件
2. **自动开始**: 回放会在 `viewDidAppear` 时自动开始
3. **全屏导航**: 当历史文件包含路线时，会自动切换到全屏导航界面
4. **自动结束**: 回放完成后自动关闭并清理资源

### 4. **调试信息**
新的实现会输出详细的调试信息：
```
Creating HistoryReplayController with file: /path/to/file.pbf.gz
当前应用历史记录目录: /current/app/directory/NavigationHistory
当前历史记录目录内容 (X 个文件):
  - file1.pbf.gz
  - file2.pbf.gz
✅ 在当前目录中找到同名文件
✅ 文件存在，创建HistoryReader，使用路径: /correct/path/file.pbf.gz
Starting free drive for history replay
```

## 🎉 预期结果

- ✅ **路径问题解决**: 自动处理 iOS 沙盒路径变化
- ✅ **官方模式**: 完全按照官方示例实现，确保兼容性
- ✅ **自动化**: 无需手动控制，自动开始和结束
- ✅ **简洁UI**: 只显示必要的导航界面
- ✅ **错误处理**: 完整的错误处理和调试信息

现在请测试新的历史回放功能！
