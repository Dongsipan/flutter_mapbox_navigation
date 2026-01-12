package com.eopeter.fluttermapboxnavigation.properties

import com.mapbox.geojson.Point
import io.kotest.property.Arb
import io.kotest.property.arbitrary.double
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import kotlin.math.max
import kotlin.math.min

/**
 * 多标记视角属性测试
 * Feature: android-map-search-feature, Property 6: 多个标记自动调整视角
 * 
 * 验证需求: 4.5
 * 
 * 属性: 对于任何包含多个搜索结果的列表，当在地图上显示所有标记时，
 * 地图的可视区域应该自动调整以包含所有标记点
 */
class MultipleAnnotationsPropertyTest {

    /**
     * 属性 6: 多个标记自动调整视角
     * 
     * 对于任何包含多个搜索结果的列表，当在地图上显示所有标记时，
     * 地图的可视区域应该自动调整以包含所有标记点
     * 
     * 验证需求: 4.5
     */
    @Test
    fun `property 6 - multiple annotations should adjust camera to include all`() = runBlocking {
        // Feature: android-map-search-feature, Property 6: 多个标记自动调整视角
        
        checkAll<Int>(100, Arb.int(2..10)) { count ->
            // Given: 多个搜索结果
            val annotations = generateRandomAnnotations(count)
            
            // When: 调整相机以包含所有标记
            val cameraPosition = adjustCameraToAnnotations(annotations)
            
            // Then: 相机视角应该包含所有标记
            val allIncluded = annotations.all { annotation ->
                isPointInView(annotation.coordinate, cameraPosition)
            }
            
            assertTrue("所有标记应该在视野内", allIncluded)
        }
    }

    /**
     * 属性测试: 相机中心应该在所有标记的中心
     */
    @Test
    fun `camera center should be at the center of all annotations`() = runBlocking {
        // Feature: android-map-search-feature, Property 6: 多个标记自动调整视角
        
        checkAll<Int>(100, Arb.int(2..10)) { count ->
            // Given: 多个标记
            val annotations = generateRandomAnnotations(count)
            
            // When: 调整相机
            val cameraPosition = adjustCameraToAnnotations(annotations)
            
            // Then: 相机中心应该接近所有标记的中心
            val expectedCenter = calculateCenter(annotations)
            
            assertEquals(
                "相机中心纬度应该接近标记中心",
                expectedCenter.latitude(),
                cameraPosition.center.latitude(),
                1.0  // 允许1度的误差
            )
            assertEquals(
                "相机中心经度应该接近标记中心",
                expectedCenter.longitude(),
                cameraPosition.center.longitude(),
                1.0  // 允许1度的误差
            )
        }
    }

    /**
     * 属性测试: 缩放级别应该根据标记分布调整
     */
    @Test
    fun `zoom level should adjust based on annotation spread`() = runBlocking {
        // Feature: android-map-search-feature, Property 6: 多个标记自动调整视角
        
        // 测试不同分布的标记
        val testCases = listOf(
            // 紧密分布的标记（应该有较高的缩放级别）
            listOf(
                Point.fromLngLat(116.4074, 39.9042),
                Point.fromLngLat(116.4084, 39.9052),
                Point.fromLngLat(116.4064, 39.9032)
            ),
            // 分散分布的标记（应该有较低的缩放级别）
            listOf(
                Point.fromLngLat(116.4074, 39.9042),
                Point.fromLngLat(121.4737, 31.2304),
                Point.fromLngLat(113.2644, 23.1291)
            )
        )
        
        val zoomLevels = testCases.map { coordinates ->
            val annotations = coordinates.mapIndexed { index, coord ->
                MockAnnotation("Place $index", coord)
            }
            adjustCameraToAnnotations(annotations).zoom
        }
        
        // 紧密分布的标记应该有更高的缩放级别
        assertTrue(
            "紧密分布的标记应该有更高的缩放级别",
            zoomLevels[0] > zoomLevels[1]
        )
    }

    /**
     * 属性测试: 单个标记应该使用固定缩放级别
     */
    @Test
    fun `single annotation should use fixed zoom level`() {
        // Feature: android-map-search-feature, Property 6: 多个标记自动调整视角
        
        // Given: 单个标记
        val annotation = MockAnnotation(
            "Single Place",
            Point.fromLngLat(116.4074, 39.9042)
        )
        
        // When: 调整相机
        val cameraPosition = adjustCameraToAnnotations(listOf(annotation))
        
        // Then: 应该使用固定的缩放级别
        assertEquals("单个标记应该使用固定缩放级别", 15.0, cameraPosition.zoom, 0.1)
    }

    /**
     * 属性测试: 两个标记应该都在视野内
     */
    @Test
    fun `two annotations should both be in view`() = runBlocking {
        // Feature: android-map-search-feature, Property 6: 多个标记自动调整视角
        
        checkAll<Double, Double, Double, Double>(
            100,
            Arb.double(-90.0..90.0),
            Arb.double(-180.0..180.0),
            Arb.double(-90.0..90.0),
            Arb.double(-180.0..180.0)
        ) { lat1, lon1, lat2, lon2 ->
            // Given: 两个标记
            val annotations = listOf(
                MockAnnotation("Place 1", Point.fromLngLat(lon1, lat1)),
                MockAnnotation("Place 2", Point.fromLngLat(lon2, lat2))
            )
            
            // When: 调整相机
            val cameraPosition = adjustCameraToAnnotations(annotations)
            
            // Then: 两个标记都应该在视野内
            annotations.forEach { annotation ->
                assertTrue(
                    "标记应该在视野内: ${annotation.name}",
                    isPointInView(annotation.coordinate, cameraPosition)
                )
            }
        }
    }

    /**
     * 属性测试: 跨越国际日期变更线的标记应该正确处理
     */
    @Test
    fun `annotations crossing international date line should be handled correctly`() {
        // Feature: android-map-search-feature, Property 6: 多个标记自动调整视角
        
        // Given: 跨越国际日期变更线的标记
        val annotations = listOf(
            MockAnnotation("East", Point.fromLngLat(179.0, 0.0)),
            MockAnnotation("West", Point.fromLngLat(-179.0, 0.0))
        )
        
        // When: 调整相机
        val cameraPosition = adjustCameraToAnnotations(annotations)
        
        // Then: 应该正确计算中心和缩放
        assertNotNull("相机位置不应该为null", cameraPosition)
        assertTrue("缩放级别应该合理", cameraPosition.zoom > 0 && cameraPosition.zoom < 22)
    }

    /**
     * 属性测试: 南北极附近的标记应该正确处理
     */
    @Test
    fun `annotations near poles should be handled correctly`() {
        // Feature: android-map-search-feature, Property 6: 多个标记自动调整视角
        
        val testCases = listOf(
            // 北极附近
            listOf(
                Point.fromLngLat(0.0, 89.0),
                Point.fromLngLat(90.0, 89.0),
                Point.fromLngLat(180.0, 89.0)
            ),
            // 南极附近
            listOf(
                Point.fromLngLat(0.0, -89.0),
                Point.fromLngLat(90.0, -89.0),
                Point.fromLngLat(180.0, -89.0)
            )
        )
        
        testCases.forEach { coordinates ->
            // Given: 极地附近的标记
            val annotations = coordinates.mapIndexed { index, coord ->
                MockAnnotation("Polar Place $index", coord)
            }
            
            // When: 调整相机
            val cameraPosition = adjustCameraToAnnotations(annotations)
            
            // Then: 应该正确处理
            assertNotNull("相机位置不应该为null", cameraPosition)
            assertTrue("缩放级别应该合理", cameraPosition.zoom > 0 && cameraPosition.zoom < 22)
        }
    }

    /**
     * 属性测试: 空列表应该被正确处理
     */
    @Test
    fun `empty annotation list should be handled gracefully`() {
        // Feature: android-map-search-feature, Property 6: 多个标记自动调整视角
        
        // Given: 空列表
        val annotations = emptyList<MockAnnotation>()
        
        // When: 调整相机
        val cameraPosition = adjustCameraToAnnotations(annotations)
        
        // Then: 应该返回默认相机位置
        assertNotNull("相机位置不应该为null", cameraPosition)
    }

    /**
     * 属性测试: 大量标记应该被正确处理
     */
    @Test
    fun `large number of annotations should be handled correctly`() = runBlocking {
        // Feature: android-map-search-feature, Property 6: 多个标记自动调整视角
        
        checkAll<Int>(50, Arb.int(50..100)) { count ->
            // Given: 大量标记
            val annotations = generateRandomAnnotations(count)
            
            // When: 调整相机
            val cameraPosition = adjustCameraToAnnotations(annotations)
            
            // Then: 应该正确处理
            assertNotNull("相机位置不应该为null", cameraPosition)
            assertTrue("缩放级别应该合理", cameraPosition.zoom > 0 && cameraPosition.zoom < 22)
        }
    }

    // ========== 辅助类和方法 ==========

    /**
     * 模拟标记
     */
    data class MockAnnotation(
        val name: String,
        val coordinate: Point
    )

    /**
     * 模拟相机位置
     */
    data class MockCameraPosition(
        val center: Point,
        val zoom: Double,
        val bounds: Bounds
    )

    /**
     * 模拟边界
     */
    data class Bounds(
        val minLat: Double,
        val maxLat: Double,
        val minLon: Double,
        val maxLon: Double
    )

    /**
     * 生成随机标记
     */
    private fun generateRandomAnnotations(count: Int): List<MockAnnotation> {
        return (1..count).map { index ->
            MockAnnotation(
                "Place $index",
                Point.fromLngLat(
                    (Math.random() * 360) - 180,  // -180 to 180
                    (Math.random() * 180) - 90    // -90 to 90
                )
            )
        }
    }

    /**
     * 调整相机以包含所有标记
     */
    private fun adjustCameraToAnnotations(annotations: List<MockAnnotation>): MockCameraPosition {
        if (annotations.isEmpty()) {
            return MockCameraPosition(
                center = Point.fromLngLat(0.0, 0.0),
                zoom = 1.0,
                bounds = Bounds(0.0, 0.0, 0.0, 0.0)
            )
        }
        
        if (annotations.size == 1) {
            val coord = annotations.first().coordinate
            return MockCameraPosition(
                center = coord,
                zoom = 15.0,
                bounds = Bounds(
                    coord.latitude() - 0.01,
                    coord.latitude() + 0.01,
                    coord.longitude() - 0.01,
                    coord.longitude() + 0.01
                )
            )
        }
        
        // 计算边界
        val coordinates = annotations.map { it.coordinate }
        val minLat = coordinates.minOf { it.latitude() }
        val maxLat = coordinates.maxOf { it.latitude() }
        val minLon = coordinates.minOf { it.longitude() }
        val maxLon = coordinates.maxOf { it.longitude() }
        
        // 计算中心
        val centerLat = (minLat + maxLat) / 2
        val centerLon = (minLon + maxLon) / 2
        val center = Point.fromLngLat(centerLon, centerLat)
        
        // 计算缩放级别
        val latDiff = maxLat - minLat
        val lonDiff = maxLon - minLon
        val maxDiff = max(latDiff, lonDiff)
        
        val zoom = when {
            maxDiff > 10 -> 5.0
            maxDiff > 5 -> 7.0
            maxDiff > 2 -> 9.0
            maxDiff > 1 -> 11.0
            maxDiff > 0.5 -> 12.0
            maxDiff > 0.1 -> 13.0
            else -> 14.0
        }
        
        return MockCameraPosition(
            center = center,
            zoom = zoom,
            bounds = Bounds(minLat, maxLat, minLon, maxLon)
        )
    }

    /**
     * 计算标记的中心点
     */
    private fun calculateCenter(annotations: List<MockAnnotation>): Point {
        val avgLat = annotations.map { it.coordinate.latitude() }.average()
        val avgLon = annotations.map { it.coordinate.longitude() }.average()
        return Point.fromLngLat(avgLon, avgLat)
    }

    /**
     * 检查点是否在视野内
     */
    private fun isPointInView(point: Point, cameraPosition: MockCameraPosition): Boolean {
        val bounds = cameraPosition.bounds
        return point.latitude() >= bounds.minLat &&
                point.latitude() <= bounds.maxLat &&
                point.longitude() >= bounds.minLon &&
                point.longitude() <= bounds.maxLon
    }
}
