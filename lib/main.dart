import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'src/matrix.dart';
import 'src/pages/home_page.dart';
import 'src/pages/login_page.dart';
import 'src/settings.dart';
import 'src/widgets/key_verification_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  final client = await buildMatrixClient();
  runApp(ProteaApp(client: client, settings: settings));
}

class ProteaApp extends StatelessWidget {
  const ProteaApp({super.key, required this.client, required this.settings});

  final Client client;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Protea',
        debugShowCheckedModeBanner: false,
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
        home: StreamBuilder<LoginState>(
          stream: client.onLoginStateChanged.stream,
          initialData:
              client.isLogged() ? LoginState.loggedIn : LoginState.loggedOut,
          builder: (context, snapshot) => snapshot.data == LoginState.loggedIn
              ? KeyVerificationListener(
                  client: client,
                  child: HomePage(client: client, settings: settings),
                )
              : LoginPage(client: client),
        ),
      ),
    );
  }
}
