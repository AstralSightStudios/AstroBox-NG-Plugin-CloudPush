package moe.astralsight.astrobox.plugin.cloud_push

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import app.tauri.PermissionState
import app.tauri.annotation.Command
import app.tauri.annotation.Permission
import app.tauri.annotation.PermissionCallback
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import java.util.UUID

@TauriPlugin(
    permissions = [
        Permission(
            strings = [Manifest.permission.POST_NOTIFICATIONS],
            alias = "notifications"
        )
    ]
)
class CloudPushPlugin(private val activity: Activity) : Plugin(activity) {
    companion object {
        private const val TAG = "AstroBoxCloudPush"
        private const val PREFS_NAME = "astrobox_cloud_push"
        private const val DEVICE_ID_KEY = "device_id"
        private const val DEFAULT_CHANNEL_ID = "astrobox_default"
    }

    override fun load(webView: android.webkit.WebView) {
        super.load(webView)
        createDefaultNotificationChannel()
    }

    @Command
    fun requestRegistration(invoke: Invoke) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            getPermissionState("notifications") != PermissionState.GRANTED
        ) {
            requestPermissionForAlias("notifications", invoke, "notificationPermissionResult")
            return
        }

        resolveRegistration(invoke)
    }

    @PermissionCallback
    fun notificationPermissionResult(invoke: Invoke) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            getPermissionState("notifications") != PermissionState.GRANTED
        ) {
            invoke.resolve(registrationResult(status = "denied", token = null, error = null))
            return
        }

        resolveRegistration(invoke)
    }

    private fun resolveRegistration(invoke: Invoke) {
        try {
            if (FirebaseApp.getApps(activity).isEmpty()) {
                FirebaseApp.initializeApp(activity)
            }
        } catch (error: Exception) {
            invoke.resolve(
                registrationResult(
                    status = "error",
                    token = null,
                    error = "firebase_init_failed: ${error.localizedMessage ?: error.javaClass.simpleName}"
                )
            )
            return
        }

        if (!NotificationManagerCompat.from(activity).areNotificationsEnabled()) {
            invoke.resolve(registrationResult(status = "denied", token = null, error = null))
            return
        }

        FirebaseMessaging.getInstance().token
            .addOnCompleteListener { task ->
                if (!task.isSuccessful) {
                    val error = task.exception
                    Log.w(TAG, "Fetching FCM registration token failed", error)
                    invoke.resolve(
                        registrationResult(
                            status = "error",
                            token = null,
                            error = "fcm_token_failed: ${error?.localizedMessage ?: "unknown"}"
                        )
                    )
                    return@addOnCompleteListener
                }

                AstroBoxFirebaseMessagingService.writeCachedToken(activity, task.result)
                invoke.resolve(
                    registrationResult(
                        status = "success",
                        token = task.result,
                        error = null
                    )
                )
            }
    }

    private fun registrationResult(status: String, token: String?, error: String?): JSObject {
        val result = JSObject()
        result.put("platform", "android")
        result.put("status", status)
        result.put("token", token)
        result.put("environment", if (token == null) null else "production")
        result.put("deviceId", stableDeviceId())
        result.put("bundleId", activity.packageName)
        result.put("error", error)
        return result
    }

    private fun stableDeviceId(): String {
        val prefs = activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(DEVICE_ID_KEY, null)
        if (!existing.isNullOrBlank()) return existing

        val androidId = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ANDROID_ID
        )
        val generated = if (!androidId.isNullOrBlank() && androidId != "9774d56d682e549c") {
            "android-$androidId"
        } else {
            UUID.randomUUID().toString()
        }
        prefs.edit().putString(DEVICE_ID_KEY, generated).apply()
        return generated
    }

    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = activity.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(DEFAULT_CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            DEFAULT_CHANNEL_ID,
            "AstroBox",
            NotificationManager.IMPORTANCE_DEFAULT
        )
        channel.description = "AstroBox remote notifications"
        manager.createNotificationChannel(channel)
    }
}
