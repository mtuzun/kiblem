package com.metint.kiblem

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.prayer_widget_layout).apply {
                val city = widgetData.getString("widget_city", null) ?: "Namaz Vakti"
                val prayerName = widgetData.getString("widget_prayer_name", null) ?: "--"
                val prayerTime = widgetData.getString("widget_prayer_time", null) ?: "--:--"

                setTextViewText(R.id.widget_label, "SONRAKİ VAKİT • ${city.uppercase()}")
                setTextViewText(R.id.widget_prayer_name, prayerName)
                setTextViewText(R.id.widget_prayer_time, prayerTime)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
