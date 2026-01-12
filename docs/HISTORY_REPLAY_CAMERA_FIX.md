# History Replay Camera Fix - Trajectory Not Visible

## Problem
After successfully loading 320 replay events and drawing the trajectory, the map showed no visible route, start point, or end point. The logs showed:
```
D/NavigationReplayActivity: 加载回放事件完成，事件数量: 320
D/NavigationReplayActivity: 预解析完成: 总点数=X, 总距离=Xm
D/NavigationReplayActivity: ✅ 完整路线绘制完成: 轨迹点X, 平均速度Xkm/h
```

But the map remained at the default position without showing the trajectory.

## Root Cause
The `drawCompleteRoute()` function successfully:
1. Drew the trajectory line on the map
2. Set the start and end point markers
3. Applied speed gradient coloring

However, it **did not adjust the camera** to show the drawn trajectory. The camera remained at its initial position (likely showing a different location), so the user couldn't see the trajectory even though it was correctly drawn on the map.

## Solution
Added a `adjustCameraToShowRoute()` function that:
1. Calculates the bounding box of all trajectory points
2. Computes the center point of the trajectory
3. Determines an appropriate zoom level based on the trajectory extent
4. Moves the camera to show the entire route with padding

### Implementation

```kotlin
/**
 * 一次性绘制完整路线
 */
private fun drawCompleteRoute() {
    binding.mapView.mapboxMap.style?.let { style ->
        try {
            // 绘制完整轨迹线
            val line = LineString.fromLngLats(traveledPoints)
            style.getSourceAs<GeoJsonSource>("replay-travel-line-source")?.feature(Feature.fromGeometry(line))

            // 设置起点和终点
            if (traveledPoints.isNotEmpty()) {
                val startPoint = traveledPoints.first()
                val endPoint = traveledPoints.last()

                style.getSourceAs<GeoJsonSource>("replay-start-source")?.feature(Feature.fromGeometry(startPoint))
                style.getSourceAs<GeoJsonSource>("replay-end-source")?.feature(Feature.fromGeometry(endPoint))

                endPointCoord = endPoint
                
                // 调整相机以显示整个轨迹
                adjustCameraToShowRoute()
            }

            // 应用速度渐变
            val gradientExpr = buildSpeedGradientExpression()
            val layer = style.getLayerAs<LineLayer>("replay-travel-line-layer")
            layer?.lineGradient(gradientExpr)

            val avgSpeed = if (traveledSpeedsKmh.isNotEmpty()) traveledSpeedsKmh.average() else 0.0
            Log.d(TAG, "✅ 完整路线绘制完成: 轨迹点${traveledPoints.size}, 平均速度${String.format("%.1f", avgSpeed)}km/h")

        } catch (e: Exception) {
            Log.e(TAG, "绘制完整路线失败: ${e.message}", e)
        }
    } ?: Log.w(TAG, "样式未加载，无法绘制路线")
}

/**
 * 调整相机以显示整个路线
 */
private fun adjustCameraToShowRoute() {
    if (traveledPoints.isEmpty()) {
        Log.w(TAG, "没有轨迹点，无法调整相机")
        return
    }
    
    try {
        // 计算所有点的边界
        var minLat = Double.MAX_VALUE
        var maxLat = Double.MIN_VALUE
        var minLng = Double.MAX_VALUE
        var maxLng = Double.MIN_VALUE
        
        for (point in traveledPoints) {
            minLat = min(minLat, point.latitude())
            maxLat = max(maxLat, point.latitude())
            minLng = min(minLng, point.longitude())
            maxLng = max(maxLng, point.longitude())
        }
        
        // 计算中心点
        val centerLat = (minLat + maxLat) / 2
        val centerLng = (minLng + maxLng) / 2
        val centerPoint = Point.fromLngLat(centerLng, centerLat)
        
        // 计算合适的缩放级别
        val latDiff = maxLat - minLat
        val lngDiff = maxLng - minLng
        val maxDiff = max(latDiff, lngDiff)
        
        // 根据范围计算缩放级别（简单估算）
        val zoom = when {
            maxDiff > 0.1 -> 11.0
            maxDiff > 0.05 -> 12.0
            maxDiff > 0.02 -> 13.0
            maxDiff > 0.01 -> 14.0
            maxDiff > 0.005 -> 15.0
            else -> 16.0
        }
        
        // 设置相机
        binding.mapView.mapboxMap.setCamera(
            CameraOptions.Builder()
                .center(centerPoint)
                .zoom(zoom)
                .padding(EdgeInsets(100.0, 100.0, 100.0, 100.0))
                .build()
        )
        
        Log.d(TAG, "相机已调整到轨迹中心: lat=$centerLat, lng=$centerLng, zoom=$zoom")
    } catch (e: Exception) {
        Log.e(TAG, "调整相机失败: ${e.message}", e)
    }
}
```

## How It Works Now

1. History file is loaded successfully (320 events)
2. Events are parsed to extract location points
3. Trajectory line is drawn on the map
4. Start point (green circle) and end point (red circle) are added
5. Speed gradient is applied to the trajectory
6. **Camera automatically adjusts to show the entire route**
7. User can see the complete trajectory with start/end markers

## Camera Zoom Logic

The zoom level is calculated based on the trajectory extent:
- Very large area (>0.1°) → Zoom 11
- Large area (>0.05°) → Zoom 12
- Medium area (>0.02°) → Zoom 13
- Small area (>0.01°) → Zoom 14
- Very small area (>0.005°) → Zoom 15
- Tiny area → Zoom 16

Padding of 100px is added on all sides to ensure the trajectory doesn't touch the screen edges.

## Files Modified
- `android/src/main/kotlin/com/eopeter/fluttermapboxnavigation/NavigationReplayActivity.kt`
  - Modified `drawCompleteRoute()` to call `adjustCameraToShowRoute()`
  - Added `adjustCameraToShowRoute()` function to calculate and set camera position

## Testing
After this fix:
1. Navigate a route (or simulate one)
2. Complete or cancel navigation (history is saved)
3. Go to history list
4. Click the replay button
5. `NavigationReplayActivity` launches
6. The trajectory is drawn AND visible on the map
7. Start point (green) and end point (red) are visible
8. Camera is positioned to show the entire route

## Related Components
- `drawCompleteRoute()` - Draws the trajectory and markers
- `adjustCameraToShowRoute()` - Calculates and sets camera position
- `preDrawCompleteRoute()` - Extracts location data from replay events
- Mapbox `CameraOptions` - Controls camera position and zoom
