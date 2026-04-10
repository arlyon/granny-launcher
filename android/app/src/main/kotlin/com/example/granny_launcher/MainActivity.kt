package com.example.granny_launcher

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.CallLog
import android.provider.Settings
import android.provider.Telephony
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.app.PendingIntent
import android.content.pm.PackageInstaller
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
                    else -> result.notImplemented()
                }
            }
    }
}
