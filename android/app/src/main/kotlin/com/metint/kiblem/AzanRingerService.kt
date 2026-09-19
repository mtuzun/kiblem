package com.metint.kiblem

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class AzanRingerService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val stopHandler = Handler(Looper.getMainLooper())
    private val stopRunnable = Runnable { stopRinging() }

    companion object {
        const val CHANNEL_ID = "azan_ringer"
        const val NOTIFICATION_ID = 9001
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val ACTION_STOP = "com.metint.kiblem.ACTION_STOP_AZAN"
        const val RING_DURATION_MS = 60_000L
    }

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopRinging()
            return START_NOT_STICKY
        }

        val prayerName = intent?.getStringExtra(EXTRA_PRAYER_NAME) ?: "Namaz"
        startForeground(NOTIFICATION_ID, buildNotification(prayerName))
        startRinging()
        stopHandler.removeCallbacks(stopRunnable)
        stopHandler.postDelayed(stopRunnable, RING_DURATION_MS)
        return START_NOT_STICKY
    }

    private fun startRinging() {
        val channelSoundUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.getNotificationChannel("azan_reminder")?.sound
        } else null

        val uri: Uri = channelSoundUri
            ?: RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)

        try {
            mediaPlayer?.release()
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(this@AzanRingerService, uri)
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            // Ses çalınamıyorsa sessizce devam et; bildirim ve titreşim yine de gösterilir.
        }

        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "kiblem:azan_ringer")
            wakeLock?.acquire(RING_DURATION_MS + 5_000L)
        } catch (e: Exception) {
            // Wake lock alınamazsa servis yine de çalışmaya devam eder.
        }
    }

    private fun stopRinging() {
        stopHandler.removeCallbacks(stopRunnable)
        mediaPlayer?.let {
            try {
                if (it.isPlaying) it.stop()
            } catch (e: Exception) {
                // yoksay
            }
            it.release()
        }
        mediaPlayer = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        stopRinging()
        super.onDestroy()
    }

    private fun buildNotification(prayerName: String): Notification {
        createChannelIfNeeded()

        val stopIntent = Intent(this, AzanRingerService::class.java).apply { action = ACTION_STOP }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val contentIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentPendingIntent = PendingIntent.getActivity(
            this, 0, contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("$prayerName Vakti")
            .setContentText("Ezan vakti geldi — durdurmak için dokunun")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(contentPendingIntent)
            .addAction(android.R.drawable.ic_media_pause, "Durdur", stopPendingIntent)
            .build()
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID, "Ezan Çalıyor", NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Ezan vakti geldiğinde çalan uyarı"
                    setSound(null, null) // Ses MediaPlayer ile ayrı çalınıyor
                    enableVibration(true)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }
}
