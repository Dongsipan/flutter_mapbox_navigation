import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

/// 地图搜索示例页面 - 展示带有搜索框的地图界面
class MapSearchExamplePage extends StatefulWidget {
  const MapSearchExamplePage({Key? key}) : super(key: key);

  @override
  State<MapSearchExamplePage> createState() => _MapSearchExamplePageState();
}

class _MapSearchExamplePageState extends State<MapSearchExamplePage> {
  
  /// 显示地图搜索视图
  Future<void> _showMapSearchView() async {
    try {
      // 调用原生的地图搜索界面，获取wayPoints数组数据
      final wayPointsData = await MapboxSearch.showSearchView();

      if (wayPointsData != null && wayPointsData.isNotEmpty && mounted) {
        // 添加调试信息
        print('🔍 收到的wayPoints数据: $wayPointsData');

        // 构建显示信息
        String displayInfo = '✅ 获取到 ${wayPointsData.length} 个路径点:\n\n';

        for (int i = 0; i < wayPointsData.length; i++) {
          final wayPoint = wayPointsData[i];
          final pointType = i == 0 ? '🚩 起点' : '🎯 终点';
          displayInfo += '$pointType: ${wayPoint['name']}\n';
          displayInfo += '📍 坐标: ${wayPoint['latitude']}, ${wayPoint['longitude']}\n';
          if (wayPoint['address'] != null && wayPoint['address'].toString().isNotEmpty) {
            displayInfo += '🏠 地址: ${wayPoint['address']}\n';
          }
          if (i < wayPointsData.length - 1) displayInfo += '\n';
        }

        // 显示选中的路径点信息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayInfo),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 8),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // 这里可以使用wayPoints数据进行导航
        // 例如：
        // List<WayPoint> wayPoints = wayPointsData.map((data) => WayPoint(
        //   name: data['name'],
        //   latitude: data['latitude'],
        //   longitude: data['longitude'],
        // )).toList();
        //
        // await MapBoxNavigation.instance.startNavigation(wayPoints: wayPoints);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打开搜索视图失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图搜索示例'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // 功能说明
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          '地图搜索功能',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '这个功能展示了集成的地图搜索界面，包含以下特性：',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureItem('🗺️ 完整的地图视图'),
                    _buildFeatureItem('🔍 顶部搜索框'),
                    _buildFeatureItem('⚡ 实时自动补全建议'),
                    _buildFeatureItem('📍 选中位置在地图上显示标记'),
                    _buildFeatureItem('🎯 自动调整地图视角到选中位置'),
                    _buildFeatureItem('🎨 使用官方Mapbox Search UI组件'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 主要操作按钮
            ElevatedButton.icon(
              onPressed: _showMapSearchView,
              icon: const Icon(Icons.map, size: 28),
              label: const Text(
                '打开地图搜索界面',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 使用说明
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          '使用说明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionItem('1. 点击上方按钮打开地图搜索界面'),
                    _buildInstructionItem('2. 在搜索框中输入地点名称'),
                    _buildInstructionItem('3. 从自动补全列表中选择地点'),
                    _buildInstructionItem('4. 地图会自动显示选中位置的标记'),
                    _buildInstructionItem('5. 地图视角会自动调整到该位置'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 底部提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '注意：使用此功能需要配置有效的Mapbox访问令牌',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}
