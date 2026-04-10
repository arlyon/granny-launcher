import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';

export 'package:notification_listener_service/notification_event.dart'
    show ServiceNotificationEvent;

class NotifService {
  static Stream<ServiceNotificationEvent> get stream =>
      NotificationListenerService.notificationsStream;

  static Future<bool> isPermissionGranted() =>
      NotificationListenerService.isPermissionGranted();

  static Future<bool> requestPermission() =>
      NotificationListenerService.requestPermission();

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
}
