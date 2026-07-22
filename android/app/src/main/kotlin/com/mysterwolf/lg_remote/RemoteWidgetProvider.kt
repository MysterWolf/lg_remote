package com.mysterwolf.lg_remote

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen widget — same button set and command relay as OverlayService,
 * just rendered with RemoteViews (a separate launcher process) instead of
 * WindowManager-added native Views. Reuses OverlayBridge for taps and the
 * same "connected/connecting/disconnected" status vocabulary the overlay uses.
 */
class RemoteWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_WIDGET_COMMAND = "com.mysterwolf.lg_remote.WIDGET_ACTION"
        const val EXTRA_ACTION = "action"

        private var lastStatus: String? = null

        private val buttonActions = mapOf(
            R.id.widget_status_dot to "RECONNECT",
            R.id.btn_back to "BACK",
            R.id.btn_up to "UP",
            R.id.btn_down to "DOWN",
            R.id.btn_left to "LEFT",
            R.id.btn_right to "RIGHT",
            R.id.btn_ok to "ENTER",
            R.id.btn_vol_down to "VOL_DOWN",
            R.id.btn_vol_up to "VOL_UP",
            R.id.btn_mute to "MUTE",
            R.id.btn_app_disney to "APP_DISNEY",
            R.id.btn_app_youtube to "APP_YOUTUBE",
            R.id.btn_app_amazon to "APP_AMAZON",
            R.id.btn_app_netflix to "APP_NETFLIX",
        )

        fun updateStatus(context: Context, status: String) {
            if (status == lastStatus) return
            lastStatus = status
            pushToAllWidgets(context)
        }

        private fun pushToAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, RemoteWidgetProvider::class.java))
            for (id in ids) {
                manager.updateAppWidget(id, buildViews(context))
            }
        }

        private fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.remote_widget)

            val dotRes = when (lastStatus) {
                "connected"  -> R.drawable.dot_connected
                "connecting" -> R.drawable.dot_connecting
                else         -> R.drawable.dot_disconnected
            }
            views.setInt(R.id.widget_status_dot, "setBackgroundResource", dotRes)

            for ((viewId, action) in buttonActions) {
                val intent = Intent(context, WidgetActionReceiver::class.java).apply {
                    this.action = ACTION_WIDGET_COMMAND
                    putExtra(EXTRA_ACTION, action)
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context, action.hashCode(), intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(viewId, pendingIntent)
            }

            val openAppIntent = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_header, openAppIntent)

            return views
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }
}
