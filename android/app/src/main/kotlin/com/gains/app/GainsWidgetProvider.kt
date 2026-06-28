package com.gains.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class GainsWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, widgetId)
            } catch (_: Exception) {}
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val streak = prefs.getInt("gains.streak", 0)
        val weeklyCount = prefs.getInt("gains.weeklyCount", 0)
        val weeklyTarget = prefs.getInt("gains.weeklyTarget", 4)
        val volume = prefs.getString("gains.weeklyVolume", "—") ?: "—"

        val views = RemoteViews(context.packageName, R.layout.gains_widget)

        // Header
        val streakText = if (streak == 1) "1 wk streak" else "$streak wk streak"
        views.setTextViewText(R.id.widget_streak_label, streakText)

        // Footer
        views.setTextViewText(R.id.widget_weekly_label, "$weeklyCount / $weeklyTarget this week")
        views.setTextViewText(R.id.widget_volume, volume)

        // 7-day grid: each day stored as "<state>|<detail>" where
        // state: 1=trained(orange), 2=today not trained(blue), 0=past rest(gray), 3=future(dim)
        // Format: "<state>|<muscles>|<duration>"
        // muscles = newline-separated list shown inside the box
        // duration = shown below the box
        val boxIds = intArrayOf(
            R.id.day_0_box, R.id.day_1_box, R.id.day_2_box, R.id.day_3_box,
            R.id.day_4_box, R.id.day_5_box, R.id.day_6_box
        )
        val detailIds = intArrayOf(
            R.id.day_0_detail, R.id.day_1_detail, R.id.day_2_detail, R.id.day_3_detail,
            R.id.day_4_detail, R.id.day_5_detail, R.id.day_6_detail
        )

        for (i in 0..6) {
            val raw = prefs.getString("gains.day$i", "3||") ?: "3||"
            val parts = raw.split("|", limit = 3)
            val state   = parts.getOrElse(0) { "3" }.trim()
            val muscles = parts.getOrElse(1) { "" }.trim().replace("\\n", "\n")
            val dur     = parts.getOrElse(2) { "" }.trim()

            val bgRes = when (state) {
                "1" -> R.drawable.widget_day_done
                "2" -> R.drawable.widget_day_today
                "0" -> R.drawable.widget_day_rest
                else -> R.drawable.widget_day_future
            }
            views.setInt(boxIds[i], "setBackgroundResource", bgRes)
            views.setTextViewText(boxIds[i], muscles)
            views.setTextViewText(detailIds[i], dur)
        }

        views.setOnClickPendingIntent(R.id.widget_root_layout, buildPendingIntent(context, 0))
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun buildPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("gains://open/metrics")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}

class GainsWidgetSmallProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, widgetId)
            } catch (_: Exception) {}
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val streak = prefs.getInt("gains.streak", 0)
        val weeklyCount = prefs.getInt("gains.weeklyCount", 0)
        val weeklyTarget = prefs.getInt("gains.weeklyTarget", 4)

        val views = RemoteViews(context.packageName, R.layout.gains_widget_small)
        views.setTextViewText(R.id.widget_small_streak, streak.toString())
        views.setTextViewText(R.id.widget_small_weekly, "$weeklyCount/$weeklyTarget")
        views.setOnClickPendingIntent(R.id.widget_small_root, buildPendingIntent(context, 1))

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun buildPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("gains://open/metrics")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
