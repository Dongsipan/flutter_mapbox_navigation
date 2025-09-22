import MapboxDirections
import MapboxMaps
import MapboxNavigationCore
import MapboxNavigationUIKit
import UIKit

/// 简化的历史回放视图控制器
/// 完全按照官方 History-Replaying.swift 示例实现
/// 自动开始回放，无需手动控制
final class HistoryReplayViewController: UIViewController {

    // MARK: - Properties (following official example pattern)

    private let historyFilePath: String

    private var navigationMapView: NavigationMapView! {
        didSet {
            if let navigationMapView = oldValue {
                navigationMapView.removeFromSuperview()
            }

            if navigationMapView != nil {
                configure()
            }
        }
    }

    private lazy var historyReplayController: HistoryReplayController = {
        // Create HistoryReplayController following official example
        print("Creating HistoryReplayController with file: \(historyFilePath)")

        // Smart path resolution for iOS sandbox changes
        let currentHistoryDir = defaultHistoryDirectoryURL()
        print("当前应用历史记录目录: \(currentHistoryDir.path)")

        // List current directory contents
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: currentHistoryDir.path) {
            print("当前历史记录目录内容 (\(contents.count) 个文件):")
            for file in contents {
                print("  - \(file)")
            }
        }

        let fileURL = URL(fileURLWithPath: historyFilePath)
        print("提供的文件URL: \(fileURL)")
        print("文件URL路径: \(fileURL.path)")
        print("文件URL绝对字符串: \(fileURL.absoluteString)")

        var finalFileURL = fileURL

        // Check if file exists, if not try to find it in current directory
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            print("❌ 原始路径文件不存在")

            // Extract filename and try to find it in current directory
            let filename = fileURL.lastPathComponent
            let currentDirFileURL = currentHistoryDir.appendingPathComponent(filename)
            print("在当前目录中查找文件: \(currentDirFileURL.path)")

            if FileManager.default.fileExists(atPath: currentDirFileURL.path) {
                print("✅ 在当前目录中找到同名文件")
                finalFileURL = currentDirFileURL
            } else {
                print("❌ 在当前目录中也未找到文件")
            }
        } else {
            print("✅ 原始路径文件存在")
        }

        print("✅ 文件存在，创建HistoryReader，使用路径: \(finalFileURL.path)")

        guard let historyReader = HistoryReader(fileUrl: finalFileURL, readOptions: nil) else {
            fatalError("Failed to create HistoryReader with file: \(finalFileURL.path)")
        }

        var historyReplayController = HistoryReplayController(historyReader: historyReader)
        historyReplayController.delegate = self
        return historyReplayController
    }()

    private lazy var mapboxNavigationProvider = MapboxNavigationProvider(
        coreConfig: .init(
            routingConfig: .init(
                rerouteConfig: .init(
                    detectsReroute: false // disabling reroute detection for history replay
                )
            ),
            locationSource: .custom(
                .historyReplayingValue(with: historyReplayController)
            )
        )
    )

    private var mapboxNavigation: MapboxNavigation {
        mapboxNavigationProvider.mapboxNavigation
    }

    private var navigationRoutes: NavigationRoutes?

    // MARK: - Initialization

    init(historyFilePath: String) {
        self.historyFilePath = historyFilePath
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        loadNavigationViewIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Following official example: start free drive automatically
        startFreeDrive()
    }

    // MARK: - Private Methods

    private func loadNavigationViewIfNeeded() {
        if navigationMapView == nil {
            navigationMapView = .init(
                location: mapboxNavigation.navigation()
                    .locationMatching.map(\.enhancedLocation)
                    .eraseToAnyPublisher(),
                routeProgress: mapboxNavigation.navigation()
                    .routeProgress.map(\.?.routeProgress)
                    .eraseToAnyPublisher(),
                predictiveCacheManager: mapboxNavigationProvider.predictiveCacheManager
            )
        }
    }

    private func configure() {
        setupNavigationMapView()
    }

    private func startFreeDrive() {
        print("Starting free drive for history replay")
        mapboxNavigation.tripSession().startFreeDrive()
    }

    private func setupNavigationMapView() {
        navigationMapView.translatesAutoresizingMaskIntoConstraints = false

        view.insertSubview(navigationMapView, at: 0)

        NSLayoutConstraint.activate([
            navigationMapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationMapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationMapView.topAnchor.constraint(equalTo: view.topAnchor),
            navigationMapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func presentNavigationController(with navigationRoutes: NavigationRoutes) {
        let navigationOptions = NavigationOptions(
            mapboxNavigation: mapboxNavigation,
            voiceController: mapboxNavigationProvider.routeVoiceController,
            eventsManager: mapboxNavigationProvider.eventsManager()
        )
        let navigationViewController = NavigationViewController(
            navigationRoutes: navigationRoutes,
            navigationOptions: navigationOptions
        )
        navigationViewController.delegate = self
        navigationViewController.modalPresentationStyle = .fullScreen
        navigationViewController.routeLineTracksTraversal = true

        presentAndRemoveNavigationMapView(navigationViewController)
    }

    private func presentAndRemoveNavigationMapView(
        _ navigationViewController: NavigationViewController,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        navigationViewController.modalPresentationStyle = .fullScreen
        present(navigationViewController, animated: animated) {
            completion?()
            self.navigationMapView = nil
        }
    }

    private func cleanupReplay() {
        print("Cleaning up history replay")
        mapboxNavigation.tripSession().setToIdle()
        navigationMapView = nil
    }
}

// MARK: - HistoryReplayDelegate (following official example)

extension HistoryReplayViewController: HistoryReplayDelegate {
    func historyReplayController(
        _: MapboxNavigationCore.HistoryReplayController,
        didReplayEvent event: any MapboxNavigationCore.HistoryEvent
    ) {
        // Monitor all incoming events as they come (following official example)
        // In this simplified version we don't need to handle specific events
    }

    func historyReplayController(
        _: MapboxNavigationCore.HistoryReplayController,
        wantsToSetRoutes routes: MapboxNavigationCore.NavigationRoutes
    ) {
        // Handle cases when the history file had updated current routes set
        // Following official example pattern
        if presentedViewController == nil {
            presentNavigationController(with: routes)
        } else {
            mapboxNavigation.tripSession().startActiveGuidance(
                with: routes,
                startLegIndex: 0
            )
        }
    }

    func historyReplayControllerDidFinishReplay(_: HistoryReplayController) {
        // Following official example: dismiss and cleanup when replay finishes
        presentedViewController?.dismiss(animated: true) {
            self.loadNavigationViewIfNeeded()
            self.mapboxNavigation.tripSession().setToIdle()
        }
    }
}

// MARK: - NavigationViewControllerDelegate (following official example)

extension HistoryReplayViewController: NavigationViewControllerDelegate {
    func navigationViewControllerDidDismiss(
        _ navigationViewController: NavigationViewController,
        byCanceling canceled: Bool
    ) {
        dismiss(animated: true) {
            self.mapboxNavigation.tripSession().setToIdle()
        }
        loadNavigationViewIfNeeded()
    }
}