package moe.astralsight.astrobox.plugin.cloud_push

import android.content.Context
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class AstroBoxFirebaseMessagingService : FirebaseMessagingService() {
    companion object {
        private const val TAG = "AstroBoxCloudPush"
        private const val PREFS_NAME = "astrobox_cloud_push"
        private const val FCM_TOKEN_KEY = "fcm_token"

        fun readCachedToken(context: Context): String? =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(FCM_TOKEN_KEY, null)
                ?.takeIf { it.isNotBlank() }

        fun writeCachedToken(context: Context, token: String) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(FCM_TOKEN_KEY, token)
                .apply()
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        writeCachedToken(applicationContext, token)
        Log.i(TAG, "FCM token refreshed")
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        Log.d(TAG, "FCM message received from=${message.from} dataKeys=${message.data.keys}")
    }
}
