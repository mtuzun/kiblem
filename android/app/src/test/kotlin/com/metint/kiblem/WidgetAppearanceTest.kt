package com.metint.kiblem

import android.app.Activity
import android.app.Application
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageButton
import android.widget.RemoteViews
import android.widget.TextView
import android.widget.Switch
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowAlertDialog

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class WidgetAppearanceTest {
    private lateinit var context: Context

    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences("widget_appearance", Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test fun preferencesRemainIndependentAndDeletedWidgetDoesNotResetOtherWidget() {
        val first = WidgetStyle(true, Color.BLUE, Color.YELLOW, true)
        val second = WidgetStyle(false, Color.BLACK, Color.WHITE, true)
        WidgetAppearance.save(context, 11, first)
        WidgetAppearance.save(context, 12, second)
        assertEquals(first, WidgetAppearance.load(context, 11))
        assertEquals(second, WidgetAppearance.load(context, 12))
        WidgetAppearance.remove(context, intArrayOf(11))
        assertEquals(WidgetStyle(), WidgetAppearance.load(context, 11))
        assertEquals(second, WidgetAppearance.load(context, 12))
    }

    @Test fun transparentAppearanceActuallyHidesBackgroundAndSettingsOpensCorrectInstance() {
        WidgetAppearance.save(context, 21, WidgetStyle(true, Color.BLACK, Color.YELLOW, true))
        val views = RemoteViews(context.packageName, R.layout.prayer_widget_compact_layout)
        WidgetAppearance.apply(context, 21, views, intArrayOf(R.id.widget_countdown), false)
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val rendered = views.apply(activity, null)
        assertEquals(View.GONE, rendered.findViewById<View>(R.id.widget_background_image).visibility)
        assertEquals(Color.YELLOW, rendered.findViewById<TextView>(R.id.widget_countdown).currentTextColor)
        val button = rendered.findViewById<ImageButton>(R.id.widget_settings_button)
        assertTrue(button.performClick())
        val intent = Shadows.shadowOf(activity).nextStartedActivity
        assertEquals(21, intent.getIntExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_ID, -1))
        assertEquals(WidgetSettingsActivity::class.java.name, intent.component?.className)
    }

    @Test fun resetRestoresOriginalWidgetColorsAndOpaqueBackground() {
        WidgetAppearance.save(context, 31, WidgetStyle(true, Color.BLACK, Color.YELLOW, true))
        val customViews = RemoteViews(context.packageName, R.layout.prayer_widget_layout)
        WidgetAppearance.apply(context, 31, customViews, intArrayOf(R.id.widget_label, R.id.widget_countdown), false)
        val rendered = customViews.apply(context, null)
        assertEquals(Color.YELLOW, rendered.findViewById<TextView>(R.id.widget_countdown).currentTextColor)
        WidgetAppearance.save(context, 31, WidgetStyle())
        val views = RemoteViews(context.packageName, R.layout.prayer_widget_layout)
        WidgetAppearance.apply(context, 31, views, intArrayOf(R.id.widget_label, R.id.widget_countdown), false)
        views.reapply(context, rendered)
        assertEquals(View.VISIBLE, rendered.findViewById<View>(R.id.widget_background_image).visibility)
        assertEquals(Color.WHITE, rendered.findViewById<TextView>(R.id.widget_countdown).currentTextColor)
        assertEquals(WidgetStyle(), WidgetAppearance.load(context, 31))
    }

    @Test fun fullWidgetRecolorsDateCountdownAndEveryPrayerText() {
        WidgetAppearance.save(context, 41, WidgetStyle(false, Color.BLACK, Color.CYAN, true))
        val ids = intArrayOf(R.id.widget_full_label, R.id.widget_full_date,
            R.id.widget_full_chronometer, R.id.widget_full_countdown_fallback,
            R.id.widget_slot_name_0, R.id.widget_slot_time_0,
            R.id.widget_slot_name_1, R.id.widget_slot_time_1,
            R.id.widget_slot_name_2, R.id.widget_slot_time_2,
            R.id.widget_slot_name_3, R.id.widget_slot_time_3,
            R.id.widget_slot_name_4, R.id.widget_slot_time_4,
            R.id.widget_slot_name_5, R.id.widget_slot_time_5)
        val views = RemoteViews(context.packageName, R.layout.prayer_widget_full_layout)
        WidgetAppearance.apply(context, 41, views, ids, true)
        val rendered = views.apply(context, null)
        ids.forEach { assertEquals(Color.CYAN, rendered.findViewById<TextView>(it).currentTextColor) }
        assertEquals("Widget appearance settings", rendered.findViewById<ImageButton>(R.id.widget_settings_button).contentDescription)
    }

    @Test @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun prayerRowStaysCloseToDateWhenWidgetIsResizedVertically() {
        val rendered = RemoteViews(context.packageName, R.layout.prayer_widget_full_layout).apply(context, null)
        rendered.findViewById<TextView>(R.id.widget_full_label).text = "İkindi için kalan süre"
        rendered.findViewById<TextView>(R.id.widget_full_date).text = "11 Ekim 2026 · 1448"
        rendered.findViewById<TextView>(R.id.widget_slot_name_0).text = "İmsak"
        rendered.findViewById<TextView>(R.id.widget_slot_time_0).text = "05:39"
        val density = context.resources.displayMetrics.density
        fun layout(height: Int) {
            rendered.measure(View.MeasureSpec.makeMeasureSpec((360 * density).toInt(), View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec((height * density).toInt(), View.MeasureSpec.EXACTLY))
            rendered.layout(0, 0, rendered.measuredWidth, rendered.measuredHeight)
        }
        layout(400)
        val date = rendered.findViewById<View>(R.id.widget_full_date)
        val slot = rendered.findViewById<View>(R.id.widget_slot_0)
        val row = slot.parent as View
        assertTrue(row.top - date.bottom in 0..(8 * density).toInt())
        assertTrue("slot height=${slot.height}, density=$density", slot.height < 60 * density)
        val rowTop = row.top
        layout(600)
        assertEquals(rowTop, row.top)
        assertTrue("resized slot height=${slot.height}, density=$density", slot.height < 60 * density)
        layout(140)
        val content = row.parent as View
        assertTrue("Prayer times must fit in the minimum widget height", row.bottom <= content.height - content.paddingBottom)
    }

    private fun descendants(view: View): Sequence<View> = sequence {
        yield(view)
        if (view is ViewGroup) for (i in 0 until view.childCount) yieldAll(descendants(view.getChildAt(i)))
    }

    @Test @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun responsiveFullWidgetFitsNarrowAndLargeFontHosts() {
        for ((width, height, fontScale) in listOf(Triple(180, 100, 1f), Triple(300, 160, 2f), Triple(400, 240, 1f))) {
            val config = android.content.res.Configuration(context.resources.configuration).apply { this.fontScale = fontScale }
            val host = context.createConfigurationContext(config)
            val options = android.os.Bundle().apply {
                putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, width)
                putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, height)
            }
            val sizing = WidgetSizing(host, options)
            assertEquals(width / fontScale < 320, sizing.narrow)
            val views = RemoteViews(context.packageName, if (sizing.narrow)
                R.layout.prayer_widget_full_narrow_layout else R.layout.prayer_widget_full_layout)
            val names = intArrayOf(R.id.widget_slot_name_0, R.id.widget_slot_name_1, R.id.widget_slot_name_2,
                R.id.widget_slot_name_3, R.id.widget_slot_name_4, R.id.widget_slot_name_5)
            val times = intArrayOf(R.id.widget_slot_time_0, R.id.widget_slot_time_1, R.id.widget_slot_time_2,
                R.id.widget_slot_time_3, R.id.widget_slot_time_4, R.id.widget_slot_time_5)
            val labels = listOf("İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı")
            names.forEachIndexed { i, id -> views.setTextViewText(id, labels[i]) }
            times.forEach { views.setTextViewText(it, "16:45") }
            views.setTextViewText(R.id.widget_full_label, "İkindi")
            views.setTextViewText(R.id.widget_full_date, "11 Ekim 2026 · 1448")
            sizing.applyFull(views, names, times, labels, List(6) { "16:45" }, "İkindi", "11 Ekim 2026 · 1448")
            val rendered = views.apply(host, null)
            val density = host.resources.displayMetrics.density
            rendered.measure(View.MeasureSpec.makeMeasureSpec((width * density).toInt(), View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec((height * density).toInt(), View.MeasureSpec.EXACTLY))
            rendered.layout(0, 0, rendered.measuredWidth, rendered.measuredHeight)
            val rows = rendered.findViewById<View>(R.id.widget_prayer_rows)
            val content = rows.parent as View
            assertTrue("$width x $height fontScale=$fontScale: bottom=${rows.bottom}, available=${content.height - content.paddingBottom}",
                rows.bottom <= content.height - content.paddingBottom)
            assertTrue(rendered.findViewById<TextView>(R.id.widget_slot_time_5).textSize > 0)
        }
    }

    @Test fun settingsPaletteAndTransparencySaveOnlySelectedWidget() {
        val manager = AppWidgetManager.getInstance(context)
        val info = AppWidgetProviderInfo().apply { provider = ComponentName(context, PrayerWidgetFullProvider::class.java) }
        Shadows.shadowOf(manager).addBoundWidget(51, info)
        val intent = Intent(context, WidgetSettingsActivity::class.java).putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, 51)
        val activity = Robolectric.buildActivity(WidgetSettingsActivity::class.java, intent).setup().get()
        val content = activity.findViewById<ViewGroup>(android.R.id.content)
        descendants(content).filterIsInstance<Button>().first { it.text.startsWith("Yazı rengi") }.performClick()
        val dialog = ShadowAlertDialog.getLatestAlertDialog()
        val palette = dialog.findViewById<ViewGroup>(android.R.id.content)
        descendants(palette).first { it.contentDescription == "Mavi" }.performClick()
        descendants(content).filterIsInstance<Switch>().single().isChecked = true
        descendants(content).filterIsInstance<Button>().first { it.text == "Kaydet" }.performClick()
        val saved = WidgetAppearance.load(context, 51)
        assertTrue(saved.transparent)
        assertEquals(0xFF2563EB.toInt(), saved.foreground)
        assertTrue(saved.customized)
        assertEquals(WidgetStyle(), WidgetAppearance.load(context, 52))
    }
}
