import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'home_tab.dart';
import 'notif_tab.dart';
import 'admin_overlay.dart';
import '../models/quick_action_intent.dart';
import '../services/communication_service.dart';
import '../services/storage_service.dart';
import '../main.dart' show backgroundImageNotifier;

class HomeScreen extends StatefulWidget {
  final bool notifPermissionGranted;

  const HomeScreen({super.key, required this.notifPermissionGranted});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  final GlobalKey<HomeTabState> _homeTabKey = GlobalKey<HomeTabState>();
  int _currentPage = 0;
  int _missedCalls = 0;
  int _unreadSms = 0;

  final _battery = Battery();
  int _batteryLevel = 0;
  BatteryState _batteryState = BatteryState.unknown;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  Timer? _batteryTimer;
  Timer? _commsTimer;

  @override
  void initState() {
    super.initState();
    _fetchBattery();
    _fetchCommunicationCounts();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now());
    });
    _batteryTimer = Timer.periodic(const Duration(minutes: 1), (_) => _fetchBattery());
    _commsTimer = Timer.periodic(const Duration(minutes: 1), (_) => _fetchCommunicationCounts());
    _battery.onBatteryStateChanged.listen((s) {
      setState(() => _batteryState = s);
    });
    CommunicationService.requestPermissions().then((_) => _fetchCommunicationCounts());
  }

  Future<void> _fetchCommunicationCounts() async {
    final counts = await CommunicationService.getCounts();
    if (!mounted) return;
    setState(() {
      _missedCalls = counts.missedCalls;
      _unreadSms = counts.unreadSms;
    });
  }

  Future<void> _fetchBattery() async {
    final level = await _battery.batteryLevel;
    final state = await _battery.batteryState;
    setState(() {
      _batteryLevel = level;
      _batteryState = state;
    });
  }

  // 10-tap admin trigger
  int _homeTapCount = 0;
  DateTime? _firstHomeTap;

  Future<void> _launchQuickAction(
      Future<String?> Function() getJson, String label) async {
    final cfg = QuickActionIntent.tryParse(await getJson());
    if (cfg == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$label not configured — set it in Admin Settings',
              style: const TextStyle(fontSize: 16)),
          backgroundColor: const Color(0xFF883300),
        ));
      }
      return;
    }
    await AndroidIntent(
      action: cfg.action,
      category: cfg.category,
      type: cfg.type,
      data: cfg.data,
      package: cfg.package,
      flags: cfg.flags ?? [0x10000000, 0x00200000], // NEW_TASK | RESET_TASK_IF_NEEDED
    ).launch();
  }

  Future<void> _openPhoneRecents() =>
      _launchQuickAction(StorageService().getPhoneIntent, 'Phone app');

  Future<void> _openMessages() =>
      _launchQuickAction(StorageService().getSmsIntent, 'Messages app');

  void _goToNotifications() {
    _pageController.jumpToPage(1);
    setState(() => _currentPage = 1);
  }

  void _goToHome() {
    _pageController.jumpToPage(0);
    setState(() => _currentPage = 0);
    _countHomeTap();
  }

  void _countHomeTap() {
    final now = DateTime.now();
    if (_firstHomeTap == null ||
        now.difference(_firstHomeTap!) > const Duration(seconds: 5)) {
      _firstHomeTap = now;
      _homeTapCount = 1;
    } else {
      _homeTapCount++;
      if (_homeTapCount >= 10) {
        _homeTapCount = 0;
        _firstHomeTap = null;
        _showPinOverlay();
      }
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _batteryTimer?.cancel();
    _commsTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.black,
        body: ValueListenableBuilder<String?>(
          valueListenable: backgroundImageNotifier,
          builder: (context, bgPath, child) {
            final bgFile = bgPath != null ? File(bgPath) : null;
            final hasBg = bgFile != null && bgFile.existsSync();
            return Stack(
              children: [
                if (hasBg)
                  Positioned.fill(
                    child: Image.file(bgFile, fit: BoxFit.cover),
                  ),
                if (hasBg)
                  Positioned.fill(
                    child: ColoredBox(color: Color(0xAA000000)),
                  ),
                child!,
              ],
            );
          },
          child: Column(
            children: [
              _buildStatusBar(),
              _buildHeader(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    HomeTab(key: _homeTabKey, onAdminRequested: _showPinOverlay),
                    NotifTab(initialPermissionGranted: widget.notifPermissionGranted),
                  ],
                ),
              ),
              _buildTabBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final hour = _now.hour;
    final minute = _now.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final timeStr = '$hour12:$minute $ampm';

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateStr = '${days[_now.weekday - 1]} ${months[_now.month - 1]} ${_now.day}';

    IconData batteryIcon;
    Color batteryColor;
    if (_batteryState == BatteryState.charging || _batteryState == BatteryState.full) {
      batteryIcon = Icons.battery_charging_full;
      batteryColor = Colors.greenAccent;
    } else if (_batteryLevel <= 20) {
      batteryIcon = Icons.battery_alert;
      batteryColor = const Color(0xFFFF4444);
    } else if (_batteryLevel <= 50) {
      batteryIcon = Icons.battery_3_bar;
      batteryColor = const Color(0xFFFFFF00);
    } else {
      batteryIcon = Icons.battery_full;
      batteryColor = Colors.white70;
    }

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            timeStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              dateStr,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 22,
              ),
            ),
          ),
          Icon(batteryIcon, color: batteryColor, size: 32),
          const SizedBox(width: 6),
          Text(
            '$_batteryLevel%',
            style: TextStyle(
              color: batteryColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      child: Container(
        color: const Color(0xFF111111),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _missedCalls > 0 ? _openPhoneRecents : null,
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_missed,
                      color: _missedCalls > 0
                          ? const Color(0xFFFF4444)
                          : Colors.white38,
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Missed: $_missedCalls',
                      style: TextStyle(
                        color: _missedCalls > 0
                            ? const Color(0xFFFF4444)
                            : Colors.white38,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: _unreadSms > 0 ? _openMessages : null,
              child: Row(
                children: [
                  Icon(
                    Icons.message,
                    color: _unreadSms > 0
                        ? const Color(0xFFFFFF00)
                        : Colors.white38,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SMS: $_unreadSms',
                    style: TextStyle(
                      color: _unreadSms > 0
                          ? const Color(0xFFFFFF00)
                          : Colors.white38,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF111111),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              icon: Icons.home,
              label: 'Home',
              selected: _currentPage == 0,
              onTap: _goToHome,
            ),
          ),
          Expanded(
            child: _TabButton(
              icon: Icons.notifications,
              label: 'Notifications',
              selected: _currentPage == 1,
              onTap: _goToNotifications,
            ),
          ),
        ],
      ),
    );
  }

  void _showPinOverlay() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => const AdminOverlay(),
          fullscreenDialog: true,
        ))
        .then((_) => _homeTabKey.currentState?.reload());
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFFFF00) : Colors.white38;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        color: selected ? const Color(0xFF1A1A00) : Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
