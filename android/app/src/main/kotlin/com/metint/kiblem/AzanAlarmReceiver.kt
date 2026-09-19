package com.metint.kiblem

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AzanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra(AzanRingerService.EXTRA_PRAYER_NAME) ?: "Namaz"
        val serviceIntent = Intent(context, AzanRingerService::class.java).apply {
            putExtra(AzanRingerService.EXTRA_PRAYER_NAME, prayerName)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
