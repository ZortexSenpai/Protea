import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLayout {
  /// Spaces rail, channel list per space and the chat pane next to it.
  workspace,

  /// Flat room list on the left with the chat pane next to it.
  split,

  /// Flat room list only; chats open as their own page.
  list,
}

enum RailPosition { left, right }

/// How messages are rendered in the timeline.
enum MessageLayout {
  /// Asymmetric chat bubbles (own messages right, others left).
  bubbles,

  /// Full-width rows with avatars and a sender header per message group.
  cozy,

  /// Dense rows with a time gutter and inline sender names.
  compact,

  /// Terminal-style text lines: `[12:34] <name> message`.
  text,
}

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

  AppLayout get layout {
    final raw = _prefs.getString('layout');
    // Legacy names from before the layouts were renamed.
    return switch (raw) {
      'discord' => AppLayout.workspace,
      'classic' => AppLayout.list,
      _ => AppLayout.values.asNameMap()[raw] ?? AppLayout.workspace,
    };
  }

  RailPosition get railPosition =>
      RailPosition.values.asNameMap()[_prefs.getString('railPosition')] ??
      RailPosition.left;

  ThemeMode get themeMode =>
      ThemeMode.values.asNameMap()[_prefs.getString('themeMode')] ??
      ThemeMode.system;

  AppThemeColor get themeColor =>
      AppThemeColor.values.asNameMap()[_prefs.getString('themeColor')] ??
      AppThemeColor.protea;

  double get textScale => _prefs.getDouble('textScale') ?? 1.0;

  Future<void> setTextScale(double value) async {
    await _prefs.setDouble('textScale', value);
    notifyListeners();
  }

  bool get notificationSounds => _prefs.getBool('notificationSounds') ?? true;

  Future<void> setNotificationSounds(bool value) async {
    await _prefs.setBool('notificationSounds', value);
    notifyListeners();
  }

  MessageLayout get messageLayout =>
      MessageLayout.values.asNameMap()[_prefs.getString('messageLayout')] ??
      MessageLayout.bubbles;

  Future<void> setMessageLayout(MessageLayout value) =>
      _set('messageLayout', value.name);

  bool get autoAway => _prefs.getBool('autoAway') ?? true;

  Future<void> setAutoAway(bool value) async {
    await _prefs.setBool('autoAway', value);
    notifyListeners();
  }

  /// API key for the Klipy GIF search; empty when the feature is unused.
  String get klipyApiKey => _prefs.getString('klipyApiKey') ?? '';

  Future<void> setKlipyApiKey(String value) => _set('klipyApiKey', value);

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

/// Makes [AppSettings] available to any widget below the app's Navigator
/// (including pushed routes) and rebuilds dependents on changes.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
