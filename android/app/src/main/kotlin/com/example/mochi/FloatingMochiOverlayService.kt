package com.example.mochi

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.FlutterInjector
import kotlin.math.abs

class FloatingMochiOverlayService : Service() {
    companion object {
        const val actionStart = "com.example.mochi.action.START_FLOATING_MOCHI"
        const val actionStop = "com.example.mochi.action.STOP_FLOATING_MOCHI"

        private const val notificationChannelId = "floating_mochi_overlay"
        private const val notificationId = 4403

        @JvmStatic
        var isRunning: Boolean = false
            private set
    }

    private val touchSlop by lazy { ViewConfiguration.get(this).scaledTouchSlop }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var overlayLayoutParams: WindowManager.LayoutParams? = null
    private var positionX = 0f
    private var positionY = 0f
    private var touchStartX = 0f
    private var touchStartY = 0f
    private var bubbleStartX = 0f
    private var bubbleStartY = 0f
    private var dragDistanceX = 0f
    private var dragDistanceY = 0f
    private var isDragging = false

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == actionStop) {
            stopSelf()
            return START_NOT_STICKY
        }

        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(notificationId, notification)
        }

        if (!canDrawOverlays()) {
            stopSelf()
            return START_NOT_STICKY
        }
        showOverlayIfNeeded()
        isRunning = true
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        removeOverlayIfNeeded()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        isRunning = false
        super.onDestroy()
    }

    private fun showOverlayIfNeeded() {
        if (overlayView != null) {
            return
        }

        val bubbleSize = dp(88)
        val layoutParams = WindowManager.LayoutParams(
            bubbleSize,
            bubbleSize,
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(24)
            y = dp(180)
        }

        positionX = layoutParams.x.toFloat()
        positionY = layoutParams.y.toFloat()
        overlayLayoutParams = layoutParams

        val bubbleView = buildBubbleView()
        overlayView = bubbleView
        val added = runCatching {
            windowManager?.addView(bubbleView, layoutParams)
        }.isSuccess
        if (!added) {
            stopSelf()
            return
        }
        bubbleView.post {
            clampPositionToBounds()
            applyPosition()
        }
    }

    private fun removeOverlayIfNeeded() {
        overlayView?.let { view ->
            runCatching {
                windowManager?.removeView(view)
            }
        }
        overlayView = null
        overlayLayoutParams = null
    }

    private fun buildBubbleView(): View {
        val card = FrameLayout(this).apply {
            alpha = 0.98f
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(28).toFloat()
                setColor(Color.WHITE)
                setStroke(dp(3), Color.parseColor("#28324E"))
            }
            elevation = dp(8).toFloat()
            setOnTouchListener(bubbleTouchListener())
        }

        val image = ImageView(this).apply {
            setPadding(dp(10), dp(10), dp(10), dp(10))
            scaleType = ImageView.ScaleType.FIT_CENTER
            setImageDrawable(loadMochiDrawable())
        }

        card.addView(
            image,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        return card
    }

    private fun bubbleTouchListener(): View.OnTouchListener {
        return View.OnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = false
                    touchStartX = event.rawX
                    touchStartY = event.rawY
                    bubbleStartX = positionX
                    bubbleStartY = positionY
                    dragDistanceX = 0f
                    dragDistanceY = 0f
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    dragDistanceX = event.rawX - touchStartX
                    dragDistanceY = event.rawY - touchStartY
                    if (!isDragging &&
                        (abs(dragDistanceX) > touchSlop || abs(dragDistanceY) > touchSlop)
                    ) {
                        isDragging = true
                    }

                    if (isDragging) {
                        positionX = bubbleStartX + dragDistanceX
                        positionY = bubbleStartY + dragDistanceY
                        clampPositionToBounds()
                        applyPosition()
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        openApp()
                        stopSelf()
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    true
                }
                else -> false
            }
        }
    }

    private fun clampPositionToBounds() {
        positionX = positionX.coerceIn(dp(12).toFloat(), maxPositionX())
        positionY = positionY.coerceIn(dp(24).toFloat(), maxPositionY())
    }

    private fun applyPosition() {
        overlayLayoutParams?.let { layoutParams ->
            layoutParams.x = positionX.toInt()
            layoutParams.y = positionY.toInt()
            overlayView?.let { view ->
                runCatching {
                    windowManager?.updateViewLayout(view, layoutParams)
                }
            }
        }
    }

    private fun maxPositionX(): Float {
        val screenWidth = screenBounds().width()
        val bubbleWidth = overlayView?.width?.takeIf { it > 0 } ?: dp(88)
        return (screenWidth - bubbleWidth - dp(12)).coerceAtLeast(dp(12)).toFloat()
    }

    private fun maxPositionY(): Float {
        val screenHeight = screenBounds().height()
        val bubbleHeight = overlayView?.height?.takeIf { it > 0 } ?: dp(88)
        return (screenHeight - bubbleHeight - dp(48)).coerceAtLeast(dp(24)).toFloat()
    }

    private fun screenBounds(): Rect {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            windowManager?.currentWindowMetrics?.bounds ?: Rect(0, 0, dp(360), dp(640))
        } else {
            @Suppress("DEPRECATION")
            val display = windowManager?.defaultDisplay
            val metrics = resources.displayMetrics
            @Suppress("DEPRECATION")
            display?.getMetrics(metrics)
            Rect(0, 0, metrics.widthPixels, metrics.heightPixels)
        }
    }

    private fun overlayWindowType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
    }

    private fun canDrawOverlays(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
    }

    private fun buildNotification() = NotificationCompat.Builder(this, notificationChannelId)
        .setSmallIcon(android.R.drawable.star_on)
        .setContentTitle("Floating Mochi")
        .setContentText("Mochi is drifting above your other apps.")
        .setOngoing(true)
        .setSilent(true)
        .setContentIntent(openAppPendingIntent())
        .build()

    private fun openAppPendingIntent(): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(this, 0, appLaunchIntent(), flags)
    }

    private fun openApp() {
        startActivity(appLaunchIntent())
    }

    private fun appLaunchIntent(): Intent {
        return packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        } ?: Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            notificationChannelId,
            "Floating Mochi",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps Mochi visible while the app is in the background."
            setShowBadge(false)
        }
        notificationManager?.createNotificationChannel(channel)
    }

    private fun loadMochiDrawable() = try {
        val assetKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(
            "assets/mochi/png/mochi_normal.png",
        )
        assets.open(assetKey).use { stream ->
            BitmapFactory.decodeStream(stream)?.let { bitmap ->
                BitmapDrawable(resources, bitmap)
            } ?: ContextCompat.getDrawable(this, R.mipmap.mochi_icon)
        }
    } catch (_: Exception) {
        ContextCompat.getDrawable(this, R.mipmap.mochi_icon)
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}
