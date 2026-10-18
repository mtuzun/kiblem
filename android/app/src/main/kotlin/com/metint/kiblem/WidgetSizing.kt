package com.metint.kiblem

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews

/** Launcher sizes are dp; text also needs to account for the user's font scale. */
internal class WidgetSizing(context: Context, options: Bundle) {
    val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 300).coerceAtLeast(80)
    val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 160).coerceAtLeast(40)
    private val fontScale = context.resources.configuration.fontScale.coerceAtLeast(0.5f)
    private val density = context.resources.displayMetrics.density
    val narrow = width / fontScale < 320
    val compact = width / fontScale < 240 || height / fontScale < 64

    fun applyFull(views: RemoteViews, nameIds: IntArray, timeIds: IntArray,
                  names: List<String>, times: List<String>, label: String, date: String,
                  weather: String? = null) {
        val showLabel = true
        val showDate = height / fontScale >= if (narrow) 150 else 120
        views.setViewVisibility(R.id.widget_full_label, if (showLabel) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.widget_full_date, if (showDate) View.VISIBLE else View.GONE)
        val rows = if (narrow) 2 else 1
        // Limit typography by both available height and the actual measured strings.
        val nominalHeight = 24 + 38 + rows * 36 + (if (showLabel) 17 else 0) + (if (showDate) 26 else 0)
        val scale = minOf(1.2f, (height - 24f) / ((nominalHeight - 24) * fontScale)).coerceAtLeast(0.45f)
        fun text(id: Int, value: String, size: Float, availableWidth: Float) {
            val paint = Paint().apply {
                textSize = size * scale * fontScale
                typeface = when (id) {
                    R.id.widget_full_chronometer, R.id.widget_full_countdown_fallback ->
                        Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
                    in timeIds -> Typeface.DEFAULT_BOLD
                    else -> Typeface.DEFAULT
                }
            }
            val widthScale = minOf(1f, availableWidth / paint.measureText(value).coerceAtLeast(1f))
            views.setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, size * scale * widthScale)
        }
        text(R.id.widget_full_label, label, 13f, width - 56f)
        text(R.id.widget_full_date, date, 12f, width - 48f)
        text(R.id.widget_full_chronometer, "00:00:00", 30f, width - 24f)
        text(R.id.widget_full_countdown_fallback, "00:00:00", 30f, width - 24f)
        // Today's weather sits in the top row, left of the settings button, in whatever width the
        // label leaves free; it is hidden when that space is too small to read.
        val labelPaint = Paint().apply { textSize = 13f * scale * fontScale }
        val labelWidth = minOf(labelPaint.measureText(label), width - 56f)
        val weatherWidth = width - 56f - labelWidth - 6f
        val showWeather = weather != null && weatherWidth >= 50f
        views.setViewVisibility(R.id.widget_full_weather, if (showWeather) View.VISIBLE else View.GONE)
        if (showWeather && weather != null) {
            views.setTextViewText(R.id.widget_full_weather, weather)
            text(R.id.widget_full_weather, weather, 12f, weatherWidth)
        }
        // The current time sits to the right of the countdown, in whatever width the countdown
        // leaves free; it is hidden when that space is too small to read.
        val countdownPaint = Paint().apply {
            textSize = 30f * scale * fontScale
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
        }
        val countdownText = countdownPaint.measureText("00:00:00").coerceAtLeast(1f)
        val countdownWidth = countdownText * minOf(1f, (width - 24f) / countdownText)
        val clockWidth = width - 24f - countdownWidth - 8f
        val showClock = clockWidth >= 56f
        views.setViewVisibility(R.id.widget_full_clock, if (showClock) View.VISIBLE else View.GONE)
        if (showClock) text(R.id.widget_full_clock, "00:00", 22f, clockWidth)
        val cellWidth = (width - 24f) / (if (narrow) 3 else 6) - 4f
        nameIds.forEachIndexed { i, id -> text(id, names[i], 10f, cellWidth) }
        timeIds.forEachIndexed { i, id -> text(id, times[i], 12f, cellWidth) }
        views.setViewPadding(R.id.widget_prayer_rows, 0, 0, 0, 0)
        // Padding remains proportional to the fitted type instead of stretching with the host.
        val padding = (4 * scale * fontScale * density).toInt()
        val slots = intArrayOf(R.id.widget_slot_0, R.id.widget_slot_1, R.id.widget_slot_2,
            R.id.widget_slot_3, R.id.widget_slot_4, R.id.widget_slot_5)
        slots.forEach { views.setViewPadding(it, 0, padding, 0, padding) }
    }
}
