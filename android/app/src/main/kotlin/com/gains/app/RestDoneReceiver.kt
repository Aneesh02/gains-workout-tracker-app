package com.gains.app

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
class RestDoneReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        vibrate(context)
        Companion.playBell(context)
        // Only post the fallback notification when the Flutter engine is NOT
        // running (app killed). When backgrounded, the Dart timer is still alive
        // and will post the proper next-set notification itself.
        val engine = io.flutter.embedding.engine.FlutterEngineCache
            .getInstance().get("main_engine")
        if (engine == null) {
            showNotification(context)
        }
    }

    private fun vibrate(context: Context) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                val v = vm.defaultVibrator
                v.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 400, 200, 400), -1))
            } else {
                @Suppress("DEPRECATION")
                val v = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 400, 200, 400), -1))
                } else {
                    @Suppress("DEPRECATION")
                    v.vibrate(longArrayOf(0, 400, 200, 400), -1)
                }
            }
        } catch (_: Exception) {}
    }

    private fun showNotification(context: Context) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val tapPi = PendingIntent.getActivity(
            context, 0, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Rest done — start your set")
            .setContentText("Tap to return to your workout")
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(tapPi)
            .setUsesChronometer(true)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .build()

        nm.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        const val CHANNEL_ID = "gains_workout"
        const val NOTIFICATION_ID = 3

        fun playBell(context: Context) {
            // Hold a WakeLock so the device stays awake through playback.
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "gains:bell")
            wl.acquire(15_000L)

            try {
                val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

                // USAGE_MEDIA routes to the active audio device (BT headphones,
                // wired headphones, speaker — whatever the user is listening on).
                // USAGE_ALARM ignores routing and forces the phone speaker.
                val mediaAttrs = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()

                // AUDIOFOCUS_GAIN_TRANSIENT: music apps pause briefly for the bell
                // then resume automatically when we abandon focus. More reliable
                // than MAY_DUCK because it works for every app, not just ones that
                // implement their own ducking listener.
                var focusRequest: AudioFocusRequest? = null
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                        .setAudioAttributes(mediaAttrs)
                        .build()
                    am.requestAudioFocus(focusRequest)
                } else {
                    @Suppress("DEPRECATION")
                    am.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                }

                val uri = android.net.Uri.parse(
                    "android.resource://${context.packageName}/raw/boxing_bell"
                )
                val mp = MediaPlayer()
                mp.setAudioAttributes(mediaAttrs)
                mp.setDataSource(context, uri)
                mp.prepare()
                mp.start()

                val fr = focusRequest
                mp.setOnCompletionListener { player ->
                    player.release()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        fr?.let { am.abandonAudioFocusRequest(it) }
                    } else {
                        @Suppress("DEPRECATION")
                        am.abandonAudioFocus(null)
                    }
                    if (wl.isHeld) wl.release()
                }
            } catch (_: Exception) {
                if (wl.isHeld) wl.release()
            }
        }

        fun schedule(context: Context, epochMs: Long) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = buildPendingIntent(context)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, epochMs, pi)
            }
        }

        fun cancel(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(buildPendingIntent(context))
        }

        private fun buildPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, RestDoneReceiver::class.java)
            return PendingIntent.getBroadcast(
                context, 100, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
