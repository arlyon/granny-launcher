package com.example.granny_launcher

import android.service.notification.NotificationListenerService

class MyNotificationListener : NotificationListenerService() {
    companion object {
        var instance: MyNotificationListener? = null
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        instance = null
    }

    fun dismissNotification(packageName: String, id: Int) {
        val notifications = activeNotifications ?: return
        for (sbn in notifications) {
            if (sbn.packageName == packageName && sbn.id == id) {
                cancelNotification(sbn.key)
                return
            }
        }
    }

    fun openNotification(packageName: String, id: Int) {
        val notifications = activeNotifications ?: return
        for (sbn in notifications) {
            if (sbn.packageName == packageName && sbn.id == id) {
                try {
                    sbn.notification.contentIntent.send()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                return
            }
        }
    }
}
