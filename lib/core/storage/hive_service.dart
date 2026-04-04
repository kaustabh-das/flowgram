import 'package:hive_flutter/hive_flutter.dart';

/// Centralizes all Hive box registrations and initialization.
class HiveService {
  HiveService._();

  // ── Box names ─────────────────────────────────────────────────────
  static const String settingsBox  = 'settings';
  static const String projectsBox  = 'projects';
  static const String editsBox     = 'edits';

  // ── Box handles ───────────────────────────────────────────────────
  static late Box<dynamic> _settings;
  static late Box<dynamic> _projects;
  static late Box<dynamic> _edits;

  static Box<dynamic> get settings  => _settings;
  static Box<dynamic> get projects  => _projects;
  static Box<dynamic> get edits     => _edits;

  /// Call once from [main] after [Hive.initFlutter].
  static Future<void> init() async {
    // Register type adapters here when models are added, e.g.:
    // Hive.registerAdapter(ProjectAdapter());

    _settings  = await Hive.openBox<dynamic>(settingsBox);
    _projects  = await Hive.openBox<dynamic>(projectsBox);
    _edits     = await Hive.openBox<dynamic>(editsBox);
  }

  /// Convenience typed read with a default value.
  static T read<T>(Box<dynamic> box, String key, T defaultValue) {
    final value = box.get(key);
    if (value is T) return value;
    return defaultValue;
  }

  /// Convenience write.
  static Future<void> write(Box<dynamic> box, String key, dynamic value) =>
      box.put(key, value);
}
