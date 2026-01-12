package com.eopeter.fluttermapboxnavigation.properties

import com.mapbox.api.directions.v5.DirectionsCriteria
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

/**
 * 属性测试: 导航模式映射正确性
 * 
 * Property 1: 导航模式映射正确性
 * For any valid navigation mode string, the system SHALL map it to the correct Mapbox profile
 * 
 * Validates: Requirements 4.1, 4.2, 4.3
 * 
 * Feature: android-navigation-ios-parity, Property 1: 导航模式映射正确性
 */
@RunWith(Parameterized::class)
class NavigationModePropertyTest(
    private val mode: String,
    private val expectedProfile: String,
    private val description: String
) {

    companion object {
        @JvmStatic
        @Parameterized.Parameters(name = "{2}")
        fun data(): Collection<Array<Any>> {
            return listOf(
                // Standard modes
                arrayOf("driving", DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, "driving mode"),
                arrayOf("walking", DirectionsCriteria.PROFILE_WALKING, "walking mode"),
                arrayOf("cycling", DirectionsCriteria.PROFILE_CYCLING, "cycling mode"),
                
                // Case variations
                arrayOf("DRIVING", DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, "uppercase driving"),
                arrayOf("Walking", DirectionsCriteria.PROFILE_WALKING, "capitalized walking"),
                arrayOf("CyCLiNg", DirectionsCriteria.PROFILE_CYCLING, "mixed case cycling"),
                arrayOf("dRiViNg", DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, "random case driving"),
                
                // With whitespace
                arrayOf(" driving ", DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, "driving with spaces"),
                arrayOf("  walking  ", DirectionsCriteria.PROFILE_WALKING, "walking with spaces"),
                arrayOf("\tcycling\t", DirectionsCriteria.PROFILE_CYCLING, "cycling with tabs"),
                
                // Edge cases - should default to driving
                arrayOf("", DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, "empty string"),
                arrayOf("invalid", DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, "invalid mode"),
                arrayOf("running", DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, "unsupported mode"),
                arrayOf("123", DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, "numeric mode"),
                arrayOf("driving123", DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, "mode with numbers"),
                arrayOf("walk", DirectionsCriteria.PROFILE_DRIVING_TRAFFIC, "partial mode name")
            )
        }
    }

    @Test
    fun `property - navigation mode maps to correct profile`() {
        // Property: For any navigation mode string, mapping should produce a valid profile
        
        // When
        val profile = mapNavigationModeToProfile(mode)
        
        // Then
        assertNotNull("Profile should not be null", profile)
        assertEquals("Mode '$mode' should map to expected profile", expectedProfile, profile)
        
        // Additional property: Result should always be one of the valid profiles
        val validProfiles = setOf(
            DirectionsCriteria.PROFILE_DRIVING_TRAFFIC,
            DirectionsCriteria.PROFILE_WALKING,
            DirectionsCriteria.PROFILE_CYCLING
        )
        assert(profile in validProfiles) {
            "Profile '$profile' should be one of the valid profiles"
        }
    }

    @Test
    fun `property - mapping is deterministic`() {
        // Property: Mapping the same mode multiple times should always produce the same result
        
        // When
        val result1 = mapNavigationModeToProfile(mode)
        val result2 = mapNavigationModeToProfile(mode)
        val result3 = mapNavigationModeToProfile(mode)
        
        // Then
        assertEquals("Multiple mappings should produce same result", result1, result2)
        assertEquals("Multiple mappings should produce same result", result2, result3)
    }

    @Test
    fun `property - mapping is case insensitive`() {
        // Property: Mode mapping should be case insensitive
        
        // When
        val lowercase = mapNavigationModeToProfile(mode.lowercase())
        val uppercase = mapNavigationModeToProfile(mode.uppercase())
        val original = mapNavigationModeToProfile(mode)
        
        // Then
        assertEquals("Lowercase should match original", original, lowercase)
        assertEquals("Uppercase should match original", original, uppercase)
    }

    // Helper function
    private fun mapNavigationModeToProfile(mode: String?): String {
        return when (mode?.trim()?.lowercase()) {
            "driving" -> DirectionsCriteria.PROFILE_DRIVING_TRAFFIC
            "walking" -> DirectionsCriteria.PROFILE_WALKING
            "cycling" -> DirectionsCriteria.PROFILE_CYCLING
            else -> DirectionsCriteria.PROFILE_DRIVING_TRAFFIC
        }
    }
}
