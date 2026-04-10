import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class UpdateService {
  static const _channel = MethodChannel('granny_launcher/system');
  
  // Replace with actual repository info
  static const String _repoUrl = 'https://github.com/arlyon/granny-launcher/releases/download/latest';

  /// Returns a human-readable status string describing the result.
  Future<String> checkForUpdates() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final response = await Dio().get('$_repoUrl/version.json');

      if (response.statusCode != 200) return 'Server error: ${response.statusCode}';

      final data = (response.data is String
          ? jsonDecode(response.data as String)
          : response.data) as Map<String, dynamic>;
      final serverVersion = data['version'] as String;
      final downloadUrl = data['url'] as String;

      if (_isNewer(serverVersion, info.version)) {
        final tempDir = await getTemporaryDirectory();
        final fullPath = '${tempDir.path}/update.apk';

        await Dio().download(downloadUrl, fullPath);
        await _channel.invokeMethod('installSilently', {'path': fullPath});
        return 'Update to $serverVersion is installing…';
      }

      return 'Already up to date (v${info.version})';
    } catch (e) {
      return 'Update check failed: $e';
    }
  }

  bool _isNewer(String server, String local) {
    List<int> serverParts = server.split('.').map(int.parse).toList();
    List<int> localParts = local.split('.').map(int.parse).toList();

    for (int i = 0; i < serverParts.length; i++) {
      if (i >= localParts.length) return true;
      if (serverParts[i] > localParts[i]) return true;
      if (serverParts[i] < localParts[i]) return false;
    }
    return false;
  }
}
