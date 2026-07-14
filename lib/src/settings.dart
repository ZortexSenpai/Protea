import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLayout {
  /// Discord-style: spaces rail, channel list per space, chat pane.
  discord,

  /// Classic flat room list like a mobile messenger.
  classic,
}

enum RailPosition { left, right }

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

  Future<void> setLayout(AppLayout value) => _set('layout', value.name);

  Future<void> setRailPosition(RailPosition value) =>
      _set('railPosition', value.name);

  Future<void> setThemeMode(ThemeMode value) => _set('themeMode', value.name);

  Future<void> _set(String key, String value) async {
    await _prefs.setString(key, value);
    notifyListeners();
  }
}
