# 需求文档 - Android地图搜索功能

## 简介

本功能旨在为Android平台实现与iOS平台一致的地图搜索功能。用户可以通过带有搜索框的完整地图界面搜索地点，选择目的地后自动生成包含起点（当前位置）和终点（选中位置）的路径点数组，用于后续的导航功能。

## 术语表

- **MapboxSearch**: Mapbox提供的地点搜索SDK
- **SearchEngine**: Mapbox Search SDK中的核心搜索引擎组件
- **SearchResult**: 搜索返回的地点结果对象
- **WayPoint**: 导航路径点，包含名称、坐标、地址等信息
- **MethodChannel**: Flutter与原生平台通信的通道
- **SearchActivity**: Android端实现地图搜索功能的Activity
- **PointAnnotation**: 地图上的标记点
- **BottomSheet**: 底部抽屉UI组件，用于显示地点详情

## 需求

### 需求 1: 集成Mapbox Search SDK

**用户故事:** 作为开发者，我需要在Android项目中集成Mapbox Search SDK，以便使用Mapbox的地点搜索功能。

#### 验收标准

1. WHEN 项目构建时 THEN 系统应成功引入Mapbox Search SDK依赖
2. WHEN 应用启动时 THEN 系统应正确初始化Mapbox Search SDK
3. WHEN 调用搜索API时 THEN 系统应能够正常访问Mapbox搜索服务
4. THE 系统应配置正确的Mapbox访问令牌

### 需求 2: 创建地图搜索Activity

**用户故事:** 作为用户，我想要打开一个带有搜索框的地图界面，以便我可以搜索和选择目的地。

#### 验收标准

1. WHEN Flutter调用showSearchView方法时 THEN 系统应启动SearchActivity
2. THE SearchActivity应显示完整的地图视图
3. THE SearchActivity应在顶部显示搜索输入框
4. THE SearchActivity应显示取消按钮用于关闭界面
5. THE SearchActivity应显示定位按钮用于回到当前位置
6. WHEN Activity启动时 THEN 地图应自动定位到用户当前位置

### 需求 3: 实现搜索功能

**用户故事:** 作为用户，我想要在搜索框中输入地点名称，以便系统能够提供相关的搜索建议。

#### 验收标准

1. WHEN 用户在搜索框中输入文字时 THEN 系统应实时显示自动补全建议
2. WHEN 搜索建议列表显示时 THEN 每个建议应包含地点名称和地址信息
3. WHEN 用户点击某个搜索建议时 THEN 系统应在地图上显示该地点的标记
4. WHEN 用户点击某个搜索建议时 THEN 地图应自动调整视角到该地点
5. WHEN 搜索无结果时 THEN 系统应显示友好的提示信息

### 需求 4: 显示地图标记

**用户故事:** 作为用户，我想要在地图上看到搜索结果的标记，以便我可以直观地了解地点位置。

#### 验收标准

1. WHEN 用户选择搜索结果时 THEN 系统应在地图上添加标记点
2. THE 标记点应显示地点名称
3. THE 标记点应使用清晰可见的图标
4. WHEN 用户点击地图标记时 THEN 系统应显示该地点的详细信息
5. WHEN 显示多个搜索结果时 THEN 地图应自动调整视角以显示所有标记

### 需求 5: 实现底部抽屉

**用户故事:** 作为用户，我想要在选择地点后看到详细信息，以便我可以确认是否是我想要的目的地。

#### 验收标准

1. WHEN 用户点击地图标记时 THEN 系统应从底部弹出抽屉显示地点详情
2. THE 底部抽屉应显示地点名称
3. THE 底部抽屉应显示地点地址
4. THE 底部抽屉应显示"前往此处"按钮
5. WHEN 用户点击地图其他区域时 THEN 底部抽屉应自动隐藏
6. THE 底部抽屉应有平滑的动画效果

### 需求 6: 生成路径点数组

**用户故事:** 作为用户，我想要在点击"前往此处"按钮后获得包含起点和终点的路径信息，以便系统可以开始导航。

#### 验收标准

1. WHEN 用户点击"前往此处"按钮时 THEN 系统应获取用户当前位置作为起点
2. WHEN 系统获取当前位置时 THEN 系统应通过反向地理编码获取起点名称
3. THE 系统应将选中的地点作为终点
4. THE 系统应生成包含起点和终点的wayPoints数组
5. WHEN wayPoints数组生成后 THEN 系统应通过MethodChannel返回给Flutter层
6. THE wayPoints数组中每个元素应包含name、latitude、longitude、isSilent、address字段

### 需求 7: Flutter通信接口

**用户故事:** 作为开发者，我需要通过Flutter MethodChannel调用原生搜索功能，以便在Flutter应用中使用该功能。

#### 验收标准

1. THE 系统应在flutter_mapbox_navigation/search通道上注册showSearchView方法
2. WHEN Flutter调用showSearchView方法时 THEN Android端应启动搜索Activity
3. WHEN 用户完成地点选择时 THEN 系统应返回wayPoints数组给Flutter
4. WHEN 用户取消搜索时 THEN 系统应返回null给Flutter
5. IF 发生错误 THEN 系统应通过PlatformException返回错误信息

### 需求 8: 用户位置权限

**用户故事:** 作为用户，我需要授予位置权限，以便系统可以获取我的当前位置作为导航起点。

#### 验收标准

1. WHEN SearchActivity启动时 THEN 系统应检查位置权限状态
2. IF 位置权限未授予 THEN 系统应请求位置权限
3. WHEN 位置权限被授予时 THEN 系统应在地图上显示用户位置
4. WHEN 位置权限被拒绝时 THEN 系统应显示友好的提示信息
5. THE 系统应在地图上显示用户位置指示器（puck）

### 需求 9: 错误处理

**用户故事:** 作为用户，我想要在发生错误时看到清晰的错误提示，以便我知道如何解决问题。

#### 验收标准

1. WHEN 网络连接失败时 THEN 系统应显示网络错误提示
2. WHEN 搜索服务不可用时 THEN 系统应显示服务错误提示
3. WHEN 位置服务不可用时 THEN 系统应显示位置服务错误提示
4. WHEN 反向地理编码失败时 THEN 系统应使用默认的"当前位置"作为起点名称
5. THE 所有错误信息应使用中文显示

### 需求 10: UI样式和体验

**用户故事:** 作为用户，我想要一个美观且易用的搜索界面，以便我可以快速找到目的地。

#### 验收标准

1. THE 搜索界面应使用Material Design设计规范
2. THE 搜索框应有清晰的提示文字
3. THE 按钮应有明显的点击反馈效果
4. THE 地图标记应使用醒目的颜色和图标
5. THE 底部抽屉应有圆角和阴影效果
6. THE 所有文本应使用合适的字体大小和颜色
7. THE 界面应支持深色模式（如果系统启用）
