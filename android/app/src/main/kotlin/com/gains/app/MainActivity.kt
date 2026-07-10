package com.gains.app

import android.app.AlarmManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.gains.app/battery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestIgnoreBatteryOptimization" -> {
                        requestBatteryOptimizationExemption()
                        result.success(null)
                    }
                    "canScheduleExact" -> {
                        val am = getSystemService(ALARM_SERVICE) as AlarmManager
                        val can = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                            am.canScheduleExactAlarms() else true
                        result.success(can)
                    }
                    "scheduleReminder" -> {
                        try {
                            val id     = call.argument<Int>("id") ?: 0
                            val epochMs = (call.argument<Any>("epochMs") as? Number)?.toLong() ?: 0L
                            val title  = call.argument<String>("title") ?: ""
                            val body   = call.argument<String>("body") ?: ""
                            val hour   = call.argument<Int>("hour") ?: 0
                            val min    = call.argument<Int>("minute") ?: 0
                            ReminderReceiver.schedule(this, id, epochMs, title, body, hour, min)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ALARM_ERROR", e.message, null)
                        }
                    }
                    "cancelReminder" -> {
                        val id = call.argument<Int>("id") ?: 0
                        ReminderReceiver.cancel(this, id)
                        result.success(null)
                    }
                    "scheduleRestDone" -> {
                        try {
                            val epochMs = (call.argument<Any>("epochMs") as? Number)?.toLong() ?: 0L
                            RestDoneReceiver.schedule(this, epochMs)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ALARM_ERROR", e.message, null)
                        }
                    }
                    "cancelRestDone" -> {
                        RestDoneReceiver.cancel(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        }
    }
}
