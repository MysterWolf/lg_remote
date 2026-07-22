package com.mysterwolf.lg_remote

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fired by the widget's button PendingIntents; relays straight into the main isolate. */
class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != RemoteWidgetProvider.ACTION_WIDGET_COMMAND) return
        val action = intent.getStringExtra(RemoteWidgetProvider.EXTRA_ACTION) ?: return

        if (!OverlayBridge.isEngineAlive()) {
            // The app process died without a chance to push a final status —
            // the widget's dot would otherwise stay frozen on whatever it
            // last showed. Self-correct now that we know for certain.
            RemoteWidgetProvider.updateStatus(context, "disconnected")
            return
        }
        OverlayBridge.sendCommandToMain(action)
    }
}
