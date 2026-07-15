import 'dart:async';

import 'package:flutter/material.dart';

import 'src/auto_away.dart';
import 'src/client_manager.dart';
import 'src/l10n.dart';
import 'src/notifications.dart';
import 'src/pages/home_page.dart';
import 'src/pages/login_page.dart';
import 'src/settings.dart';
import 'src/widgets/key_verification_dialog.dart';
import 'src/widgets/quick_switcher.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  final manager = await ClientManager.load();
  final autoAway = AutoAwayService(manager, settings)..init();
  runApp(ProteaApp(manager: manager, settings: settings, autoAway: autoAway));
  // After runApp so a hanging permission prompt can never block the first
  // frame.
  unawaited(
    NotificationService(
      manager,
      navigatorKey: navigatorKey,
      settings: settings,
    ).init(),
  );
}

class ProteaApp extends StatelessWidget {
  const ProteaApp({
    super.key,
    required this.manager,
    required this.settings,
    this.autoAway,
  });

  final ClientManager manager;
  final AppSettings settings;
  final AutoAwayService? autoAway;

  /// Bundled color emoji as the fallback font, so emojis render in color on
  /// platforms whose system fallback is monochrome (Linux).
  static const _fontFallback = ['Noto Color Emoji'];

  static ThemeData _theme(Color seed, Brightness brightness) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamilyFallback: _fontFallback),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamilyFallback: _fontFallback,
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
          theme: _theme(settings.themeColor.seed, Brightness.light),
          darkTheme: _theme(settings.themeColor.seed, Brightness.dark),
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
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => autoAway?.notifyActivity(),
                onPointerSignal: (_) => autoAway?.notifyActivity(),
                child: child ?? const SizedBox.shrink(),
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
                    child: HomePage(
                      client: active,
                      manager: manager,
                      settings: settings,
                    ),
                  ),
                ),
        );
      },
    );
  }
}
