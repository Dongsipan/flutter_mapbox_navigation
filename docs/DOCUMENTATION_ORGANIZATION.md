# 文档整理说明

## 整理日期
2025年1月6日

## 整理内容

将项目根目录下的 AI 生成的技术文档移动到 `docs/` 文件夹，保持根目录整洁。

## 文件夹结构

```
flutter_mapbox_navigation/
├── README.md                    # 项目主文档
├── API_DOCUMENTATION.md         # API 文档
├── DEVELOPMENT_GUIDE.md         # 开发指南
├── CHANGELOG.md                 # 更新日志
├── LICENSE                      # 许可证
├── docs/                        # 技术文档文件夹 (新增)
│   ├── README.md               # 文档索引
│   ├── ANDROID_SDK_V3_*.md     # Android SDK v3 相关文档
│   ├── GRADLE_*.md             # Gradle 配置文档
│   ├── KOTLIN_*.md             # Kotlin 相关文档
│   ├── *_IMPLEMENTATION.md     # 功能实现文档
│   ├── *_FIX.md                # 问题修复文档
│   └── ...                     # 其他技术文档
├── lib/                         # Flutter 代码
├── android/                     # Android 原生代码
├── ios/                         # iOS 原生代码
└── example/                     # 示例应用
```

## 保留在根目录的文档

以下文档保留在根目录，因为它们是项目的核心文档：

1. **README.md** - 项目主文档，包含快速开始指南
2. **API_DOCUMENTATION.md** - API 参考文档
3. **DEVELOPMENT_GUIDE.md** - 开发者指南
4. **CHANGELOG.md** - 版本更新历史
5. **LICENSE** - 开源许可证

## 移动到 docs/ 的文档

所有 AI 生成的技术文档、实现记录、修复说明等都移动到 `docs/` 文件夹：

### 文档类型

1. **SDK 升级文档** - Android SDK v3 升级相关的所有文档
2. **功能实现文档** - 各个功能的实现说明
3. **问题修复文档** - Bug 修复和问题解决记录
4. **配置文档** - Gradle、Kotlin 等配置相关文档
5. **测试文档** - 测试和调试相关文档
6. **平台对比文档** - Android 和 iOS 平台功能对比

### 文档总数

移动了约 **77 个** Markdown 文档到 `docs/` 文件夹。

## 文档索引

在 `docs/README.md` 中创建了完整的文档索引，按功能分类：

- Android SDK v3 升级相关 (30+ 文档)
- 官方 UI 组件迁移 (5 文档)
- UI 组件实现 (3 文档)
- 路线和导航功能 (9 文档)
- 地图样式和视觉效果 (10 文档)
- 位置和相机 (3 文档)
- 历史记录功能 (5 文档)
- Gradle 和构建配置 (3 文档)
- iOS 相关 (2 文档)
- 其他功能和修复 (7+ 文档)

## 使用建议

### 查找文档

1. **快速查找**：使用 `docs/README.md` 中的分类索引
2. **搜索**：使用 IDE 或命令行工具在 `docs/` 文件夹中搜索关键词
3. **按时间**：文档文件名通常包含创建日期信息

### 常用文档

- **SDK 升级**：`docs/ANDROID_SDK_V3_UPGRADE_GUIDE.md`
- **编译问题**：`docs/KOTLIN_COMPILATION_FIX.md`
- **Gradle 配置**：`docs/GRADLE_*.md`
- **功能实现**：`docs/*_IMPLEMENTATION.md`

## 维护建议

1. **新文档**：将来生成的技术文档应直接放在 `docs/` 文件夹
2. **更新索引**：添加新文档后，更新 `docs/README.md` 索引
3. **定期清理**：定期检查并归档过时的文档
4. **命名规范**：保持文档命名的一致性和描述性

## Git 操作

文档移动使用了 `mv` 命令，Git 会自动跟踪文件移动：

```bash
# 创建 docs 文件夹
mkdir -p docs

# 移动文档
mv ANDROID_*.md docs/
mv GRADLE_*.md docs/
# ... 等等

# 创建索引
# 创建 docs/README.md

# 更新主 README
# 添加文档链接到 README.md
```

## 好处

1. **根目录整洁** - 只保留核心文档，提高可读性
2. **文档分类** - 技术文档集中管理，便于查找
3. **易于维护** - 清晰的文档结构，便于后续维护
4. **更好的导航** - 通过索引文件快速定位所需文档
5. **版本控制** - Git 历史保持完整，文件移动可追踪

## 注意事项

- 所有文档的内容未修改，只是移动了位置
- Git 历史记录保持完整
- 文档间的相对链接可能需要更新（如果有的话）
- 建议在 IDE 中使用全局搜索功能查找文档引用
