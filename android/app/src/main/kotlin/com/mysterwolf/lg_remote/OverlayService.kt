package com.mysterwolf.lg_remote

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.IBinder
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

/**
 * Foreground service hosting the floating remote — a small cluster of plain
 * native Views added straight to the WindowManager (TYPE_APPLICATION_OVERLAY).
 * No card/panel background — only the individual buttons are drawn, so the
 * controls read as free-floating rather than a boxed widget. No second
 * Flutter engine: button taps go out via [OverlayBridge], status comes back
 * in via [updateStatus].
 */
class OverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "dpad_pilot_overlay"
        private const val NOTIF_ID = 4201

        @Volatile private var isShowing = false
        private var statusDot: View? = null
        private var pendingStatus: String = "disconnected"

        fun start(context: Context) {
            if (isShowing) return
            context.startForegroundService(Intent(context, OverlayService::class.java))
        }

        fun stop(context: Context) {
            if (!isShowing) return
            context.stopService(Intent(context, OverlayService::class.java))
        }

        fun updateStatus(status: String) {
            pendingStatus = status
            statusDot?.let { dot -> dot.post { applyStatusColor(dot, status) } }
        }

        private fun applyStatusColor(view: View, status: String) {
            val color = when (status) {
                "connected"  -> Color.parseColor("#69F0AE")
                "connecting" -> Color.parseColor("#FFC107")
                else         -> Color.parseColor("#FF5252")
            }
            (view.background as? GradientDrawable)?.setColor(color)
        }
    }

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private lateinit var layoutParams: WindowManager.LayoutParams

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        startForeground(NOTIF_ID, buildNotification())
        addOverlayView()
        isShowing = true
    }

    override fun onDestroy() {
        removeOverlayView()
        isShowing = false
        super.onDestroy()
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics
    ).toInt()

    // ── Notification (required for any Android 8+ foreground service) ────

    private fun buildNotification(): Notification {
        val channel = NotificationChannel(
            CHANNEL_ID, "Floating Remote", NotificationManager.IMPORTANCE_LOW
        ).apply { description = "Shown while the DPad Pilot remote is floating over other apps" }
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)

        val tapIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DPad Pilot")
            .setContentText("Remote is floating over other apps")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(tapIntent)
            .build()
    }

    private fun bringAppToForeground() {
        startActivity(Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        })
        stopSelf()
    }

    // ── Overlay view construction ─────────────────────────────────────

    private fun addOverlayView() {
        // No background/stroke here on purpose — only the buttons below
        // draw anything, so the cluster floats without a boxed panel.
        val cluster = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(6), dp(6), dp(6), dp(6))
            addView(buildHandleRow())
            addView(spacer(10))
            addView(buildDpad())
            addView(spacer(10))
            addView(buildVolumeRow())
            addView(spacer(10))
            addView(buildAppsRow())
        }

        layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16)
            y = dp(160)
        }

        windowManager.addView(cluster, layoutParams)
        overlayView = cluster
        statusDot?.let { applyStatusColor(it, pendingStatus) }
    }

    private fun removeOverlayView() {
        overlayView?.let {
            try { windowManager.removeView(it) } catch (_: Exception) { /* already gone */ }
        }
        overlayView = null
        statusDot = null
    }

    private fun spacer(sizeDp: Int): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(sizeDp))
    }

    // Drag handle + status dot + expand-to-app icon — all vector icons, no
    // background panel, so this row also just floats.
    private fun buildHandleRow(): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(28)
            )
        }

        val grip = ImageView(this).apply {
            setImageResource(R.drawable.ic_drag_handle)
            imageAlpha = 150
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
        }

        val dot = View(this).apply {
            val size = dp(10)
            layoutParams = FrameLayout.LayoutParams(size, size, Gravity.CENTER)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#FF5252"))
            }
        }
        statusDot = dot

        // Tappable to force a reconnect — wrapped in a bigger invisible touch
        // area since the visible dot itself is too small to reliably hit.
        val dotTapArea = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(28), dp(28)).apply { marginEnd = dp(4) }
            isClickable = true
            addView(dot)
            setOnClickListener { OverlayBridge.sendCommandToMain("RECONNECT") }
        }

        val expand = ImageView(this).apply {
            setImageResource(R.drawable.ic_expand)
            imageAlpha = 220
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            layoutParams = LinearLayout.LayoutParams(dp(22), dp(22))
            isClickable = true
            setOnClickListener { bringAppToForeground() }
        }

        // Only the grip is draggable — buttons elsewhere in the cluster must
        // keep working, so the touch interceptor is scoped tightly to it.
        var touchStartX = 0f
        var touchStartY = 0f
        var paramsStartX = 0
        var paramsStartY = 0
        grip.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    touchStartX = event.rawX
                    touchStartY = event.rawY
                    paramsStartX = layoutParams.x
                    paramsStartY = layoutParams.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    layoutParams.x = paramsStartX + (event.rawX - touchStartX).toInt()
                    layoutParams.y = paramsStartY + (event.rawY - touchStartY).toInt()
                    overlayView?.let { windowManager.updateViewLayout(it, layoutParams) }
                    true
                }
                else -> false
            }
        }

        row.addView(grip)
        row.addView(dotTapArea)
        row.addView(expand)
        return row
    }

    private fun makeIconButton(
        iconRes: Int,
        bg: String,
        action: String,
        sizeDp: Int = 48,
        iconPaddingDp: Int = 12,
    ): View = ImageView(this).apply {
        setImageResource(iconRes)
        scaleType = ImageView.ScaleType.FIT_CENTER
        setPadding(dp(iconPaddingDp), dp(iconPaddingDp), dp(iconPaddingDp), dp(iconPaddingDp))
        background = GradientDrawable().apply {
            setColor(Color.parseColor(bg))
            cornerRadius = dp(12).toFloat()
        }
        layoutParams = LinearLayout.LayoutParams(dp(sizeDp), dp(sizeDp)).apply { marginEnd = dp(8) }
        isClickable = true
        isFocusable = true
        setOnClickListener { OverlayBridge.sendCommandToMain(action) }
    }

    private fun makeTextButton(
        label: String,
        bg: String,
        action: String,
        widthDp: Int,
        heightDp: Int,
        textSizeSp: Float = 12f,
    ): View = TextView(this).apply {
        text = label
        setTextColor(Color.WHITE)
        gravity = Gravity.CENTER
        textSize = textSizeSp
        setTypeface(typeface, Typeface.BOLD)
        background = GradientDrawable().apply {
            setColor(Color.parseColor(bg))
            cornerRadius = dp(12).toFloat()
        }
        layoutParams = LinearLayout.LayoutParams(dp(widthDp), dp(heightDp)).apply { marginEnd = dp(8) }
        isClickable = true
        isFocusable = true
        setOnClickListener { OverlayBridge.sendCommandToMain(action) }
    }

    private fun row(vararg views: View): LinearLayout = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER
        views.forEach { addView(it) }
    }

    private fun blank(sizeDp: Int = 48): View =
        View(this).apply { layoutParams = LinearLayout.LayoutParams(dp(sizeDp), dp(sizeDp), 0f).apply { marginEnd = dp(8) } }

    private fun buildDpad(): View {
        val back  = makeIconButton(R.drawable.ic_back,        "#2A2A4A", "BACK")
        val up    = makeIconButton(R.drawable.ic_arrow_up,    "#1E1E3A", "UP")
        val left  = makeIconButton(R.drawable.ic_arrow_left,  "#1E1E3A", "LEFT")
        val ok    = makeTextButton("OK", "#4A148C", "ENTER", widthDp = 52, heightDp = 48, textSizeSp = 13f)
        val right = makeIconButton(R.drawable.ic_arrow_right, "#1E1E3A", "RIGHT")
        val down  = makeIconButton(R.drawable.ic_arrow_down,  "#1E1E3A", "DOWN")

        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            addView(row(back, up, blank()))
            addView(spacer(8))
            addView(row(left, ok, right))
            addView(spacer(8))
            addView(row(blank(), down, blank()))
        }
    }

    private fun buildVolumeRow(): View = row(
        makeTextButton("VOL−", "#0D2A5C", "VOL_DOWN", widthDp = 56, heightDp = 46, textSizeSp = 12f),
        makeTextButton("MUTE", "#2A0D4E", "MUTE",     widthDp = 52, heightDp = 46, textSizeSp = 11f),
        makeTextButton("VOL+", "#0D2A5C", "VOL_UP",   widthDp = 56, heightDp = 46, textSizeSp = 12f),
    )

    private fun buildAppsRow(): View = row(
        makeTextButton("D+", "#2A2A4A", "APP_DISNEY",  widthDp = 44, heightDp = 40, textSizeSp = 12f),
        makeTextButton("YT", "#2A2A4A", "APP_YOUTUBE", widthDp = 44, heightDp = 40, textSizeSp = 12f),
        makeTextButton("AP", "#2A2A4A", "APP_AMAZON",  widthDp = 44, heightDp = 40, textSizeSp = 12f),
        makeTextButton("NF", "#2A2A4A", "APP_NETFLIX", widthDp = 44, heightDp = 40, textSizeSp = 12f),
    )
}
