import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/app_contact.dart';
import 'storage_service.dart';

class ContactsService {
  final _storage = StorageService();

  Future<List<Contact>> getAllContacts() async {
    PermissionStatus status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted) {
      return [];
    }
    return FlutterContacts.getAll(
      properties: ContactProperties.all,
    );
  }

  Future<List<AppContact>> getPinnedContacts() async {
    final ids = await _storage.getPinnedContactIds();
    if (ids.isEmpty) return [];

    PermissionStatus status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted) {
      return [];
    }

    Future<Contact?> safeFetch(String id) async {
      try {
        return await FlutterContacts.get(id, properties: ContactProperties.all);
      } on PlatformException {
        return null;
      }
    }

    final fetched = await Future.wait(ids.map(safeFetch));
    final contacts = <AppContact>[];
    for (final contact in fetched) {
      if (contact == null) continue;
      if (contact.phones.isEmpty) continue;
      contacts.add(AppContact(
        id: contact.id!,
        name: contact.displayName!,
        phoneNumber: contact.phones.first.number,
        photo: contact.photo?.thumbnail,
      ));
    }
    return contacts;
  }
}
