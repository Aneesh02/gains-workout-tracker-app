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
            updateWidget(context, appWidgetManager, widgetId)
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
        views.setTextViewText(R.id.widget_streak_number, streak.toString())
        views.setTextViewText(R.id.widget_weekly_label, "$weeklyCount / $weeklyTarget this week")
        views.setTextViewText(R.id.widget_volume, volume)
        views.setOnClickPendingIntent(R.id.widget_root_layout, buildPendingIntent(context))

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun buildPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("gains://open/metrics")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, 0, intent,
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
            updateWidget(context, appWidgetManager, widgetId)
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
        views.setOnClickPendingIntent(R.id.widget_small_root, buildPendingIntent(context))

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun buildPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("gains://open/metrics")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, 1, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
