//
//  FreeDriveViewController.swift
//  flutter_mapbox_navigation
//
//  Created by Emmanuel Oche on 5/25/23.
//

import UIKit
import MapboxNavigationUIKit
import MapboxNavigationCore
import MapboxMaps
import Combine

public class FreeDriveViewController : UIViewController {

    private var navigationMapView: NavigationMapView!
    private let locationProvider = AppleLocationProvider()
    private var cancellables = Set<AnyCancellable>()

    public override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationMapView()
    }

    private func createNavigationMapView() {
        // Create publishers for location and route progress
        // AppleLocationProvider.onLocationUpdate provides Location objects that need to be converted to CLLocation
        let locationPublisher: AnyPublisher<CLLocation, Never> = locationProvider.onLocationUpdate
            .compactMap { locations -> CLLocation? in
                // locations is an array of Location objects, convert to CLLocation
                guard let location = locations.first else { return nil }
                return CLLocation(
                    coordinate: location.coordinate,
                    altitude: location.altitude ?? 0.0,
                    horizontalAccuracy: location.horizontalAccuracy ?? 0.0,
                    verticalAccuracy: location.verticalAccuracy ?? 0.0,
                    course: location.bearing ?? -1.0,
                    speed: location.speed ?? 0.0,
                    timestamp: location.timestamp
                )
            }
            .eraseToAnyPublisher()

        let routeProgressPublisher = Just<RouteProgress?>(nil)
            .eraseToAnyPublisher()

        // Initialize NavigationMapView with required publishers
        navigationMapView = NavigationMapView(
            location: locationPublisher,
            routeProgress: routeProgressPublisher
        )
    }

    private func setupNavigationMapView() {
        createNavigationMapView()

        navigationMapView.frame = view.bounds
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // In v3, userLocationStyle is replaced with puckType
        navigationMapView.puckType = .puck2D()

        // In v3, NavigationViewportDataSource is replaced with MobileViewportDataSource
        let navigationViewportDataSource = MobileViewportDataSource(navigationMapView.mapView)
        navigationViewportDataSource.options.followingCameraOptions.zoomUpdatesAllowed = false

        // Set the zoom level manually through currentNavigationCameraOptions
        var cameraOptions = navigationViewportDataSource.currentNavigationCameraOptions
        cameraOptions.followingCamera.zoom = 17.0
        navigationViewportDataSource.currentNavigationCameraOptions = cameraOptions

        navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource

        view.addSubview(navigationMapView)
    }

}