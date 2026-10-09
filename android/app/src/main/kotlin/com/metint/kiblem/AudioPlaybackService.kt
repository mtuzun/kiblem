package com.metint.kiblem

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Ayet sesi (Kur'an / meal) dinletilirken uygulamanın ekran kilitlenince ya da arka plana
 * alınınca susmaması için çalışan ön plan servisi. Sesin kendisini Flutter çalar; bu servis
 * yalnızca süreci canlı tutar ve bildirimde "Durdur" düğmesi gösterir.
 */
class AudioPlaybackService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    companion object {
        const val CHANNEL_ID = "ayah_playback"
        const val NOTIFICATION_ID = 9002
        const val ACTION_START = "com.metint.kiblem.ACTION_AUDIO_START"
        const val ACTION_STOP = "com.metint.kiblem.ACTION_AUDIO_STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_STOP_LABEL = "stop_label"

        /** Bildirimdeki "Durdur"a basılınca Flutter tarafına haber veren geri çağrı. */
        var onStopRequested: (() -> Unit)? = null
    }

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            onStopRequested?.invoke()
            shutDown()
            return START_NOT_STICKY
        }
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Ayet dinletiliyor"
        val stopLabel = intent?.getStringExtra(EXTRA_STOP_LABEL) ?: "Durdur"
        val notification = buildNotification(title, stopLabel)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        acquireLocks()
        return START_NOT_STICKY
    }

    private fun acquireLocks() {
        try {
            if (wakeLock == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "kiblem:ayah_playback")
                wakeLock?.acquire(3 * 60 * 60_000L)
            }
            if (wifiLock == null) {
                val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "kiblem:ayah_playback")
                wifiLock?.acquire()
            }
        } catch (e: Exception) {
            // Kilitler alınamazsa servis yine de süreci canlı tutar.
        }
    }

    private fun shutDown() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        wifiLock?.let { if (it.isHeld) it.release() }
        wifiLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wifiLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }

    private fun buildNotification(title: String, stopLabel: String): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID, "Ayet Dinletme", NotificationManager.IMPORTANCE_LOW
                ).apply { setSound(null, null) }
                manager.createNotificationChannel(channel)
            }
        }
        val stopIntent = Intent(this, AudioPlaybackService::class.java).apply { action = ACTION_STOP }
        val stopPending = PendingIntent.getService(
            this, 2, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val contentPending = PendingIntent.getActivity(
            this, 3, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setContentIntent(contentPending)
            .addAction(android.R.drawable.ic_media_pause, stopLabel, stopPending)
            .build()
    }
}
