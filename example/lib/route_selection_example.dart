import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

/// 路线选择功能示例
///
/// 演示如何使用 autoBuildRoute 参数来启用路线选择功能
class RouteSelectionExample extends StatefulWidget {
  const RouteSelectionExample({super.key});

  @override
  State<RouteSelectionExample> createState() => _RouteSelectionExampleState();
}

class _RouteSelectionExampleState extends State<RouteSelectionExample> {
  final _navigation = MapBoxNavigation.instance;

  // 示例航点
  final List<WayPoint> wayPoints = [
    WayPoint(
      name: '起点',
      latitude: 39.9042,
      longitude: 116.4074,
    ),
    WayPoint(
      name: '终点',
      latitude: 39.9162,
      longitude: 116.3978,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('路线选择功能示例'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '路线选择功能说明',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '通过 autoBuildRoute 参数，您可以控制导航的启动方式：',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: 'autoBuildRoute = true (默认)',
              description: '直接计算路线并开始导航，无需用户选择',
              icon: Icons.navigation,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: 'autoBuildRoute = false',
              description: '先显示路线选择界面，用户选择后再开始导航',
              icon: Icons.route,
              color: Colors.green,
            ),
            const SizedBox(height: 32),
            const Text(
              '选择导航模式：',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _startNavigation(autoBuildRoute: true),
              icon: const Icon(Icons.navigation),
              label: const Text('直接开始导航'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _startNavigation(autoBuildRoute: false),
              icon: const Icon(Icons.route),
              label: const Text('先选择路线再导航'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNavigation({required bool autoBuildRoute}) async {
    // 配置导航选项
    final options = MapBoxOptions(
      mode: MapBoxNavigationMode.drivingWithTraffic,
      simulateRoute: true, // 使用模拟路线进行测试
      language: 'zh-Hans',
      alternatives: true, // 启用备选路线
      autoBuildRoute: autoBuildRoute, // 关键参数！
      voiceInstructionsEnabled: true,
      bannerInstructionsEnabled: true,
    );

    try {
      await _navigation.startNavigation(
        wayPoints: wayPoints,
        options: options,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            autoBuildRoute ? '导航已启动' : '路线选择界面已显示',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('启动导航失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
