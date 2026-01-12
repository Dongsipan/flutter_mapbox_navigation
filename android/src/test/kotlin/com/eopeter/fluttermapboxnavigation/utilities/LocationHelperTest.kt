package com.eopeter.fluttermapboxnavigation.utilities

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.mapbox.geojson.Point
import io.mockk.*
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

/**
 * LocationHelper单元测试
 * Feature: android-map-search-feature
 * 测试位置权限检查、位置获取和反向地理编码功能
 */
class LocationHelperTest {

    private lateinit var context: Context
    private lateinit var activity: Activity
    private lateinit var locationHelper: LocationHelper

    @Before
    fun setup() {
        // Mock Android框架类
        mockkStatic(ContextCompat::class)
        
        context = mockk(relaxed = true)
        activity = mockk(relaxed = true)
        
        // 创建LocationHelper实例
        locationHelper = LocationHelper(context)
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    // ========== 权限检查测试 ==========

    @Test
    fun `hasLocationPermission returns true when FINE_LOCATION granted`() {
        // Given: 精确位置权限已授予
        every {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        } returns PackageManager.PERMISSION_GRANTED

        every {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        } returns PackageManager.PERMISSION_DENIED

        // When: 检查位置权限
        val hasPermission = locationHelper.hasLocationPermission()

        // Then: 应该返回true
        assertTrue("应该有位置权限", hasPermission)
    }

    @Test
    fun `hasLocationPermission returns true when COARSE_LOCATION granted`() {
        // Given: 粗略位置权限已授予
        every {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        } returns PackageManager.PERMISSION_DENIED

        every {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        } returns PackageManager.PERMISSION_GRANTED

        // When: 检查位置权限
        val hasPermission = locationHelper.hasLocationPermission()

        // Then: 应该返回true
        assertTrue("应该有位置权限", hasPermission)
    }

    @Test
    fun `hasLocationPermission returns true when both permissions granted`() {
        // Given: 两个位置权限都已授予
        every {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        } returns PackageManager.PERMISSION_GRANTED

        every {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        } returns PackageManager.PERMISSION_GRANTED

        // When: 检查位置权限
        val hasPermission = locationHelper.hasLocationPermission()

        // Then: 应该返回true
        assertTrue("应该有位置权限", hasPermission)
    }

    @Test
    fun `hasLocationPermission returns false when no permissions granted`() {
        // Given: 没有位置权限
        every {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        } returns PackageManager.PERMISSION_DENIED

        every {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        } returns PackageManager.PERMISSION_DENIED

        // When: 检查位置权限
        val hasPermission = locationHelper.hasLocationPermission()

        // Then: 应该返回false
        assertFalse("不应该有位置权限", hasPermission)
    }

    // ========== 权限请求测试 ==========

    @Test
    fun `requestLocationPermission calls ActivityCompat requestPermissions`() {
        // Given: Mock ActivityCompat
        mockkStatic("androidx.core.app.ActivityCompat")
        every {
            androidx.core.app.ActivityCompat.requestPermissions(
                any(),
                any(),
                any()
            )
        } just Runs

        // When: 请求位置权限
        locationHelper.requestLocationPermission(activity)

        // Then: 应该调用ActivityCompat.requestPermissions
        verify {
            androidx.core.app.ActivityCompat.requestPermissions(
                activity,
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ),
                LocationHelper.LOCATION_PERMISSION_REQUEST_CODE
            )
        }
    }

    // ========== 位置获取测试 ==========

    @Test
    fun `getCurrentLocation returns null when no permission`() = runBlocking {
        // Given: 没有位置权限
        every {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        } returns PackageManager.PERMISSION_DENIED

        every {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        } returns PackageManager.PERMISSION_DENIED

        // When: 获取当前位置
        val location = locationHelper.getCurrentLocation()

        // Then: 应该返回null
        assertNull("没有权限时应该返回null", location)
    }

    // ========== 反向地理编码测试 ==========

    @Test
    fun `reverseGeocode returns default name on error`() = runBlocking {
        // Given: 一个有效的坐标点
        val point = Point.fromLngLat(116.397428, 39.90923)

        // When: 调用反向地理编码（由于是mock环境，会失败）
        val locationName = locationHelper.reverseGeocode(point)

        // Then: 应该返回默认名称
        assertEquals("错误时应该返回默认名称", "当前位置", locationName)
    }

    @Test
    fun `reverseGeocode handles null point gracefully`() = runBlocking {
        // Given: 一个边界值坐标点
        val point = Point.fromLngLat(0.0, 0.0)

        // When: 调用反向地理编码
        val locationName = locationHelper.reverseGeocode(point)

        // Then: 应该返回默认名称（不应该崩溃）
        assertNotNull("应该返回非null值", locationName)
        assertEquals("应该返回默认名称", "当前位置", locationName)
    }

    @Test
    fun `reverseGeocode handles extreme coordinates`() = runBlocking {
        // Given: 极端坐标值
        val testCases = listOf(
            Point.fromLngLat(-180.0, -90.0),  // 最小值
            Point.fromLngLat(180.0, 90.0),    // 最大值
            Point.fromLngLat(0.0, 0.0)        // 零点
        )

        // When & Then: 所有情况都应该返回有效的名称
        testCases.forEach { point ->
            val locationName = locationHelper.reverseGeocode(point)
            assertNotNull("应该返回非null值", locationName)
            assertTrue("应该返回非空字符串", locationName.isNotEmpty())
        }
    }

    // ========== 边界值测试 ==========

    @Test
    fun `reverseGeocode handles Chinese coordinates`() = runBlocking {
        // Given: 中国境内的坐标（北京天安门）
        val point = Point.fromLngLat(116.397428, 39.90923)

        // When: 调用反向地理编码
        val locationName = locationHelper.reverseGeocode(point)

        // Then: 应该返回有效的名称
        assertNotNull("应该返回非null值", locationName)
        assertTrue("应该返回非空字符串", locationName.isNotEmpty())
    }

    @Test
    fun `reverseGeocode handles international coordinates`() = runBlocking {
        // Given: 国际坐标（纽约时代广场）
        val point = Point.fromLngLat(-73.985130, 40.758896)

        // When: 调用反向地理编码
        val locationName = locationHelper.reverseGeocode(point)

        // Then: 应该返回有效的名称
        assertNotNull("应该返回非null值", locationName)
        assertTrue("应该返回非空字符串", locationName.isNotEmpty())
    }
}
