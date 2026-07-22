package com.mysterwolf.lg_remote

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val bridgeChannelName = "dpadpilot/overlay_bridge"
    private var bridgeChannel: MethodChannel? = null

    // Only true while RemoteScreen is mounted (there's a live TV connection
    // worth showing). DiscoveryScreen leaves this false.
    private var overlayEnabled = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridgeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bridgeChannelName)
        OverlayBridge.mainChannel = bridgeChannel

        // A fresh engine attach means the process just (re)started — any
        // "connected" the widget/overlay might still be showing is leftover
        // from before the process died. Reset to the true baseline; a real
        // connection will push its own status once RemoteScreen connects.
        RemoteWidgetProvider.updateStatus(this, "disconnected")

        bridgeChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setOverlayEnabled" -> {
                    overlayEnabled = call.argument<Boolean>("enabled") ?: false
                    if (!overlayEnabled) OverlayService.stop(this)
                    result.success(null)
                }
                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                    )
                    result.success(null)
                }
                "updateStatus" -> {
                    val status = call.argument<String>("status") ?: "disconnected"
                    OverlayService.updateStatus(status)
                    RemoteWidgetProvider.updateStatus(this, status)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Fired when the user presses Home or switches away — show the floating
    // overlay instead of just backgrounding, so the remote stays reachable.
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (overlayEnabled && Settings.canDrawOverlays(this)) {
            OverlayService.start(this)
        }
    }

    // Returning to the app (including via the overlay's expand button)
    // always dismisses the overlay — no reason to show both at once.
    override fun onResume() {
        super.onResume()
        OverlayService.stop(this)
    }

    override fun onDestroy() {
        if (OverlayBridge.mainChannel === bridgeChannel) {
            OverlayBridge.mainChannel = null
        }
        super.onDestroy()
    }
}
