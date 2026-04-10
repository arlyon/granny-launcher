import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pinput/pinput.dart';
import '../main.dart' show kUiScales, uiScaleNotifier, backgroundImageNotifier;
import '../models/app_contact.dart';
import '../models/pinned_app.dart';
import '../models/quick_action_intent.dart';
import '../services/storage_service.dart';
import '../services/contacts_service.dart';
import '../services/app_service.dart';
import 'admin/contact_picker.dart';
import 'admin/app_picker.dart';

const _kPin = '1996';
const _kMaxContacts = 6;
const _kMaxApps = 8;

class AdminOverlay extends StatefulWidget {
  const AdminOverlay({super.key});

  @override
  State<AdminOverlay> createState() => _AdminOverlayState();
}

class _AdminOverlayState extends State<AdminOverlay>
    with SingleTickerProviderStateMixin {
  bool _unlocked = false;
  bool _showError = false;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -20.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -20.0, end: 20.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 20.0, end: -20.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -20.0, end: 20.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 20.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onPinCompleted(String pin) {
    if (pin == _kPin) {
      setState(() {
        _unlocked = true;
        _showError = false;
      });
    } else {
      setState(() => _showError = true);
      _shakeController.forward(from: 0).then((_) {
        if (mounted) _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _unlocked ? 'Admin Settings' : 'Admin Access',
          style: const TextStyle(
            color: Color(0xFFFFFF00),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: _unlocked
            ? [
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white, size: 32),
                  tooltip: 'Android Settings',
                  onPressed: () async {
                    const channel = MethodChannel('granny_launcher/system');
                    try {
                      await channel.invokeMethod<void>('openSettings');
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open settings'),
                            backgroundColor: Color(0xFF880000),
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: _unlocked ? const _AdminSettings() : _buildPinScreen(),
    );
  }

  Widget _buildPinScreen() {
    final defaultTheme = PinTheme(
      width: 72,
      height: 72,
      textStyle: const TextStyle(
        fontSize: 36,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white38, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1A1A1A),
      ),
    );

    final focusedTheme = defaultTheme.copyWith(
      decoration: defaultTheme.decoration!.copyWith(
        border: Border.all(color: const Color(0xFFFFFF00), width: 2),
      ),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFFFFFF00), size: 80),
            const SizedBox(height: 32),
            const Text(
              'Enter PIN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 36),
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              ),
              child: Pinput(
                length: 4,
                obscureText: true,
                autofocus: true,
                controller: _pinController,
                defaultPinTheme: defaultTheme,
                focusedPinTheme: focusedTheme,
                onCompleted: _onPinCompleted,
              ),
            ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              opacity: _showError ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Text(
                'Incorrect PIN',
                style: TextStyle(
                  color: Color(0xFFFF4444),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Admin settings (shown after correct PIN)
// ---------------------------------------------------------------------------

class _AdminSettings extends StatefulWidget {
  const _AdminSettings();

  @override
  State<_AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<_AdminSettings> {
  static const _channel = MethodChannel('granny_launcher/system');

  final _storage = StorageService();
  final _contactsService = ContactsService();
  final _appService = AppService();
  final _sosController = TextEditingController();

  List<AppContact> _contacts = [];
  List<PinnedApp> _apps = [];
  bool _loading = true;
  bool _sosSaving = false;
  String? _loadError;
  bool _isDeviceOwner = false;
  bool _statusBarDisabled = false;
  int _uiScaleIndex = uiScaleNotifier.value;
  String? _bgImagePath = backgroundImageNotifier.value;
  QuickActionIntent? _phoneIntent;
  QuickActionIntent? _smsIntent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sosController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final contacts = await _contactsService.getPinnedContacts();
      // Prune any stored IDs that no longer resolve to a contact
      final storedIds = await _storage.getPinnedContactIds();
      final validIds = contacts.map((c) => c.id).toList();
      if (storedIds.length != validIds.length) {
        await _storage.setPinnedContactIds(validIds);
      }
      final apps = await _appService.getPinnedApps();
      final sos = await _storage.getSosNumber();
      final bgPath = await _storage.getBackgroundImagePath();
      final smsApp = QuickActionIntent.tryParse(await _storage.getSmsIntent());
      final phoneApp = QuickActionIntent.tryParse(await _storage.getPhoneIntent());
      final isDeviceOwner =
          await _channel.invokeMethod<bool>('isDeviceOwner') ?? false;
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _apps = apps;
          _sosController.text = sos ?? '';
          _bgImagePath = bgPath;
          _smsIntent = smsApp;
          _phoneIntent = phoneApp;
          _isDeviceOwner = isDeviceOwner;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleStatusBar(bool disabled) async {
    final success = await _channel.invokeMethod<bool>(
          'setStatusBarDisabled',
          {'disabled': disabled},
        ) ??
        false;
    if (success && mounted) {
      setState(() => _statusBarDisabled = disabled);
    }
  }

  Future<void> _pickContacts() async {
    final currentIds = _contacts.map((c) => c.id).toList();
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ContactPickerPage(
          selectedIds: currentIds,
          maxCount: _kMaxContacts,
        ),
      ),
    );
    if (result != null) {
      await _storage.setPinnedContactIds(result);
      // Reload full contact objects for display
      final updated = await _contactsService.getPinnedContacts();
      if (mounted) setState(() => _contacts = updated);
    }
  }

  Future<void> _removeContact(String id) async {
    final ids = _contacts.map((c) => c.id).where((i) => i != id).toList();
    await _storage.setPinnedContactIds(ids);
    setState(() => _contacts.removeWhere((c) => c.id == id));
  }

  Future<void> _pickApps() async {
    final currentPkgs = _apps.map((a) => a.packageName).toList();
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AppPickerPage(
          selectedPackages: currentPkgs,
          maxCount: _kMaxApps,
        ),
      ),
    );
    if (result != null) {
      await _storage.setPinnedAppPackages(result);
      final updated = await _appService.getPinnedApps();
      if (mounted) setState(() => _apps = updated);
    }
  }

  Future<void> _removeApp(String packageName) async {
    final pkgs =
        _apps.map((a) => a.packageName).where((p) => p != packageName).toList();
    await _storage.setPinnedAppPackages(pkgs);
    setState(() => _apps.removeWhere((a) => a.packageName == packageName));
  }

  Future<void> _pickPhoneIntent() async {
    final intent = await _showIntentPicker(
      title: 'Phone / Recents',
      presets: const [
        _IntentPreset(
          label: 'Call log',
          subtitle: 'Opens recents tab (android.intent.action.VIEW)',
          intent: QuickActionIntent.phoneCallLog,
        ),
        _IntentPreset(
          label: 'Phone app',
          subtitle: 'Opens default phone app (APP_PHONE)',
          intent: QuickActionIntent.phoneApp,
        ),
      ],
    );
    if (intent != null) {
      await _storage.setPhoneIntent(intent.toJsonString());
      if (mounted) setState(() => _phoneIntent = intent);
    }
  }

  Future<void> _pickSmsIntent() async {
    final intent = await _showIntentPicker(
      title: 'Messages / Inbox',
      presets: const [
        _IntentPreset(
          label: 'Messages app',
          subtitle: 'Opens default SMS app (APP_MESSAGING)',
          intent: QuickActionIntent.messagesApp,
        ),
      ],
    );
    if (intent != null) {
      await _storage.setSmsIntent(intent.toJsonString());
      if (mounted) setState(() => _smsIntent = intent);
    }
  }

  Future<QuickActionIntent?> _showIntentPicker({
    required String title,
    required List<_IntentPreset> presets,
  }) async {
    return showModalBottomSheet<QuickActionIntent>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _IntentPickerSheet(
        title: title,
        presets: presets,
        appService: _appService,
      ),
    );
  }

  Future<void> _saveSosNumber() async {
    setState(() => _sosSaving = true);
    await _storage.setSosNumber(_sosController.text.trim());
    if (mounted) {
      setState(() => _sosSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS number saved', style: TextStyle(fontSize: 18)),
          backgroundColor: Color(0xFF1A3300),
        ),
      );
    }
  }

  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final dest = File('${appDir.path}/background.jpg');
    await File(picked.path).copy(dest.path);

    await _storage.setBackgroundImagePath(dest.path);
    backgroundImageNotifier.value = dest.path;
    if (mounted) setState(() => _bgImagePath = dest.path);
  }

  Future<void> _removeBackgroundImage() async {
    await _storage.setBackgroundImagePath(null);
    backgroundImageNotifier.value = null;
    if (mounted) setState(() => _bgImagePath = null);
  }

  Future<void> _exitLauncher() async {
    try {
      await _channel.invokeMethod<void>('showLauncherChooser');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open launcher chooser'),
            backgroundColor: Color(0xFF880000),
          ),
        );
      }
    }
  }

  Future<void> _clearDeviceOwner() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Remove Device Owner?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove the app\'s administrative control over the device. '
          'You may need to manually re-enable it via ADB if you want it back.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFFFFF00))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Color(0xFFFF4444))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await _channel.invokeMethod<bool>('clearDeviceOwner') ?? false;
      if (success && mounted) {
        setState(() => _isDeviceOwner = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device Owner removed successfully'),
            backgroundColor: Color(0xFF1A3300),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove Device Owner: $e'),
            backgroundColor: const Color(0xFF880000),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFFF00)),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to load settings:\n$_loadError',
            style: const TextStyle(color: Color(0xFFFF4444), fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildContactsSection(),
        const SizedBox(height: 24),
        _buildAppsSection(),
        const SizedBox(height: 24),
        _buildAppShortcutsSection(),
        const SizedBox(height: 24),
        _buildSosSection(),
        const SizedBox(height: 24),
        _buildBackgroundSection(),
        const SizedBox(height: 24),
        _buildUiScaleSection(),
        const SizedBox(height: 24),
        _buildKioskSection(),
        const SizedBox(height: 24),
        _buildExitSection(),
        const SizedBox(height: 24),
        _buildChecklist(),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Contacts ──────────────────────────────────────────────────────────────

  Widget _buildContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionRow(
          'Quick Dial Contacts',
          '${_contacts.length}/$_kMaxContacts',
          'Edit',
          _pickContacts,
        ),
        const SizedBox(height: 10),
        _contacts.isEmpty
            ? _emptyCard(
                'No contacts yet. Tap Edit to add up to $_kMaxContacts.')
            : _card(
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _contacts
                        .map((c) => _ContactChip(
                              contact: c,
                              onRemove: () => _removeContact(c.id),
                            ))
                        .toList(),
                  ),
                ),
              ),
      ],
    );
  }

  // ── Apps ──────────────────────────────────────────────────────────────────

  Widget _buildAppsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionRow(
          'Pinned Apps',
          '${_apps.length}/$_kMaxApps',
          'Edit',
          _pickApps,
        ),
        const SizedBox(height: 10),
        _apps.isEmpty
            ? _emptyCard('No apps yet. Tap Edit to add up to $_kMaxApps.')
            : _card(
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _apps
                        .map((a) => _AppChip(
                              app: a,
                              onRemove: () => _removeApp(a.packageName),
                            ))
                        .toList(),
                  ),
                ),
              ),
      ],
    );
  }

  // ── App Shortcuts ─────────────────────────────────────────────────────────

  Widget _buildAppShortcutsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('App Shortcuts'),
        _card(
          Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.call, color: Color(0xFFFFFF00), size: 32),
                title: const Text('Phone / Recents',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                subtitle: Text(
                  _phoneIntent?.description ?? 'Not configured — tap to set',
                  style: TextStyle(
                    color: _phoneIntent != null
                        ? Colors.white54
                        : const Color(0xFFFF8800),
                    fontSize: 13,
                  ),
                ),
                trailing: _actionButton('Change', _pickPhoneIntent),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.message, color: Color(0xFFFFFF00), size: 32),
                title: const Text('Messages / Inbox',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                subtitle: Text(
                  _smsIntent?.description ?? 'Not configured — tap to set',
                  style: TextStyle(
                    color: _smsIntent != null
                        ? Colors.white54
                        : const Color(0xFFFF8800),
                    fontSize: 13,
                  ),
                ),
                trailing: _actionButton('Change', _pickSmsIntent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── SOS ───────────────────────────────────────────────────────────────────

  Widget _buildSosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('SOS Emergency Number'),
        _card(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _sosController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 22),
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      labelStyle:
                          TextStyle(color: Colors.white38, fontSize: 18),
                      hintText: '+44 7700 900000',
                      hintStyle:
                          TextStyle(color: Colors.white24, fontSize: 20),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: Color(0xFFFFFF00), width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _sosSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFFF00),
                          strokeWidth: 2,
                        ),
                      )
                    : _actionButton('Save', _saveSosNumber),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Background Photo ──────────────────────────────────────────────────────

  Widget _buildBackgroundSection() {
    final bgFile = _bgImagePath != null ? File(_bgImagePath!) : null;
    final hasImage = bgFile != null && bgFile.existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Background Photo'),
        _card(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: hasImage
                      ? Image.file(bgFile, width: 80, height: 60, fit: BoxFit.cover)
                      : Container(
                          width: 80,
                          height: 60,
                          color: const Color(0xFF1A1A1A),
                          child: const Icon(Icons.image_outlined,
                              color: Colors.white38, size: 32),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    hasImage ? 'Photo set' : 'No photo selected',
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _actionButton('Choose', _pickBackgroundImage),
                    if (hasImage) ...[
                      const SizedBox(height: 8),
                      _actionButton('Remove', _removeBackgroundImage),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── UI Scale ──────────────────────────────────────────────────────────────

  Future<void> _setUiScale(int index) async {
    await _storage.setUiScaleIndex(index);
    uiScaleNotifier.value = index;
    if (mounted) setState(() => _uiScaleIndex = index);
  }

  Widget _buildUiScaleSection() {
    const labels = ['XS', 'S', 'M', 'L', 'XL'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Font Size'),
        _card(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: List.generate(kUiScales.length, (i) {
                final selected = i == _uiScaleIndex;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < kUiScales.length - 1 ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => _setUiScale(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 52,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFFFFF00)
                              : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFFFFF00)
                                : Colors.white24,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              color: selected ? Colors.black : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // ── Kiosk mode ────────────────────────────────────────────────────────────

  Widget _buildKioskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Kiosk Mode'),
        _card(
          Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(
                  _isDeviceOwner ? Icons.lock : Icons.lock_open,
                  color: _isDeviceOwner
                      ? const Color(0xFFFFFF00)
                      : Colors.white38,
                  size: 32,
                ),
                title: Text(
                  _isDeviceOwner ? 'Device Owner active' : 'Not Device Owner',
                  style: TextStyle(
                    color: _isDeviceOwner ? Colors.white : Colors.white54,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  _isDeviceOwner
                      ? 'Full kiosk controls available'
                      : 'Run: adb shell dpm set-device-owner com.example.granny_launcher/.DeviceAdminReceiver',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                trailing: _isDeviceOwner
                    ? _actionButton('De-admin', _clearDeviceOwner)
                    : null,
              ),
              if (_isDeviceOwner) ...[
                const Divider(color: Colors.white12, height: 1),
                SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: const Text('Lock status bar',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  subtitle: const Text(
                      'Disables pull-down notification shade',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                  activeColor: const Color(0xFFFFFF00),
                  value: _statusBarDisabled,
                  onChanged: _toggleStatusBar,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Exit launcher ─────────────────────────────────────────────────────────

  Widget _buildExitSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Exit Launcher'),
        _card(
          Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.launch,
                    color: Color(0xFFFFFF00), size: 32),
                title: const Text('Switch home screen app',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                subtitle: const Text('Opens Android launcher chooser',
                    style: TextStyle(color: Colors.white38, fontSize: 14)),
                trailing: _actionButton('Exit', _exitLauncher),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Section header row with a count badge and an action button.
  Widget _sectionRow(
      String title, String count, String btnLabel, VoidCallback onTap) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFFFFF00),
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF333300),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  count,
                  style: const TextStyle(
                      color: Color(0xFFFFFF00),
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        _actionButton(btnLabel, onTap),
      ],
    );
  }

  Widget _card(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _emptyCard(String message) {
    return _card(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Text(
          message,
          style: const TextStyle(color: Colors.white38, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFFF00),
        foregroundColor: Colors.black,
        textStyle:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        minimumSize: const Size(64, 44),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  Widget _buildChecklist() {
    const items = [
      ('Set as default launcher', 'Settings › Apps › Default apps › Home app'),
      ('Disable Edge panels', 'Settings › Display › Edge panels › Off'),
      ('Grant notification access',
          'Settings › Notifications › Device notification management'),
      ('Disable Bixby key', 'Settings › Advanced features › Side key › Off'),
      ('Screen timeout', 'Settings › Display › Screen timeout › 10 min'),
      ('Font & display size', 'Settings › Accessibility › Font size and style'),
      ('Auto-rotate off', 'Settings › Display › Auto rotate › Off'),
      ('Set Device Owner (kiosk)',
          'adb shell dpm set-device-owner com.example.granny_launcher/.DeviceAdminReceiver'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Setup Checklist'),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Container(
                decoration: i < items.length - 1
                    ? const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: Colors.white12)),
                      )
                    : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 2),
                  leading: const Icon(Icons.check_circle_outline,
                      color: Color(0xFFFFFF00), size: 26),
                  title: Text(
                    item.$1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    item.$2,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFFFFF00),
          fontSize: 17,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

// ── Contact chip ─────────────────────────────────────────────────────────────

class _ContactChip extends StatelessWidget {
  final AppContact contact;
  final VoidCallback onRemove;

  const _ContactChip({required this.contact, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFF2A2A00),
                backgroundImage: contact.photo != null
                    ? MemoryImage(contact.photo!)
                    : null,
                child: contact.photo == null
                    ? Text(
                        contact.name.isNotEmpty
                            ? contact.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFFFFFF00),
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCC0000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            contact.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── App chip ─────────────────────────────────────────────────────────────────

class _AppChip extends StatelessWidget {
  final PinnedApp app;
  final VoidCallback onRemove;

  const _AppChip({required this.app, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: app.icon != null
                    ? Image.memory(app.icon!,
                        width: 64, height: 64, fit: BoxFit.cover)
                    : Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.apps,
                            color: Color(0xFFFFFF00), size: 36),
                      ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCC0000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            app.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Intent preset data ────────────────────────────────────────────────────────

class _IntentPreset {
  final String label;
  final String subtitle;
  final QuickActionIntent intent;

  const _IntentPreset({
    required this.label,
    required this.subtitle,
    required this.intent,
  });
}

// ── Intent picker bottom sheet ────────────────────────────────────────────────

class _IntentPickerSheet extends StatefulWidget {
  final String title;
  final List<_IntentPreset> presets;
  final AppService appService;

  const _IntentPickerSheet({
    required this.title,
    required this.presets,
    required this.appService,
  });

  @override
  State<_IntentPickerSheet> createState() => _IntentPickerSheetState();
}

class _IntentPickerSheetState extends State<_IntentPickerSheet> {
  bool _loadingApps = false;

  Future<void> _pickApp() async {
    setState(() => _loadingApps = true);
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AppPickerPage(selectedPackages: const [], maxCount: 1),
      ),
    );
    if (!mounted) return;
    setState(() => _loadingApps = false);
    if (result != null && result.isNotEmpty) {
      Navigator.pop(context, QuickActionIntent.forPackage(result.first));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                widget.title.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFFFFF00),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ...widget.presets.map((p) => ListTile(
                  onTap: () => Navigator.pop(context, p.intent),
                  leading: const Icon(Icons.flash_on,
                      color: Color(0xFFFFFF00), size: 28),
                  title: Text(p.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(p.subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 13)),
                )),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              onTap: _loadingApps ? null : _pickApp,
              leading: _loadingApps
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          color: Color(0xFFFFFF00), strokeWidth: 2),
                    )
                  : const Icon(Icons.apps, color: Color(0xFFFFFF00), size: 28),
              title: const Text('Choose app…',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              subtitle: const Text('Launch any installed app directly',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
