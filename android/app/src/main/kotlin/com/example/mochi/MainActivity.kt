package com.example.mochi

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.Display
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val channelName = "mochi/device_permissions"
        private const val preferencesName = "mochi_features"
        private const val floatingMochiEnabledKey = "floating_mochi_enabled"
        private const val mediaRequestCode = 4401
        private const val microphoneRequestCode = 4402
    }

    private val preferences by lazy {
        getSharedPreferences(preferencesName, MODE_PRIVATE)
    }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var isAppInForeground = true
    private val floatingMochiHandler = Handler(Looper.getMainLooper())
    private val startFloatingMochiRunnable = Runnable {
        if (!isAppInForeground && isFloatingMochiEnabled() && canDrawOverlays()) {
            startFloatingMochi()
        }
    }

    override fun onResume() {
        super.onResume()
        requestHighestRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler(::handleMethodCall)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            mediaRequestCode,
            microphoneRequestCode,
            -> {
                pendingPermissionResult?.success(buildPermissionSnapshot())
                pendingPermissionResult = null
            }
        }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPermissionSnapshot" -> result.success(buildPermissionSnapshot())
            "requestMediaUploadPermission" -> requestPermissions(
                permissions = mediaPermissions(),
                requestCode = mediaRequestCode,
                result = result,
            )
            "requestMicrophonePermission" -> requestPermissions(
                permissions = arrayOf(Manifest.permission.RECORD_AUDIO),
                requestCode = microphoneRequestCode,
                result = result,
            )
            "openBatteryOptimizationSettings" -> {
                openBatteryOptimizationSettings()
                result.success(null)
            }
            "openFloatingWindowSettings" -> {
                openFloatingWindowSettings()
                result.success(null)
            }
            "openAppSettings" -> {
                openAppSettings()
                result.success(null)
            }
            "getFloatingMochiState" -> result.success(buildFloatingMochiState())
            "setFloatingMochiEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setFloatingMochiEnabled(enabled)
                result.success(buildFloatingMochiState())
            }
            "syncFloatingMochiAppForegroundState" -> {
                val isForeground = call.argument<Boolean>("isForeground") ?: true
                syncFloatingMochiAppForegroundState(isForeground)
                result.success(buildFloatingMochiState())
            }
            else -> result.notImplemented()
        }
    }

    private fun requestPermissions(
        permissions: Array<String>,
        requestCode: Int,
        result: MethodChannel.Result,
    ) {
        if (pendingPermissionResult != null) {
            result.error(
                "permission_request_in_progress",
                "Another permission request is already in progress.",
                null,
            )
            return
        }

        val missingPermissions = permissions.filterNot(::hasPermission)
        if (missingPermissions.isEmpty()) {
            result.success(buildPermissionSnapshot())
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            missingPermissions.toTypedArray(),
            requestCode,
        )
    }

    private fun mediaPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
            )
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
    }

    private fun buildPermissionSnapshot(): Map<String, String> {
        return mapOf(
            "media" to mediaStatus(),
            "microphone" to permissionStatus(Manifest.permission.RECORD_AUDIO),
            "batteryOptimization" to batteryOptimizationStatus(),
            "floatingWindow" to floatingWindowStatus(),
        )
    }

    private fun buildFloatingMochiState(): Map<String, Any> {
        return mapOf(
            "enabled" to isFloatingMochiEnabled(),
            "running" to FloatingMochiOverlayService.isRunning,
            "overlayGranted" to canDrawOverlays(),
        )
    }

    private fun mediaStatus(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val imagesGranted = hasPermission(Manifest.permission.READ_MEDIA_IMAGES)
            val videosGranted = hasPermission(Manifest.permission.READ_MEDIA_VIDEO)
            val selectedVisualMediaGranted =
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
                    hasPermission(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)

            return when {
                imagesGranted && videosGranted -> "granted"
                imagesGranted || videosGranted || selectedVisualMediaGranted -> "partial"
                else -> "denied"
            }
        }

        return permissionStatus(Manifest.permission.READ_EXTERNAL_STORAGE)
    }

    private fun permissionStatus(permission: String): String {
        return if (hasPermission(permission)) "granted" else "denied"
    }

    private fun batteryOptimizationStatus(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return "granted"
        }

        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        return if (powerManager.isIgnoringBatteryOptimizations(packageName)) {
            "granted"
        } else {
            "denied"
        }
    }

    private fun floatingWindowStatus(): String {
        return if (canDrawOverlays()) "granted" else "denied"
    }

    private fun setFloatingMochiEnabled(enabled: Boolean) {
        preferences.edit().putBoolean(floatingMochiEnabledKey, enabled).apply()
        if (!enabled) {
            floatingMochiHandler.removeCallbacks(startFloatingMochiRunnable)
            stopFloatingMochi()
            return
        }

        if (!isAppInForeground && canDrawOverlays()) {
            scheduleFloatingMochiStart()
        }
    }

    private fun syncFloatingMochiAppForegroundState(isForeground: Boolean) {
        isAppInForeground = isForeground
        if (isForeground) {
            floatingMochiHandler.removeCallbacks(startFloatingMochiRunnable)
            stopFloatingMochi()
            return
        }

        if (isFloatingMochiEnabled() && canDrawOverlays()) {
            scheduleFloatingMochiStart()
        }
    }

    private fun isFloatingMochiEnabled(): Boolean {
        return preferences.getBoolean(floatingMochiEnabledKey, false)
    }

    private fun startFloatingMochi() {
        if (!canDrawOverlays()) {
            return
        }

        val intent = Intent(this, FloatingMochiOverlayService::class.java).apply {
            action = FloatingMochiOverlayService.actionStart
        }
        runCatching {
            ContextCompat.startForegroundService(this, intent)
        }
    }

    private fun scheduleFloatingMochiStart() {
        floatingMochiHandler.removeCallbacks(startFloatingMochiRunnable)
        floatingMochiHandler.postDelayed(startFloatingMochiRunnable, 450L)
    }

    private fun stopFloatingMochi() {
        stopService(
            Intent(this, FloatingMochiOverlayService::class.java).apply {
                action = FloatingMochiOverlayService.actionStop
            },
        )
    }

    private fun canDrawOverlays(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
    }

    private fun openBatteryOptimizationSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }

        val directIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }

        if (directIntent.resolveActivity(packageManager) != null) {
            startActivity(directIntent)
            return
        }

        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
    }

    private fun openFloatingWindowSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }

        val overlayIntent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
            data = Uri.parse("package:$packageName")
        }

        if (overlayIntent.resolveActivity(packageManager) != null) {
            startActivity(overlayIntent)
            return
        }

        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            },
        )
    }

    private fun openAppSettings() {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            },
        )
    }

    // Android loves picking a power-friendly 60Hz mode; ask for the fastest
    // one at the current resolution so Flutter vsync runs at 120Hz on capable
    // panels. Re-applied on resume because the system resets it sometimes.
    private fun requestHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }

        runCatching {
            @Suppress("DEPRECATION")
            val display: Display = windowManager.defaultDisplay ?: return
            val current = display.mode ?: return
            val bestMode = display.supportedModes
                .filter { mode ->
                    mode.physicalWidth == current.physicalWidth &&
                        mode.physicalHeight == current.physicalHeight &&
                        mode.refreshRate > current.refreshRate + 0.1f
                }
                .maxByOrNull { it.refreshRate } ?: return

            window.attributes = window.attributes.apply {
                preferredDisplayModeId = bestMode.modeId
            }
        }
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) ==
            PackageManager.PERMISSION_GRANTED
    }
}
