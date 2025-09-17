import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

class HistoryTestPage extends StatefulWidget {
  const HistoryTestPage({super.key});

  @override
  State<HistoryTestPage> createState() => _HistoryTestPageState();
}

class _HistoryTestPageState extends State<HistoryTestPage> {
  final List<WayPoint> _currentWayPoints = [];
  final List<List<WayPoint>> _routeHistory = [];
  String? _statusMessage;

  // 添加测试路径点
  void _addTestWayPoints() {
    setState(() {
      _currentWayPoints.clear();
      _currentWayPoints.addAll([
        WayPoint(name: "起点", latitude: 39.9021, longitude: 116.4272),
        WayPoint(name: "中点", latitude: 39.9042, longitude: 116.4074),
        WayPoint(name: "终点", latitude: 39.9163, longitude: 116.3972),
      ]);
      _statusMessage = "已添加3个测试路径点";
    });
  }

  // 保存当前路线
  void _saveCurrentRoute() {
    if (_currentWayPoints.isEmpty) {
      setState(() {
        _statusMessage = "没有路线可保存";
      });
      return;
    }

    _routeHistory.add(List<WayPoint>.from(_currentWayPoints));
    setState(() {
      _statusMessage = "路线已保存！历史记录数量: ${_routeHistory.length}";
    });
    
    // 显示成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('路线已保存！当前共有${_routeHistory.length}条历史记录'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: '查看',
          textColor: Colors.white,
          onPressed: _showRouteHistory,
        ),
      ),
    );
  }

  // 显示路线历史
  void _showRouteHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('路线历史记录 (${_routeHistory.length}条)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _routeHistory.isEmpty
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无历史记录'),
                  SizedBox(height: 8),
                  Text(
                    '先添加路径点，然后点击"保存路线"',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView.builder(
                itemCount: _routeHistory.length,
                itemBuilder: (context, index) {
                  final route = _routeHistory[index];
                  
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text('${index + 1}'),
                      ),
                      title: Text('路线 ${index + 1}'),
                      subtitle: Text('${route.length}个路径点'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore, color: Colors.green),
                            tooltip: '恢复此路线',
                            onPressed: () {
                              setState(() {
                                _currentWayPoints.clear();
                                _currentWayPoints.addAll(route);
                                _statusMessage = "已恢复路线 ${index + 1}";
                              });
                              Navigator.of(context).pop();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: '删除此路线',
                            onPressed: () {
                              setState(() {
                                _routeHistory.removeAt(index);
                                _statusMessage = "已删除路线 ${index + 1}";
                              });
                              Navigator.of(context).pop();
                              _showRouteHistory(); // 重新显示对话框
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _routeHistory.clear();
                _statusMessage = "已清除所有历史记录";
              });
              Navigator.of(context).pop();
            },
            child: const Text('清除全部'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录测试'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 状态显示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前路径点: ${_currentWayPoints.length}个',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text('历史记录: ${_routeHistory.length}条'),
                  if (_statusMessage != null)
                    Text('状态: $_statusMessage'),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 操作按钮
            ElevatedButton(
              onPressed: _addTestWayPoints,
              child: const Text('添加测试路径点'),
            ),
            
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: _currentWayPoints.isNotEmpty ? _saveCurrentRoute : null,
              child: const Text('保存当前路线'),
            ),
            
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: _showRouteHistory,
              child: const Text('查看历史记录'),
            ),
            
            const SizedBox(height: 20),
            
            // 当前路径点列表
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '当前路径点',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _currentWayPoints.isEmpty
                        ? const Center(
                            child: Text('暂无路径点\n点击"添加测试路径点"'),
                          )
                        : ListView.builder(
                            itemCount: _currentWayPoints.length,
                            itemBuilder: (context, index) {
                              final wayPoint = _currentWayPoints[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green,
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(wayPoint.name ?? '路径点 ${index + 1}'),
                                subtitle: Text(
                                  '${wayPoint.latitude?.toStringAsFixed(4)}, ${wayPoint.longitude?.toStringAsFixed(4)}'
                                ),
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
