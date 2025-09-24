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

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_mapbox_navigation", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "flutter_mapbox_navigation/events", binaryMessenger: registrar.messenger())
    let searchChannel = FlutterMethodChannel(name: "flutter_mapbox_navigation/search", binaryMessenger: registrar.messenger())

    let instance = FlutterMapboxNavigationPlugin()
    instance.searchController = SearchViewController(methodChannel: searchChannel)

    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addMethodCallDelegate(instance.searchController!, channel: searchChannel)

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

        else
        {
            result("Method is Not Implemented");
        }

    }

}
