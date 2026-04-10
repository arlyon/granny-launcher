import 'dart:convert';

class QuickActionIntent {
  final String action;
  final String? category;
  final String? type;
  final String? data;
  final String? package;
  final List<int>? flags;

  const QuickActionIntent({
    required this.action,
    this.category,
    this.type,
    this.data,
    this.package,
    this.flags,
  });

  // ── Well-known presets ───────────────────────────────────────────────────

  static const phoneCallLog = QuickActionIntent(
    action: 'android.intent.action.VIEW',
    type: 'vnd.android.cursor.dir/calls',
    flags: [0x10000000, 0x00200000], // NEW_TASK | RESET_TASK_IF_NEEDED
  );

  static const phoneApp = QuickActionIntent(
    action: 'android.intent.action.MAIN',
    category: 'android.intent.category.APP_PHONE',
    flags: [0x10000000, 0x00200000],
  );

  static const messagesApp = QuickActionIntent(
    action: 'android.intent.action.MAIN',
    category: 'android.intent.category.APP_MESSAGING',
    flags: [0x10000000, 0x00200000],
  );

  static QuickActionIntent forPackage(String package) => QuickActionIntent(
        action: 'android.intent.action.MAIN',
        package: package,
        flags: [0x10000000, 0x00200000],
      );

  // ── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'action': action,
        if (category != null) 'category': category,
        if (type != null) 'type': type,
        if (data != null) 'data': data,
        if (package != null) 'package': package,
        if (flags != null) 'flags': flags,
      };

  factory QuickActionIntent.fromJson(Map<String, dynamic> json) =>
      QuickActionIntent(
        action: json['action'] as String,
        category: json['category'] as String?,
        type: json['type'] as String?,
        data: json['data'] as String?,
        package: json['package'] as String?,
        flags: (json['flags'] as List<dynamic>?)?.cast<int>(),
      );

  String toJsonString() => jsonEncode(toJson());

  static QuickActionIntent? tryParse(String? s) {
    if (s == null) return null;
    try {
      return QuickActionIntent.fromJson(
          jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Display ──────────────────────────────────────────────────────────────

  String get description {
    if (package != null) return package!;
    if (category != null) return category!.split('.').last;
    if (type != null) return type!;
    return action;
  }
}
