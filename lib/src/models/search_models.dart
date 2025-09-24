/// Mapbox搜索结果模型
class MapboxSearchResult {
  /// 搜索结果的唯一标识符
  final String id;
  
  /// 地点名称
  final String name;
  
  /// 地址信息
  final String? address;
  
  /// 坐标信息
  final MapboxCoordinate coordinate;
  
  /// 地点类别
  final List<String>? categories;
  
  /// 距离（米）
  final double? distance;

  const MapboxSearchResult({
    required this.id,
    required this.name,
    this.address,
    required this.coordinate,
    this.categories,
    this.distance,
  });

  factory MapboxSearchResult.fromMap(Map<String, dynamic> map) {
    return MapboxSearchResult(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String?,
      coordinate: MapboxCoordinate.fromMap(map['coordinate'] as Map<String, dynamic>),
      categories: (map['categories'] as List<dynamic>?)?.cast<String>(),
      distance: map['distance'] as double?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'coordinate': coordinate.toMap(),
      'categories': categories,
      'distance': distance,
    };
  }

  @override
  String toString() {
    return 'MapboxSearchResult(id: $id, name: $name, address: $address, coordinate: $coordinate, categories: $categories, distance: $distance)';
  }
}

/// 坐标模型
class MapboxCoordinate {
  /// 纬度
  final double latitude;
  
  /// 经度
  final double longitude;

  const MapboxCoordinate({
    required this.latitude,
    required this.longitude,
  });

  factory MapboxCoordinate.fromMap(Map<String, dynamic> map) {
    return MapboxCoordinate(
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  String toString() {
    return 'MapboxCoordinate(latitude: $latitude, longitude: $longitude)';
  }
}

/// 边界框模型
class MapboxBoundingBox {
  /// 西南角坐标
  final MapboxCoordinate southwest;
  
  /// 东北角坐标
  final MapboxCoordinate northeast;

  const MapboxBoundingBox({
    required this.southwest,
    required this.northeast,
  });

  factory MapboxBoundingBox.fromMap(Map<String, dynamic> map) {
    return MapboxBoundingBox(
      southwest: MapboxCoordinate.fromMap(map['southwest'] as Map<String, dynamic>),
      northeast: MapboxCoordinate.fromMap(map['northeast'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'southwest': southwest.toMap(),
      'northeast': northeast.toMap(),
    };
  }

  @override
  String toString() {
    return 'MapboxBoundingBox(southwest: $southwest, northeast: $northeast)';
  }
}

/// 搜索选项
class MapboxSearchOptions {
  /// 搜索查询字符串
  final String query;
  
  /// 搜索中心点（用于距离排序）
  final MapboxCoordinate? proximity;
  
  /// 搜索边界框
  final MapboxBoundingBox? boundingBox;
  
  /// 最大结果数量
  final int limit;
  
  /// 搜索类别
  final List<String>? categories;

  const MapboxSearchOptions({
    required this.query,
    this.proximity,
    this.boundingBox,
    this.limit = 10,
    this.categories,
  });

  Map<String, dynamic> toMap() {
    return {
      'query': query,
      'proximity': proximity?.toMap(),
      'boundingBox': boundingBox?.toMap(),
      'limit': limit,
      'categories': categories,
    };
  }

  @override
  String toString() {
    return 'MapboxSearchOptions(query: $query, proximity: $proximity, boundingBox: $boundingBox, limit: $limit, categories: $categories)';
  }
}

/// 附近搜索选项
class MapboxNearbySearchOptions {
  /// 搜索中心坐标
  final MapboxCoordinate coordinate;
  
  /// 搜索半径（米）
  final double radius;
  
  /// 搜索类别
  final List<String>? categories;
  
  /// 最大结果数量
  final int limit;

  const MapboxNearbySearchOptions({
    required this.coordinate,
    this.radius = 1000.0,
    this.categories,
    this.limit = 10,
  });

  Map<String, dynamic> toMap() {
    return {
      'coordinate': coordinate.toMap(),
      'radius': radius,
      'categories': categories,
      'limit': limit,
    };
  }

  @override
  String toString() {
    return 'MapboxNearbySearchOptions(coordinate: $coordinate, radius: $radius, categories: $categories, limit: $limit)';
  }
}

/// 搜索建议模型
class MapboxSearchSuggestion {
  /// 建议的唯一标识符
  final String id;
  
  /// 建议的名称
  final String name;
  
  /// 建议的地址
  final String? address;
  
  /// 坐标信息
  final MapboxCoordinate coordinate;

  const MapboxSearchSuggestion({
    required this.id,
    required this.name,
    this.address,
    required this.coordinate,
  });

  factory MapboxSearchSuggestion.fromMap(Map<String, dynamic> map) {
    return MapboxSearchSuggestion(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String?,
      coordinate: MapboxCoordinate.fromMap(map['coordinate'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'coordinate': coordinate.toMap(),
    };
  }

  @override
  String toString() {
    return 'MapboxSearchSuggestion(id: $id, name: $name, address: $address, coordinate: $coordinate)';
  }
}
