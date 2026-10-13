package com.metint.kiblem

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Geniş namaz vakitleri widget'ı: canlı geri sayım, miladi/hicri tarih ve günün 6 vakti.
 * Küçük widget'tan (PrayerWidgetProvider) ayrı bir sağlayıcıdır; kullanıcı ikisinden
 * birini ya da ikisini de ana ekrana ekleyebilir.
 */
class PrayerWidgetFullProvider : HomeWidgetProvider() {
    private val refreshAction = "com.metint.kiblem.REFRESH_PRAYER_WIDGET_FULL"

    private fun refreshIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, PrayerWidgetFullProvider::class.java).setAction(refreshAction),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == refreshAction) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PrayerWidgetFullProvider::class.java))
            if (ids.isNotEmpty()) onUpdate(context, manager, ids)
        } else {
            super.onReceive(context, intent)
        }
    }

    override fun onDisabled(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(refreshIntent(context))
        super.onDisabled(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        WidgetAppearance.remove(context, appWidgetIds)
        super.onDeleted(context, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager,
                                         appWidgetId: Int, newOptions: Bundle) {
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
        val english = widgetData.getString("widget_language", "tr") == "en"
        // "widget_prayer_timeline" holds the next 7 days of prayers and keeps working even if
        // the app hasn't run since the single "widget_prayer_name"/"widget_prayer_timestamp"
        // snapshot expired (otherwise the countdown freezes and shows the "--:--:--" fallback).
        val timeline = runCatching {
            widgetData.getString("widget_prayer_timeline", null)?.let { JSONArray(it) }
        }.getOrNull()
        val nextFromTimeline = timeline?.let { entries ->
            (0 until entries.length()).asSequence()
                .map { entries.getJSONObject(it) }
                .firstOrNull { it.optLong("timestamp") > now }
        }
        val prayerName = nextFromTimeline?.optString("name")
            ?: widgetData.getString("widget_prayer_name", null) ?: "--"
        val prayerTimestamp = nextFromTimeline?.optLong("timestamp")?.takeIf { it > 0 }
            ?: widgetData.getString("widget_prayer_timestamp", null)?.toLongOrNull()
        val activeIndex = widgetData.getInt("widget_active_index", -1)
        val todayPrayers = runCatching {
            widgetData.getString("widget_today_prayers", null)?.let { JSONArray(it) }
        }.getOrNull()
        val dateGregorian = widgetData.getString("widget_date_gregorian", "") ?: ""
        val dateHijri = widgetData.getString("widget_date_hijri", "") ?: ""

        appWidgetIds.forEach { widgetId ->
            val sizing = WidgetSizing(context, appWidgetManager.getAppWidgetOptions(widgetId))
            val layout = if (sizing.narrow) R.layout.prayer_widget_full_narrow_layout else R.layout.prayer_widget_full_layout
            val label = if (sizing.height < 100 * context.resources.configuration.fontScale) prayerName
                else if (english) "Time until $prayerName" else "$prayerName vaktine kalan süre"
            val views = RemoteViews(context.packageName, layout).apply {
                setTextViewText(
                    R.id.widget_full_label,
                    label,
                )
                setTextViewText(R.id.widget_full_date, "$dateGregorian   $dateHijri".trim())

                val remainingMillis = (prayerTimestamp ?: 0L) - now
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && remainingMillis > 0) {
                    setViewVisibility(R.id.widget_full_chronometer, android.view.View.VISIBLE)
                    setViewVisibility(R.id.widget_full_countdown_fallback, android.view.View.GONE)
                    val base = SystemClock.elapsedRealtime() + remainingMillis
                    setChronometer(R.id.widget_full_chronometer, base, null, true)
                    setChronometerCountDown(R.id.widget_full_chronometer, true)
                } else {
                    setViewVisibility(R.id.widget_full_chronometer, android.view.View.GONE)
                    setViewVisibility(R.id.widget_full_countdown_fallback, android.view.View.VISIBLE)
                    setTextViewText(R.id.widget_full_countdown_fallback, formatRemaining(remainingMillis, english))
                }

                val slotIds = intArrayOf(
                    R.id.widget_slot_0, R.id.widget_slot_1, R.id.widget_slot_2,
                    R.id.widget_slot_3, R.id.widget_slot_4, R.id.widget_slot_5,
                )
                val nameIds = intArrayOf(
                    R.id.widget_slot_name_0, R.id.widget_slot_name_1, R.id.widget_slot_name_2,
                    R.id.widget_slot_name_3, R.id.widget_slot_name_4, R.id.widget_slot_name_5,
                )
                val timeIds = intArrayOf(
                    R.id.widget_slot_time_0, R.id.widget_slot_time_1, R.id.widget_slot_time_2,
                    R.id.widget_slot_time_3, R.id.widget_slot_time_4, R.id.widget_slot_time_5,
                )
                for (i in 0 until 6) {
                    val entry = todayPrayers?.optJSONObject(i)
                    setTextViewText(nameIds[i], entry?.optString("name") ?: "--")
                    setTextViewText(timeIds[i], entry?.optString("time") ?: "--:--")
                    val active = i == activeIndex
                    setInt(slotIds[i], "setBackgroundResource", if (active) R.drawable.widget_slot_active else R.drawable.widget_slot_inactive)
                    val nameColor = if (active) Color.WHITE else Color.parseColor("#4B5563")
                    val timeColor = if (active) Color.WHITE else Color.parseColor("#111827")
                    setTextColor(nameIds[i], nameColor)
                    setTextColor(timeIds[i], timeColor)
                }

                sizing.applyFull(this, nameIds, timeIds,
                    (0 until 6).map { todayPrayers?.optJSONObject(it)?.optString("name") ?: "--" },
                    (0 until 6).map { todayPrayers?.optJSONObject(it)?.optString("time") ?: "--:--" },
                    label,
                    "$dateGregorian   $dateHijri".trim())

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_full_container, pendingIntent)
                WidgetAppearance.apply(context, widgetId, this, nameIds + timeIds + intArrayOf(
                    R.id.widget_full_label, R.id.widget_full_date, R.id.widget_full_chronometer,
                    R.id.widget_full_countdown_fallback,
                ), english)
                val style = WidgetAppearance.load(context, widgetId)
                setInt(R.id.widget_full_date, "setBackgroundResource", R.drawable.widget_date_chip)
                if (style.customized || style.transparent) {
                    setInt(R.id.widget_full_date, "setBackgroundColor", Color.TRANSPARENT)
                    slotIds.forEachIndexed { index, slotId ->
                        val highlight = if (index == activeIndex)
                            (style.foreground and 0x00FFFFFF) or 0x30000000 else Color.TRANSPARENT
                        setInt(slotId, "setBackgroundColor", highlight)
                    }
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        if (appWidgetIds.isNotEmpty()) {
            val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val nextMinute = now - now % 60_000 + 60_000
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

    /** API 24 altı cihazlar için: Chronometer kullanılamadığında statik "sa dk" metni. */
    private fun formatRemaining(remainingMillis: Long, english: Boolean): String {
        if (remainingMillis <= 0) return "--:--:--"
        val totalSeconds = remainingMillis / 1000
        val h = totalSeconds / 3600
        val m = (totalSeconds % 3600) / 60
        val s = totalSeconds % 60
        return "%02d:%02d:%02d".format(h, m, s)
    }
}
