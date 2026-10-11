package com.metint.kiblem

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.widget.Button
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import es.antonborri.home_widget.HomeWidgetPlugin

/** Edits only the widget instance which opened this screen. */
class WidgetSettingsActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var style = WidgetStyle()
    private var english = false
    private var fullWidget = false
    private var prayerName = "İkindi"
    private lateinit var preview: Preview
    private lateinit var transparentSwitch: Switch
    private lateinit var backgroundButton: Button
    private lateinit var foregroundButton: Button
    private val colors = intArrayOf(
        0xFF3E8E7E.toInt(), 0xFF166534.toInt(), 0xFF14B8A6.toInt(), 0xFF22C55E.toInt(),
        0xFFFFFFFF.toInt(), 0xFF111827.toInt(), 0xFF6B7280.toInt(), 0xFFE5E7EB.toInt(),
        0xFF1E3A8A.toInt(), 0xFF2563EB.toInt(), 0xFF38BDF8.toInt(), 0xFF7C3AED.toInt(),
        0xFFBE185D.toInt(), 0xFFF472B6.toInt(), 0xFFDC2626.toInt(), 0xFFF97316.toInt(),
        0xFFFACC15.toInt(), 0xFF92400E.toInt(), 0xFFF5E6D3.toInt(), 0xFFD6B98C.toInt(),
    )
    private val colorNamesTr = arrayOf("Yeşil", "Koyu yeşil", "Turkuaz", "Açık yeşil", "Beyaz", "Siyah", "Gri", "Açık gri",
        "Lacivert", "Mavi", "Açık mavi", "Mor", "Koyu pembe", "Pembe", "Kırmızı", "Turuncu", "Sarı", "Kahverengi", "Krem", "Bej")
    private val colorNamesEn = arrayOf("Green", "Dark green", "Teal", "Light green", "White", "Black", "Gray", "Light gray",
        "Navy", "Blue", "Light blue", "Purple", "Dark pink", "Pink", "Red", "Orange", "Yellow", "Brown", "Cream", "Beige")

    private fun tr(turkish: String, en: String) = if (english) en else turkish
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val info = AppWidgetManager.getInstance(this).getAppWidgetInfo(widgetId)
        if (info == null || info.provider.packageName != packageName ||
            info.provider.className !in listOf(PrayerWidgetProvider::class.java.name, PrayerWidgetFullProvider::class.java.name)) {
            finish()
            return
        }
        val data = HomeWidgetPlugin.getData(this)
        english = data.getString("widget_language", "tr") == "en"
        prayerName = data.getString("widget_prayer_name", null) ?: tr("İkindi", "Asr")
        fullWidget = info.provider.className == PrayerWidgetFullProvider::class.java.name
        style = if (savedInstanceState == null) WidgetAppearance.load(this, widgetId) else WidgetStyle(
            savedInstanceState.getBoolean("transparent"), savedInstanceState.getInt("background"),
            savedInstanceState.getInt("foreground"), savedInstanceState.getBoolean("customized"),
        )
        buildScreen()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean("transparent", style.transparent)
        outState.putInt("background", style.background)
        outState.putInt("foreground", style.foreground)
        outState.putBoolean("customized", style.customized)
        super.onSaveInstanceState(outState)
    }

    private fun label(text: String, size: Float = 16f) = TextView(this).apply {
        this.text = text
        textSize = size
        setTextColor(0xFF111827.toInt())
        setPadding(0, dp(12), 0, dp(8))
    }

    private fun buildScreen() {
        val scroll = ScrollView(this).apply { setBackgroundColor(Color.WHITE); isFillViewport = true }
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(12), dp(20), dp(20))
        }
        scroll.addView(column)
        scroll.setOnApplyWindowInsetsListener { view, insets ->
            val top: Int
            val bottom: Int
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bars = insets.getInsets(WindowInsets.Type.systemBars())
                top = bars.top; bottom = bars.bottom
            } else {
                @Suppress("DEPRECATION")
                top = insets.systemWindowInsetTop
                @Suppress("DEPRECATION")
                bottom = insets.systemWindowInsetBottom
            }
            view.setPadding(0, top, 0, bottom)
            insets
        }
        column.addView(label(tr("Widget görünümü", "Widget appearance"), 24f).apply { setTypeface(null, Typeface.BOLD) })
        column.addView(label(tr("Bu ayarlar yalnızca açtığınız widget için geçerlidir.", "These settings apply only to the widget you opened."), 14f))
        column.addView(label(tr("Önizleme", "Preview")))
        preview = Preview()
        preview.contentDescription = tr("Seçilen zemin ve yazı renkleriyle widget önizlemesi", "Widget preview with your selected colors")
        column.addView(preview, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(if (fullWidget) 180 else 112)))
        column.addView(label(tr("Şeffaf önizlemede kareli desen yalnızca şeffaflığı belirtir; ana ekranda duvar kâğıdınız görünür.",
            "The checkerboard indicates transparency in the preview; your wallpaper shows on the home screen."), 13f))
        transparentSwitch = Switch(this).apply {
            text = tr("Şeffaf zemin", "Transparent background")
            textSize = 17f
            setTextColor(0xFF111827.toInt())
            minHeight = dp(56)
            isChecked = style.transparent
            setOnCheckedChangeListener { _, checked ->
                style = style.copy(transparent = checked, customized = true)
                updatePreview()
            }
        }
        column.addView(transparentSwitch)
        backgroundButton = Button(this).apply { setOnClickListener { showPalette(true) } }
        foregroundButton = Button(this).apply { setOnClickListener { showPalette(false) } }
        column.addView(backgroundButton)
        column.addView(foregroundButton)
        column.addView(Button(this).apply {
            text = tr("Varsayılana dön", "Reset to default")
            setOnClickListener {
                // Avoid the switch listener marking the restored default as customized.
                style = WidgetStyle()
                transparentSwitch.isChecked = false
                style = WidgetStyle()
                updatePreview()
            }
        })
        column.addView(Button(this).apply {
            text = tr("Kaydet", "Save")
            setOnClickListener {
                if (AppWidgetManager.getInstance(this@WidgetSettingsActivity).getAppWidgetInfo(widgetId) == null) {
                    finish()
                    return@setOnClickListener
                }
                WidgetAppearance.save(this@WidgetSettingsActivity, widgetId, style)
                WidgetAppearance.refresh(this@WidgetSettingsActivity, widgetId)
                Toast.makeText(this@WidgetSettingsActivity, tr("Widget görünümü kaydedildi", "Widget appearance saved"), Toast.LENGTH_SHORT).show()
                finish()
            }
        })
        column.addView(Button(this).apply { text = tr("Vazgeç", "Cancel"); setOnClickListener { finish() } })
        setContentView(scroll)
        updatePreview()
    }

    private fun colorName(color: Int): String {
        val index = colors.indexOf(color)
        return if (index < 0) tr("Seçili renk", "Selected color") else if (english) colorNamesEn[index] else colorNamesTr[index]
    }

    private fun updatePreview() {
        backgroundButton.text = "${tr("Zemin rengi", "Background color")}: ${colorName(style.background)}"
        backgroundButton.isEnabled = !style.transparent
        foregroundButton.text = "${tr("Yazı rengi", "Text color")}: ${colorName(style.foreground)}"
        preview.invalidate()
    }

    private fun showPalette(background: Boolean) {
        val grid = GridLayout(this).apply {
            columnCount = if (resources.displayMetrics.widthPixels / resources.displayMetrics.density < 360) 3 else 4
            setPadding(dp(12), dp(12), dp(12), dp(12))
        }
        val selected = if (background) style.background else style.foreground
        val dialog = AlertDialog.Builder(this)
            .setTitle(if (background) tr("Zemin rengi seçin", "Choose background color") else tr("Yazı rengi seçin", "Choose text color"))
            .setView(ScrollView(this).apply { addView(grid) })
            .setNegativeButton(tr("Vazgeç", "Cancel"), null).create()
        colors.forEach { color ->
            grid.addView(TextView(this).apply {
                gravity = Gravity.CENTER
                text = if (color == selected) "✓" else ""
                textSize = 24f
                setTypeface(null, Typeface.BOLD)
                val light = Color.red(color) * 0.299 + Color.green(color) * 0.587 + Color.blue(color) * 0.114 > 150
                setTextColor(if (light) Color.BLACK else Color.WHITE)
                this.background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(color)
                    setStroke(dp(if (color == selected) 3 else 1), if (color == selected) 0xFF3E8E7E.toInt() else 0xFF9CA3AF.toInt())
                }
                contentDescription = colorName(color)
                isFocusable = true
                isClickable = true
                layoutParams = GridLayout.LayoutParams().apply {
                    width = dp(48); height = dp(48); setMargins(dp(3), dp(3), dp(3), dp(3))
                }
                setOnClickListener {
                    style = if (background) style.copy(background = color, customized = true)
                        else style.copy(foreground = color, customized = true)
                    updatePreview()
                    dialog.dismiss()
                }
            })
        }
        dialog.show()
    }

    private inner class Preview : View(this@WidgetSettingsActivity) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val tile = dp(12)
            for (y in 0..height / tile) for (x in 0..width / tile) {
                paint.color = if ((x + y) % 2 == 0) 0xFFE5E7EB.toInt() else 0xFFF9FAFB.toInt()
                canvas.drawRect((x * tile).toFloat(), (y * tile).toFloat(), ((x + 1) * tile).toFloat(), ((y + 1) * tile).toFloat(), paint)
            }
            if (!style.transparent) {
                paint.color = style.background
                canvas.drawRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), dp(20).toFloat(), dp(20).toFloat(), paint)
            }
            val scale = minOf(1f, width / dp(300).toFloat())
            canvas.save()
            canvas.scale(scale, scale)
            paint.color = style.foreground
            paint.typeface = Typeface.DEFAULT
            paint.textSize = dp(13).toFloat()
            canvas.drawText(if (english) "Time until $prayerName" else "$prayerName için kalan süre", dp(16).toFloat(), dp(26).toFloat(), paint)
            paint.typeface = Typeface.DEFAULT_BOLD
            paint.textSize = dp(30).toFloat()
            canvas.drawText(if (fullWidget) "02:20:00" else tr("2 sa 20 dk", "2 h 20 min"), dp(16).toFloat(), dp(65).toFloat(), paint)
            if (fullWidget) {
                paint.typeface = Typeface.DEFAULT
                paint.textSize = dp(12).toFloat()
                canvas.drawText(tr("Miladi tarih · Hicri tarih", "Gregorian date · Hijri date"), dp(16).toFloat(), dp(92).toFloat(), paint)
                val cell = (width / scale - dp(24)) / 6
                val names = if (english) arrayOf("Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha")
                    else arrayOf("İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı")
                for (i in 0..5) {
                    val left = dp(12) + cell * i
                    if (!style.customized) {
                        paint.color = if (i == 3) 0xFF3E8E7E.toInt() else Color.WHITE
                        canvas.drawRoundRect(RectF(left, dp(112).toFloat(), left + cell - dp(3), dp(160).toFloat()), dp(8).toFloat(), dp(8).toFloat(), paint)
                    } else if (i == 3) {
                        paint.color = (style.foreground and 0x00FFFFFF) or 0x30000000
                        canvas.drawRect(left, dp(112).toFloat(), left + cell - dp(3), dp(160).toFloat(), paint)
                    }
                    paint.color = if (!style.customized && i != 3) 0xFF111827.toInt() else style.foreground
                    paint.textSize = dp(10).toFloat()
                    canvas.drawText(names[i], left + dp(3), dp(130).toFloat(), paint)
                    canvas.drawText("16:45", left + dp(3), dp(149).toFloat(), paint)
                }
            }
            canvas.restore()
        }
    }
}
