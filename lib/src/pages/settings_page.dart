import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../room_actions.dart';
import '../settings.dart';
import '../widgets/bootstrap_dialog.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/key_verification_dialog.dart';
import '../widgets/mxc_avatar.dart';
import '../widgets/user_banner.dart';

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
                    context.l10n.settings,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: context.l10n.close,
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
                    _SectionHeader(context.l10n.layout),
                    ListTile(
                      title: Text(context.l10n.appLayout),
                      subtitle: Text(context.l10n.appLayoutDescription),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<AppLayout>(
                        segments: [
                          ButtonSegment(
                            value: AppLayout.workspace,
                            label: Text(context.l10n.workspace),
                            icon: const Icon(Icons.view_sidebar_outlined),
                          ),
                          ButtonSegment(
                            value: AppLayout.split,
                            label: Text(context.l10n.split),
                            icon: const Icon(Icons.vertical_split_outlined),
                          ),
                          ButtonSegment(
                            value: AppLayout.list,
                            label: Text(context.l10n.list),
                            icon: const Icon(Icons.view_list_outlined),
                          ),
                        ],
                        selected: {settings.layout},
                        onSelectionChanged: (selection) =>
                            settings.setLayout(selection.single),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(context.l10n.spacesListPosition),
                      enabled: settings.layout == AppLayout.workspace,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<RailPosition>(
                        segments: [
                          ButtonSegment(
                            value: RailPosition.left,
                            label: Text(context.l10n.left),
                            icon: const Icon(Icons.align_horizontal_left),
                          ),
                          ButtonSegment(
                            value: RailPosition.right,
                            label: Text(context.l10n.right),
                            icon: const Icon(Icons.align_horizontal_right),
                          ),
                        ],
                        selected: {settings.railPosition},
                        onSelectionChanged:
                            settings.layout == AppLayout.workspace
                            ? (selection) =>
                                  settings.setRailPosition(selection.single)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(context.l10n.appearance),
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: Text(context.l10n.language),
                      trailing: DropdownButton<String>(
                        value: settings.locale?.languageCode ?? '',
                        onChanged: (value) => settings.setLocale(
                          value == null || value.isEmpty ? null : value,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(context.l10n.systemDefault),
                          ),
                          const DropdownMenuItem(
                            value: 'en',
                            child: Text('English'),
                          ),
                          const DropdownMenuItem(
                            value: 'de',
                            child: Text('Deutsch'),
                          ),
                          const DropdownMenuItem(
                            value: 'es',
                            child: Text('Español'),
                          ),
                          const DropdownMenuItem(
                            value: 'fr',
                            child: Text('Français'),
                          ),
                          const DropdownMenuItem(
                            value: 'it',
                            child: Text('Italiano'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(title: Text(context.l10n.theme)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text(context.l10n.systemDefault),
                            icon: const Icon(Icons.brightness_auto),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text(context.l10n.light),
                            icon: const Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text(context.l10n.dark),
                            icon: const Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (selection) =>
                            settings.setThemeMode(selection.single),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(title: Text(context.l10n.color)),
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
                    ListTile(
                      title: Text(context.l10n.messageLayout),
                      subtitle: Text(context.l10n.messageLayoutDescription),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<MessageLayout>(
                        segments: [
                          ButtonSegment(
                            value: MessageLayout.bubbles,
                            label: Text(context.l10n.bubbles),
                            icon: const Icon(Icons.chat_bubble_outline),
                          ),
                          ButtonSegment(
                            value: MessageLayout.cozy,
                            label: Text(context.l10n.cozy),
                            icon: const Icon(Icons.view_agenda_outlined),
                          ),
                          ButtonSegment(
                            value: MessageLayout.compact,
                            label: Text(context.l10n.compact),
                            icon: const Icon(Icons.view_headline),
                          ),
                          ButtonSegment(
                            value: MessageLayout.text,
                            label: Text(context.l10n.text),
                            icon: const Icon(Icons.terminal),
                          ),
                        ],
                        selected: {settings.messageLayout},
                        onSelectionChanged: (selection) =>
                            settings.setMessageLayout(selection.single),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(title: Text(context.l10n.fontSize)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<double>(
                        segments: [
                          ButtonSegment(
                            value: 0.85,
                            label: Text(context.l10n.small),
                          ),
                          ButtonSegment(
                            value: 1.0,
                            label: Text(context.l10n.normal),
                          ),
                          ButtonSegment(
                            value: 1.15,
                            label: Text(context.l10n.large),
                          ),
                          ButtonSegment(
                            value: 1.3,
                            label: Text(context.l10n.huge),
                          ),
                        ],
                        selected: {settings.textScale},
                        onSelectionChanged: (selection) =>
                            settings.setTextScale(selection.single),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(context.l10n.notifications),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: Text(context.l10n.notificationSounds),
                      subtitle: Text(
                        context.l10n.notificationSoundsDescription,
                      ),
                      value: settings.notificationSounds,
                      onChanged: (value) =>
                          settings.setNotificationSounds(value),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(context.l10n.integrations),
                    ListTile(
                      leading: const Icon(Icons.gif_box_outlined),
                      title: Text(context.l10n.gifSearchKlipy),
                      subtitle: Text(context.l10n.klipyApiKeyDescription),
                    ),
                    _KlipyKeyField(settings: settings),
                    const SizedBox(height: 24),
                    _SectionHeader(context.l10n.status),
                    _StatusSection(client: client),
                    SwitchListTile(
                      secondary: const Icon(Icons.snooze_outlined),
                      title: Text(context.l10n.autoAway),
                      subtitle: Text(context.l10n.autoAwayDescription),
                      value: settings.autoAway,
                      onChanged: (value) => settings.setAutoAway(value),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(context.l10n.security),
                    _BackupSection(client: client),
                    _DevicesSection(client: client),
                    const SizedBox(height: 24),
                    _SectionHeader(context.l10n.account),
                    _ProfileSection(client: client),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: Text(context.l10n.signOut),
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

/// Text field storing the Klipy API key for the GIF picker.
class _KlipyKeyField extends StatefulWidget {
  const _KlipyKeyField({required this.settings});

  final AppSettings settings;

  @override
  State<_KlipyKeyField> createState() => _KlipyKeyFieldState();
}

class _KlipyKeyFieldState extends State<_KlipyKeyField> {
  late final _controller = TextEditingController(
    text: widget.settings.klipyApiKey,
  );
  bool _saved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.settings.setKlipyApiKey(_controller.text.trim());
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: context.l10n.klipyApiKey,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: _saved
              ? const Icon(Icons.check, color: Color(0xFF43A047))
              : IconButton(
                  tooltip: context.l10n.save,
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _save,
                ),
        ),
        onChanged: (_) {
          if (_saved) setState(() => _saved = false);
        },
        onSubmitted: (_) => _save(),
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
          title: Text(context.l10n.resetChatBackup),
          content: Text(context.l10n.resetChatBackupWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.reset),
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
        title: Text(context.l10n.chatBackupNotSetUp),
        subtitle: Text(context.l10n.chatBackupNotSetUpDescription),
        trailing: FilledButton(
          onPressed: () => _openBootstrap(),
          child: Text(context.l10n.setUp),
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
          return ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(context.l10n.chatBackup),
            subtitle: Text(context.l10n.checking),
          );
        }
        if (!cached) {
          return ListTile(
            leading: Icon(Icons.lock_clock, color: const Color(0xFFF9A825)),
            title: Text(context.l10n.chatBackupLocked),
            subtitle: Text(context.l10n.chatBackupLockedDescription),
            trailing: FilledButton(
              onPressed: () => _openBootstrap(),
              child: Text(context.l10n.unlock),
            ),
          );
        }
        return ListTile(
          leading: const Icon(Icons.verified_user, color: Color(0xFF43A047)),
          title: Text(context.l10n.chatBackupEnabled),
          subtitle: Text(context.l10n.chatBackupEnabledDescription),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') _openBootstrap(wipe: true);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset',
                child: Text(context.l10n.resetBackup),
              ),
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
      return ListTile(
        leading: const Icon(Icons.no_encryption_outlined),
        title: Text(context.l10n.encryptionNotAvailable),
        subtitle: Text(context.l10n.encryptionNotAvailableDescription),
      );
    }
    if (_loading) {
      return ListTile(
        leading: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(context.l10n.loadingDevices),
      );
    }
    final keysList = client.userDeviceKeys[client.userID];
    final devices = keysList?.deviceKeys.values.toList() ?? [];
    if (devices.isEmpty) {
      return ListTile(
        leading: const Icon(Icons.devices_outlined),
        title: Text(context.l10n.noDevicesWithEncryptionKeys),
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
            title: Text(context.l10n.sessionNotVerified),
            subtitle: Text(context.l10n.sessionNotVerifiedDescription),
            trailing: FilledButton(
              onPressed: _verifySession,
              child: Text(context.l10n.verifySession),
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
                if (device.deviceId == client.deviceID) context.l10n.thisDevice,
                if (device.verified)
                  context.l10n.verified
                else if (!sessionTrusted && device.signed)
                  context.l10n.crossSignedPendingVerification
                else
                  context.l10n.unverified,
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
                    child: Text(context.l10n.verify),
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

  Uri? get _bannerUrl => bannerUrlFromProfile(_profile);

  /// Picks an image, uploads it and stores its mxc URI in the profile field
  /// [fieldName].
  Future<void> _uploadImageTo(String fieldName) async {
    final picked = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: context.l10n.images,
          extensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp'],
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
      if (fieldName == bannerWriteField) {
        invalidateUserProfile(client.userID!);
      }
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
        title: Text(context.l10n.displayName),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.l10n.save),
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
    final userId = client.userID ?? context.l10n.unknownUser;
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
                      tooltip: context.l10n.changeBanner,
                      icon: const Icon(Icons.panorama_outlined, size: 20),
                      onPressed: _busy
                          ? null
                          : () => _uploadImageTo(bannerWriteField),
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
                      tooltip: context.l10n.editDisplayName,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _editDisplayName,
                    ),
                    IconButton(
                      tooltip: context.l10n.changeProfilePicture,
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
        ).showSnackBar(SnackBar(content: Text(context.l10n.statusUpdated)));
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
            segments: [
              ButtonSegment(
                value: PresenceType.online,
                label: Text(context.l10n.online),
                icon: const Icon(
                  Icons.circle,
                  color: Color(0xFF43A047),
                  size: 12,
                ),
              ),
              ButtonSegment(
                value: PresenceType.unavailable,
                label: Text(context.l10n.away),
                icon: const Icon(
                  Icons.circle,
                  color: Color(0xFFF9A825),
                  size: 12,
                ),
              ),
              ButtonSegment(
                value: PresenceType.offline,
                label: Text(context.l10n.invisible),
                icon: const Icon(Icons.circle_outlined, size: 12),
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
                  decoration: InputDecoration(
                    labelText: context.l10n.statusMessage,
                    hintText: context.l10n.whatsHappening,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _apply(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: context.l10n.setStatus,
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
