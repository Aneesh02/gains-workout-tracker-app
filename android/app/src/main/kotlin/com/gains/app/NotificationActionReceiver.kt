package com.gains.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val actionId = intent.getStringExtra("action_id") ?: return

        // For "end_rest", directly update the notification here — avoids the
        // dart→native roundtrip which is unreliable inside a native→dart callback.
        if (actionId == "end_rest") {
            WorkoutNotifier.showNextSetFromPending(context)
        }

        // Notify dart to update internal rest state (clear rest timer, etc.).
        val engine = FlutterEngineCache.getInstance().get("main_engine") ?: return
        Handler(Looper.getMainLooper()).post {
            MethodChannel(engine.dartExecutor.binaryMessenger, "com.gains.app/battery")
                .invokeMethod("notificationAction", actionId)
        }
    }
}
