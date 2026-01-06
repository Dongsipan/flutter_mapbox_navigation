package com.eopeter.fluttermapboxnavigation.utilities

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.mapbox.geojson.Point
import com.mapbox.search.ResponseInfo
import com.mapbox.search.ReverseGeoOptions
import com.mapbox.search.SearchEngine
import com.mapbox.search.SearchEngineSettings
import com.mapbox.search.result.SearchResult
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * 位置辅助类 - 处理位置权限、位置获取和反向地理编码
 */
class LocationHelper(private val context: Context) {

    companion object {
        const val LOCATION_PERMISSION_REQUEST_CODE = 1001
        private const val DEFAULT_LOCATION_NAME = "当前位置"
    }

    private val fusedLocationClient: FusedLocationProviderClient by lazy {
        LocationServices.getFusedLocationProviderClient(context)
    }

    private val searchEngine: SearchEngine by lazy {
        SearchEngine.createSearchEngineWithBuiltInDataProviders(
            SearchEngineSettings()
        )
    }

    /**
     * 检查是否已授予位置权限
     */
    fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 请求位置权限
     */
    fun requestLocationPermission(activity: Activity) {
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            LOCATION_PERMISSION_REQUEST_CODE
        )
    }

    /**
     * 获取当前位置
     * @return Point对象，如果获取失败返回null
     */
    suspend fun getCurrentLocation(): Point? = suspendCancellableCoroutine { continuation ->
        if (!hasLocationPermission()) {
            continuation.resume(null)
            return@suspendCancellableCoroutine
        }

        try {
            val cancellationTokenSource = CancellationTokenSource()

            // 设置取消回调
            continuation.invokeOnCancellation {
                cancellationTokenSource.cancel()
            }

            fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_HIGH_ACCURACY,
                cancellationTokenSource.token
            ).addOnSuccessListener { location: Location? ->
                if (location != null) {
                    val point = Point.fromLngLat(location.longitude, location.latitude)
                    continuation.resume(point)
                } else {
                    continuation.resume(null)
                }
            }.addOnFailureListener {
                continuation.resume(null)
            }
        } catch (e: SecurityException) {
            continuation.resume(null)
        }
    }

    /**
     * 反向地理编码 - 根据坐标获取位置名称
     * @param point 地理坐标
     * @return 位置名称，如果失败返回默认名称"当前位置"
     */
    suspend fun reverseGeocode(point: Point): String = suspendCancellableCoroutine { continuation ->
        try {
            val options = ReverseGeoOptions(
                center = point,
                limit = 1
            )

            val task = searchEngine.search(options, object : com.mapbox.search.SearchCallback {
                override fun onResults(results: List<SearchResult>, responseInfo: ResponseInfo) {
                    if (results.isNotEmpty()) {
                        val result = results.first()
                        // 优先使用地点名称，然后是地址
                        val locationName = result.name.ifEmpty {
                            result.address?.formattedAddress() ?: DEFAULT_LOCATION_NAME
                        }
                        continuation.resume(locationName)
                    } else {
                        continuation.resume(DEFAULT_LOCATION_NAME)
                    }
                }

                override fun onError(e: Exception) {
                    // 反向地理编码失败时使用默认名称
                    continuation.resume(DEFAULT_LOCATION_NAME)
                }
            })

            // 设置取消回调
            continuation.invokeOnCancellation {
                task.cancel()
            }
        } catch (e: Exception) {
            continuation.resume(DEFAULT_LOCATION_NAME)
        }
    }
}
