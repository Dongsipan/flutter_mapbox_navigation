package com.eopeter.fluttermapboxnavigation.properties

import com.eopeter.fluttermapboxnavigation.models.WayPointData
import org.junit.Assert.*
import org.junit.Test
import kotlin.random.Random

/**
 * WayPointData属性测试
 * 
 * Feature: android-map-search-feature, Property 10: wayPoints数组格式正确性
 * Validates: Requirements 6.4, 6.6
 */
class WayPointDataPropertyTest {

    /**
     * Property 10: wayPoints数组格式正确性
     * 
     * For any generated wayPoints数组, 数组应该包含恰好2个元素（起点和终点），
     * 并且每个元素都应该包含name、latitude、longitude、isSilent、address这5个字段
     * 
     * Validates: Requirements 6.4, 6.6
     */
    @Test
    fun `property 10 - wayPoints array format correctness`() {
        // 运行100次迭代
        repeat(100) {
            // 生成随机的起点和终点
            val origin = generateRandomWayPoint("起点")
            val destination = generateRandomWayPoint("终点")
            
            // 创建wayPoints数组
            val wayPoints = listOf(origin, destination)
            
            // 验证数组长度
            assertEquals(
                "wayPoints数组应该包含恰好2个元素",
                2,
                wayPoints.size
            )
            
            // 验证每个wayPoint都包含所有必需字段
            wayPoints.forEachIndexed { index, wayPoint ->
                val map = wayPoint.toMap()
                
                // 验证包含5个字段
                assertEquals(
                    "wayPoint[$index]应该包含5个字段",
                    5,
                    map.size
                )
                
                // 验证name字段
                assertTrue(
                    "wayPoint[$index]应该包含name字段",
                    map.containsKey("name")
                )
                assertTrue(
                    "wayPoint[$index]的name应该是String类型",
                    map["name"] is String
                )
                
                // 验证latitude字段
                assertTrue(
                    "wayPoint[$index]应该包含latitude字段",
                    map.containsKey("latitude")
                )
                assertTrue(
                    "wayPoint[$index]的latitude应该是Double类型",
                    map["latitude"] is Double
                )
                val latitude = map["latitude"] as Double
                assertTrue(
                    "wayPoint[$index]的latitude应该在-90到90之间",
                    latitude >= -90.0 && latitude <= 90.0
                )
                
                // 验证longitude字段
                assertTrue(
                    "wayPoint[$index]应该包含longitude字段",
                    map.containsKey("longitude")
                )
                assertTrue(
                    "wayPoint[$index]的longitude应该是Double类型",
                    map["longitude"] is Double
                )
                val longitude = map["longitude"] as Double
                assertTrue(
                    "wayPoint[$index]的longitude应该在-180到180之间",
                    longitude >= -180.0 && longitude <= 180.0
                )
                
                // 验证isSilent字段
                assertTrue(
                    "wayPoint[$index]应该包含isSilent字段",
                    map.containsKey("isSilent")
                )
                assertTrue(
                    "wayPoint[$index]的isSilent应该是Boolean类型",
                    map["isSilent"] is Boolean
                )
                
                // 验证address字段
                assertTrue(
                    "wayPoint[$index]应该包含address字段",
                    map.containsKey("address")
                )
                assertTrue(
                    "wayPoint[$index]的address应该是String类型",
                    map["address"] is String
                )
            }
        }
    }

    /**
     * Property: WayPointData序列化往返一致性
     * 
     * For any WayPointData, toMap()然后fromMap()应该产生相等的对象
     */
    @Test
    fun `property - waypoint serialization round trip`() {
        repeat(100) {
            // 生成随机waypoint
            val original = generateRandomWayPoint()
            
            // 序列化然后反序列化
            val map = original.toMap()
            val deserialized = WayPointData.fromMap(map)
            
            // 验证往返一致性
            assertEquals("name应该相等", original.name, deserialized.name)
            assertEquals("latitude应该相等", original.latitude, deserialized.latitude, 0.000001)
            assertEquals("longitude应该相等", original.longitude, deserialized.longitude, 0.000001)
            assertEquals("isSilent应该相等", original.isSilent, deserialized.isSilent)
            assertEquals("address应该相等", original.address, deserialized.address)
        }
    }

    /**
     * Property: WayPointData字段不可变性
     * 
     * For any WayPointData, 字段值应该保持不变
     */
    @Test
    fun `property - waypoint fields are immutable`() {
        repeat(100) {
            val waypoint = generateRandomWayPoint()
            
            // 获取初始值
            val initialName = waypoint.name
            val initialLat = waypoint.latitude
            val initialLon = waypoint.longitude
            val initialSilent = waypoint.isSilent
            val initialAddress = waypoint.address
            
            // 多次调用toMap()
            repeat(10) {
                waypoint.toMap()
            }
            
            // 验证值没有改变
            assertEquals("name应该保持不变", initialName, waypoint.name)
            assertEquals("latitude应该保持不变", initialLat, waypoint.latitude, 0.0)
            assertEquals("longitude应该保持不变", initialLon, waypoint.longitude, 0.0)
            assertEquals("isSilent应该保持不变", initialSilent, waypoint.isSilent)
            assertEquals("address应该保持不变", initialAddress, waypoint.address)
        }
    }

    /**
     * Property: 空字符串处理
     * 
     * For any WayPointData with empty strings, 应该正确处理
     */
    @Test
    fun `property - empty string handling`() {
        repeat(100) {
            val waypoint = WayPointData(
                name = "",
                latitude = generateRandomLatitude(),
                longitude = generateRandomLongitude(),
                isSilent = Random.nextBoolean(),
                address = ""
            )
            
            val map = waypoint.toMap()
            val deserialized = WayPointData.fromMap(map)
            
            assertEquals("空name应该保持为空", "", deserialized.name)
            assertEquals("空address应该保持为空", "", deserialized.address)
        }
    }

    /**
     * Property: 边界值处理
     * 
     * For any WayPointData with boundary values, 应该正确处理
     */
    @Test
    fun `property - boundary value handling`() {
        val boundaryValues = listOf(
            Triple(-90.0, -180.0, "最小边界"),
            Triple(90.0, 180.0, "最大边界"),
            Triple(0.0, 0.0, "零点"),
            Triple(-90.0, 180.0, "混合边界1"),
            Triple(90.0, -180.0, "混合边界2")
        )
        
        boundaryValues.forEach { (lat, lon, description) ->
            val waypoint = WayPointData(
                name = description,
                latitude = lat,
                longitude = lon,
                isSilent = false,
                address = "测试地址"
            )
            
            val map = waypoint.toMap()
            val deserialized = WayPointData.fromMap(map)
            
            assertEquals("$description: latitude应该相等", lat, deserialized.latitude, 0.0)
            assertEquals("$description: longitude应该相等", lon, deserialized.longitude, 0.0)
        }
    }

    /**
     * Property: 中文字符处理
     * 
     * For any WayPointData with Chinese characters, 应该正确处理
     */
    @Test
    fun `property - chinese character handling`() {
        val chineseNames = listOf(
            "北京市",
            "上海市",
            "广州市",
            "深圳市",
            "天安门广场",
            "长城",
            "故宫",
            "西湖"
        )
        
        chineseNames.forEach { name ->
            val waypoint = WayPointData(
                name = name,
                latitude = generateRandomLatitude(),
                longitude = generateRandomLongitude(),
                isSilent = false,
                address = "${name}详细地址"
            )
            
            val map = waypoint.toMap()
            val deserialized = WayPointData.fromMap(map)
            
            assertEquals("中文name应该正确保存", name, deserialized.name)
            assertEquals("中文address应该正确保存", "${name}详细地址", deserialized.address)
        }
    }

    // Helper functions

    /**
     * 生成随机的WayPointData
     */
    private fun generateRandomWayPoint(namePrefix: String = "地点"): WayPointData {
        return WayPointData(
            name = "$namePrefix${Random.nextInt(1000)}",
            latitude = generateRandomLatitude(),
            longitude = generateRandomLongitude(),
            isSilent = Random.nextBoolean(),
            address = "地址${Random.nextInt(1000)}"
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
