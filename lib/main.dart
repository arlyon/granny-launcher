import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notif_service.dart';
import 'ui/home_screen.dart';

/// The 5 available UI scale steps (applied as textScaleFactor).
const kUiScales = [0.70, 0.85, 1.00, 1.20, 1.40];
const _kUiScaleKey = 'ui_scale_index';

/// Global notifier so AdminOverlay can change the scale and have it
/// take effect immediately without a restart.
final uiScaleNotifier = ValueNotifier<int>(2);

/// Global notifier for the background image path.
final backgroundImageNotifier = ValueNotifier<String?>(null);

const _kBackgroundImageKey = 'background_image_path';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final notifPermissionGranted = await NotifService.isPermissionGranted();

  final prefs = await SharedPreferences.getInstance();
  uiScaleNotifier.value = prefs.getInt(_kUiScaleKey) ?? 2;
  backgroundImageNotifier.value = prefs.getString(_kBackgroundImageKey);

  runApp(GrannyLauncherApp(notifPermissionGranted: notifPermissionGranted));
}

class GrannyLauncherApp extends StatelessWidget {
  final bool notifPermissionGranted;

  const GrannyLauncherApp({super.key, required this.notifPermissionGranted});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: uiScaleNotifier,
      builder: (context, scaleIndex, _) {
        return MaterialApp(
          title: 'Granny Launcher',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: Colors.black,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFFF00),
              onPrimary: Colors.black,
              surface: Color(0xFF111111),
              onSurface: Colors.white,
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              bodyMedium: TextStyle(color: Colors.white, fontSize: 20),
              headlineLarge: TextStyle(
                color: Color(0xFFFFFF00),
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
              headlineMedium: TextStyle(
                color: Color(0xFFFFFF00),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white, size: 48),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFFF00),
                foregroundColor: Colors.black,
                textStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                minimumSize: const Size(double.infinity, 70),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Override textScaler so our setting fully replaces the system
          // font-size preference — prevents HiDPI blowup.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(kUiScales[scaleIndex]),
            ),
            child: child!,
          ),
          home: HomeScreen(notifPermissionGranted: notifPermissionGranted),
        );
      },
    );
  }
}
