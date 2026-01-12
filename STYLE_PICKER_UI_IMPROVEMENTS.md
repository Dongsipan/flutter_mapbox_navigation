# StylePickerViewController 交互改进

## 改进内容

### 1. Light Preset 区域的状态管理（iOS 最佳实践）

**设计原则：** 遵循 iOS Human Interface Guidelines，使用**禁用状态**而不是隐藏，保持界面一致性和可预测性。

**功能：** Light Preset 区域始终可见，根据当前样式动态调整按钮状态和提示文本。

**支持的样式：**

- ✅ Standard（标准）
- ✅ Standard Satellite（卫星）
- ✅ Faded（褪色）
- ✅ Monochrome（单色）

**不支持的样式：**

- ❌ Light（浅色）
- ❌ Dark（深色）
- ❌ Outdoors（户外）

**视觉反馈：**

- **支持的样式**：提示文本为灰色，按钮可交互
- **不支持的样式**：提示文本为橙色警告，按钮禁用（alpha=0.4，文字为三级标签色）

**实现：**

```swift
private func updateLightPresetSectionVisibility() {
    let supportedStyles = ["standard", "standardSatellite", "faded", "monochrome"]
    let isSupported = supportedStyles.contains(selectedStyle)
    
    // 更新提示文本和颜色
    if let subtitleLabel = lightPresetSection.viewWithTag(9999) as? UILabel {
        if isSupported {
            subtitleLabel.text = "仅标有 ✨ 的样式支持，已根据时间自动选择"
            subtitleLabel.textColor = .secondaryLabel
        } else {
            subtitleLabel.text = "⚠️ 当前样式不支持 Light Preset，请选择标有 ✨ 的样式"
            subtitleLabel.textColor = .systemOrange
        }
    }
    
    // 刷新按钮状态（禁用或启用）
    refreshLightPresetButtons()
}
```

### 2. 自动调整模式下的交互限制

**功能：** 当开启"根据日出日落自动调整"时：

#### 自动行为
1. **自动选择当前光照模式**：根据当前时间自动选中对应的 Light Preset
   - 5:00-7:00 → Dawn（黎明）
   - 7:00-17:00 → Day（白天）
   - 17:00-19:00 → Dusk（黄昏）
   - 19:00-5:00 → Night（夜晚）

2. **禁用手动选择**：用户无法点击其他 Light Preset 选项

3. **视觉反馈**：
   - 按钮透明度降低（alpha = 0.7）
   - 文字颜色变为次要标签色
   - 选中项显示绿色边框 + 时钟图标 🕒
   - 未选中项保持灰显状态

#### 手动模式恢复
关闭自动调整开关后：
- 恢复用户的手动选择能力
- 按钮恢复正常透明度和颜色
- 选中项显示蓝色边框 + 勾选图标 ✓

**实现：**
```swift
@objc private func automaticModeSwitchChanged() {
    lightPresetMode = automaticModeSwitch.isOn ? "automatic" : "manual"
    
    if lightPresetMode == "automatic" {
        // 自动选中当前时间对应的 preset
        selectedLightPreset = getCurrentTimeBasedLightPreset()
    }
    
    // 刷新按钮状态
    refreshLightPresetButtons()
    
    // 更新地图预览
    applyLightPresetToMap()
}
```

### 3. 实时地图预览更新

**功能：** 顶部地图预览会实时反映当前的光照模式设置。

**触发时机：**
- 切换地图样式时
- 手动选择 Light Preset 时
- 开启/关闭自动调整时

**实现：**
```swift
private func applyLightPresetToMap() {
    guard let mapView = mapView else { return }
    
    do {
        // 应用 light preset
        try mapView.mapboxMap.setStyleImportConfigProperty(
            for: "basemap",
            config: "lightPreset",
            value: selectedLightPreset
        )
        
        // 应用 theme（如果需要）
        if selectedStyle == "faded" {
            try mapView.mapboxMap.setStyleImportConfigProperty(
                for: "basemap",
                config: "theme",
                value: "faded"
            )
        }
        // ...
    } catch {
        print("⚠️ 应用样式配置失败: \(error)")
    }
}
```

## 用户体验流程

### 场景 1：选择不支持 Light Preset 的样式

1. 用户选择 "Light" 或 "Dark" 样式
2. **Light Preset 区域保持可见**（符合 iOS 最佳实践）
3. 提示文本变为橙色警告："⚠️ 当前样式不支持 Light Preset，请选择标有 ✨ 的样式"
4. 所有 Light Preset 按钮变为禁用状态（alpha=0.4，文字颜色变暗）
5. 用户点击按钮无响应
6. 用户知道此功能存在，并明白需要切换样式才能使用

### 场景 2：选择支持 Light Preset 的样式

1. 用户选择 "Standard" 样式
2. 提示文本恢复为灰色："仅标有 ✨ 的样式支持，已根据时间自动选择"
3. 所有 Light Preset 按钮恢复正常状态（可点击）
4. 默认显示当前时间对应的光照模式，蓝色边框 + 勾选图标
5. 用户可以手动选择其他光照模式
6. 顶部地图预览实时更新

### 场景 3：开启自动调整（样式支持时）

1. 用户开启"根据日出日落自动调整"开关
2. 系统自动选中当前时间对应的光照模式
3. 所有 Light Preset 按钮变为半透明（alpha=0.7）
4. 当前选中的按钮显示**绿色边框 + 时钟图标** 🕒
5. 文字颜色变为次要标签色
6. 顶部地图预览更新为自动选中的光照模式
7. 用户点击其他按钮无响应（交互已禁用）

### 场景 4：关闭自动调整

1. 用户关闭"根据日出日落自动调整"开关
2. 所有 Light Preset 按钮恢复可点击状态
3. 按钮透明度恢复正常（alpha=1.0）
4. 当前选中的按钮显示**蓝色边框 + 勾选图标** ✓
5. 文字颜色恢复为主标签色
6. 用户可以手动选择任意光照模式

### 场景 5：在不支持的样式下查看自动调整功能

1. 用户选择了 "Light" 样式（不支持 Light Preset）
2. Light Preset 按钮全部禁用（alpha=0.4）
3. **"根据日出日落自动调整"开关也被禁用**（isEnabled=false）
4. 开关标题和说明文字变为三级标签色（灰显）
5. 提示文本保持橙色警告状态
6. 用户无法操作开关，直到切换到支持的样式

## 视觉设计

### 样式支持 + 手动模式

- **选中项**：蓝色边框 + 蓝色勾选图标 ✓，正常透明度
- **未选中项**：灰色背景，正常透明度

### 样式支持 + 自动模式

- **选中项**：绿色边框 + 绿色时钟图标 🕒
- **所有项**：半透明（alpha = 0.7），文字变为次要颜色

### 样式不支持（任何模式）

- **所有按钮**：禁用外观（alpha = 0.4），文字变为三级标签色
- **自动调整开关**：禁用（isEnabled = false）
- **开关文字**：标题和说明文字变为三级标签色
- **提示文本**：橙色警告 "⚠️ 当前样式不支持 Light Preset"

## 技术细节

### 新增方法

1. **updateLightPresetSectionVisibility()**
   - 根据当前样式决定是否显示 Light Preset 区域

2. **refreshLightPresetButtons()**
   - 刷新所有 Light Preset 按钮，更新选中和禁用状态

3. **createLightPresetButton() 增强**
   - 支持自动模式的视觉样式
   - 根据模式显示不同的图标和颜色

### 修改的方法

1. **styleButtonTapped()**
   - 添加了 `updateLightPresetSectionVisibility()` 调用

2. **lightPresetTapped()**
   - 添加了自动模式的拦截逻辑

3. **automaticModeSwitchChanged()**
   - 添加了自动选择和刷新逻辑

4. **viewDidLoad()**
   - 初始化时调用 `updateLightPresetSectionVisibility()`

## 修改时间

2025-11-18
