import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../room_actions.dart';
import '../settings.dart';
import '../widgets/key_verification_dialog.dart';
import '../widgets/mxc_avatar.dart';

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
            const SizedBox(height: 16),
            ListTile(title: const Text('Color')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final color in AppThemeColor.values)
                    _ColorSwatch(
                      color: color,
                      selected: settings.themeColor == color,
                      onTap: () => settings.setThemeColor(color),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader('Status'),
            _StatusSection(client: client),
            const SizedBox(height: 24),
            _SectionHeader('Security'),
            _DevicesSection(client: client),
            const SizedBox(height: 24),
            _SectionHeader('Account'),
            _ProfileSection(client: client),
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

/// Lists the user's devices with their verification state and lets the user
/// start an interactive verification with any of them.
class _DevicesSection extends StatefulWidget {
  const _DevicesSection({required this.client});

  final Client client;

  @override
  State<_DevicesSection> createState() => _DevicesSectionState();
}

class _DevicesSectionState extends State<_DevicesSection> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      await widget.client.updateUserDeviceKeys();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _verify(DeviceKeys deviceKeys) async {
    try {
      final request = await deviceKeys.startVerification();
      if (!mounted) return;
      await KeyVerificationDialog.show(context, request);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    if (!client.encryptionEnabled) {
      return const ListTile(
        leading: Icon(Icons.no_encryption_outlined),
        title: Text('End-to-end encryption is not available'),
        subtitle: Text(
          'The crypto library could not be initialized on this platform.',
        ),
      );
    }
    if (_loading) {
      return const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Loading devices…'),
      );
    }
    final devices =
        client.userDeviceKeys[client.userID]?.deviceKeys.values.toList() ?? [];
    if (devices.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.devices_outlined),
        title: Text('No devices with encryption keys found'),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final device in devices)
          ListTile(
            leading: Icon(
              device.deviceId == client.deviceID
                  ? Icons.computer
                  : Icons.devices_other_outlined,
            ),
            title: Text(device.deviceDisplayName ?? device.deviceId ?? '?'),
            subtitle: Text(
              [
                device.deviceId ?? '?',
                if (device.deviceId == client.deviceID) 'this device',
                device.verified ? 'verified' : 'unverified',
              ].join(' · '),
              style: TextStyle(
                color: device.verified
                    ? const Color(0xFF43A047)
                    : colorScheme.error,
              ),
            ),
            trailing: device.deviceId == client.deviceID || device.verified
                ? Icon(
                    device.verified ? Icons.verified_user : Icons.computer,
                    color: device.verified
                        ? const Color(0xFF43A047)
                        : null,
                  )
                : TextButton(
                    onPressed: () => _verify(device),
                    child: const Text('Verify'),
                  ),
          ),
      ],
    );
  }
}

/// Own profile: avatar, names, and a button to upload a new profile picture.
class _ProfileSection extends StatefulWidget {
  const _ProfileSection({required this.client});

  final Client client;

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  Profile? _profile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.client.fetchOwnProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  Future<void> _changeAvatar() async {
    final picked = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Images',
          extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
        ),
      ],
    );
    if (picked == null) return;
    setState(() => _busy = true);
    final client = widget.client;
    try {
      final bytes = await picked.readAsBytes();
      final mxc = await client.uploadContent(bytes, filename: picked.name);
      await client.setProfileField(
        client.userID!,
        'avatar_url',
        {'avatar_url': mxc.toString()},
      );
      if (mounted) {
        setState(() => _profile?.avatarUrl = mxc);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final userId = client.userID ?? 'Unknown user';
    return ListTile(
      leading: MxcAvatar(
        client: client,
        name: _profile?.displayName ?? userId,
        avatarUrl: _profile?.avatarUrl,
      ),
      title: Text(_profile?.displayName ?? userId),
      subtitle: Text(
        '$userId · ${client.homeserver?.host ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              tooltip: 'Change profile picture',
              icon: const Icon(Icons.add_a_photo_outlined),
              onPressed: _changeAvatar,
            ),
    );
  }
}

/// Own presence and status message, applied via the presence API.
class _StatusSection extends StatefulWidget {
  const _StatusSection({required this.client});

  final Client client;

  @override
  State<_StatusSection> createState() => _StatusSectionState();
}

class _StatusSectionState extends State<_StatusSection> {
  PresenceType _presence = PresenceType.online;
  final _statusController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    final userId = widget.client.userID;
    if (userId == null) return;
    try {
      final presence = await widget.client.fetchCurrentPresence(userId);
      if (!mounted) return;
      setState(() {
        _presence = presence.presence;
        _statusController.text = presence.statusMsg ?? '';
      });
    } catch (_) {}
  }

  Future<void> _apply() async {
    final client = widget.client;
    final userId = client.userID;
    if (userId == null) return;
    setState(() => _busy = true);
    try {
      final message = _statusController.text.trim();
      // Keep later syncs from resetting the chosen presence to online.
      client.syncPresence = _presence;
      await client.setPresence(
        userId,
        _presence,
        statusMsg: message.isEmpty ? null : message,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<PresenceType>(
            segments: const [
              ButtonSegment(
                value: PresenceType.online,
                label: Text('Online'),
                icon: Icon(Icons.circle, color: Color(0xFF43A047), size: 12),
              ),
              ButtonSegment(
                value: PresenceType.unavailable,
                label: Text('Away'),
                icon: Icon(Icons.circle, color: Color(0xFFF9A825), size: 12),
              ),
              ButtonSegment(
                value: PresenceType.offline,
                label: Text('Invisible'),
                icon: Icon(Icons.circle_outlined, size: 12),
              ),
            ],
            selected: {_presence},
            onSelectionChanged: _busy
                ? null
                : (selection) {
                    setState(() => _presence = selection.single);
                    _apply();
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _statusController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Status message',
                    hintText: "What's happening?",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _apply(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Set status',
                onPressed: _busy ? null : _apply,
                icon: const Icon(Icons.check),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final AppThemeColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: color.label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.seed,
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 2.5,
                  )
                : null,
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 22)
              : null,
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
