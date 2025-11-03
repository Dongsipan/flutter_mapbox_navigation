import 'package:flutter/material.dart';

import 'app.dart';
import 'custom_navigation_example.dart';
import 'advanced_features_example.dart';
import 'history_test_page.dart';
import 'history_replay_example.dart';
import 'map_search_example.dart';
import 'route_selection_example.dart';

void main() => runApp(const NavigationDemoApp());

class NavigationDemoApp extends StatelessWidget {
  const NavigationDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapbox Navigation Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const NavigationHomePage(),
    );
  }
}

class NavigationHomePage extends StatelessWidget {
  const NavigationHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox Navigation 示例'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '选择一个示例来体验不同的导航功能：',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildDemoCard(
              context,
              title: '原始示例',
              description: '官方提供的基础导航功能示例',
              icon: Icons.navigation,
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SampleNavigationApp()),
              ),
            ),
            const SizedBox(height: 16),
            _buildDemoCard(
              context,
              title: '自定义导航',
              description: '展示如何自定义导航选项和界面',
              icon: Icons.settings,
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CustomNavigationExample()),
              ),
            ),
            const SizedBox(height: 16),
            _buildDemoCard(
              context,
              title: '高级功能',
              description: '路线优化、历史记录等高级功能',
              icon: Icons.auto_awesome,
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AdvancedFeaturesExample()),
              ),
            ),
            const SizedBox(height: 16),
            _buildDemoCard(
              context,
              title: '历史记录测试',
              description: '专门测试历史记录保存和查看功能',
              icon: Icons.history,
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const HistoryTestPage()),
              ),
            ),
            const SizedBox(height: 16),
            _buildDemoCard(
              context,
              title: '历史记录回放',
              description: '回放已保存的导航历史记录',
              icon: Icons.play_circle_filled,
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const HistoryReplayExample()),
              ),
            ),
            const SizedBox(height: 16),
            _buildDemoCard(
              context,
              title: '地图搜索界面',
              description: '带有搜索框的完整地图界面，支持实时自动补全',
              icon: Icons.map,
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MapSearchExamplePage()),
              ),
            ),
            const SizedBox(height: 16),
            _buildDemoCard(
              context,
              title: '路线选择功能',
              description: '展示如何在导航前让用户选择路线',
              icon: Icons.route,
              color: Colors.deepOrange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RouteSelectionExample()),
              ),
            ),
            const SizedBox(height: 24), // 底部间距
          ],
        ),
      ),
    );
  }

  Widget _buildDemoCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
