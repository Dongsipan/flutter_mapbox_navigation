# iOS 沙箱路径变化问题修复

## 🐛 问题描述

**症状**: 
- iOS 端成功传递 `cover` 字段给 Flutter
- Flutter 端接收到路径，例如：
  ```
  cover: /var/mobile/Containers/.../FA8E11FC-1EC3-455D-88BB-020C3FECFB22/.../xxx_cover.png
  ```
- 但页面不显示封面图片

**根本原因**:
iOS 应用每次启动时，**沙箱路径会变化**。例如：
- 生成封面时的路径：`FA8E11FC-1EC3-455D-88BB-020C3FECFB22`
- 当前运行时的路径：`905818BA-23EC-4178-852F-17311A3C277B`

导致 `File(history.cover!).existsSync()` 返回 `false`。

---

## 🔍 问题分析

### iOS 沙箱机制

iOS 应用沙箱路径格式：
```
/var/mobile/Containers/Data/Application/{UUID}/...
                                         ^^^^
                                    每次启动可能不同
```

### 示例对比

**封面保存时**（第一次启动）:
```
/var/mobile/.../FA8E11FC-1EC3-455D-88BB-020C3FECFB22/Library/Application Support/.../xxx_cover.png
```

**应用重启后**（第二次启动）:
```
/var/mobile/.../B7E14D8E-B4B3-421B-836B-CF932882A97F/Library/Application Support/.../xxx_cover.png
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                        UUID 变了！
```

### 为什么会出现这个问题？

1. **导航记录保存时**: 使用的是当时的沙箱 UUID
2. **应用重启后**: 沙箱 UUID 变化，但数据库中的路径是旧的
3. **读取封面时**: 旧路径文件不存在

---

## ✅ 解决方案

### 方案选择

有两种解决方案：

#### 方案 1: iOS 端动态更新路径（彻底解决）
在 `getNavigationHistoryList` 时，实时更新路径到当前沙箱。

**优点**: 
- ✅ 彻底解决问题
- ✅ Flutter 端无需改动

**缺点**: 
- ❌ 需要遍历更新所有记录
- ❌ 性能开销稍大

#### 方案 2: Flutter 端智能查找（当前实现） ✅
根据文件名在当前沙箱中查找。

**优点**: 
- ✅ 简单高效
- ✅ 不影响 iOS 端
- ✅ 适用于所有旧数据

**缺点**: 
- ⚠️ 依赖目录结构不变

**选择**: 采用方案 2，因为更简单且性能更好。

---

## 🔧 实现方案 2: Flutter 端智能查找

### 核心逻辑

```dart
/// 智能查找封面文件（处理 iOS 沙箱路径变化）
File? _findCoverFile(String? coverPath) {
  if (coverPath == null || coverPath.isEmpty) {
    return null;
  }

  // 1. 尝试原始路径（正常情况）
  final originalFile = File(coverPath);
  if (originalFile.existsSync()) {
    return originalFile;  // 路径没变，直接返回
  }

  // 2. iOS 沙箱路径可能变化，尝试智能查找
  final fileName = coverPath.split('/').last;
  
  // 3. 在当前沙箱的 NavigationHistory 目录查找
  if (coverPath.contains('NavigationHistory')) {
    try {
      final appSupportDir = Directory.systemTemp.parent.path;
      final targetDir = '$appSupportDir/Library/Application Support/com.mapbox.FlutterMapboxNavigation/NavigationHistory';
      final targetFile = File('$targetDir/$fileName');
      
      if (targetFile.existsSync()) {
        return targetFile;  // 找到了！
      }
    } catch (e) {
      // 查找失败，返回 null
    }
  }

  return null;  // 未找到
}
```

---

## 📊 查找流程图

```
开始
  ↓
检查 coverPath 是否为 null/空
  ↓ 否
尝试原始路径: /var/.../FA8E11FC/.../xxx_cover.png
  ↓ 文件不存在
提取文件名: xxx_cover.png
  ↓
构建当前路径: /var/.../B7E14D8E/.../NavigationHistory/xxx_cover.png
                                  ^^^^^^^^^^^^^^^^
                              当前运行时的 UUID
  ↓
检查文件是否存在
  ↓ 是
返回 File 对象 ✅
  ↓
显示封面图片
```

---

## 🎯 关键代码改动

### 改动 1: 添加智能查找方法

**文件**: `example/lib/history_replay_example.dart`

**位置**: 第 241-276 行

```dart
/// 智能查找封面文件（处理 iOS 沙箱路径变化）
File? _findCoverFile(String? coverPath) {
  if (coverPath == null || coverPath.isEmpty) {
    return null;
  }

  // 尝试原始路径
  final originalFile = File(coverPath);
  if (originalFile.existsSync()) {
    return originalFile;
  }

  // iOS 沙箱路径可能变化，尝试智能查找
  final fileName = coverPath.split('/').last;
  
  if (coverPath.contains('NavigationHistory')) {
    try {
      final appSupportDir = Directory.systemTemp.parent.path;
      final targetDir = '$appSupportDir/Library/Application Support/com.mapbox.FlutterMapboxNavigation/NavigationHistory';
      final targetFile = File('$targetDir/$fileName');
      
      if (targetFile.existsSync()) {
        print('✅ 智能查找成功: ${targetFile.path}');
        return targetFile;
      }
    } catch (e) {
      print('⚠️ 智能查找失败: $e');
    }
  }

  print('❌ 未找到封面: $fileName');
  return null;
}
```

---

### 改动 2: 使用智能查找

**修改前**:
```dart
Widget _buildHistoryItem(NavigationHistory history) {
  final hasCover = history.cover != null &&
      history.cover!.isNotEmpty &&
      File(history.cover!).existsSync();  // ❌ 沙箱路径变化后失败
      
  return Card(
    child: Column(
      children: [
        if (hasCover)
          Image.file(File(history.cover!), ...),
      ],
    ),
  );
}
```

**修改后**:
```dart
Widget _buildHistoryItem(NavigationHistory history) {
  // 🆕 使用智能查找封面文件
  final coverFile = _findCoverFile(history.cover);
  final hasCover = coverFile != null;
  
  return Card(
    child: Column(
      children: [
        if (hasCover)
          Image.file(
            coverFile,  // ✅ 使用智能查找到的文件
            errorBuilder: (context, error, stackTrace) {
              // 🆕 添加错误处理
              return Container(
                child: Text('封面加载失败'),
              );
            },
          ),
      ],
    ),
  );
}
```

---

### 改动 3: 添加错误处理

**新增**:
```dart
Image.file(
  coverFile,
  errorBuilder: (context, error, stackTrace) {
    print('❌ 封面图片加载失败: $error');
    return Container(
      width: double.infinity,
      height: 200,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 48),
          const SizedBox(height: 8),
          Text('封面加载失败'),
        ],
      ),
    );
  },
)
```

**作用**:
- 即使文件找到了，但加载失败也会有友好提示
- 帮助调试问题

---

## 🧪 测试场景

### 场景 1: 正常情况（路径未变）
1. 生成封面
2. 不重启应用
3. 查看列表
4. **结果**: ✅ 使用原始路径，封面正常显示

### 场景 2: 沙箱路径变化（重启应用）
1. 生成封面
2. **完全关闭应用**
3. 重新打开应用
4. 查看列表
5. **结果**: ✅ 智能查找成功，封面正常显示

### 场景 3: 文件真的不存在
1. 手动删除封面文件
2. 查看列表
3. **结果**: ⚠️ 不显示封面（预期行为）

---

## 📝 日志输出

### 成功找到封面
```
✅ 智能查找成功: /var/mobile/.../B7E14D8E/.../NavigationHistory/xxx_cover.png
```

### 未找到封面
```
❌ 未找到封面: xxx_cover.png
```

### 图片加载失败
```
❌ 封面图片加载失败: [错误详情]
```

---

## 🎁 额外好处

### 1. **向后兼容**
- 旧的历史记录（路径已变）也能正确显示封面
- 无需迁移数据

### 2. **容错性强**
- 原始路径可用 → 直接使用（性能最优）
- 原始路径失效 → 智能查找（兼容性最优）
- 文件真不存在 → 优雅降级（用户体验最优）

### 3. **调试友好**
- 详细的日志输出
- 清晰的错误提示
- 便于排查问题

---

## ⚠️ 注意事项

### 1. **依赖目录结构**

此方案假设封面文件始终保存在：
```
Library/Application Support/com.mapbox.FlutterMapboxNavigation/NavigationHistory/
```

如果未来改变这个目录结构，需要同步更新 `_findCoverFile` 方法。

### 2. **文件名唯一性**

此方案依赖文件名唯一性。由于使用 UUID 作为文件名前缀，这个假设是安全的：
```
DA309A17-A558-4501-8175-841CB156EF9E_cover.png
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
              UUID 保证唯一性
```

### 3. **性能考虑**

- **第一次查找**: 尝试原始路径 → 快
- **智能查找**: 提取文件名 + 构建新路径 + 检查文件 → 也很快
- **总体**: 性能影响可忽略

---

## 🚀 未来优化方向

### 可选：iOS 端路径更新（更彻底的方案）

如果想彻底解决，可以在 iOS 端实现：

```swift
func getNavigationHistoryList(result: @escaping FlutterResult) {
    let historyList = historyManager!.getHistoryList()
    
    let historyMaps = historyList.map { history in
        var map = history.toFlutterMap()
        
        // 🆕 动态更新 cover 路径到当前沙箱
        if let oldCoverPath = history.cover {
            let fileName = URL(fileURLWithPath: oldCoverPath).lastPathComponent
            let currentCoverPath = defaultHistoryDirectoryURL()
                .appendingPathComponent(fileName).path
            
            if FileManager.default.fileExists(atPath: currentCoverPath) {
                map["cover"] = currentCoverPath  // 更新为当前路径
            }
        }
        
        return map
    }
    
    result(historyMaps)
}
```

**权衡**:
- ✅ 更彻底，Flutter 端无需改动
- ❌ 每次获取列表都要遍历更新
- ❌ 当前 Flutter 方案已足够好

---

## ✨ 总结

这个问题是 iOS 开发中的**经典问题**：沙箱路径不稳定。

**解决思路**: 
- 🔑 **不要依赖绝对路径**
- 🔍 **使用相对路径或文件名查找**
- 🛡️ **添加容错和降级机制**

当前的 Flutter 端智能查找方案：
- ✅ 简单高效
- ✅ 完全解决问题
- ✅ 向后兼容
- ✅ 用户体验友好

**原则**: 在正确的层级解决问题。这个问题本质上是"显示层"的问题，所以在 Flutter 端（显示层）解决是合理的。

