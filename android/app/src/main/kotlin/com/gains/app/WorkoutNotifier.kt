package com.gains.app

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat

object WorkoutNotifier {
    const val CHANNEL_ID = "gains_workout"
    const val NOTIFICATION_ID = 3

    private fun actionPi(context: Context, actionId: String): PendingIntent {
        val intent = Intent(context, NotificationActionReceiver::class.java).apply {
            putExtra("action_id", actionId)
        }
        val reqCode = if (actionId == "complete_set") 201 else 202
        return PendingIntent.getBroadcast(
            context, reqCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Countdown timer + End Rest button. */
    fun showResting(context: Context, exerciseName: String, endTimeMs: Long) {
        val title = if (exerciseName.isNotEmpty()) "Resting · $exerciseName" else "Resting"
        val notif = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText("Rest timer running")
            .setOngoing(true).setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setWhen(endTimeMs).setShowWhen(true)
            .addAction(0, "End Rest", actionPi(context, "end_rest"))
            .build()
        nm(context).notify(NOTIFICATION_ID, notif)
    }

    /** Static next-set card + Complete Set button (no chronometer). */
    fun showNextSet(context: Context, exerciseName: String, body: String) {
        val notif = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(exerciseName)
            .setContentText(body)
            .setOngoing(true).setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setShowWhen(false)
            .addAction(0, "Complete Set", actionPi(context, "complete_set"))
            .build()
        nm(context).notify(NOTIFICATION_ID, notif)
    }

    /** Count-up overtime timer + Complete Set button. */
    fun showRestDone(context: Context, exerciseName: String, body: String, whenMs: Long) {
        val notif = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(exerciseName)
            .setContentText(body)
            .setOngoing(true).setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setUsesChronometer(true)
            .setChronometerCountDown(false)
            .setWhen(whenMs).setShowWhen(true)
            .addAction(0, "Complete Set", actionPi(context, "complete_set"))
            .build()
        nm(context).notify(NOTIFICATION_ID, notif)
    }

    private fun nm(ctx: Context) =
        ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
