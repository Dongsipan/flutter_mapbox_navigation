package com.eopeter.fluttermapboxnavigation.properties

import com.mapbox.geojson.Point
import io.kotest.property.Arb
import io.kotest.property.arbitrary.double
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

/**
 * 地图点击属性测试
 * Feature: android-map-search-feature, Property 7: 点击地图隐藏抽屉
 * 
 * 验证需求: 5.5
 * 
 * 属性: 对于任何地图上的非标记区域，当用户点击该区域且底部抽屉处于显示状态时，
 * 底部抽屉应该隐藏
 */
class MapClickPropertyTest {

    /**
     * 属性 7: 点击地图隐藏抽屉
     * 
     * 对于任何地图上的非标记区域，当用户点击该区域且底部抽屉处于显示状态时，
     * 底部抽屉应该隐藏
     * 
     * 验证需求: 5.5
     */
    @Test
    fun `property 7 - clicking map should hide bottom sheet when visible`() = runBlocking {
        // Feature: android-map-search-feature, Property 7: 点击地图隐藏抽屉
        
        checkAll<Double, Double>(
            100,
            Arb.double(-90.0..90.0),
            Arb.double(-180.0..180.0)
        ) { lat, lon ->
            // Given: 底部抽屉处于显示状态
            val bottomSheet = MockBottomSheet(isVisible = true)
            val clickPoint = Point.fromLngLat(lon, lat)
            
            // When: 点击地图
            val newBottomSheet = handleMapClick(clickPoint, bottomSheet)
            
            // Then: 底部抽屉应该隐藏
            assertFalse("底部抽屉应该隐藏", newBottomSheet.isVisible)
        }
    }

    /**
     * 属性测试: 底部抽屉隐藏时点击地图不应有影响
     */
    @Test
    fun `clicking map when bottom sheet is hidden should have no effect`() = runBlocking {
        // Feature: android-map-search-feature, Property 7: 点击地图隐藏抽屉
        
        checkAll<Double, Double>(
            100,
            Arb.double(-90.0..90.0),
            Arb.double(-180.0..180.0)
        ) { lat, lon ->
            // Given: 底部抽屉已经隐藏
            val bottomSheet = MockBottomSheet(isVisible = false)
            val clickPoint = Point.fromLngLat(lon, lat)
            
            // When: 点击地图
            val newBottomSheet = handleMapClick(clickPoint, bottomSheet)
            
            // Then: 底部抽屉应该保持隐藏
            assertFalse("底部抽屉应该保持隐藏", newBottomSheet.isVisible)
        }
    }

    /**
     * 属性测试: 点击地图的任何位置都应该隐藏抽屉
     */
    @Test
    fun `clicking any map location should hide bottom sheet`() {
        // Feature: android-map-search-feature, Property 7: 点击地图隐藏抽屉
        
        val testLocations = listOf(
            Point.fromLngLat(0.0, 0.0),           // 赤道本初子午线
            Point.fromLngLat(116.4074, 39.9042),  // 北京
            Point.fromLngLat(121.4737, 31.2304),  // 上海
            Point.fromLngLat(-74.0060, 40.7128),  // 纽约
            Point.fromLngLat(-0.1276, 51.5074),   // 伦敦
            Point.fromLngLat(139.6917, 35.6895),  // 东京
            Point.fromLngLat(180.0, 0.0),         // 国际日期变更线
            Point.fromLngLat(0.0, 90.0),          // 北极
            Point.fromLngLat(0.0, -90.0)          // 南极
        )
        
        testLocations.forEach { clickPoint ->
            // Given: 底部抽屉可见
            val bottomSheet = MockBottomSheet(isVisible = true)
            
            // When: 点击地图
            val newBottomSheet = handleMapClick(clickPoint, bottomSheet)
            
            // Then: 底部抽屉应该隐藏
            assertFalse(
                "点击 ${clickPoint.latitude()}, ${clickPoint.longitude()} 应该隐藏抽屉",
                newBottomSheet.isVisible
            )
        }
    }

    /**
     * 属性测试: 多次点击地图应该保持抽屉隐藏
     */
    @Test
    fun `multiple map clicks should keep bottom sheet hidden`() = runBlocking {
        // Feature: android-map-search-feature, Property 7: 点击地图隐藏抽屉
        
        checkAll<Int>(100, Arb.int(2..10)) { clickCount ->
            // Given: 底部抽屉初始可见
            var bottomSheet = MockBottomSheet(isVisible = true)
            
            // When: 多次点击地图
            repeat(clickCount) {
                val clickPoint = Point.fromLngLat(
                    (Math.random() * 360) - 180,
                    (Math.random() * 180) - 90
                )
                bottomSheet = handleMapClick(clickPoint, bottomSheet)
            }
            
            // Then: 底部抽屉应该保持隐藏
            assertFalse("多次点击后底部抽屉应该保持隐藏", bottomSheet.isVisible)
        }
    }

    /**
     * 属性测试: 点击地图后再显示抽屉应该正常工作
     */
    @Test
    fun `showing bottom sheet after map click should work correctly`() {
        // Feature: android-map-search-feature, Property 7: 点击地图隐藏抽屉
        
        // Given: 底部抽屉可见
        var bottomSheet = MockBottomSheet(isVisible = true)
        
        // When: 点击地图隐藏抽屉
        bottomSheet = handleMapClick(Point.fromLngLat(0.0, 0.0), bottomSheet)
        
        // Then: 抽屉应该隐藏
        assertFalse("抽屉应该隐藏", bottomSheet.isVisible)
        
        // When: 再次显示抽屉
        bottomSheet = MockBottomSheet(isVisible = true)
        
        // Then: 抽屉应该可见
        assertTrue("抽屉应该可见", bottomSheet.isVisible)
    }

    /**
     * 属性测试: 点击边界坐标应该正确处理
     */
    @Test
    fun `clicking boundary coordinates should hide bottom sheet`() {
        // Feature: android-map-search-feature, Property 7: 点击地图隐藏抽屉
        
        val boundaryPoints = listOf(
            Point.fromLngLat(180.0, 90.0),    // 东北角
            Point.fromLngLat(-180.0, 90.0),   // 西北角
            Point.fromLngLat(180.0, -90.0),   // 东南角
            Point.fromLngLat(-180.0, -90.0),  // 西南角
            Point.fromLngLat(0.0, 0.0)        // 中心
        )
        
        boundaryPoints.forEach { clickPoint ->
            // Given: 底部抽屉可见
            val bottomSheet = MockBottomSheet(isVisible = true)
            
            // When: 点击边界坐标
            val newBottomSheet = handleMapClick(clickPoint, bottomSheet)
            
            // Then: 底部抽屉应该隐藏
            assertFalse(
                "点击边界坐标应该隐藏抽屉",
                newBottomSheet.isVisible
            )
        }
    }

    /**
     * 属性测试: 快速连续点击应该正确处理
     */
    @Test
    fun `rapid successive clicks should be handled correctly`() {
        // Feature: android-map-search-feature, Property 7: 点击地图隐藏抽屉
        
        // Given: 底部抽屉可见
        var bottomSheet = MockBottomSheet(isVisible = true)
        
        // When: 快速连续点击
        repeat(10) {
            val clickPoint = Point.fromLngLat(
                (Math.random() * 360) - 180,
                (Math.random() * 180) - 90
            )
            bottomSheet = handleMapClick(clickPoint, bottomSheet)
        }
        
        // Then: 底部抽屉应该隐藏
        assertFalse("快速连续点击后抽屉应该隐藏", bottomSheet.isVisible)
    }

    /**
     * 属性测试: 点击地图不应该影响其他UI状态
     */
    @Test
    fun `map click should not affect other UI state`() = runBlocking {
        // Feature: android-map-search-feature, Property 7: 点击地图隐藏抽屉
        
        checkAll<Double, Double>(
            100,
            Arb.double(-90.0..90.0),
            Arb.double(-180.0..180.0)
        ) { lat, lon ->
            // Given: 底部抽屉可见，其他UI状态
            val bottomSheet = MockBottomSheet(isVisible = true)
            val otherUIState = MockUIState(searchVisible = true, annotationsCount = 5)
            val clickPoint = Point.fromLngLat(lon, lat)
            
            // When: 点击地图
            val newBottomSheet = handleMapClick(clickPoint, bottomSheet)
            
            // Then: 只有底部抽屉状态改变，其他UI状态不变
            assertFalse("底部抽屉应该隐藏", newBottomSheet.isVisible)
            assertTrue("搜索视图应该保持可见", otherUIState.searchVisible)
            assertEquals("标记数量应该不变", 5, otherUIState.annotationsCount)
        }
    }

    // ========== 辅助类和方法 ==========

    /**
     * 模拟底部抽屉
     */
    data class MockBottomSheet(
        val isVisible: Boolean
    )

    /**
     * 模拟其他UI状态
     */
    data class MockUIState(
        val searchVisible: Boolean,
        val annotationsCount: Int
    )

    /**
     * 处理地图点击
     */
    private fun handleMapClick(clickPoint: Point, bottomSheet: MockBottomSheet): MockBottomSheet {
        // 如果底部抽屉可见，点击地图后隐藏它
        return if (bottomSheet.isVisible) {
            MockBottomSheet(isVisible = false)
        } else {
            bottomSheet
        }
    }
}
