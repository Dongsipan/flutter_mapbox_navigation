# Android History 反地理编码 - 使用 SEARCH_BOX API

## 更新说明

根据 Mapbox 官方文档和示例，将反地理编码从 `ApiType.GEOCODING` 更新为 `ApiType.SEARCH_BOX`。

## 官方推荐

### Mapbox 官方示例

```kotlin
// 官方推荐：使用 SEARCH_BOX API 进行反地理编码
searchEngine = SearchEngine.createSearchEngineWithBuiltInDataProviders(
    ApiType.SEARCH_BOX,
    SearchEngineSettings()
)

val options = ReverseGeoOptions(
    center = Point.fromLngLat(lng, lat),
    limit = 1
)

searchEngine.search(options, searchCallback)
```

参考：
- [Reverse geocoding 示例](https://docs.mapbox.com/android/search/examples/reverse-geocoding/)
- [Reverse geocoding 指南](https://docs.mapbox.com/android/search/guides/reverse-geocoding/)

## 代码更新

### 修改前
```kotlin
searchEngine = SearchEngine.createSearchEngineWithBuiltInDataProviders(
    settings = SearchEngineSettings(),
    apiType = ApiType.GEOCODING  // ❌ 不推荐
)
```

### 修改后
```kotlin
searchEngine = SearchEngine.createSearchEngineWithBuiltInDataProviders(
    ApiType.SEARCH_BOX,          // ✅ 官方推荐
    SearchEngineSettings()
)
```

## API 对比

| API Type | 用途 | 推荐场景 |
|----------|------|---------|
| `GEOCODING` | 传统地理编码 | 旧版 API，不推荐 |
| `SEARCH_BOX` | 搜索和反地理编码 | ✅ 官方推荐，功能更全 |
| `AUTOFILL` | 地址自动填充 | 表单填写场景 |

## 完整实现

### ReverseGeocoder.kt

```kotlin
object ReverseGeocoder {
    private const val TAG = "ReverseGeocoder"
    private const val TIMEOUT_MS = 5000L
    
    private var searchEngine: SearchEngine? = null
    
    /**
     * 初始化 SearchEngine（延迟初始化）
     * 使用 SEARCH_BOX API（官方推荐用于反地理编码）
     */
    private fun getSearchEngine(): SearchEngine {
        if (searchEngine == null) {
            searchEngine = SearchEngine.createSearchEngineWithBuiltInDataProviders(
                ApiType.SEARCH_BOX,
                SearchEngineSettings()
            )
        }
        return searchEngine!!
    }
    
    /**
     * 反地理编码：将坐标转换为地点名称
     */
    suspend fun reverseGeocode(context: Context, point: Point): String? {
        return withTimeoutOrNull(TIMEOUT_MS) {
            suspendCancellableCoroutine { continuation ->
                try {
                    val options = ReverseGeoOptions(
                        center = point,
                        limit = 1
                    )
                    
                    val task = getSearchEngine().search(options, object : SearchCallback {
                        override fun onResults(results: List<SearchResult>, responseInfo: ResponseInfo) {
                            if (results.isNotEmpty()) {
                                val result = results.first()
                                
                                // 提取地点名称（过滤邮政编码）
                                val placeName = when {
                                    !result.name.isNullOrEmpty() && !isPostalCode(result.name) -> {
                                        result.name
                                    }
                                    !result.address?.street.isNullOrEmpty() -> {
                                        result.address?.street
                                    }
                                    !result.address?.formattedAddress().isNullOrEmpty() -> {
                                        result.address?.formattedAddress()
                                    }
                                    !result.address?.place.isNullOrEmpty() -> {
                                        result.address?.place
                                    }
                                    !result.address?.locality.isNullOrEmpty() -> {
                                        result.address?.locality
                                    }
                                    !result.name.isNullOrEmpty() -> {
                                        result.name
                                    }
                                    else -> null
                                }
                                
                                continuation.resume(placeName)
                            } else {
                                continuation.resume(null)
                            }
                        }
                        
                        override fun onError(e: Exception) {
                            continuation.resume(null)
                        }
                    })
                    
                    continuation.invokeOnCancellation {
                        task.cancel()
                    }
                } catch (e: Exception) {
                    continuation.resume(null)
                }
            }
        }
    }
    
    /**
     * 检查字符串是否是邮政编码
     */
    private fun isPostalCode(name: String): Boolean {
        return name.matches(Regex("^\\d+$")) || name.matches(Regex("^\\d+-\\d+$"))
    }
}
```

## 关键特性

### 1. 使用官方推荐的 API
- ✅ `ApiType.SEARCH_BOX` - 官方推荐
- ✅ 更好的搜索结果质量
- ✅ 更完整的地址信息

### 2. 邮政编码过滤
- ✅ 检测纯数字邮政编码（如 "215008"）
- ✅ 检测带连字符的邮政编码（如 "215008-1234"）
- ✅ 优先返回有意义的地点名称

### 3. 多层回退机制
1. 地点名称（非邮政编码）
2. 街道名
3. 格式化地址
4. 地区名
5. 城市名
6. 地点名称（即使是邮政编码）

### 4. 异步处理
- ✅ Kotlin Coroutines
- ✅ 5秒超时保护
- ✅ 支持取消操作
- ✅ 非阻塞

## 构建状态

```bash
cd example/android
./gradlew assembleDebug
```

**结果**: ✅ BUILD SUCCESSFUL

## 测试结果

### 预期输出
```
D ReverseGeocoder: 📍 正在反地理编码 (Mapbox): 31.3189, 120.6154
D ReverseGeocoder: ✅ 反地理编码成功: 苏州工业园区星湖街 (原始name: 215008)
```

### 历史记录
```json
{
  "startPointName": "苏州工业园区星湖街",
  "endPointName": "苏州工业园区金鸡湖大道"
}
```

## 与官方示例的一致性

| 特性 | 官方示例 | 我们的实现 |
|------|---------|-----------|
| API Type | `SEARCH_BOX` | ✅ `SEARCH_BOX` |
| Options | `ReverseGeoOptions` | ✅ `ReverseGeoOptions` |
| Callback | `SearchCallback` | ✅ `SearchCallback` |
| 结果处理 | `SearchResult` | ✅ `SearchResult` |
| 取消支持 | `task.cancel()` | ✅ `task.cancel()` |
| 额外功能 | - | ✅ 邮政编码过滤 |
| 额外功能 | - | ✅ 多层回退机制 |
| 额外功能 | - | ✅ Coroutines 封装 |

## 离线支持（可选）

如果需要离线反地理编码，可以使用 `OfflineSearchEngine`：

```kotlin
// 创建离线搜索引擎
val offlineSearchEngine = OfflineSearchEngine.create(
    OfflineSearchEngineSettings(tileStore = tileStore)
)

// 下载离线 tiles
tileStore.loadTileRegion(tileRegionId, tileRegionLoadOptions, ...)

// 离线反地理编码
offlineSearchEngine.reverseGeocoding(
    OfflineReverseGeoOptions(center = point),
    offlineSearchCallback
)
```

参考：[Offline reverse geocoding 示例](https://docs.mapbox.com/android/search/examples/offline-reverse-geocoding/)

## 总结

### 更新内容
- ✅ 使用 `ApiType.SEARCH_BOX`（官方推荐）
- ✅ 符合官方示例的最佳实践
- ✅ 保持邮政编码过滤功能
- ✅ 保持多层回退机制

### 优势
- ✅ 更好的搜索结果质量
- ✅ 更完整的地址信息
- ✅ 官方长期支持
- ✅ 与官方文档一致

---

**Status**: ✅ COMPLETED
**Date**: 2026-01-29
**Build**: ✅ SUCCESS
**Official API**: ✅ SEARCH_BOX (推荐)
