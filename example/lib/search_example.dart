import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

/// Mapbox搜索功能示例页面
class SearchExamplePage extends StatefulWidget {
  const SearchExamplePage({Key? key}) : super(key: key);

  @override
  State<SearchExamplePage> createState() => _SearchExamplePageState();
}

class _SearchExamplePageState extends State<SearchExamplePage> {
  final TextEditingController _searchController = TextEditingController();
  List<MapboxSearchResult> _searchResults = [];
  List<MapboxSearchSuggestion> _suggestions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 搜索地点
  Future<void> _searchPlaces() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchResults.clear();
    });

    try {
      final options = MapboxSearchOptions(
        query: _searchController.text.trim(),
        limit: 10,
        // 可以添加搜索中心点
        // proximity: const MapboxCoordinate(latitude: 39.9042, longitude: 116.4074), // 北京
      );

      final results = await MapboxSearch.searchPlaces(options);
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 获取搜索建议
  Future<void> _getSearchSuggestions() async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _suggestions.clear();
      });
      return;
    }

    try {
      final suggestions = await MapboxSearch.getSearchSuggestions(
        query: _searchController.text.trim(),
        limit: 5,
      );
      
      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      print('获取搜索建议失败: $e');
    }
  }

  /// 搜索附近的餐厅
  Future<void> _searchNearbyRestaurants() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchResults.clear();
    });

    try {
      // 使用北京天安门的坐标作为示例
      const coordinate = MapboxCoordinate(latitude: 39.9042, longitude: 116.4074);
      
      final results = await MapboxSearch.searchPointsOfInterest(
        coordinate: coordinate,
        radius: 2000, // 2公里半径
        categories: [MapboxSearchCategories.restaurant],
        limit: 10,
      );
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 反向地理编码示例
  Future<void> _reverseGeocode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchResults.clear();
    });

    try {
      // 使用北京天安门的坐标作为示例
      const coordinate = MapboxCoordinate(latitude: 39.9042, longitude: 116.4074);
      
      final results = await MapboxSearch.reverseGeocode(coordinate);
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox搜索示例'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 搜索输入框
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '输入搜索关键词...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _suggestions.clear();
                      _searchResults.clear();
                    });
                  },
                ),
              ),
              onChanged: (value) {
                // 实时获取搜索建议
                _getSearchSuggestions();
              },
              onSubmitted: (value) {
                _searchPlaces();
              },
            ),
            
            const SizedBox(height: 16),
            
            // 功能按钮
            Wrap(
              spacing: 8.0,
              children: [
                ElevatedButton(
                  onPressed: _searchPlaces,
                  child: const Text('搜索地点'),
                ),
                ElevatedButton(
                  onPressed: _searchNearbyRestaurants,
                  child: const Text('附近餐厅'),
                ),
                ElevatedButton(
                  onPressed: _reverseGeocode,
                  child: const Text('反向地理编码'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 搜索建议
            if (_suggestions.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '搜索建议:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 100,
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(suggestion.name),
                      subtitle: Text(suggestion.address ?? ''),
                      onTap: () {
                        _searchController.text = suggestion.name;
                        setState(() {
                          _suggestions.clear();
                        });
                        _searchPlaces();
                      },
                    );
                  },
                ),
              ),
              const Divider(),
            ],
            
            // 加载指示器
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
            
            // 错误消息
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            
            // 搜索结果
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '搜索结果:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return Card(
                      child: ListTile(
                        title: Text(result.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (result.address != null)
                              Text(result.address!),
                            Text(
                              '坐标: ${result.coordinate.latitude.toStringAsFixed(4)}, ${result.coordinate.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (result.distance != null)
                              Text(
                                '距离: ${(result.distance! / 1000).toStringAsFixed(2)} km',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            if (result.categories != null && result.categories!.isNotEmpty)
                              Text(
                                '类别: ${result.categories!.join(', ')}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.location_on),
                        onTap: () {
                          // 这里可以添加导航到该地点的功能
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('选择了: ${result.name}'),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
