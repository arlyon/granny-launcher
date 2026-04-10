import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class CommunicationService {
  static const _channel = MethodChannel('granny_launcher/system');

  static Future<void> requestPermissions() async {
    await [Permission.phone, Permission.sms].request();
  }

  static Future<int> getMissedCallCount() async {
    if (!await Permission.phone.isGranted) return 0;
    try {
      return await _channel.invokeMethod<int>('getMissedCallCount') ?? 0;
    } on PlatformException {
      return 0;
    }
  }

  static Future<int> getUnreadSmsCount() async {
    if (!await Permission.sms.isGranted) return 0;
    try {
      return await _channel.invokeMethod<int>('getUnreadSmsCount') ?? 0;
    } on PlatformException {
      return 0;
    }
  }

  static Future<({int missedCalls, int unreadSms})> getCounts() async {
    final results = await Future.wait([
      getMissedCallCount(),
      getUnreadSmsCount(),
    ]);
    return (missedCalls: results[0], unreadSms: results[1]);
  }
}
