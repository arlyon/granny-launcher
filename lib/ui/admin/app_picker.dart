import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import '../../services/app_service.dart';

class AppPickerPage extends StatefulWidget {
  final List<String> selectedPackages;

  const AppPickerPage({
    super.key,
    required this.selectedPackages,
  });

  @override
  State<AppPickerPage> createState() => _AppPickerPageState();
}

class _AppPickerPageState extends State<AppPickerPage> {
  final _service = AppService();
  final _searchController = TextEditingController();
  List<AppInfo> _apps = [];
  List<AppInfo> _filtered = [];
  Map<String, Future<Uint8List?>> _iconFutures = {};
  late Set<String> _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedPackages);
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
          ? _apps
          : _apps
              .where((a) =>
                  a.name.toLowerCase().contains(query) ||
                  a.packageName.toLowerCase().contains(query))
              .toList();
    });
  }

  Future<void> _load() async {
    final all = await _service.getAllApps();
    all.sort((a, b) => a.name.compareTo(b.name));
    if (mounted) {
      setState(() {
        _apps = all;
        _filtered = all;
        _iconFutures = {
          for (final a in all) a.packageName: _service.getAppIcon(a.packageName),
        };
        _loading = false;
      });
    }
  }

  void _toggle(String packageName) {
    setState(() {
      if (_selected.contains(packageName)) {
        _selected.remove(packageName);
      } else {
        _selected.add(packageName);
      }
    });
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
          'Apps  ${_selected.length} selected',
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
                hintText: 'Search apps…',
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
          : ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final app = _filtered[i];
                final isSelected = _selected.contains(app.packageName);

                return ListTile(
                  onTap: () => _toggle(app.packageName),
                  leading: FutureBuilder<Uint8List?>(
                    future: _iconFutures[app.packageName],
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            snapshot.data!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        );
                      }
                      return const Icon(
                        Icons.apps,
                        color: Color(0xFFFFFF00),
                        size: 52,
                      );
                    },
                  ),
                  title: Text(
                    app.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    app.packageName,
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                  trailing: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
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
