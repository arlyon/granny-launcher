import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class CommunicationService {
  static const _channel = MethodChannel('granny_launcher/system');

  static Future<void> requestPermissions() async {
    await [
      Permission.phone,
      Permission.sms,
      Permission.location,
    ].request();
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

  static Future<void> sendBackgroundSms(String number, String message) async {
    if (!await Permission.sms.isGranted) return;
    try {
      await _channel.invokeMethod('sendSms', {
        'number': number,
        'message': message,
      });
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print("Native SMS Error: $e");
    }
  }

  static Future<String?> getCallState() async {
    if (!await Permission.phone.isGranted) return null;
    try {
      return await _channel.invokeMethod<String>('getCallState');
    } on PlatformException {
      return null;
    }
  }

  static Future<bool> returnToCall() async {
    try {
      return await _channel.invokeMethod<bool>('returnToCall') ?? false;
    } on PlatformException {
      return false;
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
