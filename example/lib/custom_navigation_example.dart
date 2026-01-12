import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

class CustomNavigationExample extends StatefulWidget {
  const CustomNavigationExample({super.key});

  @override
  State<CustomNavigationExample> createState() =>
      _CustomNavigationExampleState();
}

class _CustomNavigationExampleState extends State<CustomNavigationExample> {
  MapBoxNavigationViewController? _controller;
  bool _isNavigating = false;
  String? _currentInstruction;
  double? _distanceRemaining;
  double? _durationRemaining;

  // 自定义导航选项
  late MapBoxOptions _customOptions;

  @override
  void initState() {
    super.initState();
    _initializeCustomOptions();
    _setupEventListener();
  }

  void _initializeCustomOptions() {
    _customOptions = MapBoxOptions(
      // 基础地图设置
      initialLatitude: 39.9042, // 北京天安门
      initialLongitude: 116.4074,
      zoom: 15.0,
      bearing: 0.0,
      tilt: 0.0,

      // 导航模式设置
      mode: MapBoxNavigationMode.drivingWithTraffic, // 驾驶模式（含交通）
      units: VoiceUnits.metric, // 使用公制单位
      language: "zh-CN", // 中文语音

      // 功能开关
      voiceInstructionsEnabled: true, // 启用语音指令
      bannerInstructionsEnabled: true, // 启用横幅指令
      alternatives: true, // 显示替代路线
      allowsUTurnAtWayPoints: false, // 禁止在路径点掉头

      // 模拟和调试
      simulateRoute: true, // 模拟路线（开发时使用）
      animateBuildRoute: true, // 动画显示路线构建

      // UI定制
      longPressDestinationEnabled: true, // 长按设置目的地
      showReportFeedbackButton: true, // 显示反馈按钮
      showEndOfRouteFeedback: true, // 显示路线结束反馈

      // 地图样式 - 注释掉以使用保存的用户偏好样式
      // 如果需要覆盖用户设置，可以取消注释下面两行
      // mapStyleUrlDay: "mapbox://styles/mapbox/navigation-day-v1",
      // mapStyleUrlNight: "mapbox://styles/mapbox/navigation-night-v1",
    );
  }

  void _setupEventListener() {
    MapBoxNavigation.instance.registerRouteEventListener(_onRouteEvent);
  }

  Future<void> _onRouteEvent(RouteEvent event) async {
    // 获取实时导航数据
    _distanceRemaining = await MapBoxNavigation.instance.getDistanceRemaining();
    _durationRemaining = await MapBoxNavigation.instance.getDurationRemaining();

    switch (event.eventType) {
      case MapBoxEvent.progress_change:
        final progressEvent = event.data as RouteProgressEvent;
        setState(() {
          _currentInstruction = progressEvent.currentStepInstruction;
        });
        break;

      case MapBoxEvent.navigation_running:
        setState(() {
          _isNavigating = true;
        });
        break;

      case MapBoxEvent.navigation_finished:
      case MapBoxEvent.navigation_cancelled:
        setState(() {
          _isNavigating = false;
          _currentInstruction = null;
        });
        break;

      case MapBoxEvent.on_arrival:
        _showArrivalDialog();
        break;

      default:
        break;
    }

    setState(() {});
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('到达目的地'),
        content: const Text('您已成功到达目的地！'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _controller?.finishNavigation();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 开始自定义导航
  Future<void> _startCustomNavigation() async {
    final wayPoints = [
      WayPoint(
        name: "起点 - 天安门",
        latitude: 39.9042,
        longitude: 116.4074,
      ),
      WayPoint(
        name: "终点 - 故宫",
        latitude: 39.9163,
        longitude: 116.3972,
      ),
    ];

    try {
      await MapBoxNavigation.instance.startNavigation(
        wayPoints: wayPoints,
        options: _customOptions,
      );
    } catch (e) {
      _showErrorDialog('导航启动失败: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义导航示例'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // 状态信息面板
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '导航状态: ${_isNavigating ? "进行中" : "未开始"}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('当前指令: ${_currentInstruction ?? "无"}'),
                const SizedBox(height: 4),
                Text(
                    '剩余距离: ${_distanceRemaining != null ? "${(_distanceRemaining! / 1000).toStringAsFixed(1)} 公里" : "---"}'),
                const SizedBox(height: 4),
                Text(
                    '剩余时间: ${_durationRemaining != null ? "${(_durationRemaining! / 60).toStringAsFixed(0)} 分钟" : "---"}'),
              ],
            ),
          ),

          // 控制按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isNavigating ? null : _startCustomNavigation,
                  child: const Text('开始导航'),
                ),
                ElevatedButton(
                  onPressed: _isNavigating
                      ? () => MapBoxNavigation.instance.finishNavigation()
                      : null,
                  child: const Text('结束导航'),
                ),
              ],
            ),
          ),

          // 嵌入式地图视图
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MapBoxNavigationView(
                  options: _customOptions,
                  onRouteEvent: _onRouteEvent,
                  onCreated: (MapBoxNavigationViewController controller) {
                    _controller = controller;
                    controller.initialize();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
