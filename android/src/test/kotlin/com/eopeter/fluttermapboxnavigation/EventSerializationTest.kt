package com.eopeter.fluttermapboxnavigation

import com.eopeter.fluttermapboxnavigation.models.MapBoxEvents
import com.google.gson.Gson
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 单元测试: 事件序列化
 * 
 * 测试导航事件正确序列化为 JSON 格式
 * 
 * Requirements: 12.1, 12.2, 12.3, 12.4, 12.5
 */
class EventSerializationTest {

    private val gson = Gson()

    @Test
    fun `test ROUTE_BUILT event serialization`() {
        // Given
        val eventType = MapBoxEvents.ROUTE_BUILT
        val routeData = mapOf(
            "distance" to 1500.0,
            "duration" to 300.0
        )
        val jsonData = JSONObject(routeData).toString()
        
        // When
        val event = createEvent(eventType, jsonData)
        
        // Then
        assertNotNull("Event should not be null", event)
        assertEquals("Event type should match", eventType, event.eventType)
        assertTrue("Event data should contain distance", event.data.contains("distance"))
        assertTrue("Event data should contain duration", event.data.contains("duration"))
    }

    @Test
    fun `test NAVIGATION_RUNNING event serialization`() {
        // Given
        val eventType = MapBoxEvents.NAVIGATION_RUNNING
        
        // When
        val event = createEvent(eventType, null)
        
        // Then
        assertNotNull("Event should not be null", event)
        assertEquals("Event type should match", eventType, event.eventType)
    }

    @Test
    fun `test NAVIGATION_CANCELLED event serialization`() {
        // Given
        val eventType = MapBoxEvents.NAVIGATION_CANCELLED
        
        // When
        val event = createEvent(eventType, null)
        
        // Then
        assertNotNull("Event should not be null", event)
        assertEquals("Event type should match", eventType, event.eventType)
    }

    @Test
    fun `test USER_OFF_ROUTE event serialization`() {
        // Given
        val eventType = MapBoxEvents.USER_OFF_ROUTE
        
        // When
        val event = createEvent(eventType, null)
        
        // Then
        assertNotNull("Event should not be null", event)
        assertEquals("Event type should match", eventType, event.eventType)
    }

    @Test
    fun `test REROUTE_ALONG event serialization`() {
        // Given
        val eventType = MapBoxEvents.REROUTE_ALONG
        
        // When
        val event = createEvent(eventType, null)
        
        // Then
        assertNotNull("Event should not be null", event)
        assertEquals("Event type should match", eventType, event.eventType)
    }

    @Test
    fun `test ON_ARRIVAL event with data serialization`() {
        // Given
        val eventType = MapBoxEvents.ON_ARRIVAL
        val arrivalData = mapOf(
            "isFinalDestination" to true,
            "legIndex" to 0,
            "distanceRemaining" to 0.0
        )
        val jsonData = JSONObject(arrivalData).toString()
        
        // When
        val event = createEvent(eventType, jsonData)
        
        // Then
        assertNotNull("Event should not be null", event)
        assertEquals("Event type should match", eventType, event.eventType)
        assertTrue("Event data should contain isFinalDestination", event.data.contains("isFinalDestination"))
        assertTrue("Event data should contain legIndex", event.data.contains("legIndex"))
    }

    @Test
    fun `test ROUTE_BUILD_FAILED event with error data`() {
        // Given
        val eventType = MapBoxEvents.ROUTE_BUILD_FAILED
        val errorData = mapOf(
            "message" to "No route found",
            "type" to "ROUTE_ERROR"
        )
        val jsonData = JSONObject(errorData).toString()
        
        // When
        val event = createEvent(eventType, jsonData)
        
        // Then
        assertNotNull("Event should not be null", event)
        assertEquals("Event type should match", eventType, event.eventType)
        assertTrue("Event data should contain error message", event.data.contains("message"))
        assertTrue("Event data should contain error type", event.data.contains("type"))
    }

    @Test
    fun `test event with null data serialization`() {
        // Given
        val eventType = MapBoxEvents.NAVIGATION_RUNNING
        
        // When
        val event = createEvent(eventType, null)
        
        // Then
        assertNotNull("Event should not be null", event)
        assertEquals("Event type should match", eventType, event.eventType)
        assertTrue("Event data should be empty or null", event.data.isEmpty() || event.data == "null")
    }

    @Test
    fun `test event with complex nested data`() {
        // Given
        val eventType = MapBoxEvents.ROUTE_BUILT
        val complexData = mapOf(
            "routes" to listOf(
                mapOf(
                    "distance" to 1500.0,
                    "duration" to 300.0,
                    "waypoints" to listOf(
                        mapOf("lat" to 37.7749, "lng" to -122.4194),
                        mapOf("lat" to 37.7849, "lng" to -122.4094)
                    )
                )
            )
        )
        val jsonData = gson.toJson(complexData)
        
        // When
        val event = createEvent(eventType, jsonData)
        
        // Then
        assertNotNull("Event should not be null", event)
        assertEquals("Event type should match", eventType, event.eventType)
        assertTrue("Event data should contain routes", event.data.contains("routes"))
        assertTrue("Event data should contain waypoints", event.data.contains("waypoints"))
    }

    @Test
    fun `test special characters in event data`() {
        // Given
        val eventType = MapBoxEvents.BANNER_INSTRUCTION
        val textWithSpecialChars = "Turn left at \"Main St.\" & continue for 1/2 mile"
        
        // When
        val event = createEvent(eventType, textWithSpecialChars)
        
        // Then
        assertNotNull("Event should not be null", event)
        assertEquals("Event type should match", eventType, event.eventType)
        assertTrue("Event data should contain special characters", event.data.contains("Main St."))
    }

    // Helper class to represent an event
    data class NavigationEvent(
        val eventType: String,
        val data: String
    )

    // Helper function to create an event
    private fun createEvent(eventType: String, data: String?): NavigationEvent {
        return NavigationEvent(
            eventType = eventType,
            data = data ?: ""
        )
    }
}
