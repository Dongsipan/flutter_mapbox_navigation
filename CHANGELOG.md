## 0.2.5
* 📊 新增历史事件详情 API - 获取导航历史的详细事件数据
* 🔍 支持位置更新事件提取 - 访问完整的 GPS 轨迹数据
* 🛣️ 支持路线分配事件 - 获取导航过程中的路线变更信息
* 📌 支持自定义事件解析 - 处理用户推送的自定义事件
* 🗺️ 提供原始位置数据 - 用于轨迹可视化和分析
* ⚡ 后台线程解析 - 避免阻塞主线程，提升性能
* 🔧 完善错误处理 - 详细的错误码和错误信息
* 📱 跨平台支持 - iOS 和 Android 平台数据结构一致
* 📖 完整的 API 文档 - 包含使用示例和最佳实践
* ✅ 属性测试覆盖 - 确保数据完整性和正确性

## 0.2.4
* 🚀 新增路线选择功能 - 支持在导航开始前选择不同的路线选项
* 🔍 集成 Mapbox 搜索功能 - 提供强大的地点搜索和地理编码能力
* 🖼️ 增强历史记录封面生成 - 自动为导航历史生成美观的路线封面图片
* 🌈 添加速度渐变轨迹线 - 历史回放时根据速度显示不同颜色的轨迹
* 📱 优化历史回放界面 - 改进导航栏外观和状态栏样式
* 🎯 完善自定义位置提供者 - 优化历史轨迹回放的位置显示精度
* 🔧 代码格式和结构优化 - 提升代码可读性和维护性
* 📊 增强事件日志记录 - 改进事件处理和错误处理逻辑
* 🎛️ 添加模拟导航开关控件 - 方便开发和测试
* 🗺️ 优化搜索结果标注显示 - 避免重复创建注释管理器

## 0.2.3
* 添加导航历史记录功能
* 新增 `enableHistoryRecording` 参数到 MapBoxOptions
* 新增 `NavigationHistory` 数据模型
* 新增历史记录管理 API (getNavigationHistoryList, deleteNavigationHistory, clearAllNavigationHistory)
* 支持 Android 和 iOS 平台的导航历史记录
* 添加完整的使用示例和文档

## 0.2.2
* Fix issue with voice units in Android
* Fix BannerText, VoiceInstruction and Off Route Events

## 0.2.1
* Fix issue with setting the language in Android

## 0.2.0
* Update MapBox Android Version
* Resolve issue where Navigation Does Not Dismiss Activity on Cancel

## 0.1.9
* Android Day/Night Style Default Values [PR 272](https://github.com/eopeter/flutter_mapbox_navigation/pull/272)
* Fix iOS Embedded Clear Route Issue [PR 284](https://github.com/eopeter/flutter_mapbox_navigation/pull/284)
* Fix Route Events Not Sent [PR 288](https://github.com/eopeter/flutter_mapbox_navigation/pull/288)
* Set WayPoint IsSilent to default false

## 0.1.8
* Fix Android NavigationMode [261](https://github.com/eopeter/flutter_mapbox_navigation/pull/261)

## 0.1.7
* Fix Android mainClass entry Error

## 0.1.6
* Embedded Clear Route Bug Fix

## 0.1.5
* Bug Fixes [248](https://github.com/eopeter/flutter_mapbox_navigation/pull/248) and [250](https://github.com/eopeter/flutter_mapbox_navigation/pull/250)

## 0.1.4
* Android Send Cancel Event [235](https://github.com/eopeter/flutter_mapbox_navigation/pull/235)
* iOS Receive Feedback Sent to Mapbox on Dart Side; Ability to Turn On/Off Show Feedback [235](https://github.com/eopeter/flutter_mapbox_navigation/pull/235)
* Add Free Drive Mode [240](https://github.com/eopeter/flutter_mapbox_navigation/pull/240)

## 0.1.3
* Android Send Cancel Event [236](https://github.com/eopeter/flutter_mapbox_navigation/pull/236)

## 0.1.2
* Android embedded view now working [#225](https://github.com/eopeter/flutter_mapbox_navigation/pull/225)
* Fixes Progress Changed and Route Build Event Data serialization on Android [#227](https://github.com/eopeter/flutter_mapbox_navigation/pull/227)

## 0.1.1
* Android: move LeakCanary as DebugImplementation [#221](https://github.com/eopeter/flutter_mapbox_navigation/pull/221)
* Emit Route Data Upon Route Build [#218](https://github.com/eopeter/flutter_mapbox_navigation/pull/218)
* Implement Silent Waypoints [#214](https://github.com/eopeter/flutter_mapbox_navigation/pull/214)

## 0.1.0
* breaking changes
* Android Gradle Upgrade
* Bug Fixes
* MapBox Library Upgrade
* iOS MapBox Token Property Name in info.plist is now MBXAccessToken
* Embedded Nav Broken in Android - Working On It

## 0.0.26
* not implemented bug for onNextLegStart

## 0.0.25
* bug fixes

## 0.0.24
* bug fixes

## 0.0.22
* bug fixes

## 0.0.21
* Fix static analysis bug

## 0.0.20
* Upgrade Mapbox Libraries
* Upgrade to Null Safety

## 0.0.19
* Upgrade MapBox Android to v1.0.1
* Gradle Updates
* Bug Fixes

## 0.0.18
* Bug Fixes

## 0.0.17
* Offline Navigation
* Bug Fixes

## 0.0.16
* Refactoring with breaking changes. Sorry :-(
* Add Embedded Navigation
* Consolidated Navigation Options
* Add ability to change map style
* Can select alternate routes

## 0.0.15
* Remove Dialog at WayPoint Arrival
* Tweak iOS WayPoint navigation behavior to match Android
* Bug Fixes

## 0.0.14
* Bug Fixes

## 0.0.13
* Apply Dart Formats
* Added Some Documentation
* Bug Fixes

## 0.0.12
* Added Multi-Stop WayPoint Navigation
* More Detailed Progress Events like route leg and step details
* MapBox Version Updates

## 0.0.11
* Deprecated NavigationMode. Use MapBoxNavigationMode instead.
* Upgrade MapBox Libraries
* Android Gradle Update
* Bug Fixes

## 0.0.10
* Added ability to override the measurement system used in spoken instructions

## 0.0.9
* Added option to change default language. See example in Read Me. This is only the language for the spoken instruction.

## 0.0.8
* Plugin upgrade for Flutter 1.12

## 0.0.7
* Remove extraneous jars for Kotlin-Reflect Inserted to lib folder by Android Studio

## 0.0.6
* Android Bug Fix

## 0.0.5
*[Breaking] Constructor and Name Change. See Example
* Route Progress And Arrival Events on iOS. Android Pending.
* Ending Navigation
* Navigation Modes Support (driving, walking, cycling)
* Simulation Mode Support

## 0.0.4
* Gradle 5.4.1 Support
* Mapbox Update to Current Versions
* iOS 10 Minimum Requirement

## 0.0.3

* Added AndroidX Support

## 0.0.2

* Added Android Support

## 0.0.1

* Initial Release That Targets only iOS
