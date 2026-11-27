package io.github.trvnce.cartelera

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

/**
 * Servicio en primer plano mientras la app lee las webs de los cines.
 *
 * Sin él, al salir de la app Android la pasa a «en caché» y, desde Android 14, la congela a
 * los pocos segundos: las descargas se quedan paradas y, al volver, todas las esperas límite
 * vencen a la vez y las fuentes dan error. Con el servicio el proceso sigue vivo y la
 * lectura termina aunque la app no esté delante. Se arranca y se para desde Dart
 * (lib/data/keep_alive.dart) por el canal `cartelera/refresh_service`.
 */
class RefreshService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val n = build(this, done = 0, total = 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
        running = true
        return START_NOT_STICKY
    }

    // Android 15 limita los servicios dataSync a 6 h al día: si se llega, se para sin más.
    override fun onTimeout(startId: Int) {
        stopSelf()
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_ID = "refresh"
        private const val NOTIFICATION_ID = 1001

        @Volatile
        var running = false
            private set

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "Actualización de la cartelera", NotificationManager.IMPORTANCE_LOW).apply {
                        description = "Aparece mientras se leen las webs de los cines"
                        setShowBadge(false)
                    }
                )
            }
        }

        fun build(context: Context, done: Int, total: Int): Notification {
            ensureChannel(context)
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            @Suppress("DEPRECATION")
            val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(context, CHANNEL_ID) else Notification.Builder(context)
            return b.setSmallIcon(R.drawable.ic_stat_cartelera)
                .setContentTitle("Actualizando la cartelera")
                .setContentText(if (total > 0) "$done de $total fuentes" else "Leyendo las webs de los cines")
                .setProgress(total, done, total == 0)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(open)
                .build()
        }

        fun start(context: Context): Boolean = try {
            val i = Intent(context, RefreshService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(i) else context.startService(i)
            true
        } catch (e: Exception) {
            false // p. ej., si el sistema no deja arrancarlo: la lectura sigue igual, sin servicio
        }

        fun progress(context: Context, done: Int, total: Int) {
            if (!running) return
            context.getSystemService(NotificationManager::class.java)?.notify(NOTIFICATION_ID, build(context, done, total))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, RefreshService::class.java))
        }
    }
}
