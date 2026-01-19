package com.eopeter.fluttermapboxnavigation.utilities

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.mapbox.geojson.Point
import com.mapbox.search.ResponseInfo
import com.mapbox.search.ReverseGeoOptions
import com.mapbox.search.SearchEngine
import com.mapbox.search.SearchEngineSettings
import com.mapbox.search.result.SearchResult
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/**
 * 位置辅助类 - 处理位置权限、位置获取和反向地理编码
 * 
 * 注意：此实现使用 Android 原生 LocationManager 而不是 Google Play Services，
 * 以避免对 Google Services 的依赖。
 */
class LocationHelper(private val context: Context) {

    companion object {
        const val LOCATION_PERMISSION_REQUEST_CODE = 1001
        private const val DEFAULT_LOCATION_NAME = "当前位置"
        private const val LOCATION_TIMEOUT_MS = 10000L // 10秒超时
    }

    private val locationManager: LocationManager by lazy {
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
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
     * 使用 Android 原生 LocationManager 而不是 Google Play Services
     * @return Point对象，如果获取失败返回null
     */
    suspend fun getCurrentLocation(): Point? = withTimeoutOrNull(LOCATION_TIMEOUT_MS) {
        suspendCancellableCoroutine { continuation ->
            if (!hasLocationPermission()) {
                continuation.resume(null)
                return@suspendCancellableCoroutine
            }

            try {
                // 首先尝试获取最后已知位置
                val lastKnownLocation = getLastKnownLocation()
                if (lastKnownLocation != null) {
                    android.util.Log.d("LocationHelper", "使用最后已知位置: ${lastKnownLocation.latitude()}, ${lastKnownLocation.longitude()}")
                    continuation.resume(lastKnownLocation)
                    return@suspendCancellableCoroutine
                }

                // 如果没有最后已知位置，请求单次位置更新
                val providers = locationManager.getProviders(true)
                if (providers.isEmpty()) {
                    android.util.Log.w("LocationHelper", "没有可用的位置提供者")
                    continuation.resume(null)
                    return@suspendCancellableCoroutine
                }

                // 优先使用 GPS，其次是网络定位
                val provider = when {
                    providers.contains(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
                    providers.contains(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
                    else -> providers.first()
                }

                android.util.Log.d("LocationHelper", "使用位置提供者: $provider")

                val locationListener = object : android.location.LocationListener {
                    override fun onLocationChanged(location: Location) {
                        android.util.Log.d("LocationHelper", "收到位置更新: ${location.latitude}, ${location.longitude}")
                        locationManager.removeUpdates(this)
                        val point = Point.fromLngLat(location.longitude, location.latitude)
                        continuation.resume(point)
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {
                        android.util.Log.w("LocationHelper", "位置提供者被禁用: $provider")
                    }
                }

                // 设置取消回调
                continuation.invokeOnCancellation {
                    locationManager.removeUpdates(locationListener)
                }

                // 请求单次位置更新
                locationManager.requestSingleUpdate(
                    provider,
                    locationListener,
                    android.os.Looper.getMainLooper()
                )

            } catch (e: SecurityException) {
                android.util.Log.e("LocationHelper", "位置权限被拒绝", e)
                continuation.resume(null)
            } catch (e: Exception) {
                android.util.Log.e("LocationHelper", "获取位置失败", e)
                continuation.resume(null)
            }
        }
    }

    /**
     * 获取最后已知位置
     * @return Point对象，如果没有最后已知位置返回null
     */
    private fun getLastKnownLocation(): Point? {
        if (!hasLocationPermission()) {
            return null
        }

        try {
            val providers = locationManager.getProviders(true)
            var bestLocation: Location? = null

            for (provider in providers) {
                val location = locationManager.getLastKnownLocation(provider) ?: continue
                
                if (bestLocation == null || location.accuracy < bestLocation.accuracy) {
                    bestLocation = location
                }
            }

            return bestLocation?.let {
                Point.fromLngLat(it.longitude, it.latitude)
            }
        } catch (e: SecurityException) {
            android.util.Log.e("LocationHelper", "获取最后已知位置失败：权限被拒绝", e)
            return null
        } catch (e: Exception) {
            android.util.Log.e("LocationHelper", "获取最后已知位置失败", e)
            return null
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
