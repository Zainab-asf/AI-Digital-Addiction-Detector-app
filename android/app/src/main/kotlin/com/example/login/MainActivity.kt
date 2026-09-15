package com.example.login

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "loopaware/usage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUsageAccessSettings" -> {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }

                    "hasUsageAccess" -> result.success(hasUsageAccess())

                    "queryUsageEvents" -> {
                        val start = call.argument<Any>("startMillis").asLong()
                        val end = call.argument<Any>("endMillis").asLong()
                        if (start == null || end == null || end <= start) {
                            result.error(
                                "bad-range",
                                "startMillis and endMillis are required",
                                null
                            )
                        } else {
                            try {
                                result.success(queryUsageEvents(start, end))
                            } catch (e: Throwable) {
                                result.error("query-failed", e.message, null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun Any?.asLong(): Long? = when (this) {
        is Long -> this
        is Int -> this.toLong()
        is Number -> this.toLong()
        else -> null
    }

    /** True when the user has granted the PACKAGE_USAGE_STATS special access. */
    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
            ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Returns raw foreground/background transitions in [start, end).
     *
     * Deliberately does no aggregation: the Dart side turns these into
     * per-app minutes, pickup counts and an hourly histogram, which keeps
     * that logic unit-testable off-device.
     *
     * ACTIVITY_RESUMED/ACTIVITY_PAUSED (API 29+) share the integer values of
     * the older MOVE_TO_FOREGROUND/MOVE_TO_BACKGROUND, so comparing against
     * the numeric constants works across supported API levels.
     */
    private fun queryUsageEvents(start: Long, end: Long): List<Map<String, Any>> {
        val usage = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()

        val out = ArrayList<Map<String, Any>>()
        val events: UsageEvents = usage.queryEvents(start, end)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val type = event.eventType
            if (type != FOREGROUND && type != BACKGROUND) continue
            val pkg = event.packageName ?: continue
            out.add(
                mapOf(
                    "packageName" to pkg,
                    "type" to type,
                    "timestamp" to event.timeStamp
                )
            )
        }
        return out
    }

    private companion object {
        /** UsageEvents.Event.ACTIVITY_RESUMED / MOVE_TO_FOREGROUND. */
        const val FOREGROUND = 1

        /** UsageEvents.Event.ACTIVITY_PAUSED / MOVE_TO_BACKGROUND. */
        const val BACKGROUND = 2
    }
}
