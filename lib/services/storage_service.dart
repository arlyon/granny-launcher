import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyPinnedContacts = 'pinned_contact_ids';
  static const _keyPinnedApps = 'pinned_app_packages';
  static const _keySosNumber = 'sos_number';
  static const _keyUiScaleIndex = 'ui_scale_index';
  static const _keyBackgroundImagePath = 'background_image_path';

  static Future<SharedPreferences>? _prefsInstance;
  Future<SharedPreferences> get _prefs =>
      _prefsInstance ??= SharedPreferences.getInstance();

  Future<List<String>> getPinnedContactIds() async {
    return (await _prefs).getStringList(_keyPinnedContacts) ?? [];
  }

  Future<void> setPinnedContactIds(List<String> ids) async {
    await (await _prefs).setStringList(_keyPinnedContacts, ids);
  }

  Future<List<String>> getPinnedAppPackages() async {
    return (await _prefs).getStringList(_keyPinnedApps) ?? [];
  }

  Future<void> setPinnedAppPackages(List<String> packages) async {
    await (await _prefs).setStringList(_keyPinnedApps, packages);
  }

  Future<String?> getSosNumber() async {
    return (await _prefs).getString(_keySosNumber);
  }

  Future<void> setSosNumber(String number) async {
    await (await _prefs).setString(_keySosNumber, number);
  }

  Future<int> getUiScaleIndex() async {
    return (await _prefs).getInt(_keyUiScaleIndex) ?? 2;
  }

  Future<void> setUiScaleIndex(int index) async {
    await (await _prefs).setInt(_keyUiScaleIndex, index);
  }

  Future<String?> getBackgroundImagePath() async {
    return (await _prefs).getString(_keyBackgroundImagePath);
  }

  Future<void> setBackgroundImagePath(String? path) async {
    final prefs = await _prefs;
    if (path == null) {
      await prefs.remove(_keyBackgroundImagePath);
    } else {
      await prefs.setString(_keyBackgroundImagePath, path);
    }
  }

  static const _keyPhoneIntent = 'phone_intent';
  static const _keySmsIntent = 'sms_intent';

  Future<String?> getPhoneIntent() async {
    return (await _prefs).getString(_keyPhoneIntent);
  }

  Future<void> setPhoneIntent(String? json) async {
    final prefs = await _prefs;
    if (json == null) {
      await prefs.remove(_keyPhoneIntent);
    } else {
      await prefs.setString(_keyPhoneIntent, json);
    }
  }

  Future<String?> getSmsIntent() async {
    return (await _prefs).getString(_keySmsIntent);
  }

  Future<void> setSmsIntent(String? json) async {
    final prefs = await _prefs;
    if (json == null) {
      await prefs.remove(_keySmsIntent);
    } else {
      await prefs.setString(_keySmsIntent, json);
    }
  }
}
