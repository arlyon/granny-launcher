import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../services/contacts_service.dart';

class ContactPickerPage extends StatefulWidget {
  final List<String> selectedIds;
  final int maxCount;

  const ContactPickerPage({
    super.key,
    required this.selectedIds,
    required this.maxCount,
  });

  @override
  State<ContactPickerPage> createState() => _ContactPickerPageState();
}

class _ContactPickerPageState extends State<ContactPickerPage> {
  final _service = ContactsService();
  final _searchController = TextEditingController();
  List<Contact> _contacts = [];
  List<Contact> _filtered = [];
  late Set<String> _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedIds);
    _searchController.addListener(_onSearch);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _contacts
          : _contacts
              .where((c) =>
                  (c.displayName ?? '').toLowerCase().contains(query) ||
                  c.phones.any((p) => p.number.toLowerCase().contains(query)))
              .toList();
    });
  }

  Future<void> _load() async {
    final all = await _service.getAllContacts();
    // Only show contacts that have at least one phone number
    final withPhone = all.where((c) => c.phones.isNotEmpty).toList()
      ..sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));
    if (mounted) {
      setState(() {
        _contacts = withPhone;
        _filtered = withPhone;
        _loading = false;
      });
    }
  }

  void _toggle(String id) {
    if (_selected.contains(id)) {
      setState(() => _selected.remove(id));
    } else if (_selected.length < widget.maxCount) {
      setState(() => _selected.add(id));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum ${widget.maxCount} contacts allowed',
            style: const TextStyle(fontSize: 18),
          ),
          backgroundColor: const Color(0xFF333300),
        ),
      );
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Contacts  ${_selected.length}/${widget.maxCount}',
          style: const TextStyle(
            color: Color(0xFFFFFF00),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected.toList()),
            child: const Text(
              'SAVE',
              style: TextStyle(
                color: Color(0xFFFFFF00),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Search contacts…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF222222),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFFF00)),
            )
          : _contacts.isEmpty
              ? const Center(
                  child: Text(
                    'No contacts found.\nGrant contacts permission in Settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                )
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final contact = _filtered[i];
                    final id = contact.id ?? '';
                    final name = contact.displayName ?? '?';
                    final phone = contact.phones.first.number;
                    final photo = contact.photo?.thumbnail;
                    final isSelected = _selected.contains(id);

                    return ListTile(
                      onTap: () => _toggle(id),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF2A2A00),
                        backgroundImage:
                            photo != null ? MemoryImage(photo) : null,
                        child: photo == null
                            ? Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Color(0xFFFFFF00),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        phone,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: isSelected
                            ? const Color(0xFFFFFF00)
                            : Colors.white38,
                        size: 32,
                      ),
                    );
                  },
                ),
    );
  }
}
