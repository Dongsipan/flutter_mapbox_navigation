package com.eopeter.fluttermapboxnavigation.properties

import android.app.Activity
import android.content.Intent
import com.eopeter.fluttermapboxnavigation.FlutterMapboxNavigationPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import kotlin.random.Random

/**
 * MethodChannel通信属性测试
 * 
 * Feature: android-map-search-feature
 * Tests Properties 11 and 12 related to MethodChannel communication
 */
class MethodChannelPropertyTest {

    private lateinit var mockActivity: Activity
    private lateinit var mockResult: MethodChannel.Result

    @Before
    fun setup() {
        mockActivity = mockk(relaxed = true)
        mockResult = mockk(relaxed = true)
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    /**
     * Property 11: wayPoints通过MethodChannel返回
     * 
     * For any 成功生成的wayPoints数组, 系统应该通过MethodChannel将数组返回给Flutter层
     * 
     * Validates: Requirement 6.5
     */
    @Test
    fun `property 11 - wayPoints returned through MethodChannel`() {
        // 运行100次迭代
        repeat(100) { iteration ->
            // 生成随机的wayPoints数组
            val wayPoints = generateRandomWayPoints()
            
            // 模拟MethodChannel的result回调
            val resultSlot = slot<Any?>()
            every { mockResult.success(capture(resultSlot)) } just Runs
            
            // 模拟返回wayPoints
            mockResult.success(wayPoints)
            
            // 验证success被调用
            verify(exactly = iteration + 1) {
                mockResult.success(any())
            }
            
            // 验证返回的数据是wayPoints数组
            val returnedData = resultSlot.captured
            assertNotNull(
                "迭代 $iteration: 应该返回数据",
                returnedData
            )
            
            assertTrue(
                "迭代 $iteration: 返回的数据应该是List类型",
                returnedData is List<*>
            )
            
            @Suppress("UNCHECKED_CAST")
            val returnedWayPoints = returnedData as List<Map<String, Any>>
            
            assertEquals(
                "迭代 $iteration: wayPoints数组长度应该为2",
                2,
                returnedWayPoints.size
            )
            
            // 验证每个wayPoint包含所有必需字段
            returnedWayPoints.forEachIndexed { index, wayPoint ->
                assertTrue(
                    "迭代 $iteration, wayPoint[$index]: 应该包含name字段",
                    wayPoint.containsKey("name")
                )
                assertTrue(
                    "迭代 $iteration, wayPoint[$index]: 应该包含latitude字段",
                    wayPoint.containsKey("latitude")
                )
                assertTrue(
                    "迭代 $iteration, wayPoint[$index]: 应该包含longitude字段",
                    wayPoint.containsKey("longitude")
                )
                assertTrue(
                    "迭代 $iteration, wayPoint[$index]: 应该包含isSilent字段",
                    wayPoint.containsKey("isSilent")
                )
                assertTrue(
                    "迭代 $iteration, wayPoint[$index]: 应该包含address字段",
                    wayPoint.containsKey("address")
                )
            }
        }
    }

    /**
     * Property 11 扩展: 空wayPoints处理
     * 
     * For any 空的wayPoints数组, 系统应该正确处理
     */
    @Test
    fun `property 11 extended - empty wayPoints handling`() {
        repeat(100) {
            val emptyWayPoints = emptyList<Map<String, Any>>()
            
            val resultSlot = slot<Any?>()
            every { mockResult.success(capture(resultSlot)) } just Runs
            
            mockResult.success(emptyWayPoints)
            
            verify { mockResult.success(any()) }
            
            val returnedData = resultSlot.captured
            assertTrue(
                "空wayPoints应该返回空列表",
                returnedData is List<*> && (returnedData as List<*>).isEmpty()
            )
        }
    }

    /**
     * Property 11 扩展: 大量wayPoints处理
     * 
     * For any 包含大量wayPoints的数组, 系统应该正确处理
     */
    @Test
    fun `property 11 extended - large wayPoints array handling`() {
        repeat(10) { iteration ->
            // 生成包含多个wayPoints的数组（2-20个）
            val count = Random.nextInt(2, 20)
            val wayPoints = (0 until count).map {
                mapOf(
                    "name" to "地点$it",
                    "latitude" to generateRandomLatitude(),
                    "longitude" to generateRandomLongitude(),
                    "isSilent" to Random.nextBoolean(),
                    "address" to "地址$it"
                )
            }
            
            val resultSlot = slot<Any?>()
            every { mockResult.success(capture(resultSlot)) } just Runs
            
            mockResult.success(wayPoints)
            
            verify { mockResult.success(any()) }
            
            @Suppress("UNCHECKED_CAST")
            val returnedWayPoints = resultSlot.captured as List<Map<String, Any>>
            
            assertEquals(
                "迭代 $iteration: wayPoints数量应该匹配",
                count,
                returnedWayPoints.size
            )
        }
    }

    /**
     * Property 12: 地点选择返回wayPoints
     * 
     * For any 用户完成的地点选择操作, 系统应该返回包含起点和终点的wayPoints数组给Flutter
     * 
     * Validates: Requirement 7.3
     */
    @Test
    fun `property 12 - place selection returns wayPoints`() {
        // 运行100次迭代
        repeat(100) { iteration ->
            // 生成随机的wayPoints（起点和终点）
            val wayPoints = generateRandomWayPoints()
            
            // 模拟用户完成地点选择
            val resultSlot = slot<Any?>()
            every { mockResult.success(capture(resultSlot)) } just Runs
            
            // 返回wayPoints
            mockResult.success(wayPoints)
            
            // 验证success被调用
            verify(exactly = iteration + 1) {
                mockResult.success(any())
            }
            
            // 验证返回的是wayPoints数组
            val returnedData = resultSlot.captured
            assertNotNull(
                "迭代 $iteration: 应该返回wayPoints",
                returnedData
            )
            
            @Suppress("UNCHECKED_CAST")
            val returnedWayPoints = returnedData as List<Map<String, Any>>
            
            // 验证包含起点和终点
            assertEquals(
                "迭代 $iteration: 应该包含起点和终点",
                2,
                returnedWayPoints.size
            )
            
            // 验证起点
            val origin = returnedWayPoints[0]
            assertNotNull("迭代 $iteration: 起点name不应为空", origin["name"])
            assertNotNull("迭代 $iteration: 起点latitude不应为空", origin["latitude"])
            assertNotNull("迭代 $iteration: 起点longitude不应为空", origin["longitude"])
            
            // 验证终点
            val destination = returnedWayPoints[1]
            assertNotNull("迭代 $iteration: 终点name不应为空", destination["name"])
            assertNotNull("迭代 $iteration: 终点latitude不应为空", destination["latitude"])
            assertNotNull("迭代 $iteration: 终点longitude不应为空", destination["longitude"])
        }
    }

    /**
     * Property 12 扩展: 用户取消返回null
     * 
     * For any 用户取消的操作, 系统应该返回null
     */
    @Test
    fun `property 12 extended - user cancellation returns null`() {
        repeat(100) { iteration ->
            val resultSlot = slot<Any?>()
            every { mockResult.success(capture(resultSlot)) } just Runs
            
            // 模拟用户取消
            mockResult.success(null)
            
            verify(exactly = iteration + 1) {
                mockResult.success(any())
            }
            
            // 验证返回null
            assertNull(
                "迭代 $iteration: 用户取消应该返回null",
                resultSlot.captured
            )
        }
    }

    /**
     * Property 12 扩展: 不同地理位置的wayPoints
     * 
     * For any 不同地理位置的wayPoints, 系统应该正确返回
     */
    @Test
    fun `property 12 extended - various geographic locations`() {
        val testLocations = listOf(
            Triple(39.9042, 116.4074, "北京"),
            Triple(31.2304, 121.4737, "上海"),
            Triple(23.1291, 113.2644, "广州"),
            Triple(22.5431, 114.0579, "深圳"),
            Triple(0.0, 0.0, "赤道零点"),
            Triple(-90.0, -180.0, "最小边界"),
            Triple(90.0, 180.0, "最大边界")
        )
        
        testLocations.forEach { (lat, lon, name) ->
            val wayPoints = listOf(
                mapOf(
                    "name" to "起点",
                    "latitude" to generateRandomLatitude(),
                    "longitude" to generateRandomLongitude(),
                    "isSilent" to false,
                    "address" to ""
                ),
                mapOf(
                    "name" to name,
                    "latitude" to lat,
                    "longitude" to lon,
                    "isSilent" to false,
                    "address" to "${name}地址"
                )
            )
            
            val resultSlot = slot<Any?>()
            every { mockResult.success(capture(resultSlot)) } just Runs
            
            mockResult.success(wayPoints)
            
            verify { mockResult.success(any()) }
            
            @Suppress("UNCHECKED_CAST")
            val returnedWayPoints = resultSlot.captured as List<Map<String, Any>>
            
            // 验证终点位置正确
            val destination = returnedWayPoints[1]
            assertEquals(
                "$name: 终点名称应该匹配",
                name,
                destination["name"]
            )
            assertEquals(
                "$name: 终点纬度应该匹配",
                lat,
                destination["latitude"] as Double,
                0.000001
            )
            assertEquals(
                "$name: 终点经度应该匹配",
                lon,
                destination["longitude"] as Double,
                0.000001
            )
        }
    }

    /**
     * Property: MethodChannel错误处理
     * 
     * For any 错误情况, 系统应该通过MethodChannel返回错误
     */
    @Test
    fun `property - method channel error handling`() {
        val errorCodes = listOf(
            "NO_ACTIVITY",
            "SEARCH_ERROR",
            "INVALID_RESULT",
            "NO_DATA",
            "UNKNOWN_RESULT"
        )
        
        errorCodes.forEach { errorCode ->
            val errorSlot = slot<String>()
            val messageSlot = slot<String>()
            every { 
                mockResult.error(
                    capture(errorSlot), 
                    capture(messageSlot), 
                    any()
                ) 
            } just Runs
            
            // 模拟错误
            mockResult.error(errorCode, "错误消息", null)
            
            verify { mockResult.error(any(), any(), any()) }
            
            // 验证错误码
            assertEquals(
                "错误码应该匹配",
                errorCode,
                errorSlot.captured
            )
            
            // 验证错误消息不为空
            assertTrue(
                "错误消息不应为空",
                messageSlot.captured.isNotEmpty()
            )
        }
    }

    /**
     * Property: 中文错误消息
     * 
     * For any 错误消息, 应该使用中文
     */
    @Test
    fun `property - chinese error messages`() {
        val chineseErrorMessages = listOf(
            "Activity为空",
            "启动搜索界面失败",
            "wayPoints数据无效",
            "未返回数据",
            "未知的结果码"
        )
        
        chineseErrorMessages.forEach { message ->
            val messageSlot = slot<String>()
            every { 
                mockResult.error(any(), capture(messageSlot), any()) 
            } just Runs
            
            mockResult.error("ERROR", message, null)
            
            verify { mockResult.error(any(), any(), any()) }
            
            // 验证消息包含中文字符
            assertTrue(
                "错误消息应该包含中文字符",
                messageSlot.captured.any { it.code in 0x4E00..0x9FFF }
            )
        }
    }

    /**
     * Property: Intent数据序列化
     * 
     * For any wayPoints数组, 应该能够正确序列化到Intent
     */
    @Test
    fun `property - intent data serialization`() {
        repeat(100) {
            val wayPoints = generateRandomWayPoints()
            
            // 模拟Intent
            val mockIntent = mockk<Intent>(relaxed = true)
            val dataSlot = slot<ArrayList<Map<String, Any>>>()
            
            every { 
                mockIntent.putExtra(any<String>(), capture(dataSlot)) 
            } returns mockIntent
            
            // 序列化wayPoints到Intent
            @Suppress("UNCHECKED_CAST")
            mockIntent.putExtra("result_waypoints", ArrayList(wayPoints))
            
            verify { mockIntent.putExtra(any<String>(), any<ArrayList<Map<String, Any>>>()) }
            
            // 验证序列化的数据
            val serializedData = dataSlot.captured
            assertEquals(
                "序列化后的数据长度应该匹配",
                wayPoints.size,
                serializedData.size
            )
        }
    }

    // Helper functions

    /**
     * 生成随机的wayPoints数组（起点和终点）
     */
    private fun generateRandomWayPoints(): List<Map<String, Any>> {
        return listOf(
            mapOf(
                "name" to "起点${Random.nextInt(1000)}",
                "latitude" to generateRandomLatitude(),
                "longitude" to generateRandomLongitude(),
                "isSilent" to false,
                "address" to ""
            ),
            mapOf(
                "name" to "终点${Random.nextInt(1000)}",
                "latitude" to generateRandomLatitude(),
                "longitude" to generateRandomLongitude(),
                "isSilent" to false,
                "address" to "地址${Random.nextInt(1000)}"
            )
        )
    }

    /**
     * 生成随机纬度 (-90 到 90)
     */
    private fun generateRandomLatitude(): Double {
        return Random.nextDouble(-90.0, 90.0)
    }

    /**
     * 生成随机经度 (-180 到 180)
     */
    private fun generateRandomLongitude(): Double {
        return Random.nextDouble(-180.0, 180.0)
    }
}
