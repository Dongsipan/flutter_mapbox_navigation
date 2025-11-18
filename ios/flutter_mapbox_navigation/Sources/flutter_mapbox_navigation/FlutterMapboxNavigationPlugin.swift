import Flutter
import UIKit
import MapboxMaps
import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit
import MapboxSearch
import MapboxSearchUI

public class FlutterMapboxNavigationPlugin: NavigationFactory, FlutterPlugin {

  private var searchController: SearchViewController?
  private var stylePickerHandler: StylePickerHandler?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_mapbox_navigation", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "flutter_mapbox_navigation/events", binaryMessenger: registrar.messenger())
    let searchChannel = FlutterMethodChannel(name: "flutter_mapbox_navigation/search", binaryMessenger: registrar.messenger())

    let instance = FlutterMapboxNavigationPlugin()
    instance.searchController = SearchViewController(methodChannel: searchChannel)
    // StylePickerHandler 内部创建自己的 channel 并处理方法调用
    instance.stylePickerHandler = StylePickerHandler(messenger: registrar.messenger())

    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addMethodCallDelegate(instance.searchController!, channel: searchChannel)
    // StylePickerHandler 内部已经设置了 method call handler，不需要在这里注册

    eventChannel.setStreamHandler(instance)

    let viewFactory = FlutterMapboxNavigationViewFactory(messenger: registrar.messenger())
    registrar.register(viewFactory, withId: "FlutterMapboxNavigationView")

  }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

        let arguments = call.arguments as? NSDictionary

        if(call.method == "getPlatformVersion")
        {
            result("iOS " + UIDevice.current.systemVersion)
        }
        else if(call.method == "getDistanceRemaining")
        {
            result(_distanceRemaining)
        }
        else if(call.method == "getDurationRemaining")
        {
            result(_durationRemaining)
        }
        else if(call.method == "startFreeDrive")
        {
            startFreeDrive(arguments: arguments, result: result)
        }
        else if(call.method == "startNavigation")
        {
            startNavigation(arguments: arguments, result: result)
        }
        else if(call.method == "addWayPoints")
        {
            addWayPoints(arguments: arguments, result: result)
        }
        else if(call.method == "finishNavigation")
        {
            endNavigation(result: result)
        }
        else if(call.method == "enableOfflineRouting")
        {
            downloadOfflineRoute(arguments: arguments, flutterResult: result)
        }
        else if(call.method == "getNavigationHistoryList")
        {
            getNavigationHistoryList(result: result)
        }
        else if(call.method == "deleteNavigationHistory")
        {
            deleteNavigationHistory(arguments: arguments, result: result)
        }
        else if(call.method == "clearAllNavigationHistory")
        {
            clearAllNavigationHistory(result: result)
        }
        else if(call.method == "startHistoryReplay")
        {
            startHistoryReplay(arguments: arguments, result: result)
        }
        else if(call.method == "generateHistoryCover")
        {
            guard let args = arguments,
                  let historyFilePath = args["historyFilePath"] as? String,
                  let historyId = args["historyId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required parameters (historyFilePath, historyId)", details: nil))
                return
            }
            
            // 读取当前存储的样式设置
            let styleSettings = StylePickerHandler.loadStoredStyleSettings()
            
            HistoryCoverGenerator.shared.generateHistoryCover(
                filePath: historyFilePath, 
                historyId: historyId,
                mapStyle: styleSettings.mapStyle,       // 使用当前存储的样式
                lightPreset: styleSettings.lightPreset  // 使用当前存储的 light preset
            ) { [weak self] coverPath in
                guard let self = self else {
                    result(nil)
                    return
                }
                
                if let coverPath = coverPath {
                    // 🆕 更新历史记录数据库中的封面路径
                    if self.historyManager == nil {
                        self.historyManager = HistoryManager()
                    }
                    
                    let updateSuccess = self.historyManager!.updateHistoryCover(historyId: historyId, coverPath: coverPath)
                    
                    if updateSuccess {
                        print("✅ 封面生成并更新成功: \(coverPath)")
                        result(coverPath)
                    } else {
                        print("⚠️ 封面生成成功但更新记录失败")
                        result(coverPath)  // 仍然返回路径，让用户知道封面已生成
                    }
                } else {
                    print("❌ 封面生成失败")
                    result(nil)
                }
            }
        }

        else
        {
            result("Method is Not Implemented");
        }

    }

}
