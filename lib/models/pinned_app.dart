import 'dart:typed_data';

class PinnedApp {
  final String label;
  final String packageName;
  final Uint8List? icon;

  const PinnedApp({
    required this.label,
    required this.packageName,
    this.icon,
  });
}
