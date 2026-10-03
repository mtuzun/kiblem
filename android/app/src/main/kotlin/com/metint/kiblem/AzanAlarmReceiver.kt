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
            putExtra(AzanRingerService.EXTRA_TITLE, intent.getStringExtra(AzanRingerService.EXTRA_TITLE))
            putExtra(AzanRingerService.EXTRA_BODY, intent.getStringExtra(AzanRingerService.EXTRA_BODY))
            putExtra(AzanRingerService.EXTRA_STOP_LABEL, intent.getStringExtra(AzanRingerService.EXTRA_STOP_LABEL))
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
