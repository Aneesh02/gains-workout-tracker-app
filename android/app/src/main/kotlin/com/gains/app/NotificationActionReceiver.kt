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
        // Find the running Flutter engine (null if app is killed — can't route then).
        val engine = FlutterEngineCache.getInstance().get("main_engine") ?: return
        Handler(Looper.getMainLooper()).post {
            MethodChannel(engine.dartExecutor.binaryMessenger, "com.gains.app/battery")
                .invokeMethod("notificationAction", actionId)
        }
    }
}
