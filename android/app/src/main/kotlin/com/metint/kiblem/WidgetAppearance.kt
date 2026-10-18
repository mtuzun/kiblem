package com.metint.kiblem

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews

data class WidgetStyle(
    val transparent: Boolean = false,
    val background: Int = 0xFF3E8E7E.toInt(),
    val foreground: Int = Color.WHITE,
    val customized: Boolean = false,
)

object WidgetAppearance {
    private const val STORE = "widget_appearance"

    fun load(context: Context, widgetId: Int): WidgetStyle {
        val prefs = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
        val defaults = WidgetStyle()
        return WidgetStyle(
            prefs.getBoolean("$widgetId.transparent", false),
            prefs.getInt("$widgetId.background", defaults.background),
            prefs.getInt("$widgetId.foreground", defaults.foreground),
            prefs.getBoolean("$widgetId.customized", false),
        )
    }

    fun save(context: Context, widgetId: Int, style: WidgetStyle) {
        context.getSharedPreferences(STORE, Context.MODE_PRIVATE).edit()
            .putBoolean("$widgetId.transparent", style.transparent)
            .putInt("$widgetId.background", style.background)
            .putInt("$widgetId.foreground", style.foreground)
            .putBoolean("$widgetId.customized", style.customized)
            .apply()
    }

    fun remove(context: Context, widgetIds: IntArray) {
        val editor = context.getSharedPreferences(STORE, Context.MODE_PRIVATE).edit()
        widgetIds.forEach { id ->
            listOf("transparent", "background", "foreground", "customized").forEach {
                editor.remove("$id.$it")
            }
        }
        editor.apply()
    }

    fun apply(context: Context, widgetId: Int, views: RemoteViews, textIds: IntArray, english: Boolean) {
        val style = load(context, widgetId)
        views.setViewVisibility(R.id.widget_background_image, if (style.transparent) View.GONE else View.VISIBLE)
        views.setInt(R.id.widget_background_image, "setColorFilter", style.background)
        // Launchers usually reapply actions to existing views. Explicitly restore
        // default colors too, otherwise a previous custom color survives reset.
        textIds.forEach { id ->
            val color = if (style.customized) style.foreground else when (id) {
                R.id.widget_label, R.id.widget_full_label -> 0xD9FFFFFF.toInt()
                R.id.widget_countdown, R.id.widget_full_date, R.id.widget_full_weather, R.id.widget_full_clock,
                R.id.widget_full_chronometer, R.id.widget_full_countdown_fallback -> Color.WHITE
                else -> null // Prayer slot defaults are set by the full provider.
            }
            if (color != null) views.setTextColor(id, color)
        }
        views.setInt(R.id.widget_settings_button, "setColorFilter", style.foreground)
        views.setContentDescription(R.id.widget_settings_button, if (english) "Widget appearance settings" else "Widget görünüm ayarları")
        val intent = Intent(context, WidgetSettingsActivity::class.java)
            .setData(Uri.parse("kiblem://widget-settings/$widgetId"))
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        views.setOnClickPendingIntent(R.id.widget_settings_button, PendingIntent.getActivity(
            context, widgetId, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        ))
    }

    fun refresh(context: Context, widgetId: Int) {
        val info = AppWidgetManager.getInstance(context).getAppWidgetInfo(widgetId) ?: return
        if (info.provider.packageName != context.packageName) return
        context.sendBroadcast(Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
            .setComponent(info.provider)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId)))
    }
}
