import 'dart:async';

import 'package:flutter/material.dart';

import 'src/client_manager.dart';
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
  runApp(ProteaApp(manager: manager, settings: settings));
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
  const ProteaApp({super.key, required this.manager, required this.settings});

  final ClientManager manager;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([settings, manager]),
      builder: (context, _) {
        final active = manager.activeClient;
        return MaterialApp(
          title: 'Protea',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.themeColor.seed,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.themeColor.seed,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: settings.themeMode,
          builder: (context, child) => SettingsScope(
            settings: settings,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(settings.textScale),
              ),
              child: child ?? const SizedBox.shrink(),
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
