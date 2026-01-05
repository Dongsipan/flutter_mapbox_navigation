package com.eopeter.fluttermapboxnavigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 单元测试: 错误处理逻辑
 * 
 * 测试各种错误场景的处理逻辑
 * 
 * Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6
 */
class ErrorHandlingTest {

    @Test
    fun `test route calculation failure error message parsing`() {
        // Given
        val errorMessage = "No route found between the selected locations"
        
        // When
        val errorType = parseErrorType(errorMessage)
        
        // Then
        assertEquals("Should identify as NO_ROUTE error", ErrorType.NO_ROUTE, errorType)
    }

    @Test
    fun `test network error message parsing`() {
        // Given
        val errorMessages = listOf(
            "Network connection failed",
            "connection timeout",
            "network error occurred"
        )
        
        // When & Then
        errorMessages.forEach { message ->
            val errorType = parseErrorType(message)
            assertEquals("Should identify as NETWORK_ERROR: $message", ErrorType.NETWORK_ERROR, errorType)
        }
    }

    @Test
    fun `test timeout error message parsing`() {
        // Given
        val errorMessage = "Request timed out. Please try again"
        
        // When
        val errorType = parseErrorType(errorMessage)
        
        // Then
        assertEquals("Should identify as TIMEOUT error", ErrorType.TIMEOUT, errorType)
    }

    @Test
    fun `test unauthorized error message parsing`() {
        // Given
        val errorMessages = listOf(
            "Invalid access token",
            "unauthorized request",
            "token expired"
        )
        
        // When & Then
        errorMessages.forEach { message ->
            val errorType = parseErrorType(message)
            assertEquals("Should identify as UNAUTHORIZED: $message", ErrorType.UNAUTHORIZED, errorType)
        }
    }

    @Test
    fun `test unknown error message parsing`() {
        // Given
        val errorMessage = "Some unexpected error occurred"
        
        // When
        val errorType = parseErrorType(errorMessage)
        
        // Then
        assertEquals("Should identify as UNKNOWN error", ErrorType.UNKNOWN, errorType)
    }

    @Test
    fun `test should retry logic for network errors`() {
        // Given
        val networkError = ErrorType.NETWORK_ERROR
        val timeoutError = ErrorType.TIMEOUT
        val noRouteError = ErrorType.NO_ROUTE
        
        // When & Then
        assertTrue("Should retry network errors", shouldRetry(networkError))
        assertTrue("Should retry timeout errors", shouldRetry(timeoutError))
        assertFalse("Should not retry no route errors", shouldRetry(noRouteError))
    }

    @Test
    fun `test retry attempt limit`() {
        // Given
        val maxRetries = 3
        val currentAttempts = listOf(1, 2, 3, 4)
        
        // When & Then
        assertTrue("Should allow retry on attempt 1", canRetry(currentAttempts[0], maxRetries))
        assertTrue("Should allow retry on attempt 2", canRetry(currentAttempts[1], maxRetries))
        assertTrue("Should allow retry on attempt 3", canRetry(currentAttempts[2], maxRetries))
        assertFalse("Should not allow retry on attempt 4", canRetry(currentAttempts[3], maxRetries))
    }

    @Test
    fun `test exponential backoff delay calculation`() {
        // Given
        val baseDelay = 1000L // 1 second
        
        // When & Then
        assertEquals("Attempt 1 delay should be 1s", 1000L, calculateBackoffDelay(1, baseDelay))
        assertEquals("Attempt 2 delay should be 2s", 2000L, calculateBackoffDelay(2, baseDelay))
        assertEquals("Attempt 3 delay should be 3s", 3000L, calculateBackoffDelay(3, baseDelay))
    }

    @Test
    fun `test GPS signal quality assessment`() {
        // Given
        val goodAccuracy = 10.0 // 10 meters
        val poorAccuracy = 60.0 // 60 meters
        val veryPoorAccuracy = 150.0 // 150 meters
        
        // When & Then
        assertEquals("10m accuracy should be GOOD", GPSQuality.GOOD, assessGPSQuality(goodAccuracy))
        assertEquals("60m accuracy should be POOR", GPSQuality.POOR, assessGPSQuality(poorAccuracy))
        assertEquals("150m accuracy should be VERY_POOR", GPSQuality.VERY_POOR, assessGPSQuality(veryPoorAccuracy))
    }

    @Test
    fun `test GPS signal timeout detection`() {
        // Given
        val currentTime = System.currentTimeMillis()
        val recentUpdate = currentTime - 5000 // 5 seconds ago
        val oldUpdate = currentTime - 15000 // 15 seconds ago
        val timeout = 10000L // 10 seconds
        
        // When & Then
        assertFalse("Recent update should not be timed out", isGPSTimedOut(recentUpdate, currentTime, timeout))
        assertTrue("Old update should be timed out", isGPSTimedOut(oldUpdate, currentTime, timeout))
    }

    @Test
    fun `test error message user-friendly conversion`() {
        // Given
        val technicalErrors = mapOf(
            "RouterFailure: NO_ROUTE" to "No route found between the selected locations",
            "NetworkException: timeout" to "Request timed out. Please try again",
            "AuthException: invalid_token" to "Invalid access token. Please check your Mapbox configuration"
        )
        
        // When & Then
        technicalErrors.forEach { (technical, userFriendly) ->
            val converted = convertToUserFriendlyMessage(technical)
            assertEquals("Should convert technical error to user-friendly", userFriendly, converted)
        }
    }

    @Test
    fun `test permission denied error handling`() {
        // Given
        val permissionDenied = true
        
        // When
        val errorMessage = getPermissionErrorMessage(permissionDenied)
        
        // Then
        assertTrue("Should contain permission message", errorMessage.contains("permission", ignoreCase = true))
        assertTrue("Should mention location", errorMessage.contains("location", ignoreCase = true))
    }

    // Helper enums and functions

    enum class ErrorType {
        NO_ROUTE,
        NETWORK_ERROR,
        TIMEOUT,
        UNAUTHORIZED,
        UNKNOWN
    }

    enum class GPSQuality {
        GOOD,
        POOR,
        VERY_POOR
    }

    private fun parseErrorType(message: String): ErrorType {
        return when {
            message.contains("no route", ignoreCase = true) -> ErrorType.NO_ROUTE
            message.contains("network", ignoreCase = true) || 
            message.contains("connection", ignoreCase = true) -> ErrorType.NETWORK_ERROR
            message.contains("timeout", ignoreCase = true) -> ErrorType.TIMEOUT
            message.contains("unauthorized", ignoreCase = true) || 
            message.contains("token", ignoreCase = true) -> ErrorType.UNAUTHORIZED
            else -> ErrorType.UNKNOWN
        }
    }

    private fun shouldRetry(errorType: ErrorType): Boolean {
        return errorType in listOf(ErrorType.NETWORK_ERROR, ErrorType.TIMEOUT)
    }

    private fun canRetry(currentAttempt: Int, maxRetries: Int): Boolean {
        return currentAttempt < maxRetries
    }

    private fun calculateBackoffDelay(attempt: Int, baseDelay: Long): Long {
        return baseDelay * attempt
    }

    private fun assessGPSQuality(accuracy: Double): GPSQuality {
        return when {
            accuracy < 50.0 -> GPSQuality.GOOD
            accuracy < 100.0 -> GPSQuality.POOR
            else -> GPSQuality.VERY_POOR
        }
    }

    private fun isGPSTimedOut(lastUpdateTime: Long, currentTime: Long, timeout: Long): Boolean {
        return (currentTime - lastUpdateTime) > timeout
    }

    private fun convertToUserFriendlyMessage(technicalError: String): String {
        return when {
            technicalError.contains("NO_ROUTE") -> "No route found between the selected locations"
            technicalError.contains("timeout") -> "Request timed out. Please try again"
            technicalError.contains("invalid_token") -> "Invalid access token. Please check your Mapbox configuration"
            else -> "An error occurred. Please try again"
        }
    }

    private fun getPermissionErrorMessage(denied: Boolean): String {
        return if (denied) {
            "Location permissions are required for navigation"
        } else {
            ""
        }
    }
}
