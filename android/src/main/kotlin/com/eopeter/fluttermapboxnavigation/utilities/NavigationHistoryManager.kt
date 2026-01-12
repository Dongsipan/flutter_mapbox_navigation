package com.eopeter.fluttermapboxnavigation.utilities

import android.util.Log
import com.mapbox.navigation.core.replay.history.ReplayEventBase
import com.mapbox.navigation.core.replay.history.ReplayHistoryMapper
import com.mapbox.navigation.core.history.MapboxHistoryReader
import java.io.File

/**
 * 导航历史管理器 - SDK v3
 */
object NavigationHistoryManager {
    
    private const val TAG = "NavigationHistoryManager"
    
    /**
     * 加载回放事件
     * 使用 MapboxHistoryReader 读取历史文件，然后用 ReplayHistoryMapper 转换为回放事件
     */
    fun loadReplayEvents(filePath: String): List<ReplayEventBase> {
        return try {
            val file = File(filePath)
            if (!file.exists()) {
                Log.e(TAG, "History file does not exist: $filePath")
                return emptyList()
            }
            
            Log.d(TAG, "Loading history file: $filePath")
            
            // 使用 MapboxHistoryReader 读取历史文件
            val historyReader = MapboxHistoryReader(filePath)
            
            // 使用 Builder 创建 ReplayHistoryMapper 实例
            val replayHistoryMapper = ReplayHistoryMapper.Builder()
                .build()
            
            val events = mutableListOf<ReplayEventBase>()
            
            // 使用 hasNext() 判断是否还有更多元素，避免在文件末尾抛异常
            while (historyReader.hasNext()) {
                val historyEvent = historyReader.next()
                val replayEvent = replayHistoryMapper.mapToReplayEvent(historyEvent)
                if (replayEvent != null) {
                    events.add(replayEvent)
                }
            }
            
            Log.d(TAG, "Successfully loaded ${events.size} replay events from history file")
            events
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load replay events: ${e.message}", e)
            emptyList()
        }
    }
    
    /**
     * 验证历史文件是否有效
     */
    fun isValidHistoryFile(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            file.exists() && file.length() > 0
        } catch (e: Exception) {
            Log.e(TAG, "Failed to validate history file: ${e.message}", e)
            false
        }
    }
}
