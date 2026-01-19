# Google Services 移除验证清单

## 代码更改验证

### ✅ 已完成的更改

- [x] 移除 `android/build.gradle` 中的 Google Play Services 依赖
- [x] 更新 `LocationHelper.kt` 使用 Android 原生 LocationManager
- [x] 移除所有 Google Play Services 的 import 语句
- [x] 添加 `getLastKnownLocation()` 方法
- [x] 添加超时机制（10秒）
- [x] 优化定位策略（优先使用缓存位置）
- [x] 更新 CHANGELOG.md
- [x] 更新 README.md
- [x] 创建技术文档

### 📝 文档清单

- [x] `docs/ANDROID_REMOVE_GOOGLE_SERVICES.md` - 技术实现详细说明
- [x] `docs/GOOGLE_SERVICES_REMOVAL_GUIDE.md` - 用户指南和迁移说明
- [x] `docs/LOCATION_WITHOUT_GOOGLE_SERVICES.md` - 快速参考和最佳实践
- [x] `docs/AUTOBUILDROUTE_FIX_SUMMARY.md` - 修复总结
- [x] `docs/VERIFICATION_CHECKLIST.md` - 本文档

## 代码质量检查

### 编译检查

```bash
# 检查 Kotlin 代码编译
cd example/android
./gradlew assembleDebug

# 预期结果：编译成功，无错误
```

### 语法检查

- [x] LocationHelper.kt 无语法错误
- [x] 所有导入语句正确
- [x] 方法签名保持不变
- [x] 返回值类型一致

### 依赖检查

```bash
# 检查依赖树
cd example/android
./gradlew dependencies | grep google

# 预期结果：
# - 应该看到 com.google.gson（JSON 库，安全）
# - 应该看到 com.google.android.material（Material Design，安全）
# - 不应该看到 com.google.android.gms（Google Play Services）
```

## 功能测试清单

### 基本功能测试

- [ ] **权限检查**
  ```dart
  final hasPermission = await checkLocationPermission();
  // 预期：返回 true/false，无崩溃
  ```

- [ ] **获取当前位置**
  ```dart
  final location = await getCurrentLocation();
  // 预期：返回位置或 null，无崩溃
  ```

- [ ] **反向地理编码**
  ```dart
  final name = await reverseGeocode(point);
  // 预期：返回位置名称，无崩溃
  ```

- [ ] **开始导航（autoBuildRoute=true）**
  ```dart
  await MapboxNavigation.startNavigation(
    waypoints: waypoints,
    options: MapboxNavigationOptions(autoBuildRoute: true),
  );
  // 预期：成功启动导航，无 Google Service 错误
  ```

### 设备兼容性测试

#### 华为设备
- [ ] 华为 Mate 系列（鸿蒙系统）
- [ ] 华为 P 系列（鸿蒙系统）
- [ ] 华为 Nova 系列（鸿蒙系统）

#### 小米设备
- [ ] 小米手机（MIUI）
- [ ] Redmi 手机（MIUI）

#### OPPO 设备
- [ ] OPPO 手机（ColorOS）
- [ ] Realme 手机（Realme UI）

#### vivo 设备
- [ ] vivo 手机（OriginOS）
- [ ] iQOO 手机（OriginOS）

#### 其他设备
- [ ] 原生 Android 设备
- [ ] 三星设备（One UI）
- [ ] 定制 ROM（LineageOS 等）

### 环境测试

#### 户外环境（GPS）
- [ ] 首次定位（无缓存）
- [ ] 有缓存位置
- [ ] 移动中定位
- [ ] 静止时定位

#### 室内环境（网络定位）
- [ ] 有 WiFi 连接
- [ ] 仅移动网络
- [ ] 弱信号环境

#### 特殊环境
- [ ] 地下室（无信号）
- [ ] 高楼密集区
- [ ] 隧道内
- [ ] 电梯内

### 权限场景测试

- [ ] **首次安装**
  - 请求位置权限
  - 授予权限后获取位置
  - 拒绝权限后的处理

- [ ] **权限被拒绝**
  - 显示权限说明
  - 引导用户授予权限
  - 提供手动输入选项

- [ ] **权限被永久拒绝**
  - 引导用户打开设置
  - 提供替代方案

- [ ] **位置服务关闭**
  - 检测位置服务状态
  - 引导用户开启位置服务

### 性能测试

#### 定位速度
- [ ] 有缓存：< 100ms
- [ ] 无缓存（GPS）：1-5秒
- [ ] 无缓存（网络）：2-8秒
- [ ] 超时：10秒

#### 位置精度
- [ ] GPS：5-10米
- [ ] 网络：20-100米
- [ ] 混合：根据环境自动选择

#### 电量消耗
- [ ] 单次定位：低
- [ ] 持续导航：中等
- [ ] 后台运行：低

### 错误处理测试

- [ ] **无权限**
  ```
  预期：返回 null，不崩溃
  ```

- [ ] **位置服务关闭**
  ```
  预期：返回 null 或超时，不崩溃
  ```

- [ ] **无可用提供者**
  ```
  预期：返回 null，不崩溃
  ```

- [ ] **超时**
  ```
  预期：10秒后返回 null，不崩溃
  ```

- [ ] **网络错误**
  ```
  预期：使用 GPS 或返回 null，不崩溃
  ```

## 回归测试

### 现有功能验证

- [ ] **基本导航**
  - 开始导航
  - 停止导航
  - 暂停导航
  - 恢复导航

- [ ] **路线功能**
  - 路线规划
  - 路线选择
  - 路线重新规划
  - 多途经点

- [ ] **搜索功能**
  - 地点搜索
  - 地理编码
  - 反向地理编码
  - 搜索建议

- [ ] **历史记录**
  - 记录导航历史
  - 查看历史列表
  - 回放历史
  - 删除历史

- [ ] **地图样式**
  - 切换地图样式
  - 保存样式偏好
  - Light Preset 控制
  - 自动光照调整

- [ ] **语音指令**
  - 播放语音指令
  - 静音/取消静音
  - 语言切换
  - 音量控制

## 文档验证

### 用户文档
- [x] README.md 更新
- [x] CHANGELOG.md 更新
- [x] API_DOCUMENTATION.md 检查
- [x] 快速开始指南

### 技术文档
- [x] 实现细节说明
- [x] 架构变更说明
- [x] 迁移指南
- [x] 故障排除指南

### 示例代码
- [ ] 基本导航示例
- [ ] 搜索功能示例
- [ ] 历史记录示例
- [ ] 错误处理示例

## 发布前检查

### 代码审查
- [ ] 代码风格一致
- [ ] 注释完整清晰
- [ ] 无调试代码
- [ ] 无硬编码值

### 测试覆盖
- [ ] 单元测试通过
- [ ] 集成测试通过
- [ ] 手动测试完成
- [ ] 性能测试通过

### 文档完整性
- [ ] API 文档完整
- [ ] 使用示例完整
- [ ] 迁移指南完整
- [ ] 故障排除指南完整

### 版本管理
- [ ] 版本号更新
- [ ] CHANGELOG 更新
- [ ] Git 标签创建
- [ ] 发布说明准备

## 已知限制

### 定位精度
- 首次定位可能需要几秒钟
- 室内环境精度较低（20-100米）
- 地下室可能无法定位

### 设备兼容性
- 需要 Android 5.0 (API 21) 及以上
- 需要设备支持位置服务
- 需要用户授予位置权限

### 功能限制
- 不支持地理围栏（需要 Google Play Services）
- 不支持活动识别（需要 Google Play Services）
- 不支持融合定位（使用原生定位）

## 测试报告模板

```markdown
## 测试报告

### 测试环境
- 设备型号：
- Android 版本：
- 系统版本：
- 是否有 Google Services：

### 测试结果
- [ ] 基本功能正常
- [ ] 定位功能正常
- [ ] 导航功能正常
- [ ] 搜索功能正常

### 发现的问题
1. 问题描述
   - 重现步骤
   - 预期结果
   - 实际结果
   - 截图/日志

### 性能数据
- 首次定位时间：
- 缓存定位时间：
- 位置精度：
- 电量消耗：

### 建议
- 改进建议
- 优化建议
```

## 总结

### 完成情况
- ✅ 代码更改完成
- ✅ 文档编写完成
- ⏳ 测试进行中
- ⏳ 发布准备中

### 下一步
1. 在多个设备上进行测试
2. 收集测试反馈
3. 修复发现的问题
4. 准备发布说明
5. 发布新版本

### 联系方式
如有问题，请：
1. 查看文档
2. 查看示例代码
3. 提交 Issue
4. 联系维护者
