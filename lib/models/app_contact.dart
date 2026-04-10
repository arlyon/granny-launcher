import 'dart:typed_data';

class AppContact {
  final String id;
  final String name;
  final String phoneNumber;
  final Uint8List? photo;

  const AppContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.photo,
  });
}
