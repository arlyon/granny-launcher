import 'dart:typed_data';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../models/pinned_app.dart';
import 'storage_service.dart';

class AppService {
  final _storage = StorageService();

  Future<List<AppInfo>> getAllApps() async {
    return InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      withIcon: false,
    );
  }

  Future<List<PinnedApp>> getPinnedApps() async {
    final packages = await _storage.getPinnedAppPackages();
    if (packages.isEmpty) return [];

    final infos = await Future.wait(packages.map(InstalledApps.getAppInfo));
    final result = <PinnedApp>[];

    for (final info in infos) {
      if (info == null) continue;
      result.add(PinnedApp(
        label: info.name,
        packageName: info.packageName,
        icon: info.icon,
      ));
    }
    return result;
  }

  Future<Uint8List?> getAppIcon(String packageName) async {
    final info = await InstalledApps.getAppInfo(packageName);
    return info?.icon;
  }
}
