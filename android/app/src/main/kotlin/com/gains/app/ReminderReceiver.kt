package com.gains.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import java.util.Calendar

class ReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val id    = intent.getIntExtra("id", 0)
        val title = intent.getStringExtra("title") ?: "GAINS"
        val body  = intent.getStringExtra("body") ?: ""
        val hour  = intent.getIntExtra("hour", 0)
        val min   = intent.getIntExtra("minute", 0)

        showNotification(context, id, title, body)
        rescheduleForTomorrow(context, id, title, body, hour, min)
    }

    private fun showNotification(context: Context, id: Int, title: String, body: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Training Reminders", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Smart daily training nudges from Gains"
                }
            )
        }
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val tapPi = PendingIntent.getActivity(
            context, id, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(tapPi)
            .build()
        nm.notify(id, notification)
    }

    private fun rescheduleForTomorrow(context: Context, id: Int, title: String, body: String, hour: Int, min: Int) {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, min)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_MONTH, 1)
        }
        schedule(context, id, cal.timeInMillis, title, body, hour, min)
    }

    companion object {
        const val CHANNEL_ID = "gains_reminders"

        fun buildPendingIntent(context: Context, id: Int, title: String, body: String, hour: Int, min: Int): PendingIntent {
            val intent = Intent(context, ReminderReceiver::class.java).apply {
                putExtra("id", id)
                putExtra("title", title)
                putExtra("body", body)
                putExtra("hour", hour)
                putExtra("minute", min)
            }
            return PendingIntent.getBroadcast(
                context, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        fun schedule(context: Context, id: Int, epochMs: Long, title: String, body: String, hour: Int, min: Int) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = buildPendingIntent(context, id, title, body, hour, min)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, epochMs, pi)
            }
        }

        fun cancel(context: Context, id: Int) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = buildPendingIntent(context, id, "", "", 0, 0)
            am.cancel(pi)
        }
    }
}
