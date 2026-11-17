package dev.zeekr.bluetooth_low_energy_android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.annotation.MainThread
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/** Keeps the process that owns the DOT GATT connection alive while measuring. */
class DotMeasurementService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    @Suppress("DEPRECATION")
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startPending = false
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "DOT 저울 연결", NotificationManager.IMPORTANCE_LOW),
            )
            Notification.Builder(this, CHANNEL)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.stat_notify_sync_noanim)
            .setContentTitle("DOT 저울 연결 중")
            .setContentText("앱을 전환해도 저울 측정값을 받습니다.")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            notification.setContentIntent(
                PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE),
            )
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION, notification.build(), ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
            } else {
                startForeground(NOTIFICATION, notification.build())
            }
            if (required) {
                running = this
            } else {
                // A disconnect can arrive after startForegroundService but before this callback.
                ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
                stopSelf(startId)
            }
        } catch (e: RuntimeException) {
            Log.w(TAG, "Unable to promote the DOT connection service", e)
            stopSelf(startId)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        if (running === this) running = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "DotMeasurementService"
        private const val CHANNEL = "dot_scale_connection"
        private const val NOTIFICATION = 0xD07
        private var required = false
        private var startPending = false
        private var running: DotMeasurementService? = null

        @MainThread
        internal fun setRequired(context: Context, active: Boolean) {
            required = active
            if (!active) {
                val service = running ?: return
                running = null
                ServiceCompat.stopForeground(service, ServiceCompat.STOP_FOREGROUND_REMOVE)
                service.stopSelf()
                return
            }
            if (startPending || running != null) return

            startPending = true
            try {
                ContextCompat.startForegroundService(context, Intent(context, DotMeasurementService::class.java))
            } catch (e: RuntimeException) {
                startPending = false
                // The link still works if Android disallows foreground promotion.
                Log.w(TAG, "Unable to start the DOT connection service", e)
            }
        }
    }
}
