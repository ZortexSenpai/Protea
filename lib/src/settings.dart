import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart' show PresenceType;
import 'package:shared_preferences/shared_preferences.dart';

import 'gif_proxy.dart';
import 'site_previews.dart';
import 'themes.dart';

// The theme enums live in themes.dart with the palettes they select, and are
// re-exported here so `settings.dart` stays the single import for settings.
export 'site_previews.dart' show PreviewSite;
export 'themes.dart' show AppTheme, AppThemeColor, CustomPalette;

enum AppLayout {
  /// Spaces rail, channel list per space and the chat pane next to it.
  workspace,

  /// The workspace layout as floating frosted-glass panels over a themed
  /// gradient.
  liquid,

  /// The workspace layout as solid rounded panels floating on a plain
  /// background.
  floating,

  /// Chat only: the navigation stays in a drawer even on wide windows.
  focus,
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

/// Selectable full app themes; Material derives its scheme from the chosen
/// seed color, the others carry complete palettes (see themes.dart).
/// User-configurable app settings, persisted with shared_preferences and
/// exposed as a [ChangeNotifier] so the UI can rebuild on changes.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async =>
      AppSettings._(await SharedPreferences.getInstance());

  AppLayout get layout =>
      // Removed and legacy layout names fall back to workspace.
      AppLayout.values.asNameMap()[_prefs.getString('layout')] ??
      AppLayout.workspace;

  RailPosition get railPosition =>
      RailPosition.values.asNameMap()[_prefs.getString('railPosition')] ??
      RailPosition.left;

  ThemeMode get themeMode =>
      ThemeMode.values.asNameMap()[_prefs.getString('themeMode')] ??
      ThemeMode.system;

  AppTheme get appTheme =>
      AppTheme.values.asNameMap()[_prefs.getString('appTheme')] ??
      AppTheme.material;

  Future<void> setAppTheme(AppTheme value) => _set('appTheme', value.name);

  AppThemeColor get themeColor =>
      AppThemeColor.values.asNameMap()[_prefs.getString('themeColor')] ??
      AppThemeColor.protea;

  /// The custom theme's palette for [brightness]. Until one is stored this
  /// mirrors the Material theme in the chosen seed color, so opening the
  /// editor starts from something readable rather than from black.
  CustomPalette customPalette(Brightness brightness) {
    final stored = _prefs.getStringList(_customPaletteKey(brightness));
    final colors = stored
        ?.map(int.tryParse)
        .map((value) => value == null ? null : Color(value))
        .nonNulls
        .toList();
    return (colors == null ? null : CustomPalette.fromColors(colors)) ??
        CustomPalette.fromScheme(
          schemeFor(AppTheme.material, themeColor, brightness),
        );
  }

  Future<void> setCustomPalette(Brightness brightness, CustomPalette value) =>
      _setStringList(_customPaletteKey(brightness), [
        for (final color in value.colors) '${color.toARGB32()}',
      ]);

  /// Forgets the stored palette for [brightness], so it follows the Material
  /// theme again.
  Future<void> resetCustomPalette(Brightness brightness) async {
    await _prefs.remove(_customPaletteKey(brightness));
    notifyListeners();
  }

  bool hasCustomPalette(Brightness brightness) =>
      _prefs.containsKey(_customPaletteKey(brightness));

  static String _customPaletteKey(Brightness brightness) =>
      'customPalette.${brightness.name}';

  /// Accent applied over a theme that ships its own palette, or null to keep
  /// the theme's own. Never applies to Material (seeded from [themeColor])
  /// or to the custom theme (which carries its own accent).
  AppThemeColor? get accentOverride =>
      AppThemeColor.values.asNameMap()[_prefs.getString('accentOverride')];

  Future<void> setAccentOverride(AppThemeColor? value) async {
    if (value == null) {
      await _prefs.remove('accentOverride');
      notifyListeners();
      return;
    }
    await _set('accentOverride', value.name);
  }

  /// The accent [schemeFor] should be given for the current theme, or null
  /// when the theme supplies its own.
  Color? get effectiveAccent => switch (appTheme) {
    AppTheme.material || AppTheme.custom => null,
    _ => accentOverride?.seed,
  };

  /// Color washed over the app's backdrop — the page behind the panels and
  /// the glow in the Liquid layout's gradient — or null to keep the theme's
  /// own.
  Color? get appBackgroundColor {
    final stored = _prefs.getInt('appBackgroundColor');
    return stored == null ? null : Color(stored);
  }

  Future<void> setAppBackgroundColor(Color? value) async {
    if (value == null) {
      await _prefs.remove('appBackgroundColor');
      notifyListeners();
      return;
    }
    await _prefs.setInt('appBackgroundColor', value.toARGB32());
    notifyListeners();
  }

  /// Whether the Liquid layout's backdrop glows in the top-left and
  /// bottom-right corners. Off makes it one flat color.
  bool get backgroundGlow => _prefs.getBool('backgroundGlow') ?? true;

  Future<void> setBackgroundGlow(bool value) =>
      _setBool('backgroundGlow', value);

  /// How much of [appBackgroundColor] shows against the theme's own
  /// background, 0..1.
  double get appBackgroundFade => _prefs.getDouble('appBackgroundFade') ?? 0.35;

  Future<void> setAppBackgroundFade(double value) =>
      _setDouble('appBackgroundFade', value);

  /// File name of the chat wallpaper inside the app support directory, empty
  /// when the timeline has no wallpaper.
  String get chatWallpaper => _prefs.getString('chatWallpaper') ?? '';

  Future<void> setChatWallpaper(String value) => _set('chatWallpaper', value);

  /// How strongly the wallpaper shows through, 0..1.
  double get chatWallpaperOpacity =>
      _prefs.getDouble('chatWallpaperOpacity') ?? 0.35;

  Future<void> setChatWallpaperOpacity(double value) =>
      _setDouble('chatWallpaperOpacity', value);

  /// Blur radius applied to the wallpaper, in logical pixels.
  double get chatWallpaperBlur => _prefs.getDouble('chatWallpaperBlur') ?? 0;

  Future<void> setChatWallpaperBlur(double value) =>
      _setDouble('chatWallpaperBlur', value);

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

  /// Whether links to [site] get its rich card, loaded straight from the
  /// site; otherwise they get the homeserver's generic preview. Stored as the
  /// list of switched-off sites so sites added later start switched on.
  bool sitePreviewEnabled(PreviewSite site) =>
      !(_prefs.getStringList('disabledSitePreviews') ?? const []).contains(
        site.name,
      );

  Future<void> setSitePreviewEnabled(PreviewSite site, bool enabled) {
    final disabled = {...?_prefs.getStringList('disabledSitePreviews')};
    if (enabled) {
      disabled.remove(site.name);
    } else {
      disabled.add(site.name);
    }
    return _setStringList('disabledSitePreviews', disabled.toList());
  }

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

  /// Whether mouse-wheel scrolling glides smoothly instead of jumping in
  /// discrete steps.
  bool get smoothScrolling => _prefs.getBool('smoothScrolling') ?? true;

  Future<void> setSmoothScrolling(bool value) =>
      _setBool('smoothScrolling', value);

  /// Whether arrow up in an empty composer starts editing the own last
  /// message, Discord-style.
  bool get arrowUpToEdit => _prefs.getBool('arrowUpToEdit') ?? true;

  Future<void> setArrowUpToEdit(bool value) => _setBool('arrowUpToEdit', value);

  /// Whether closing the window hides the app to the system tray instead
  /// of quitting (desktop only).
  bool get closeToTray => _prefs.getBool('closeToTray') ?? true;

  Future<void> setCloseToTray(bool value) => _setBool('closeToTray', value);

  /// Whether Protea looks for new releases in the background (desktop).
  bool get autoCheckUpdates => _prefs.getBool('autoCheckUpdates') ?? true;

  Future<void> setAutoCheckUpdates(bool value) =>
      _setBool('autoCheckUpdates', value);

  /// Whether pre-releases (`v1.2.0-beta.1`) are offered as updates.
  bool get betaUpdates => _prefs.getBool('betaUpdates') ?? false;

  Future<void> setBetaUpdates(bool value) => _setBool('betaUpdates', value);

  /// When the last successful background update check ran.
  DateTime? get lastUpdateCheck {
    final millis = _prefs.getInt('lastUpdateCheck');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Not announced to listeners: nothing on screen shows it, and a
  /// notification would rebuild the whole app.
  Future<void> setLastUpdateCheck(DateTime value) =>
      _prefs.setInt('lastUpdateCheck', value.millisecondsSinceEpoch);

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

  /// The presence the user chose for the account named [clientName]:
  /// online (the default), unavailable (away) or offline (invisible).
  PresenceType presenceFor(String clientName) =>
      PresenceType.values.asNameMap()[_prefs.getString(
        'presence.$clientName',
      )] ??
      PresenceType.online;

  Future<void> setPresenceFor(String clientName, PresenceType value) =>
      _set('presence.$clientName', value.name);

  /// The channel last opened in [spaceId] (null for Home) by the account
  /// named [clientName], so going back to a space reopens it.
  String? lastRoomFor(String clientName, String? spaceId) =>
      _lastRooms(clientName)[spaceId ?? ''];

  /// Not announced to listeners: nothing on screen shows it, and a
  /// notification would rebuild the whole app on every channel switch.
  Future<void> setLastRoomFor(
    String clientName,
    String? spaceId,
    String roomId,
  ) async {
    final rooms = _lastRooms(clientName);
    if (rooms[spaceId ?? ''] == roomId) return;
    rooms[spaceId ?? ''] = roomId;
    await _prefs.setString('lastRooms.$clientName', jsonEncode(rooms));
  }

  /// Space id ('' for Home) → last opened room id, for [clientName].
  Map<String, String> _lastRooms(String clientName) {
    final raw = _prefs.getString('lastRooms.$clientName');
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (key is String && value is String) key: value,
      };
    } on FormatException {
      return {};
    }
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

  /// Whether picked GIFs are sent as a link through the GIF proxy instead of
  /// being downloaded and uploaded to the homeserver. On unless switched off.
  bool get gifProxyEnabled => _prefs.getBool('gifProxyEnabled') ?? true;

  Future<void> setGifProxyEnabled(bool value) =>
      _setBool('gifProxyEnabled', value);

  /// Server name of the GIF proxy, [defaultGifProxyServer] unless changed.
  String get gifProxyServer =>
      _prefs.getString('gifProxyServer') ?? defaultGifProxyServer;

  Future<void> setGifProxyServer(String value) =>
      _set('gifProxyServer', value.trim());

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

  Future<void> _setDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
    notifyListeners();
  }

  Future<void> _setStringList(String key, List<String> value) async {
    await _prefs.setStringList(key, value);
    notifyListeners();
  }

  Future<void> _setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
    notifyListeners();
  }
}

/// The presence an account's sync loop should advertise to its homeserver:
/// only the [active] account claims its [chosen] presence — accounts in the
/// background appear offline since nobody is watching them, and the active
/// one drops to away while the app is [idle]. Manually invisible accounts
/// always stay invisible.
PresenceType effectiveSyncPresence(
  PresenceType chosen, {
  required bool active,
  bool idle = false,
}) {
  if (!active || chosen == PresenceType.offline) return PresenceType.offline;
  if (idle) return PresenceType.unavailable;
  return chosen;
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
