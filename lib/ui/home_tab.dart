import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:installed_apps/installed_apps.dart';
import '../models/app_contact.dart';
import '../models/pinned_app.dart';
import '../services/contacts_service.dart';
import '../services/app_service.dart';
import '../services/storage_service.dart';
import 'widgets/contact_card.dart';
import 'widgets/app_icon_tile.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onAdminRequested;

  const HomeTab({super.key, required this.onAdminRequested});

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  final _contactsService = ContactsService();
  final _appService = AppService();
  final _storage = StorageService();

  // Cached across reloads so we can render immediately on next open
  static List<AppContact>? _cachedContacts;
  static List<PinnedApp>? _cachedApps;
  static String? _cachedSosNumber;

  List<AppContact> _contacts = [];
  List<PinnedApp> _apps = [];
  String? _sosNumber;
  bool _loading = true;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    // Render immediately from cache if available, skipping the loading spinner
    if (_cachedContacts != null && mounted) {
      setState(() {
        _contacts = _cachedContacts!;
        _apps = _cachedApps!;
        _sosNumber = _cachedSosNumber;
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = true);
    }

    // Fetch fresh data (in background if cache was available)
    final results = await Future.wait([
      _contactsService.getPinnedContacts(),
      _appService.getPinnedApps(),
      _storage.getSosNumber(),
    ]);
    final contacts = results[0] as List<AppContact>;
    final apps = results[1] as List<PinnedApp>;
    final sos = results[2] as String?;

    _cachedContacts = contacts;
    _cachedApps = apps;
    _cachedSosNumber = sos;

    if (mounted) {
      final same = !_loading &&
          sos == _sosNumber &&
          contacts.length == _contacts.length &&
          apps.length == _apps.length &&
          List.generate(contacts.length, (i) => contacts[i].phoneNumber == _contacts[i].phoneNumber).every((b) => b) &&
          List.generate(apps.length, (i) => apps[i].packageName == _apps[i].packageName).every((b) => b);

      if (!same) {
        setState(() {
          _contacts = contacts;
          _apps = apps;
          _sosNumber = sos;
          _loading = false;
        });
      }
    }
  }

  Future<void> _callContact(AppContact contact) async {
    final uri = Uri.parse('tel:${contact.phoneNumber}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchApp(PinnedApp app) async {
    await AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      package: app.packageName,
      flags: [0x10000000, 0x00200000], // NEW_TASK | RESET_TASK_IF_NEEDED
    ).launch();
  }

  Future<void> _callSos() async {
    final number = _sosNumber;
    if (number == null || number.isEmpty) {
      if (mounted) {
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
      }
      return;
    }
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _toggleTorch() async {
    try {
      if (_torchOn) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFFF00)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('QUICK DIAL'),
                const SizedBox(height: 8),
                _buildContactGrid(),
                const SizedBox(height: 20),
                _sectionHeader('APPS'),
                const SizedBox(height: 8),
                _buildAppGrid(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        _buildSosButton(),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFFFFF00),
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildContactGrid() {
    if (_contacts.isEmpty) {
      return _emptyState('No contacts set up yet.\nLong-press the top bar to configure.');
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.0,
      children: _contacts
          .map((c) => ContactCard(contact: c, onTap: () => _callContact(c)))
          .toList(),
    );
  }

  Widget _buildAppGrid() {
    if (_apps.isEmpty) {
      return _emptyState('No apps set up yet.\nLong-press the top bar to configure.');
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 16,
      childAspectRatio: 0.8,
      children: _apps
          .map((a) => AppIconTile(
                label: a.label,
                icon: a.icon,
                onTap: () => _launchApp(a),
              ))
          .toList(),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white38, fontSize: 18),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSosButton() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 72,
              child: ElevatedButton.icon(
                onPressed: _callSos,
                icon: const Icon(Icons.warning_rounded, size: 36, color: Colors.white),
                label: const Text(
                  'SOS',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            height: 72,
            child: ElevatedButton(
              onPressed: _toggleTorch,
              style: ElevatedButton.styleFrom(
                backgroundColor: _torchOn ? const Color(0xFFFFD700) : const Color(0xFF333333),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Icon(
                _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
                size: 36,
                color: _torchOn ? Colors.black : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
