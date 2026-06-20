package com.example.granny_launcher

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.app.ActivityManager
import android.media.AudioManager
import android.os.Build
import android.provider.CallLog
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager
import android.telephony.TelephonyManager
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.app.PendingIntent
import android.telephony.SmsManager
import android.content.pm.PackageInstaller
import androidx.core.app.NotificationCompat
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "granny_launcher/system"

    private val dpm by lazy {
        getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    }
    private val adminComponent by lazy {
        ComponentName(this, DeviceAdminReceiver::class.java)
    }

    private var immersiveModeEnabled = false

    private fun installSilently(apkPath: String) {
        val file = File(apkPath)
        val packageInstaller = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        val sessionId = packageInstaller.createSession(params)
        val session = packageInstaller.openSession(sessionId)

        file.inputStream().use { inputStream ->
            session.openWrite("update", 0, file.length()).use { outputStream ->
                inputStream.copyTo(outputStream)
                session.fsync(outputStream)
            }
        }

        val intent = Intent(this, UpdateReceiver::class.java)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(this, 0, intent, flags)
        session.commit(pendingIntent.intentSender)
        session.close()
    }

    private fun sendDirectSms(number: String, message: String) {
        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            this.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        val parts = smsManager.divideMessage(message)
        smsManager.sendMultipartTextMessage(number, null, parts, null, null)
    }

    private fun showNativeNotification(title: String, body: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "granny_alerts"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, "Granny Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High priority launcher alerts"
                enableLights(true)
                lightColor = android.graphics.Color.YELLOW
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 400, 200, 400)
            }
            notificationManager.createNotificationChannel(channel)
        }
        val notification = NotificationCompat.Builder(applicationContext, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setColor(android.graphics.Color.YELLOW)
            .setVibrate(longArrayOf(0, 400, 200, 400))
            .build()
        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }

    private fun getCallState(): String? {
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return when {
            tm.callState != TelephonyManager.CALL_STATE_IDLE -> "CELLULAR"
            am.mode == AudioManager.MODE_IN_COMMUNICATION && isMicrophoneActive(am) -> "VOIP"
            else -> null
        }
    }

    // A VoIP app sets MODE_IN_COMMUNICATION as soon as a call starts *ringing*,
    // before it is answered. Requiring an active mic capture distinguishes an
    // answered (connected) call from one that is merely ringing, so the
    // "back to call" overlay does not appear for unanswered incoming calls.
    private fun isMicrophoneActive(am: AudioManager): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return true
        return am.activeRecordingConfigurations.isNotEmpty()
    }

    private fun returnToCall(): Boolean {
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        return if (tm.callState != TelephonyManager.CALL_STATE_IDLE) {
            val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            try {
                telecomManager.showInCallScreen(false)
                true
            } catch (e: Exception) {
                val intent = telecomManager.defaultDialerPackage
                    ?.let { packageManager.getLaunchIntentForPackage(it) }
                    ?.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                if (intent != null) { startActivity(intent); true } else false
            }
        } else if (am.mode == AudioManager.MODE_IN_COMMUNICATION) {
            val voipPackages = listOf(
                "com.google.android.apps.tachyon",   // Google Meet (legacy)
                "com.google.android.apps.meetings",  // Google Meet (new)
                "com.whatsapp",
                "us.zoom.videomeetings",
                "org.telegram.messenger",
                "com.facebook.orca",
            )
            // Use getAppTasks to bring the app's existing task to front rather
            // than launching a fresh activity (which may open the home screen).
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val runningPkg = activityManager.appTasks
                .mapNotNull { it.taskInfo.baseActivity?.packageName }
                .firstOrNull { it in voipPackages }

            if (runningPkg != null) {
                val task = activityManager.appTasks
                    .first { it.taskInfo.baseActivity?.packageName == runningPkg }
                task.moveToFront()
                true
            } else {
                // Fallback: plain launch intent
                voipPackages.firstNotNullOfOrNull { pkg ->
                    packageManager.getLaunchIntentForPackage(pkg)
                        ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }?.also { startActivity(it) } != null
            }
        } else {
            false
        }
    }

    override fun onResume() {
        super.onResume()
        if (immersiveModeEnabled) enterLockTask()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && immersiveModeEnabled) applyImmersiveMode()
    }

    private fun enterLockTask() {
        if (dpm.isDeviceOwnerApp(packageName)) {
            dpm.setLockTaskPackages(adminComponent, arrayOf(packageName))
        }
        startLockTask()
        applyImmersiveMode()
    }

    private fun applyImmersiveMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let {
                it.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_DEFAULT
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "granny_launcher/notif_control")
            .setMethodCallHandler { call, result ->
                val packageName = call.argument<String>("packageName")
                val id = call.argument<Int>("id")
                when (call.method) {
                    "dismissNotification" -> {
                        if (packageName != null && id != null) {
                            MyNotificationListener.instance?.dismissNotification(packageName, id)
                            result.success(null)
                        } else {
                            result.error("INVALID", "Missing packageName or id", null)
                        }
                    }
                    "openNotification" -> {
                        if (packageName != null && id != null) {
                            MyNotificationListener.instance?.openNotification(packageName, id)
                            result.success(null)
                        } else {
                            result.error("INVALID", "Missing packageName or id", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openSettings" -> {
                        stopLockTask()
                        val intent = Intent(Settings.ACTION_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    "showLauncherChooser" -> {
                        stopLockTask()
                        val intent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                        }
                        startActivity(Intent.createChooser(intent, "Choose launcher"))
                        result.success(null)
                    }
                    "launchApp" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg == null) {
                            result.error("INVALID", "No package provided", null)
                            return@setMethodCallHandler
                        }
                        val intent = packageManager.getLaunchIntentForPackage(pkg)
                        if (intent != null) {
                            stopLockTask()
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "installSilently" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID", "No path provided", null)
                            return@setMethodCallHandler
                        }
                        try {
                            installSilently(path)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    }
                    "setStatusBarDisabled" -> {
                        val disabled = call.argument<Boolean>("disabled") ?: true
                        if (dpm.isDeviceOwnerApp(packageName)) {
                            dpm.setStatusBarDisabled(adminComponent, disabled)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "setImmersiveMode" -> {
                        immersiveModeEnabled = call.argument<Boolean>("enabled") ?: true
                        if (immersiveModeEnabled) {
                            enterLockTask()
                        } else {
                            stopLockTask()
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                window.insetsController?.show(
                                    WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars()
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                window.decorView.systemUiVisibility = android.view.View.SYSTEM_UI_FLAG_VISIBLE
                            }
                        }
                        result.success(null)
                    }
                    "isDeviceOwner" -> {
                        result.success(dpm.isDeviceOwnerApp(packageName))
                    }
                    "clearDeviceOwner" -> {
                        try {
                            dpm.clearDeviceOwnerApp(packageName)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "sendSms" -> {
                        val number = call.argument<String>("number")
                        val message = call.argument<String>("message")
                        if (number != null && message != null) {
                            try {
                                sendDirectSms(number, message)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("SMS_FAILED", e.message, null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "Number or message was null", null)
                        }
                    }
                    "getMissedCallCount" -> {
                        val cursor = contentResolver.query(
                            CallLog.Calls.CONTENT_URI,
                            arrayOf(CallLog.Calls._ID),
                            "${CallLog.Calls.TYPE} = ? AND ${CallLog.Calls.IS_READ} = 0",
                            arrayOf(CallLog.Calls.MISSED_TYPE.toString()),
                            null
                        )
                        val count = cursor?.count ?: 0
                        cursor?.close()
                        result.success(count)
                    }
                    "getUnreadSmsCount" -> {
                        val cursor = contentResolver.query(
                            Telephony.Sms.Inbox.CONTENT_URI,
                            arrayOf(Telephony.Sms._ID),
                            "${Telephony.Sms.READ} = 0",
                            null,
                            null
                        )
                        val count = cursor?.count ?: 0
                        cursor?.close()
                        result.success(count)
                    }
                    "getCallState" -> {
                        result.success(getCallState())
                    }
                    "returnToCall" -> {
                        result.success(returnToCall())
                    }
                    "showNotification" -> {
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        showNativeNotification(title, body)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
