import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_event.dart';

class NotifTile extends StatelessWidget {
  final ServiceNotificationEvent notification;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const NotifTile({
    super.key,
    required this.notification,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFFF00), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title ?? notification.packageName ?? 'Notification',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (notification.content != null &&
                        notification.content!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.content!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (notification.packageName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        notification.packageName!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF333300),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFFF00), width: 2),
                  ),
                  child: const Text(
                    'DISMISS',
                    style: TextStyle(
                      color: Color(0xFFFFFF00),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final iconBytes = notification.largeIcon ?? notification.appIcon;
    if (iconBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          iconBytes,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.notifications, color: Colors.white54, size: 30),
    );
  }
}
