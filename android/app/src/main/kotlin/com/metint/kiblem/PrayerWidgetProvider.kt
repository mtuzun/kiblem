package com.metint.kiblem

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class PrayerWidgetProvider : HomeWidgetProvider() {
    private val refreshAction = "com.metint.kiblem.REFRESH_PRAYER_WIDGET"

    private fun refreshIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, PrayerWidgetProvider::class.java).setAction(refreshAction),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == refreshAction) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java))
            if (ids.isNotEmpty()) onUpdate(context, manager, ids)
        } else {
            super.onReceive(context, intent)
        }
    }

    override fun onDisabled(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(refreshIntent(context))
        super.onDisabled(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = System.currentTimeMillis()
        val timeline = runCatching {
            widgetData.getString("widget_prayer_timeline", null)?.let { JSONArray(it) }
        }.getOrNull()
        val nextPrayer = timeline?.let { entries ->
            (0 until entries.length()).asSequence()
                .map { entries.getJSONObject(it) }
                .firstOrNull { it.optLong("timestamp") > now }
        }
        appWidgetIds.forEach { widgetId ->
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            // Launcher dimensions are in dp, regardless of screen pixel density.
            val compact = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 40) < 64 ||
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110) < 240
            val layout = if (compact) R.layout.prayer_widget_compact_layout else R.layout.prayer_widget_layout
            val views = RemoteViews(context.packageName, layout).apply {
                val prayerName = nextPrayer?.optString("name")
                    ?: if (timeline != null) "--" else widgetData.getString("widget_prayer_name", null) ?: "--"
                val english = widgetData.getString("widget_language", "tr") == "en"
                if (!compact) {
                    val label = if (english) "Time until $prayerName" else "$prayerName için kalan süre"
                    setTextViewText(R.id.widget_label, label)
                }

                val prayerTimestamp = nextPrayer?.optLong("timestamp")
                    ?: if (timeline != null) null else widgetData.getString("widget_prayer_timestamp", null)?.toLongOrNull()
                val remainingMillis = (prayerTimestamp ?: 0L) - now
                val remainingText = if (remainingMillis > 0) {
                    val totalMinutes = (remainingMillis + 59_999) / 60_000
                    val hours = totalMinutes / 60
                    val minutes = totalMinutes % 60
                    val hourLabel = if (english) "h" else "sa"
                    val minuteLabel = if (english) "min" else "dk"
                    when {
                        hours == 0L -> "$minutes $minuteLabel"
                        minutes == 0L -> "$hours $hourLabel"
                        else -> "$hours $hourLabel $minutes $minuteLabel"
                    }
                } else {
                    "--"
                }
                setTextViewText(
                    R.id.widget_countdown,
                    if (compact) "$prayerName · $remainingText" else remainingText,
                )

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
        if (appWidgetIds.isNotEmpty()) {
            val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val nextMinute = now - now % 60_000 + 60_000
            // Non-wakeup alarms avoid waking the phone just to refresh widget text.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()) {
                try {
                    alarms.setExact(AlarmManager.RTC, nextMinute, refreshIntent(context))
                } catch (_: SecurityException) {
                    alarms.set(AlarmManager.RTC, nextMinute, refreshIntent(context))
                }
            } else {
                alarms.set(AlarmManager.RTC, nextMinute, refreshIntent(context))
            }
        }
    }
}
