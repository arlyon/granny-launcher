import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';

export 'package:notification_listener_service/notification_event.dart'
    show ServiceNotificationEvent;
export 'package:notification_listener_service/notification_listener_service.dart'
    show NotificationListenerService;

class NotifService {
  static const _channel = MethodChannel('granny_launcher/notif_control');
  static const _systemChannel = MethodChannel('granny_launcher/system');

  static Stream<ServiceNotificationEvent> get stream =>
      NotificationListenerService.notificationsStream;

  static Future<bool> isPermissionGranted() =>
      NotificationListenerService.isPermissionGranted();

  static Future<bool> requestPermission() =>
      NotificationListenerService.requestPermission();

  static Future<void> dismissSystemNotification(
      ServiceNotificationEvent event) async {
    if (event.packageName != null && event.id != null) {
      try {
        await _channel.invokeMethod('dismissNotification', {
          'packageName': event.packageName,
          'id': event.id,
        });
      } catch (e) {
        // ignore
      }
    }
  }

  static Future<void> openNotification(ServiceNotificationEvent event) async {
    if (event.packageName != null && event.id != null) {
      try {
        await _channel.invokeMethod('openNotification', {
          'packageName': event.packageName,
          'id': event.id,
        });
        return;
      } catch (e) {
        // fall through to intent launch
      }
    }
    await openApp(event.packageName);
  }

  static Future<void> openApp(String? packageName) async {
    if (packageName == null) return;
    await AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      package: packageName,
    ).launch();
  }

  static bool isPhoneNotification(String? packageName) {
    if (packageName == null) return false;
    return packageName.contains('dialer') || packageName.endsWith('.phone');
  }

  static bool isSmsNotification(String? packageName) {
    if (packageName == null) return false;
    return packageName.contains('mms') ||
        packageName.contains('messaging') ||
        packageName.contains('message');
  }

  static Future<void> showLocalAlert(String title, String body) async {
    try {
      await _systemChannel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
      });
    } on PlatformException {
      // ignore
    }
  }
}
