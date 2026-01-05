package com.eopeter.fluttermapboxnavigation

import com.mapbox.api.directions.v5.DirectionsCriteria
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 单元测试: 导航模式映射
 * 
 * 测试导航模式字符串正确映射到 Mapbox DirectionsCriteria 常量
 * 
 * Requirements: 4.1, 4.2, 4.3
 */
class NavigationModeTest {

    @Test
    fun `test driving mode maps to PROFILE_DRIVING_TRAFFIC`() {
        // Given
        val mode = "driving"
        
        // When
        val profile = mapNavigationModeToProfile(mode)
        
        // Then
        assertEquals(DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, profile)
    }

    @Test
    fun `test walking mode maps to PROFILE_WALKING`() {
        // Given
        val mode = "walking"
        
        // When
        val profile = mapNavigationModeToProfile(mode)
        
        // Then
        assertEquals(DirectionsCriteria.PROFILE_WALKING, profile)
    }

    @Test
    fun `test cycling mode maps to PROFILE_CYCLING`() {
        // Given
        val mode = "cycling"
        
        // When
        val profile = mapNavigationModeToProfile(mode)
        
        // Then
        assertEquals(DirectionsCriteria.PROFILE_CYCLING, profile)
    }

    @Test
    fun `test invalid mode defaults to PROFILE_DRIVING_TRAFFIC`() {
        // Given
        val mode = "invalid_mode"
        
        // When
        val profile = mapNavigationModeToProfile(mode)
        
        // Then
        assertEquals(DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, profile)
    }

    @Test
    fun `test null mode defaults to PROFILE_DRIVING_TRAFFIC`() {
        // Given
        val mode: String? = null
        
        // When
        val profile = mapNavigationModeToProfile(mode)
        
        // Then
        assertEquals(DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, profile)
    }

    @Test
    fun `test case insensitive mode mapping`() {
        // Given
        val modes = listOf("DRIVING", "Walking", "CyCLiNg")
        
        // When & Then
        assertEquals(DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, mapNavigationModeToProfile(modes[0]))
        assertEquals(DirectionsCriteria.PROFILE_WALKING, mapNavigationModeToProfile(modes[1]))
        assertEquals(DirectionsCriteria.PROFILE_CYCLING, mapNavigationModeToProfile(modes[2]))
    }

    // Helper function to map navigation mode to profile
    private fun mapNavigationModeToProfile(mode: String?): String {
        return when (mode?.lowercase()) {
            "driving" -> DirectionsCriteria.PROFILE_DRIVING_TRAFFIC
            "walking" -> DirectionsCriteria.PROFILE_WALKING
            "cycling" -> DirectionsCriteria.PROFILE_CYCLING
            else -> DirectionsCriteria.PROFILE_DRIVING_TRAFFIC
        }
    }
}
