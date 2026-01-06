package com.eopeter.fluttermapboxnavigation.models

/**
 * 路径点数据类
 * 
 * 用于在搜索功能中表示起点和终点的数据结构
 * 
 * @property name 地点名称
 * @property latitude 纬度
 * @property longitude 经度
 * @property isSilent 是否静默（默认false）
 * @property address 地址（可选）
 */
data class WayPointData(
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val isSilent: Boolean = false,
    val address: String = ""
) {
    /**
     * 转换为Map格式，用于通过MethodChannel传递给Flutter
     * 
     * @return Map<String, Any> 包含所有字段的Map
     */
    fun toMap(): Map<String, Any> = mapOf(
        "name" to name,
        "latitude" to latitude,
        "longitude" to longitude,
        "isSilent" to isSilent,
        "address" to address
    )
    
    companion object {
        /**
         * 从Map创建WayPointData实例
         * 
         * @param map 包含路径点数据的Map
         * @return WayPointData 实例
         */
        fun fromMap(map: Map<String, Any>): WayPointData {
            return WayPointData(
                name = map["name"] as? String ?: "",
                latitude = map["latitude"] as? Double ?: 0.0,
                longitude = map["longitude"] as? Double ?: 0.0,
                isSilent = map["isSilent"] as? Boolean ?: false,
                address = map["address"] as? String ?: ""
            )
        }
    }
}
