package com.metint.kiblem

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.metint.kiblem/ringtone"
    private val pickRingtoneRequestCode = 4201
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickRingtone" -> {
                    pendingResult = result
                    val currentUriString = call.argument<String>("currentUri")
                    val currentUri = if (currentUriString != null) Uri.parse(currentUriString) else null
                    val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Ezan Sesi Seç")
                        putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, currentUri)
                    }
                    startActivityForResult(intent, pickRingtoneRequestCode)
                }
                "setChannelSound" -> {
                    val uriString = call.argument<String>("uri")
                    setNotificationChannelSound(uriString)
                    result.success(null)
                }
                "getRingtoneTitle" -> {
                    val uriString = call.argument<String>("uri")
                    result.success(getRingtoneTitleForUri(uriString))
                }
                "scheduleAzanAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val triggerAtMillis = (call.argument<Number>("triggerAtMillis"))?.toLong() ?: 0L
                    val prayerName = call.argument<String>("prayerName") ?: "Namaz"
                    scheduleAzanAlarm(id, triggerAtMillis, prayerName)
                    result.success(null)
                }
                "cancelAzanAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    cancelAzanAlarm(id)
                    result.success(null)
                }
                "canScheduleExactAlarms" -> {
                    result.success(canScheduleExactAlarms())
                }
                "requestExactAlarmPermission" -> {
                    requestExactAlarmPermission()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickRingtoneRequestCode) {
            @Suppress("DEPRECATION")
            val uri: Uri? = data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            pendingResult?.success(uri?.toString())
            pendingResult = null
        }
    }

    private fun setNotificationChannelSound(uriString: String?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "azan_reminder"
        notificationManager.deleteNotificationChannel(channelId)

        val channel = NotificationChannel(
            channelId,
            "Ezan Hatırlatıcı",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Namaz vaktine 15 dakika kala bildirim gönderir."
            enableVibration(true)
            if (uriString != null) {
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(Uri.parse(uriString), audioAttributes)
            }
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun getRingtoneTitleForUri(uriString: String?): String? {
        if (uriString == null) return null
        return try {
            RingtoneManager.getRingtone(applicationContext, Uri.parse(uriString))?.getTitle(applicationContext)
        } catch (e: Exception) {
            null
        }
    }

    private fun azanAlarmPendingIntent(id: Int): PendingIntent {
        val intent = Intent(this, AzanAlarmReceiver::class.java)
        return PendingIntent.getBroadcast(
            this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleAzanAlarm(id: Int, triggerAtMillis: Long, prayerName: String) {
        val intent = Intent(this, AzanAlarmReceiver::class.java).apply {
            putExtra(AzanRingerService.EXTRA_PRAYER_NAME, prayerName)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
        if (!canExact) {
            // İzin verilmemişse en azından yaklaşık zamanlı alarm kur; tamamen sessiz kalmasın.
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            return
        }
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
    }

    private fun cancelAzanAlarm(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(azanAlarmPendingIntent(id))
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    private fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
}
