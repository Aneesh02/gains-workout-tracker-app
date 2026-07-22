package com.gains.app

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat

object WorkoutNotifier {
    const val CHANNEL_ID = "gains_workout"
    const val NOTIFICATION_ID = 3

    // Stored when the rest timer starts so NotificationActionReceiver can show
    // the next-set notification directly without a dart→native roundtrip.
    var pendingNextExercise: String = ""
    var pendingNextBody: String = ""

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

    private fun tapPi(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, 200, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Countdown timer + End Rest button. Also caches the next-set data for
     *  direct use by NotificationActionReceiver when End Rest is tapped. */
    fun showResting(
        context: Context,
        exerciseName: String,
        endTimeMs: Long,
        nextExerciseName: String,
        nextBody: String,
    ) {
        pendingNextExercise = nextExerciseName
        pendingNextBody = nextBody

        val title = if (exerciseName.isNotEmpty()) "Resting · $exerciseName" else "Resting"
        val notif = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText("Rest timer running")
            .setOngoing(true).setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(tapPi(context))
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setWhen(endTimeMs).setShowWhen(true)
            .addAction(0, "End Rest", actionPi(context, "end_rest"))
            .build()
        nm(context).notify(NOTIFICATION_ID, notif)
    }

    /** Called by NotificationActionReceiver on "end_rest" — shows the stored
     *  next-set notification without needing a dart→native roundtrip. */
    fun showNextSetFromPending(context: Context) {
        if (pendingNextExercise.isNotEmpty()) {
            showNextSet(context, pendingNextExercise, pendingNextBody)
        }
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
            .setContentIntent(tapPi(context))
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
            .setContentIntent(tapPi(context))
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
