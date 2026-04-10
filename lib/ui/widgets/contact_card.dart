import 'package:flutter/material.dart';
import '../../models/app_contact.dart';

class ContactCard extends StatelessWidget {
  final AppContact contact;
  final VoidCallback onTap;

  const ContactCard({super.key, required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333300), width: 2),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(),
            const SizedBox(height: 4),
            Text(
              contact.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (contact.photo != null) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: MemoryImage(contact.photo!),
      );
    }
    return CircleAvatar(
      radius: 30,
      backgroundColor: const Color(0xFF333300),
      child: Text(
        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Color(0xFFFFFF00),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
