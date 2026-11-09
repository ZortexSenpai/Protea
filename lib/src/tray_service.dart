import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart' show Logs;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/generated/app_localizations.dart';
import 'settings.dart';

/// Keeps the app available from the system tray: an icon with a show/quit
/// menu, and (while the setting is on) closing the window hides it to the
/// tray instead of quitting.
///
/// Degrades gracefully: when the platform has no tray (e.g. a Linux
/// session without the appindicator library), init fails quietly and
/// closing the window keeps its default quit behavior.
class TrayService with TrayListener, WindowListener {
  TrayService(this.settings);

  final AppSettings settings;
  bool _active = false;

  static const _showKey = 'show';
  static const _quitKey = 'quit';

  static bool get _supported =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  /// Tray menus render outside the widget tree, so the strings come from a
  /// locale lookup instead of a BuildContext.
  AppLocalizations _l10n() {
    try {
      return lookupAppLocalizations(
        Locale(Platform.localeName.split(RegExp('[_.]')).first),
      );
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  Future<void> init() async {
    if (!_supported || _active) return;
    try {
      await windowManager.ensureInitialized();
      await trayManager.setIcon(
        Platform.isWindows
            ? 'windows/runner/resources/app_icon.ico'
            : 'logo.png',
      );
      final l10n = _l10n();
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: _showKey, label: l10n.showApp),
            MenuItem.separator(),
            MenuItem(key: _quitKey, label: l10n.quit),
          ],
        ),
      );
      // Tooltips are not supported by Linux app indicators.
      if (!Platform.isLinux) await trayManager.setToolTip('Protea');
      trayManager.addListener(this);
      windowManager.addListener(this);
      settings.addListener(_applyCloseToTray);
      await _applyCloseToTray();
      _active = true;
    } catch (e, s) {
      Logs().w('System tray unavailable', e, s);
    }
  }

  Future<void> _applyCloseToTray() async {
    try {
      await windowManager.setPreventClose(settings.closeToTray);
    } catch (_) {}
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quit() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() {
    // Linux app indicators open the context menu on any click themselves.
    if (!Platform.isLinux) _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _showKey:
        _showWindow();
      case _quitKey:
        quit();
    }
  }

  @override
  void onWindowClose() async {
    // Prevent-close is only set while close-to-tray is enabled.
    if (await windowManager.isPreventClose()) await windowManager.hide();
  }
}
