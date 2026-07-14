import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../client_manager.dart';
import '../settings.dart';
import 'discord_home_page.dart';
import 'room_list_page.dart';

/// Chooses the home layout based on the user's settings.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.client,
    required this.manager,
    required this.settings,
  });

  final Client client;
  final ClientManager manager;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => switch (settings.layout) {
        AppLayout.discord => DiscordHomePage(
            client: client,
            manager: manager,
            settings: settings,
          ),
        AppLayout.classic => RoomListPage(
            client: client,
            manager: manager,
            settings: settings,
          ),
      },
    );
  }
}
