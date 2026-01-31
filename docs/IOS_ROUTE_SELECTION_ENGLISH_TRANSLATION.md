# iOS Route Selection English Translation

## Overview

Translated all Chinese text in the iOS Route Selection View Controller to professional English, maintaining consistency with navigation app standards and the rest of the application.

## Translation Reference

### Class Documentation
| Chinese | English |
|---------|---------|
| 路线选择视图控制器 | Route Selection View Controller |
| 显示多条可选路线，用户可以点击选择路线，然后点击底部按钮开始导航 | Displays multiple route options, users can tap to select a route, then tap the bottom button to start navigation |

### Properties
| Chinese | English |
|---------|---------|
| 样式设置 | Style settings |
| 路线选择回调 | Route selection callback |

### UI Elements

#### Top Bar
| Chinese | English |
|---------|---------|
| 返回 | Back |
| 选择路线 | Select Route |

#### Buttons
| Chinese | English |
|---------|---------|
| 取消 | Cancel |
| 开始导航 | Start Navigation |

### Comments Translation

#### Setup Methods
| Chinese | English |
|---------|---------|
| 创建顶部栏 | Create top bar |
| 返回按钮 | Back button |
| 标题 | Title |
| 布局约束 | Layout constraints |
| 顶部栏 | Top bar |
| 创建全览按钮（类似地图应用的全览按钮） | Create overview button (similar to map app's overview button) |
| 布局约束 - 放在右下角，避开指南针 | Layout constraints - place in bottom right, avoiding compass |
| 创建底部按钮容器，扩展到屏幕底部（无间隙） | Create bottom button container, extending to screen bottom (no gap) |
| 取消按钮 | Cancel button |
| 开始导航按钮 | Start navigation button |
| 布局约束 - 扩展到屏幕底部 | Layout constraints - extend to screen bottom |
| 容器约束 - 扩展到view底部 | Container constraints - extend to view bottom |
| 容器顶部约束 - 给按钮留足够空间 | Container top constraint - leave enough space for buttons |

#### Map Setup
| Chinese | English |
|---------|---------|
| 使用 navigation() 方法访问 publishers | Use navigation() method to access publishers |
| 调整指南针位置，避免被顶部栏遮挡 | Adjust compass position to avoid being covered by top bar |
| 右上角 | Top right |
| 留出顶部栏的空间 | Leave space for top bar |
| 应用样式设置 | Apply style settings |

#### Display Routes
| Chinese | English |
|---------|---------|
| 在地图上显示所有路线 | Display all routes on the map |
| 开始展示路线到最佳视野 | Starting to showcase routes to best view |
| 备选路线数量 | Number of alternative routes |
| 使用 showcase 方法展示路线，带动画效果 | Use showcase method to display routes with animation |
| 如果有多条路线，更新界面提示 | If there are multiple routes, update UI prompt |
| 路线展示完成 | Route showcase completed |
| 可以添加路线信息标签，显示当前选中的路线信息 | Can add route info labels to display current selected route info |
| 例如：距离、预计时间等 | For example: distance, estimated time, etc. |
| 共有 X 条可选路线 | Total X routes available |

#### Actions
| Chinese | English |
|---------|---------|
| 显示完整路线全览 | Show complete route overview |
| 用户点击全览按钮 | User tapped overview button |
| 触发回调，通知选择了路线 | Trigger callback to notify route selection |
| 关闭当前视图 | Close current view |

#### Style Management
| Chinese | English |
|---------|---------|
| 应用地图样式 | Apply map style |
| 未设置地图样式，使用默认样式 | No map style set, using default style |
| 没有自定义样式，等待默认样式加载完成后展示路线 | No custom style, wait for default style to load before showcasing routes |
| 默认样式加载完成，开始展示路线 | Default style loaded, starting to showcase routes |
| 应用地图样式 | Applying map style |
| 设置地图样式 URI | Set map style URI |
| 已设置地图样式 | Map style set |
| 监听样式加载完成事件（替代固定延时） | Listen for style loaded event (replacing fixed delay) |
| 应用 Light Preset 和 Theme（如果有） | Apply Light Preset and Theme (if available) |
| 样式加载完成后，展示路线到最佳视野 | After style loading completes, showcase routes to best view |
| 样式加载完成，开始展示路线 | Style loading completed, starting to showcase routes |
| 获取 StyleURI | Get StyleURI |
| 应用 light preset 和 theme | Apply light preset and theme |
| 检查是否支持 light preset | Check if style supports light preset |
| 样式 'X' 不支持 Light Preset | Style 'X' does not support Light Preset |
| 应用 light preset | Apply light preset |
| Light preset 已应用 | Light preset applied |
| 应用 theme（如果是 faded 或 monochrome） | Apply theme (if faded or monochrome) |
| Theme 已应用 | Theme applied |
| Theme 已重置 | Theme reset |
| Light Preset 模式：手动/自动 | Light Preset mode: Manual/Automatic |
| 应用样式配置失败 | Failed to apply style configuration |

#### Delegate Methods
| Chinese | English |
|---------|---------|
| 用户点击了备选路线 | User tapped an alternative route |
| 用户选择了备选路线：路线 ID X | User selected alternative route: Route ID X |
| 切换到选中的备选路线 | Switch to the selected alternative route |
| 更新 navigationRoutes | Update navigationRoutes |
| 更新地图显示 | Update map display |
| 路线已切换为备选路线 | Route switched to alternative route |
| 无法切换到备选路线 | Unable to switch to alternative route |

## Code Structure

### Main Components
```swift
// Top bar with back button and title
- Back button: "Back"
- Title: "Select Route"

// Map view with compass
- Compass position adjusted to avoid top bar

// Overview button
- Bottom right corner
- Shows complete route overview

// Bottom buttons
- Cancel button: "Cancel"
- Start navigation button: "Start Navigation"
```

### User Interactions
1. **Back/Cancel**: Dismiss the view controller
2. **Overview**: Show all routes in best view
3. **Route Selection**: Tap on alternative routes to switch
4. **Start Navigation**: Confirm route selection and start navigation

## Consistency with Other Views

| Feature | Style Picker | Route Selection | Status |
|---------|-------------|-----------------|--------|
| Back Button | Cancel | Back | ✅ Appropriate |
| Primary Action | Apply | Start Navigation | ✅ Clear |
| Cancel Action | Cancel | Cancel | ✅ Match |
| Title Style | Map Style Settings | Select Route | ✅ Consistent |
| Button Style | Green primary | Green primary | ✅ Match |

## Implementation Date

2026-01-31

## Related Documents

- [iOS Style Picker English Translation](./IOS_STYLE_PICKER_ENGLISH_TRANSLATION.md)
- [iOS Theme Update](./IOS_THEME_UPDATE.md)
- [Route Selection Theme Fix](./ROUTE_SELECTION_THEME_FIX.md)
