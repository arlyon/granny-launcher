import 'dart:async';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/communication_service.dart';

class SosButton extends StatefulWidget {
  final String? sosNumber;

  const SosButton({super.key, required this.sosNumber});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  bool _isCalling = false;

  Future<void> _call(String number) async {
    try {
      if (await Permission.phone.isGranted) {
        await AndroidIntent(
          action: 'android.intent.action.CALL',
          data: 'tel:$number',
        ).launch();
        return;
      }
    } catch (_) {}
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendLocationSms(String number) async {
    String msg = "SOS! I need help.";
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          msg =
              "SOS! I need help. My location: https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}";
        }
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    }

    try {
      await CommunicationService.sendBackgroundSms(number, msg);
    } catch (e) {
      debugPrint("SMS Error: $e");
    }
  }

  Future<void> _onPressed(BuildContext context) async {
    final number = widget.sosNumber;
    if (number == null || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No SOS number configured. Please enter admin mode to set it up.',
            style: TextStyle(fontSize: 18),
          ),
          backgroundColor: Color(0xFF880000),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isCalling = true);
    // unawaited(FlutterRingtonePlayer().playAlarm(looping: false));

    // Fire both in parallel: SMS waits for location while call goes out immediately.
    unawaited(_sendLocationSms(number));
    await _call(number);

    if (mounted) setState(() => _isCalling = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ElevatedButton.icon(
        onPressed: _isCalling ? null : () => _onPressed(context),
        icon: const Icon(Icons.warning_rounded, size: 36, color: Colors.white),
        label: Text(
          _isCalling ? 'CALLING' : 'SOS',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCC0000),
          disabledBackgroundColor: const Color(0xFFCC0000),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
