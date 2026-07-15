import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLayout {
  /// Spaces rail, channel list per space and the chat pane next to it.
  workspace,

  /// The workspace layout as floating frosted-glass panels over a themed
  /// gradient.
  liquid,

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

  /// Full-width rows with avatars and a sender header per message group —
  /// the default.
  cozy,

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

  Future<void> setNotificationSounds(bool value) =>
      _setBool('notificationSounds', value);

  /// Master switch for desktop notifications.
  bool get desktopNotifications =>
      _prefs.getBool('desktopNotifications') ?? true;

  Future<void> setDesktopNotifications(bool value) =>
      _setBool('desktopNotifications', value);

  /// Whether others get to see that we are typing.
  bool get sendTypingNotifications =>
      _prefs.getBool('sendTypingNotifications') ?? true;

  Future<void> setSendTypingNotifications(bool value) =>
      _setBool('sendTypingNotifications', value);

  /// Whether others get to see which messages we have read.
  bool get sendReadReceipts => _prefs.getBool('sendReadReceipts') ?? true;

  Future<void> setSendReadReceipts(bool value) =>
      _setBool('sendReadReceipts', value);

  /// Whether link preview cards are fetched and shown under messages.
  bool get showUrlPreviews => _prefs.getBool('showUrlPreviews') ?? true;

  Future<void> setShowUrlPreviews(bool value) =>
      _setBool('showUrlPreviews', value);

  /// Whether join/leave/invite state messages show in the timeline.
  bool get showMembershipEvents =>
      _prefs.getBool('showMembershipEvents') ?? true;

  Future<void> setShowMembershipEvents(bool value) =>
      _setBool('showMembershipEvents', value);

  /// Whether display name and avatar changes show in the timeline.
  bool get showProfileChangeEvents =>
      _prefs.getBool('showProfileChangeEvents') ?? true;

  Future<void> setShowProfileChangeEvents(bool value) =>
      _setBool('showProfileChangeEvents', value);

  /// Whether deleted messages leave a placeholder in the timeline.
  bool get showDeletedMessages => _prefs.getBool('showDeletedMessages') ?? true;

  Future<void> setShowDeletedMessages(bool value) =>
      _setBool('showDeletedMessages', value);

  /// Whether newly started direct chats enable end-to-end encryption.
  bool get encryptNewDirectChats =>
      _prefs.getBool('encryptNewDirectChats') ?? true;

  Future<void> setEncryptNewDirectChats(bool value) =>
      _setBool('encryptNewDirectChats', value);

  /// Whether the member list panel is open in rooms.
  bool get showMemberList => _prefs.getBool('showMemberList') ?? false;

  Future<void> setShowMemberList(bool value) =>
      _setBool('showMemberList', value);

  /// Whether other people's read receipts are shown under messages.
  bool get showReadReceipts => _prefs.getBool('showReadReceipts') ?? true;

  Future<void> setShowReadReceipts(bool value) =>
      _setBool('showReadReceipts', value);

  /// Whether GIF animations pause while the window is in the background.
  bool get pauseGifsUnfocused => _prefs.getBool('pauseGifsUnfocused') ?? false;

  Future<void> setPauseGifsUnfocused(bool value) =>
      _setBool('pauseGifsUnfocused', value);

  MessageLayout get messageLayout {
    final raw = _prefs.getString('messageLayout');
    // 'compact' was removed; it renders as the closest surviving layout.
    if (raw == 'compact') return MessageLayout.cozy;
    return MessageLayout.values.asNameMap()[raw] ?? MessageLayout.cozy;
  }

  Future<void> setMessageLayout(MessageLayout value) =>
      _set('messageLayout', value.name);

  bool get autoAway => _prefs.getBool('autoAway') ?? true;

  Future<void> setAutoAway(bool value) async {
    await _prefs.setBool('autoAway', value);
    notifyListeners();
  }

  /// UI language as a locale code ('de', 'en', …), or null to follow the
  /// system locale.
  Locale? get locale {
    final code = _prefs.getString('locale');
    return (code == null || code.isEmpty) ? null : Locale(code);
  }

  Future<void> setLocale(String? code) async {
    await _prefs.setString('locale', code ?? '');
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

  Future<void> _setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
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
