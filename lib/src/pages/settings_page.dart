import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../room_actions.dart';
import '../settings.dart';
import '../widgets/bootstrap_dialog.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/key_verification_dialog.dart';
import '../widgets/mxc_avatar.dart';
import '../widgets/user_profile_card.dart';

/// Opens the settings as a modal dialog.
Future<void> showSettingsDialog(
  BuildContext context, {
  required Client client,
  required AppSettings settings,
}) => showDialog(
  context: context,
  builder: (_) => SettingsDialog(client: client, settings: settings),
);

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({
    super.key,
    required this.client,
    required this.settings,
  });

  final Client client;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListenableBuilder(
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
                            ? (selection) =>
                                  settings.setRailPosition(selection.single)
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
                    const SizedBox(height: 16),
                    ListTile(title: const Text('Font size')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<double>(
                        segments: const [
                          ButtonSegment(value: 0.85, label: Text('Small')),
                          ButtonSegment(value: 1.0, label: Text('Normal')),
                          ButtonSegment(value: 1.15, label: Text('Large')),
                          ButtonSegment(value: 1.3, label: Text('Huge')),
                        ],
                        selected: {settings.textScale},
                        onSelectionChanged: (selection) =>
                            settings.setTextScale(selection.single),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader('Status'),
                    _StatusSection(client: client),
                    const SizedBox(height: 24),
                    _SectionHeader('Security'),
                    _BackupSection(client: client),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the cross-signing / key backup state with actions to set it up,
/// unlock it with the recovery key, or reset it.
class _BackupSection extends StatefulWidget {
  const _BackupSection({required this.client});

  final Client client;

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  Future<void> _openBootstrap({bool wipe = false}) async {
    if (wipe) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reset chat backup?'),
          content: const Text(
            'This discards the existing cross-signing keys and key backup '
            'and creates new ones. Devices verified before will need to be '
            'verified again, and history encrypted with lost keys stays '
            'unreadable.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await showBootstrapDialog(context, client: widget.client, wipe: wipe);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final encryption = widget.client.encryption;
    if (encryption == null) return const SizedBox.shrink();
    final configured =
        encryption.crossSigning.enabled && encryption.keyManager.enabled;
    if (!configured) {
      return ListTile(
        leading: const Icon(Icons.backup_outlined),
        title: const Text('Chat backup is not set up'),
        subtitle: const Text(
          'Set up cross-signing and key backup so encrypted messages '
          'survive on new devices.',
        ),
        trailing: FilledButton(
          onPressed: () => _openBootstrap(),
          child: const Text('Set up'),
        ),
      );
    }
    return FutureBuilder<List<bool>>(
      future: Future.wait([
        encryption.crossSigning.isCached(),
        encryption.keyManager.isCached(),
      ]),
      builder: (context, snapshot) {
        final cached = snapshot.data?.every((value) => value) ?? false;
        if (!snapshot.hasData) {
          return const ListTile(
            leading: Icon(Icons.backup_outlined),
            title: Text('Chat backup'),
            subtitle: Text('Checking…'),
          );
        }
        if (!cached) {
          return ListTile(
            leading: Icon(Icons.lock_clock, color: const Color(0xFFF9A825)),
            title: const Text('Chat backup is locked'),
            subtitle: const Text(
              'Unlock it with your recovery key to read old encrypted '
              'messages on this device.',
            ),
            trailing: FilledButton(
              onPressed: () => _openBootstrap(),
              child: const Text('Unlock'),
            ),
          );
        }
        return ListTile(
          leading: const Icon(Icons.verified_user, color: Color(0xFF43A047)),
          title: const Text('Chat backup enabled'),
          subtitle: const Text(
            'Cross-signing and key backup are active on this device.',
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') _openBootstrap(wipe: true);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'reset', child: Text('Reset backup')),
            ],
          ),
        );
      },
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
      await _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Verifies this session against the user's cross-signing identity: sends
  /// a verification request to all other own devices, to be confirmed on one
  /// of them. On success the master key becomes trusted and every
  /// cross-signed device turns verified here as well.
  Future<void> _verifySession() async {
    final keysList = widget.client.userDeviceKeys[widget.client.userID];
    if (keysList == null) return;
    try {
      final request = await keysList.startVerification();
      if (!mounted) return;
      await KeyVerificationDialog.show(context, request);
      await _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
    final keysList = client.userDeviceKeys[client.userID];
    final devices = keysList?.deviceKeys.values.toList() ?? [];
    if (devices.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.devices_outlined),
        title: Text('No devices with encryption keys found'),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    const green = Color(0xFF43A047);
    final masterKey = keysList?.masterKey;
    final sessionTrusted = masterKey == null || masterKey.verified;
    return Column(
      children: [
        if (!sessionTrusted)
          ListTile(
            leading: Icon(Icons.gpp_maybe_outlined, color: colorScheme.error),
            title: const Text('This session is not verified'),
            subtitle: const Text(
              'Your other devices are cross-signed, but this session does '
              'not trust your identity key yet, so they all show as '
              'unverified. Verify this session from one of your other '
              'devices to fix that.',
            ),
            trailing: FilledButton(
              onPressed: _verifySession,
              child: const Text('Verify session'),
            ),
          ),
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
                if (device.verified)
                  'verified'
                else if (!sessionTrusted && device.signed)
                  'cross-signed · trusted once this session is verified'
                else
                  'unverified',
              ].join(' · '),
              style: TextStyle(
                color: device.verified
                    ? green
                    : (!sessionTrusted && device.signed)
                    ? const Color(0xFFF9A825)
                    : colorScheme.error,
              ),
            ),
            trailing: device.deviceId == client.deviceID || device.verified
                ? Icon(
                    device.verified ? Icons.verified_user : Icons.computer,
                    color: device.verified ? green : null,
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
  ProfileInformation? _profile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = widget.client.userID;
    if (userId == null) return;
    try {
      final profile = await widget.client.getUserProfile(userId);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  Uri? get _bannerUrl {
    final value = _profile?.additionalProperties[bannerProfileField];
    if (value is String && value.startsWith('mxc://')) {
      return Uri.tryParse(value);
    }
    return null;
  }

  /// Picks an image, uploads it and stores its mxc URI in the profile field
  /// [fieldName].
  Future<void> _uploadImageTo(String fieldName) async {
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
      await client.setProfileField(client.userID!, fieldName, {
        fieldName: mxc.toString(),
      });
      await _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(text: _profile?.displayname ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.client.setProfileField(
        widget.client.userID!,
        'displayname',
        {'displayname': newName},
      );
      await _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final userId = client.userID ?? 'Unknown user';
    final displayName = _profile?.displayname ?? userId;
    final bannerUrl = _bannerUrl;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (bannerUrl != null)
                    MxcImage(
                      client: client,
                      uri: bannerUrl,
                      placeholder: (_) => ColoredBox(
                        color: InitialsAvatar.colorFor(displayName),
                      ),
                    )
                  else
                    ColoredBox(color: InitialsAvatar.colorFor(displayName)),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      tooltip: 'Change banner',
                      icon: const Icon(Icons.panorama_outlined, size: 20),
                      onPressed: _busy
                          ? null
                          : () => _uploadImageTo(bannerProfileField),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ListTile(
          leading: MxcAvatar(
            client: client,
            name: displayName,
            avatarUrl: _profile?.avatarUrl,
          ),
          title: Text(displayName),
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
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit display name',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _editDisplayName,
                    ),
                    IconButton(
                      tooltip: 'Change profile picture',
                      icon: const Icon(Icons.add_a_photo_outlined),
                      onPressed: () => _uploadImageTo('avatar_url'),
                    ),
                  ],
                ),
        ),
      ],
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Status updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
