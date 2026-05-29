import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notif_service.dart';
import 'widgets/notif_tile.dart';

class NotifTab extends StatefulWidget {
  final bool initialPermissionGranted;

  const NotifTab({super.key, required this.initialPermissionGranted});

  @override
  State<NotifTab> createState() => _NotifTabState();
}

class _NotifTabState extends State<NotifTab> {
  final List<ServiceNotificationEvent> _notifications = [];
  StreamSubscription<ServiceNotificationEvent>? _subscription;
  late bool _permissionGranted;

  @override
  void initState() {
    super.initState();
    _permissionGranted = widget.initialPermissionGranted;
    if (_permissionGranted) {
      _loadExisting();
      _startListening();
    }
  }

  Future<void> _loadExisting() async {
    final existing = await NotificationListenerService.getActiveNotifications();
    if (!mounted) return;
    setState(() => _notifications.addAll(existing));
  }

  void _startListening() {
    _subscription = NotifService.stream.listen((event) {
      if (!mounted) return;
      if (event.hasRemoved == true) {
        // Notification was dismissed from the system tray externally.
        setState(() => _notifications.removeWhere((n) => n.id == event.id));
      } else {
        // Avoid duplicates with already-active notifications.
        setState(() {
          _notifications.removeWhere((n) => n.id == event.id);
          _notifications.insert(0, event);
        });
      }
    });
  }

  void _deleteNotification(ServiceNotificationEvent notif) {
    NotifService.dismissSystemNotification(notif);
    setState(() => _notifications.removeWhere((n) => n.id == notif.id));
  }

  void _openNotification(ServiceNotificationEvent notif) {
    NotifService.openNotification(notif);
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Clear All Notifications?',
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
        content: const Text(
          'This will remove all notifications from this list.',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'CLEAR ALL',
              style: TextStyle(
                color: Color(0xFFFFFF00),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _notifications.clear());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionGranted) {
      return _buildPermissionPrompt();
    }

    return Column(
      children: [
        _buildHeader(),
        _buildClearAllButton(),
        Expanded(
          child: _notifications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) => NotifTile(
                    notification: _notifications[index],
                    onDelete: () => _deleteNotification(_notifications[index]),
                    onTap: () => _openNotification(_notifications[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final missedCalls = _notifications
        .where((n) => NotifService.isPhoneNotification(n.packageName))
        .length;
    final unreadSms = _notifications
        .where((n) => NotifService.isSmsNotification(n.packageName))
        .length;

    return Container();

    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.phone_missed,
            color: missedCalls > 0 ? const Color(0xFFFF4444) : Colors.white38,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            'Missed Calls: $missedCalls',
            style: TextStyle(
              color: missedCalls > 0
                  ? const Color(0xFFFF4444)
                  : Colors.white38,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 24),
          Icon(
            Icons.message,
            color: unreadSms > 0 ? const Color(0xFFFFFF00) : Colors.white38,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            'SMS: $unreadSms',
            style: TextStyle(
              color: unreadSms > 0 ? const Color(0xFFFFFF00) : Colors.white38,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearAllButton() {
    final count = _notifications.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _notifications.isEmpty ? null : _clearAll,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF333300),
            disabledBackgroundColor: const Color(0xFF1A1A1A),
            side: BorderSide(
              color: _notifications.isEmpty
                  ? const Color(0xFF333333)
                  : const Color(0xFFFFFF00),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'CLEAR ALL',
                style: TextStyle(
                  color: _notifications.isEmpty
                      ? Colors.white24
                      : const Color(0xFFFFFF00),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFF00),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, color: Colors.white24, size: 80),
          SizedBox(height: 16),
          Text(
            'No Notifications',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.notifications_off,
              color: Colors.white24,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Notification Access Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Allow access to show missed calls and messages here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 20),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 70,
              child: ElevatedButton(
                onPressed: () async {
                  await NotifService.requestPermission();
                  final granted = await NotifService.isPermissionGranted();
                  if (!mounted) return;
                  setState(() => _permissionGranted = granted);
                  if (granted) _startListening();
                },
                child: const Text(
                  'GRANT ACCESS',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
