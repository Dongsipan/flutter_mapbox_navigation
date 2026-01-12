package com.eopeter.fluttermapboxnavigation.utilities

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/**
 * 导航历史记录管理器
 */
class HistoryManager(private val context: Context) {
    
    private val prefs: SharedPreferences = context.getSharedPreferences("navigation_history", Context.MODE_PRIVATE)
    private val gson = Gson()
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
    
    companion object {
        private const val HISTORY_LIST_KEY = "history_list"
        private const val HISTORY_DIR = "navigation_history"
    }
    
    /**
     * 保存历史记录
     */
    fun saveHistoryRecord(historyData: Map<String, Any?>): Boolean {
        return try {
            val historyList = getHistoryList().toMutableList()
            val historyRecord = HistoryRecord(
                id = historyData["id"] as? String ?: UUID.randomUUID().toString(),
                historyFilePath = historyData["filePath"] as? String ?: "",
                cover = historyData["cover"] as? String,
                startTime = (historyData["startTime"] as? Long)?.let { Date(it) } ?: Date(),
                endTime = (historyData["endTime"] as? Long)?.let { Date(it) },
                distance = (historyData["distance"] as? Number)?.toDouble(),
                duration = (historyData["duration"] as? Number)?.toInt(),
                startPointName = historyData["startPointName"] as? String,
                endPointName = historyData["endPointName"] as? String,
                navigationMode = historyData["navigationMode"] as? String
            )
            
            android.util.Log.d("HistoryManager", "💾 Saving history record: id=${historyRecord.id}, endTime=${historyRecord.endTime?.time}, distance=${historyRecord.distance}")
            
            historyList.add(historyRecord)
            saveHistoryList(historyList)
            true
        } catch (e: Exception) {
            android.util.Log.e("HistoryManager", "❌ Failed to save history record: ${e.message}", e)
            false
        }
    }
    
    /**
     * 更新现有历史记录（用于更新 endTime 和 distance）
     */
    fun updateHistoryRecord(historyId: String, updates: Map<String, Any?>): Boolean {
        return try {
            val historyList = getHistoryList().toMutableList()
            val index = historyList.indexOfFirst { it.id == historyId }
            if (index != -1) {
                val oldRecord = historyList[index]
                val updatedRecord = oldRecord.copy(
                    endTime = (updates["endTime"] as? Long)?.let { Date(it) } ?: oldRecord.endTime,
                    distance = (updates["distance"] as? Number)?.toDouble() ?: oldRecord.distance,
                    duration = (updates["duration"] as? Number)?.toInt() ?: oldRecord.duration,
                    cover = updates["cover"] as? String ?: oldRecord.cover
                )
                
                android.util.Log.d("HistoryManager", "🔄 Updating history record: id=$historyId, endTime=${updatedRecord.endTime?.time}, distance=${updatedRecord.distance}")
                
                historyList[index] = updatedRecord
                saveHistoryList(historyList)
                true
            } else {
                android.util.Log.w("HistoryManager", "⚠️ History record not found: $historyId")
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("HistoryManager", "❌ Failed to update history record: ${e.message}", e)
            false
        }
    }
    
    /**
     * 获取历史记录列表
     */
    fun getHistoryList(): List<HistoryRecord> {
        return try {
            val json = prefs.getString(HISTORY_LIST_KEY, "[]")
            val type = object : TypeToken<List<HistoryRecord>>() {}.type
            gson.fromJson(json, type) ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    /**
     * 删除指定的历史记录
     */
    fun deleteHistoryRecord(historyId: String): Boolean {
        return try {
            val historyList = getHistoryList().toMutableList()
            val record = historyList.find { it.id == historyId }
            if (record != null) {
                // 删除历史文件
                val file = File(record.historyFilePath)
                if (file.exists()) {
                    file.delete()
                }
                
                // 删除封面文件
                record.cover?.let { coverPath ->
                    val coverFile = File(coverPath)
                    if (coverFile.exists()) {
                        coverFile.delete()
                    }
                }
                
                // 从列表中移除
                historyList.remove(record)
                saveHistoryList(historyList)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 更新历史记录的封面路径
     */
    fun updateHistoryCover(historyId: String, coverPath: String?): Boolean {
        return try {
            val historyList = getHistoryList().toMutableList()
            val index = historyList.indexOfFirst { it.id == historyId }
            if (index != -1) {
                val oldRecord = historyList[index]
                val updatedRecord = oldRecord.copy(cover = coverPath)
                historyList[index] = updatedRecord
                saveHistoryList(historyList)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 清除所有历史记录
     */
    fun clearAllHistory(): Boolean {
        return try {
            val historyList = getHistoryList()
            // 删除所有文件
            historyList.forEach { record ->
                // 删除历史文件
                val file = File(record.historyFilePath)
                if (file.exists()) {
                    file.delete()
                }
                
                // 删除封面文件
                record.cover?.let { coverPath ->
                    val coverFile = File(coverPath)
                    if (coverFile.exists()) {
                        coverFile.delete()
                    }
                }
            }
            
            // 清空列表
            saveHistoryList(emptyList())
            true
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 获取历史记录存储目录
     */
    fun getHistoryDirectory(): File {
        val historyDir = File(context.filesDir, HISTORY_DIR)
        if (!historyDir.exists()) {
            historyDir.mkdirs()
        }
        return historyDir
    }
    
    /**
     * 生成历史记录文件路径
     */
    fun generateHistoryFilePath(historyId: String): String {
        val historyDir = getHistoryDirectory()
        val fileName = "navigation_history_${historyId}.json"
        return File(historyDir, fileName).absolutePath
    }
    
    private fun saveHistoryList(historyList: List<HistoryRecord>) {
        val json = gson.toJson(historyList)
        prefs.edit().putString(HISTORY_LIST_KEY, json).apply()
    }
}

/**
 * 历史记录数据类
 * 字段与 Flutter NavigationHistory model 保持一致
 */
data class HistoryRecord(
    val id: String,
    val historyFilePath: String,
    val cover: String?,              // 封面图片路径
    val startTime: Date,
    val endTime: Date?,              // 导航结束时间
    val distance: Double?,           // 导航距离（米）
    val duration: Int?,              // 导航持续时间（秒）
    val startPointName: String?,
    val endPointName: String?,
    val navigationMode: String?
)
