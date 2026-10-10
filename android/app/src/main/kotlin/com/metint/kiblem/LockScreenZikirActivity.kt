package com.metint.kiblem

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Zikirmatik'i kilit ekranının üstünde açar; telefonu kilitlemeden ekrana dokunarak sayılabilir.
 * Sayaç, Flutter tarafındaki Zikirmatik ekranıyla aynı SharedPreferences anahtarını (zikir_count)
 * kullanır, böylece iki ekran da aynı sayıyı gösterir.
 */
class LockScreenZikirActivity : Activity() {
    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY = "flutter.zikir_count"
    }

    private lateinit var countView: TextView
    private var count = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        count = prefs.getInt(KEY, 0)

        val title = intent.getStringExtra("title") ?: "Zikirmatik"
        val resetLabel = intent.getStringExtra("resetLabel") ?: "Sıfırla"
        val closeLabel = intent.getStringExtra("closeLabel") ?: "Kapat"

        countView = TextView(this).apply {
            text = count.toString()
            setTextColor(Color.WHITE)
            textSize = 96f
            typeface = Typeface.MONOSPACE
            gravity = Gravity.CENTER
        }

        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, 72, 0, 0)
            addView(TextView(this@LockScreenZikirActivity).apply {
                text = resetLabel
                setTextColor(Color.parseColor("#CCFFFFFF"))
                textSize = 16f
                setPadding(32, 16, 32, 16)
                setOnClickListener { reset(prefs) }
            })
            addView(TextView(this@LockScreenZikirActivity).apply {
                text = closeLabel
                setTextColor(Color.parseColor("#CCFFFFFF"))
                textSize = 16f
                setPadding(32, 16, 32, 16)
                setOnClickListener { finish() }
            })
        }

        val titleView = TextView(this).apply {
            text = title
            setTextColor(Color.parseColor("#9910B981"))
            textSize = 14f
            gravity = Gravity.CENTER
            letterSpacing = 0.2f
        }

        val center = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            addView(titleView)
            addView(countView, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = 16 })
        }

        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#0F172A"))
            addView(center, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER
            ))
            addView(topBar, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.CENTER_HORIZONTAL
            ))
            // Ekranın geri kalan boş alanına dokununca da sayılsın diye kendi tıklamasını dinler.
            isClickable = true
            setOnClickListener { increment(prefs) }
        }
        setContentView(root)
    }

    private fun increment(prefs: android.content.SharedPreferences) {
        count++
        countView.text = count.toString()
        prefs.edit().putInt(KEY, count).apply()
    }

    private fun reset(prefs: android.content.SharedPreferences) {
        count = 0
        countView.text = "0"
        prefs.edit().putInt(KEY, 0).apply()
    }
}
