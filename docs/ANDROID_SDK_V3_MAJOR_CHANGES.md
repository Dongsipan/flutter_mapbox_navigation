# Android SDK v3 重大架构变更

## 日期
2026-01-05

## 关键发现

### 1. Drop-in UI 完全移除

Mapbox Navigation SDK v3 **完全移除了 Drop-in UI**，这是一个重大的架构变更。

**v2 中的 Drop-in UI:**
```kotlin
import com.mapbox.navigation.dropin.navigationview.NavigationView
import com.mapbox.navigation.dropin.map.MapViewObserver

// 使用 NavigationView
binding.navigationView.api.startActiveGuidance(routes)
binding.navigationView.customizeViewOptions { ... }
```

**v3 中的变更:**
- ❌ `com.mapbox.navigation.dropin` 包已完全移除
- ❌ `NavigationView` 类不再存在
- ❌ `MapViewObserver` 接口不再存在
- ✅ 需要使用新的 `ui-components` 和 `ui-maps` 模块手动构建 UI

### 2. 新的 UI 架构

v3 提供了更灵活但需要更多手动配置的 UI 组件：

**核心模块:**
- `com.mapbox.navigationcore:ui-maps` - 地图相关 UI
- `com.mapbox.navigationcore:ui-components` - UI 组件
- `com.mapbox.maps:android` - 基础地图 SDK

**新的方式:**
```kotlin
// 需要手动创建和配置 MapView
import com.mapbox.maps.MapView
import com.mapbox.maps.Style

// 需要手动管理导航状态
import com.mapbox.navigation.core.MapboxNavigation
import com.mapbox.navigation.core.lifecycle.MapboxNavigationApp
```

### 3. 当前代码的影响

我们的 `NavigationActivity.kt` 大量使用了 Drop-in UI：

**受影响的代码:**
1. `NavigationView` 的所有使用（约 20+ 处）
2. `MapViewObserver` 接口实现
3. `NavigationViewListener` 回调
4. `customizeViewOptions` 和 `customizeViewBinders` 方法
5. 布局文件中的 `NavigationView` 组件

**需要重写的功能:**
- ✅ 地图显示和交互
- ✅ 路线规划和显示
- ✅ 导航指引 UI
- ✅ 语音播报
- ✅ 到达检测
- ✅ 自定义 UI 组件

### 4. 迁移策略

#### 选项 A: 完全重写 UI（推荐）
**优点:**
- 使用 v3 的最新架构
- 更灵活的自定义能力
- 长期维护性好

**缺点:**
- 工作量大（预计 3-5 天）
- 需要重新设计 UI 架构
- 需要大量测试

**步骤:**
1. 创建新的布局文件，使用 `MapView` 替代 `NavigationView`
2. 手动实现导航 UI 组件（转弯指示、速度显示等）
3. 使用 `MapboxNavigation` API 管理导航状态
4. 实现自定义的事件监听和回调
5. 迁移所有现有功能

#### 选项 B: 使用 v3 的预构建组件
**优点:**
- 工作量相对较小
- 可以复用一些 v3 提供的组件

**缺点:**
- v3 的预构建组件可能不如 v2 的 Drop-in UI 完整
- 仍需要大量手动配置
- 文档可能不够完善

#### 选项 C: 暂时保持 v2（不推荐）
**优点:**
- 无需修改代码

**缺点:**
- 无法使用 v3 的新功能
- v2 将逐渐停止维护
- 无法解决现有的功能缺失问题

### 5. 推荐方案

**建议采用选项 A：完全重写 UI**

理由：
1. 我们已经完成了依赖升级，回退成本高
2. v3 是未来的方向，早晚要迁移
3. 可以借此机会优化 UI 和用户体验
4. 参考项目已经提供了 v3 的实现示例

### 6. 实施计划

#### 阶段 1: 核心导航功能（2-3 天）
- [ ] 创建新的布局文件（使用 MapView）
- [ ] 实现基础的地图显示
- [ ] 实现路线规划和显示
- [ ] 实现导航启动和停止
- [ ] 实现位置跟踪

#### 阶段 2: UI 组件（1-2 天）
- [ ] 实现转弯指示 UI
- [ ] 实现速度和距离显示
- [ ] 实现到达时间显示
- [ ] 实现导航控制按钮

#### 阶段 3: 高级功能（1-2 天）
- [ ] 实现语音播报
- [ ] 实现路线偏离检测
- [ ] 实现历史记录功能
- [ ] 实现自由驾驶模式

#### 阶段 4: 测试和优化（1 天）
- [ ] 功能测试
- [ ] UI 测试
- [ ] 性能优化

### 7. 参考资源

**Mapbox 官方文档:**
- [v3 安装指南](https://docs.mapbox.com/android/navigation/guides/install/)
- [v2 到 v3 迁移指南](https://docs.mapbox.com/android/navigation/guides/migration-from-v2/)
- [UI 组件文档](https://docs.mapbox.com/android/navigation/guides/ui-components/)

**参考项目配置:**
```kotlin
// 参考项目使用的依赖
implementation("com.mapbox.navigationcore:android:3.10.0")
implementation("com.mapbox.navigationcore:copilot:3.10.0")
implementation("com.mapbox.navigationcore:ui-maps:3.10.0")
implementation("com.mapbox.navigationcore:voice:3.10.0")
implementation("com.mapbox.navigationcore:tripdata:3.10.0")
implementation("com.mapbox.navigationcore:ui-components:3.10.0")
implementation("com.mapbox.maps:android:11.4.0")
```

### 8. 下一步行动

**需要用户决策:**
1. 是否继续 v3 迁移（推荐）
2. 如果继续，是否接受完全重写 UI 的工作量
3. 是否需要先创建一个最小可行版本（MVP）

**如果继续迁移，建议:**
1. 先实现一个最小可行版本，包含基本的导航功能
2. 逐步添加 UI 组件和高级功能
3. 保持与 Flutter 层的接口不变，只修改 Android 实现

## 总结

Mapbox Navigation SDK v3 的 Drop-in UI 移除是一个重大变更，需要完全重写导航 UI 部分的代码。虽然工作量较大，但这是使用 v3 的必经之路，也是实现 Android 端功能完整性的机会。

建议采用渐进式迁移策略，先实现核心功能，再逐步完善 UI 和高级特性。

---

**创建时间**: 2026-01-05
**状态**: 等待用户决策
