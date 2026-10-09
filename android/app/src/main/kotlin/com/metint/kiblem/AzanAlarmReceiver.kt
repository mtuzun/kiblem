package com.metint.kiblem

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat

class AzanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.getStringExtra(AzanRingerService.EXTRA_MODE) == AzanRingerService.MODE_NOTIFICATION) {
            postNotification(context, intent)
            return
        }

        val prayerName = intent.getStringExtra(AzanRingerService.EXTRA_PRAYER_NAME) ?: "Namaz"
        val serviceIntent = Intent(context, AzanRingerService::class.java).apply {
            putExtra(AzanRingerService.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AzanRingerService.EXTRA_TITLE, intent.getStringExtra(AzanRingerService.EXTRA_TITLE))
            putExtra(AzanRingerService.EXTRA_BODY, intent.getStringExtra(AzanRingerService.EXTRA_BODY))
            putExtra(AzanRingerService.EXTRA_STOP_LABEL, intent.getStringExtra(AzanRingerService.EXTRA_STOP_LABEL))
            putExtra(AzanRingerService.EXTRA_SOUND_URI, intent.getStringExtra(AzanRingerService.EXTRA_SOUND_URI))
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    // Bildirim modu: tam ekran alarm yok; seçilen zil sesiyle normal bir bildirim gösterilir.
    private fun postNotification(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra(AzanRingerService.EXTRA_PRAYER_NAME) ?: "Namaz"
        val title = intent.getStringExtra(AzanRingerService.EXTRA_TITLE) ?: "$prayerName Vakti"
        val body = intent.getStringExtra(AzanRingerService.EXTRA_BODY) ?: ""
        val soundUri: Uri = intent.getStringExtra(AzanRingerService.EXTRA_SOUND_URI)?.let { Uri.parse(it) }
            ?: RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        // Dosyadan seçilen sesi (content://) bildirim sistemi okuyabilsin diye izin ver.
        if (soundUri.scheme == "content") {
            try {
                context.grantUriPermission("com.android.systemui", soundUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (e: Exception) {
                // İzin verilemezse sistem varsayılan sese düşer.
            }
        }

        // Kanal sesi sonradan değiştirilemediği için her ses kendi kanalını alır.
        val channelId = "azan_notify_${soundUri.toString().hashCode()}"
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.getNotificationChannel(channelId) == null) {
            val channel = NotificationChannel(channelId, "Ezan Hatırlatıcı", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                setSound(
                    soundUri,
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            manager.createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentIntent = PendingIntent.getActivity(
            context, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setSound(soundUri)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()
        manager.notify(9100 + prayerName.hashCode().mod(100), notification)
    }
}
