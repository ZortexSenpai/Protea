import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'src/client_manager.dart';
import 'src/dock_badge.dart';
import 'src/l10n.dart';
import 'src/notifications.dart';
import 'src/motion.dart';
import 'src/pages/home_page.dart';
import 'src/pages/login_page.dart';
import 'src/presence_service.dart';
import 'src/settings.dart';
import 'src/smooth_scroll.dart';
import 'src/themes.dart';
import 'src/tray_service.dart';
import 'src/widgets/global_search_dialog.dart';
import 'src/widgets/key_verification_dialog.dart';
import 'src/widgets/quick_switcher.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Native libmpv backend for inline video playback.
  MediaKit.ensureInitialized();
  final settings = await AppSettings.load();
  final manager = await ClientManager.load(settings);
  final presence = PresenceService(manager, settings)..init();
  runApp(ProteaApp(manager: manager, settings: settings, presence: presence));
  // After runApp so a hanging permission prompt can never block the first
  // frame.
  unawaited(
    NotificationService(
      manager,
      navigatorKey: navigatorKey,
      settings: settings,
    ).init(),
  );
  unawaited(TrayService(settings).init());
  DockBadgeService(manager).init();
}

class ProteaApp extends StatelessWidget {
  const ProteaApp({
    super.key,
    required this.manager,
    required this.settings,
    this.presence,
  });

  final ClientManager manager;
  final AppSettings settings;
  final PresenceService? presence;

  /// Bundled color emoji as the fallback font, so emojis render in color on
  /// platforms whose system fallback is monochrome (Linux).
  static const _fontFallback = ['Noto Color Emoji'];

  static ThemeData _theme(AppSettings settings, Brightness brightness) {
    final base = ThemeData(
      colorScheme: withBackground(
        schemeFor(
          settings.appTheme,
          settings.themeColor,
          brightness,
          custom: settings.customPalette(brightness),
          accent: settings.effectiveAccent,
        ),
        settings.appBackgroundColor,
        settings.appBackgroundFade,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamilyFallback: _fontFallback),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamilyFallback: _fontFallback,
      ),
      // One light fade+slide for pushed pages on every platform, instead of
      // the heavier platform defaults.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const FadeSlidePageTransitionsBuilder(),
        },
      ),
      // Explicit pointer cursor on all icon buttons (settings, footer,
      // inline edit icons, …).
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          mouseCursor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([settings, manager]),
      builder: (context, _) {
        final active = manager.activeClient;
        return MaterialApp(
          onGenerateTitle: (context) => context.l10n.appTitle,
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: settings.locale,
          theme: _theme(settings, Brightness.light),
          darkTheme: _theme(settings, Brightness.dark),
          themeMode: settings.themeMode,
          builder: (context, child) => SettingsScope(
            settings: settings,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(settings.textScale)),
              child: Listener(
                // Pointer activity feeds the auto-away idle detection
                // (keyboard activity is tracked by the service itself).
                // Hover counts too: reading a room without clicking is still
                // being at the computer, and without it the presence only
                // came back once something was clicked.
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => presence?.notifyActivity(),
                onPointerSignal: (_) => presence?.notifyActivity(),
                onPointerHover: (_) => presence?.notifyActivity(),
                child: SmoothScrolling(
                  enabled: settings.smoothScrolling,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          home: active == null
              ? LoginPage(client: manager.loginCandidate)
              : KeyVerificationListener(
                  // The key replaces the whole subtree when the account
                  // changes, so no per-room or per-client state leaks over.
                  key: ValueKey(active.clientName),
                  client: active,
                  child: QuickSwitcherListener(
                    client: active,
                    child: GlobalSearchListener(
                      client: active,
                      child: HomePage(
                        client: active,
                        manager: manager,
                        settings: settings,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
