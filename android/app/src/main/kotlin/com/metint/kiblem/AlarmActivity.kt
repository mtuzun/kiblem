package com.metint.kiblem

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** Tam ekran alarm: kilit ekranının üstünde açılır, "Durdur" ile çalan sesi susturur. */
class AlarmActivity : Activity() {
    private val closeHandler = Handler(Looper.getMainLooper())

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

        val title = intent.getStringExtra(AzanRingerService.EXTRA_TITLE) ?: "Namaz Vakti"
        val body = intent.getStringExtra(AzanRingerService.EXTRA_BODY) ?: ""
        val stopLabel = intent.getStringExtra(AzanRingerService.EXTRA_STOP_LABEL) ?: "Durdur"

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0B1F3A"))
            setPadding(64, 64, 64, 64)
        }
        root.addView(TextView(this).apply {
            text = title
            setTextColor(Color.WHITE)
            textSize = 30f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        })
        root.addView(TextView(this).apply {
            text = body
            setTextColor(Color.parseColor("#CCFFFFFF"))
            textSize = 18f
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 96)
        })
        root.addView(Button(this).apply {
            text = stopLabel
            textSize = 20f
            setOnClickListener { stopAlarm() }
        })
        setContentView(root)

        closeHandler.postDelayed({ finish() }, AzanRingerService.RING_DURATION_MS)
    }

    private fun stopAlarm() {
        startService(Intent(this, AzanRingerService::class.java).apply {
            action = AzanRingerService.ACTION_STOP
        })
        finish()
    }

    override fun onDestroy() {
        closeHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
