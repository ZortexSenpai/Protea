import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLayout {
  /// Discord-style: spaces rail, channel list per space, chat pane.
  discord,

  /// Classic flat room list like a mobile messenger.
  classic,
}

enum RailPosition { left, right }

/// Selectable color themes. Each seed generates a full light and dark
/// Material color scheme via [ColorScheme.fromSeed].
enum AppThemeColor {
  protea(Color(0xFFC2185B), 'Protea'),
  violet(Color(0xFF7B1FA2), 'Violet'),
  indigo(Color(0xFF3F51B5), 'Indigo'),
  ocean(Color(0xFF0288D1), 'Ocean'),
  teal(Color(0xFF00796B), 'Teal'),
  forest(Color(0xFF689F38), 'Forest'),
  amber(Color(0xFFFFA000), 'Amber'),
  sunset(Color(0xFFE64A19), 'Sunset'),
  graphite(Color(0xFF546E7A), 'Graphite');

  const AppThemeColor(this.seed, this.label);

  final Color seed;
  final String label;
}

/// User-configurable app settings, persisted with shared_preferences and
/// exposed as a [ChangeNotifier] so the UI can rebuild on changes.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async =>
      AppSettings._(await SharedPreferences.getInstance());

  AppLayout get layout => AppLayout.values.asNameMap()[_prefs.getString('layout')] ?? AppLayout.discord;

  RailPosition get railPosition =>
      RailPosition.values.asNameMap()[_prefs.getString('railPosition')] ??
      RailPosition.left;

  ThemeMode get themeMode =>
      ThemeMode.values.asNameMap()[_prefs.getString('themeMode')] ??
      ThemeMode.system;

  AppThemeColor get themeColor =>
      AppThemeColor.values.asNameMap()[_prefs.getString('themeColor')] ??
      AppThemeColor.protea;

  Future<void> setLayout(AppLayout value) => _set('layout', value.name);

  Future<void> setThemeColor(AppThemeColor value) =>
      _set('themeColor', value.name);

  Future<void> setRailPosition(RailPosition value) =>
      _set('railPosition', value.name);

  Future<void> setThemeMode(ThemeMode value) => _set('themeMode', value.name);

  Future<void> _set(String key, String value) async {
    await _prefs.setString(key, value);
    notifyListeners();
  }
}
