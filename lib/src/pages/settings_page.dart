import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../room_actions.dart';
import '../settings.dart';
import '../widgets/initials_avatar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.client, required this.settings});

  final Client client;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader('Layout'),
            ListTile(
              title: const Text('App layout'),
              subtitle: const Text(
                'Discord-style shows a spaces list on the left with a '
                'channel view per space.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<AppLayout>(
                segments: const [
                  ButtonSegment(
                    value: AppLayout.discord,
                    label: Text('Discord-style'),
                    icon: Icon(Icons.view_sidebar_outlined),
                  ),
                  ButtonSegment(
                    value: AppLayout.classic,
                    label: Text('Classic list'),
                    icon: Icon(Icons.view_list_outlined),
                  ),
                ],
                selected: {settings.layout},
                onSelectionChanged: (selection) =>
                    settings.setLayout(selection.single),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Spaces list position'),
              enabled: settings.layout == AppLayout.discord,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<RailPosition>(
                segments: const [
                  ButtonSegment(
                    value: RailPosition.left,
                    label: Text('Left'),
                    icon: Icon(Icons.align_horizontal_left),
                  ),
                  ButtonSegment(
                    value: RailPosition.right,
                    label: Text('Right'),
                    icon: Icon(Icons.align_horizontal_right),
                  ),
                ],
                selected: {settings.railPosition},
                onSelectionChanged: settings.layout == AppLayout.discord
                    ? (selection) => settings.setRailPosition(selection.single)
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader('Appearance'),
            ListTile(title: const Text('Theme')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selection) =>
                    settings.setThemeMode(selection.single),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader('Account'),
            ListTile(
              leading: InitialsAvatar(name: client.userID ?? '?'),
              title: Text(client.userID ?? 'Unknown user'),
              subtitle: Text(client.homeserver?.host ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () => confirmLogout(context, client),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
