import 'dart:async';

import 'package:file_selector/file_selector.dart';
// Matrix's Visibility enum is used below; Flutter's Visibility widget is
// not.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../nicknames.dart';
import 'mxc_avatar.dart';
import 'poll.dart';
import 'room_banner.dart';
import 'text_prompt_dialog.dart';

/// Settings for a room or space: image, name, topic, notifications,
/// invitations and leaving.
Future<void> showRoomSettingsDialog(BuildContext context, Room room) =>
    showDialog(
      context: context,
      builder: (_) => RoomSettingsDialog(room: room),
    );

/// Searches the user directory (or takes a raw user ID) and invites the
/// picked user to [room].
Future<void> showInviteDialog(BuildContext context, Room room) => showDialog(
  context: context,
  builder: (_) => InviteDialog(room: room),
);

class InviteDialog extends StatefulWidget {
  const InviteDialog({super.key, required this.room});

  final Room room;

  @override
  State<InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<InviteDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Profile> _results = [];
  bool _searching = false;
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
    setState(() {});
  }

  Future<void> _search() async {
    final term = _controller.text.trim();
    if (term.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final response = await widget.room.client.searchUserDirectory(
        term,
        limit: 10,
      );
      if (mounted) setState(() => _results = response.results);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _invite(String userId) async {
    setState(() => _busy = true);
    try {
      await widget.room.invite(userId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.invitedUser(userId))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = _controller.text.trim();
    final looksLikeUserId = RegExp(r'^@[^:]+:.+$').hasMatch(input);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    widget.room.isSpace
                        ? context.l10n.inviteToSpace
                        : context.l10n.inviteToRoom,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_busy,
                decoration: InputDecoration(
                  hintText: context.l10n.searchUserHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _onChanged,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (looksLikeUserId)
                    ListTile(
                      leading: const Icon(Icons.person_add_outlined),
                      title: Text(context.l10n.inviteUser(input)),
                      enabled: !_busy,
                      onTap: () => _invite(input),
                    ),
                  for (final profile in _results)
                    ListTile(
                      dense: true,
                      enabled: !_busy,
                      leading: MxcAvatar(
                        client: widget.room.client,
                        name: profile.displayName ?? profile.userId,
                        avatarUrl: profile.avatarUrl,
                        radius: 14,
                      ),
                      title: Text(
                        profile.displayName ?? profile.userId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        profile.userId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _invite(profile.userId),
                    ),
                  if (!looksLikeUserId && _results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(context.l10n.typeTwoCharactersToSearch),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomSettingsDialog extends StatefulWidget {
  const RoomSettingsDialog({super.key, required this.room});

  final Room room;

  @override
  State<RoomSettingsDialog> createState() => _RoomSettingsDialogState();
}

/// Settings categories shown in the dialog's left rail.
enum _SettingsCategory {
  overview(Icons.info_outline),
  notifications(Icons.notifications_outlined),
  access(Icons.key_outlined),
  roles(Icons.military_tech_outlined),
  permissions(Icons.admin_panel_settings_outlined),
  members(Icons.group_outlined),
  security(Icons.lock_outline);

  const _SettingsCategory(this.icon);

  final IconData icon;
}

/// Single-selection pills that wrap onto further lines instead of squeezing
/// and word-wrapping their labels like a SegmentedButton would.
class _ChoicePills<T> extends StatelessWidget {
  const _ChoicePills({
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  final List<T> options;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(labelOf(option)),
            selected: option == selected,
            onSelected: onSelected == null
                ? null
                : (picked) {
                    if (picked && option != selected) onSelected!(option);
                  },
          ),
      ],
    );
  }
}

class _RoomSettingsDialogState extends State<RoomSettingsDialog> {
  bool _busy = false;

  /// Narrow screens show the category list and the selected category as
  /// two stacked pages instead of side by side; true while the category
  /// page is open.
  bool _narrowDetail = false;

  Room get room => widget.room;

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptText({
    required String title,
    required String initial,
    String? label,
    bool multiline = false,
  }) => showTextPromptDialog(
    context,
    title: title,
    initial: initial,
    label: label,
    multiline: multiline,
  );

  Future<void> _rename() async {
    final name = await _promptText(
      title: context.l10n.name,
      initial: room.name,
      label: context.l10n.roomNameResetHint,
    );
    // An empty name removes the room name (per the spec), so the room falls
    // back to its default: alias, DM partner or member names.
    if (name == null || name == room.name) return;
    await _run(() => room.setName(name));
  }

  Future<void> _editTopic() async {
    final topic = await _promptText(
      title: context.l10n.topic,
      initial: room.topic,
      multiline: true,
    );
    if (topic == null) return;
    await _run(() => room.setDescription(topic));
  }

  Future<void> _changeImage() async {
    final picked = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: context.l10n.images,
          extensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp'],
        ),
      ],
    );
    if (picked == null) return;
    await _run(() async {
      final bytes = await picked.readAsBytes();
      await room.setAvatar(MatrixImageFile(bytes: bytes, name: picked.name));
    });
  }

  Future<void> _changeBanner() async {
    final picked = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: context.l10n.images,
          extensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp'],
        ),
      ],
    );
    if (picked == null) return;
    await _run(() async {
      final bytes = await picked.readAsBytes();
      final mxc = await room.client.uploadContent(bytes, filename: picked.name);
      await setRoomBanner(room, mxc, mimeType: picked.mimeType);
    });
  }

  Future<void> _removeBanner() => _run(() => removeRoomBanner(room));

  Future<void> _enableEncryption() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.enableEncryptionTitle),
        content: Text(context.l10n.enableEncryptionWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.enableEncryptionTitle),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => room.enableEncryption());
  }

  /// Current room version from the create event.
  String get _roomVersion =>
      room.getState(EventTypes.RoomCreate)?.content['room_version']
          as String? ??
      '1';

  Future<void> _upgrade() async {
    final client = room.client;
    List<String> versions;
    String? defaultVersion;
    setState(() => _busy = true);
    try {
      final capabilities = await client.getCapabilities();
      final roomVersions = capabilities.mRoomVersions;
      versions = roomVersions?.available.keys.toList() ?? [];
      defaultVersion = roomVersions?.default$;
    } catch (e) {
      _showError(e);
      versions = [];
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted || versions.isEmpty) return;
    versions.sort((a, b) {
      final numA = int.tryParse(a);
      final numB = int.tryParse(b);
      if (numA != null && numB != null) return numA.compareTo(numB);
      if (numA != null) return -1;
      if (numB != null) return 1;
      return a.compareTo(b);
    });
    var selected = defaultVersion ?? versions.last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.upgradeRoomTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.upgradeRoomExplanation(selected, _roomVersion)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: InputDecoration(
                labelText: context.l10n.newRoomVersion,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final version in versions)
                  DropdownMenuItem(
                    value: version,
                    child: Text(
                      version == defaultVersion
                          ? context.l10n.versionDefault(version)
                          : version,
                    ),
                  ),
              ],
              onChanged: (value) => selected = value ?? selected,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.upgrade),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await client.upgradeRoom(room.id, selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.roomUpgradedNotice)),
        );
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          room.isSpace
              ? context.l10n.leaveSpaceTitle
              : context.l10n.leaveRoomTitle,
        ),
        content: Text(context.l10n.youWillNoLongerSee(room.nickOrDisplayname)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.leave),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await room.leave();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showError(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Categories applicable to this room; hidden ones mirror the old
  /// dialog's section gates.
  List<_SettingsCategory> get _categories => [
    _SettingsCategory.overview,
    _SettingsCategory.notifications,
    if (room.canChangeJoinRules ||
        room.canChangeStateEvent(EventTypes.HistoryVisibility) ||
        room.canChangeStateEvent(EventTypes.GuestAccess) ||
        room.canChangeStateEvent(EventTypes.RoomCanonicalAlias))
      _SettingsCategory.access,
    if (!room.isDirectChat) _SettingsCategory.roles,
    _SettingsCategory.permissions,
    _SettingsCategory.members,
    _SettingsCategory.security,
  ];

  var _category = _SettingsCategory.overview;

  String _categoryLabel(_SettingsCategory category) => switch (category) {
    _SettingsCategory.overview => context.l10n.overview,
    _SettingsCategory.notifications => context.l10n.notifications,
    _SettingsCategory.access => context.l10n.access,
    _SettingsCategory.roles => context.l10n.roles,
    _SettingsCategory.permissions => context.l10n.permissions,
    _SettingsCategory.members => context.l10n.members,
    _SettingsCategory.security => context.l10n.security,
  };

  List<Widget> _buildOverview() {
    final displayname = room.nickOrDisplayname;
    final canRename = room.canChangeStateEvent(EventTypes.RoomName);
    final canTopic = room.canChangeStateEvent(EventTypes.RoomTopic);
    final canAvatar = room.canChangeStateEvent(EventTypes.RoomAvatar);
    final canBanner = room.canChangeStateEvent(roomBannerEventType);
    return [
      ListTile(
        leading: MxcAvatar(
          client: room.client,
          name: displayname,
          avatarUrl: room.avatar,
        ),
        title: Text(displayname),
        subtitle: Text(room.id, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          tooltip: context.l10n.copyRoomId,
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () => Clipboard.setData(ClipboardData(text: room.id)),
        ),
      ),
      if (canAvatar || canRename || canBanner)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canAvatar)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _changeImage,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(
                    room.isSpace
                        ? context.l10n.changeSpaceImage
                        : context.l10n.changeImage,
                  ),
                ),
              if (canRename)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _rename,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(context.l10n.rename),
                ),
              if (canBanner)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _changeBanner,
                  icon: const Icon(Icons.panorama_outlined, size: 18),
                  label: Text(context.l10n.changeBanner),
                ),
              if (canBanner && currentRoomBanner(room) != null)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _removeBanner,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(context.l10n.removeBanner),
                ),
            ],
          ),
        ),
      ListTile(
        leading: const Icon(Icons.notes_outlined),
        title: Text(context.l10n.topic),
        subtitle: Text(
          room.topic.isEmpty ? context.l10n.noTopicSet : room.topic,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: canTopic
            ? IconButton(
                tooltip: context.l10n.editTopic,
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: _busy ? null : _editTopic,
              )
            : null,
      ),
    ];
  }

  List<Widget> _buildNotifications() => [
    Padding(
      padding: const EdgeInsets.all(16),
      child: _ChoicePills<PushRuleState>(
        options: const [
          PushRuleState.notify,
          PushRuleState.mentionsOnly,
          PushRuleState.dontNotify,
        ],
        labelOf: (state) => switch (state) {
          PushRuleState.notify => context.l10n.all,
          PushRuleState.mentionsOnly => context.l10n.mentions,
          PushRuleState.dontNotify => context.l10n.muted,
        },
        selected: room.pushRuleState,
        onSelected: _busy
            ? null
            : (state) => _run(() => room.setPushRuleState(state)),
      ),
    ),
  ];

  List<Widget> _buildMembers() => [
    ListTile(
      leading: const Icon(Icons.person_add_outlined),
      title: Text(
        room.isSpace ? context.l10n.inviteToSpace : context.l10n.inviteToRoom,
      ),
      enabled: room.canInvite && !_busy,
      onTap: () => showInviteDialog(context, room),
    ),
    if (room.canBan) _BannedSection(room: room),
  ];

  List<Widget> _buildSecurity() {
    final colorScheme = Theme.of(context).colorScheme;
    return [
      ListTile(
        leading: Icon(room.encrypted ? Icons.lock_outline : Icons.lock_open),
        title: Text(
          room.encrypted
              ? context.l10n.endToEndEncrypted
              : context.l10n.notEncrypted,
        ),
      ),
      if (!room.encrypted && room.canChangeStateEvent(EventTypes.Encryption))
        ListTile(
          leading: const Icon(Icons.enhanced_encryption_outlined),
          title: Text(context.l10n.enableEncryptionTitle),
          subtitle: Text(context.l10n.enableEncryptionWarning),
          enabled: !_busy,
          onTap: _enableEncryption,
        ),
      if (room.canChangeStateEvent(EventTypes.RoomTombstone))
        ListTile(
          leading: const Icon(Icons.upgrade),
          title: Text(context.l10n.upgradeRoom),
          subtitle: Text(context.l10n.currentRoomVersion(_roomVersion)),
          enabled: !_busy,
          onTap: _upgrade,
        ),
      const SizedBox.shrink(),
      Divider(color: colorScheme.outlineVariant),
      ListTile(
        leading: Icon(Icons.logout, color: colorScheme.error),
        title: Text(
          room.isSpace ? context.l10n.leaveSpace : context.l10n.leaveRoomAction,
          style: TextStyle(color: colorScheme.error),
        ),
        enabled: !_busy,
        onTap: _leave,
      ),
    ];
  }

  List<Widget> _buildCategory(_SettingsCategory category) => switch (category) {
    _SettingsCategory.overview => _buildOverview(),
    _SettingsCategory.notifications => _buildNotifications(),
    _SettingsCategory.access => [_AccessSection(room: room)],
    _SettingsCategory.roles => [_RolesSection(room: room)],
    _SettingsCategory.permissions => [_PermissionsSection(room: room)],
    _SettingsCategory.members => _buildMembers(),
    _SettingsCategory.security => _buildSecurity(),
  };

  /// Fullscreen two-level navigation for narrow screens: the category
  /// list first, the selected category as its own page with a back button
  /// (the system back gesture also returns to the list).
  Widget _buildNarrow(
    BuildContext context,
    List<_SettingsCategory> categories,
  ) {
    return Dialog.fullscreen(
      child: PopScope(
        canPop: !_narrowDetail,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _narrowDetail = false);
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  if (_narrowDetail)
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _narrowDetail = false),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _narrowDetail
                          ? _categoryLabel(_category)
                          : room.isSpace
                          ? context.l10n.spaceSettings
                          : context.l10n.channelSettings,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    tooltip: context.l10n.close,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _narrowDetail
                  ? ListView(
                      key: ValueKey(_category),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: _buildCategory(_category),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (final category in categories)
                          ListTile(
                            leading: Icon(category.icon, size: 20),
                            title: Text(_categoryLabel(category)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => setState(() {
                              _category = category;
                              _narrowDetail = true;
                            }),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = _categories;
    if (!categories.contains(_category)) {
      _category = _SettingsCategory.overview;
    }
    // The two-pane dialog needs room for the rail next to the content;
    // below that it becomes a fullscreen two-level page.
    if (MediaQuery.sizeOf(context).width < 600) {
      return _buildNarrow(context, categories);
    }
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    room.isSpace
                        ? context.l10n.spaceSettings
                        : context.l10n.channelSettings,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    tooltip: context.l10n.close,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Category rail.
                  SizedBox(
                    width: 190,
                    child: Material(
                      color: colorScheme.surfaceContainerLow,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          for (final category in categories)
                            ListTile(
                              dense: true,
                              leading: Icon(category.icon, size: 20),
                              title: Text(_categoryLabel(category)),
                              selected: category == _category,
                              selectedTileColor: colorScheme.secondaryContainer
                                  .withValues(alpha: 0.5),
                              onTap: () => setState(() => _category = category),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  // Category content.
                  Expanded(
                    child: ListView(
                      key: ValueKey(_category),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: _buildCategory(_category),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Access settings: join rule, message history visibility, guest access,
/// directory listing and the room's canonical address. Each control renders
/// only when the user may change the backing state event.
class _AccessSection extends StatefulWidget {
  const _AccessSection({required this.room});

  final Room room;

  @override
  State<_AccessSection> createState() => _AccessSectionState();
}

class _AccessSectionState extends State<_AccessSection> {
  bool _busy = false;

  Room get room => widget.room;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
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

  Future<void> _editAddress() async {
    final server = room.client.userID?.split(':').last ?? '';
    final current = room.canonicalAlias;
    final localpart = await showTextPromptDialog(
      context,
      title: context.l10n.roomAddress,
      initial: current.isEmpty ? '' : current.substring(1).split(':').first,
      label: '#alias',
    );
    if (localpart == null || localpart.isEmpty || !mounted) return;
    final alias = '#${localpart.replaceAll('#', '').split(':').first}:$server';
    await _run(() async {
      await room.client.setRoomAlias(alias, room.id);
      await room.setCanonicalAlias(alias);
    });
  }

  @override
  Widget build(BuildContext context) {
    final joinRule = room.joinRules ?? JoinRules.invite;
    final history = room.historyVisibility ?? HistoryVisibility.shared;
    final parents = [
      for (final parent in room.spaceParents)
        if (parent.roomId != null) parent.roomId!,
    ];
    final joinOptions = <JoinRules>[
      JoinRules.public,
      JoinRules.invite,
      JoinRules.knock,
      if (parents.isNotEmpty) JoinRules.restricted,
      if (![
        JoinRules.public,
        JoinRules.invite,
        JoinRules.knock,
        JoinRules.restricted,
      ].contains(joinRule))
        joinRule,
    ];
    String joinLabel(JoinRules rule) => switch (rule) {
      JoinRules.public => context.l10n.public,
      JoinRules.invite => context.l10n.invite,
      JoinRules.knock => context.l10n.knock,
      JoinRules.restricted => context.l10n.spaceMembers,
      _ => rule.text,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.key_outlined),
          title: Text(context.l10n.access),
        ),
        if (room.canChangeJoinRules) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.l10n.whoCanJoin,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ChoicePills<JoinRules>(
              options: joinOptions,
              labelOf: joinLabel,
              selected: joinRule,
              onSelected: _busy
                  ? null
                  : (rule) => _run(
                      () => room.setJoinRules(
                        rule,
                        allowConditionRoomIds: rule == JoinRules.restricted
                            ? parents
                            : null,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (room.canChangeStateEvent(EventTypes.HistoryVisibility)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.l10n.messageHistory,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ChoicePills<HistoryVisibility>(
              options: const [
                HistoryVisibility.worldReadable,
                HistoryVisibility.shared,
                HistoryVisibility.invited,
                HistoryVisibility.joined,
              ],
              labelOf: (visibility) => switch (visibility) {
                HistoryVisibility.worldReadable => context.l10n.anyone,
                HistoryVisibility.shared => context.l10n.members,
                HistoryVisibility.invited => context.l10n.sinceInvited,
                HistoryVisibility.joined => context.l10n.sinceJoined,
              },
              selected: history,
              onSelected: _busy
                  ? null
                  : (visibility) =>
                        _run(() => room.setHistoryVisibility(visibility)),
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (room.canChangeStateEvent(EventTypes.GuestAccess))
          SwitchListTile(
            secondary: const Icon(Icons.person_outline),
            title: Text(context.l10n.guestAccess),
            value: room.guestAccess == GuestAccess.canJoin,
            onChanged: _busy
                ? null
                : (value) => _run(
                    () => room.setGuestAccess(
                      value ? GuestAccess.canJoin : GuestAccess.forbidden,
                    ),
                  ),
          ),
        if (room.canChangeJoinRules)
          FutureBuilder<Visibility?>(
            future: room.client.getRoomVisibilityOnDirectory(room.id),
            builder: (context, snapshot) => SwitchListTile(
              secondary: const Icon(Icons.public),
              title: Text(context.l10n.publishToDirectory),
              value: snapshot.data == Visibility.public,
              onChanged: _busy || !snapshot.hasData
                  ? null
                  : (value) => _run(
                      () => room.client.setRoomVisibilityOnDirectory(
                        room.id,
                        visibility: value
                            ? Visibility.public
                            : Visibility.private,
                      ),
                    ),
            ),
          ),
        if (room.canChangeStateEvent(EventTypes.RoomCanonicalAlias))
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: Text(context.l10n.roomAddress),
            subtitle: room.canonicalAlias.isEmpty
                ? null
                : Text(
                    room.canonicalAlias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            enabled: !_busy,
            onTap: _editAddress,
          ),
      ],
    );
  }
}

/// Editable power level requirements for common actions, offering the
/// standard Member/Moderator/Admin tiers.
/// Members with elevated power levels ("roles"), adjustable when the own
/// power level allows it, plus a picker to assign a role to further members.
class _RolesSection extends StatefulWidget {
  const _RolesSection({required this.room});

  final Room room;

  @override
  State<_RolesSection> createState() => _RolesSectionState();
}

class _RolesSectionState extends State<_RolesSection> {
  bool _busy = false;

  Room get room => widget.room;

  /// Cached: a new future per build would reset the FutureBuilder on every
  /// rebuild and refetch the member list.
  late Future<List<User>> _participants = room.requestParticipants();

  Future<void> _setPower(User user, int level) async {
    setState(() => _busy = true);
    try {
      await room.setPower(user.id, level);
      _participants = room.requestParticipants();
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

  String _roleLabel(BuildContext context, int level) => switch (level) {
    0 => context.l10n.member,
    50 => context.l10n.moderator,
    100 => context.l10n.admin,
    _ => level.toString(),
  };

  /// Picks a member without a role yet and makes them a moderator; their
  /// role can be refined with the dropdown afterwards.
  Future<void> _assignRole(List<User> members) async {
    final candidates =
        [
          for (final user in members)
            if (user.membership == Membership.join &&
                user.powerLevel.level <= 0)
              user,
        ]..sort(
          (a, b) => a.nickOrDisplayname.toLowerCase().compareTo(
            b.nickOrDisplayname.toLowerCase(),
          ),
        );
    var filter = '';
    final picked = await showDialog<User>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final visible = [
            for (final user in candidates)
              if (filter.isEmpty ||
                  user.nickOrDisplayname.toLowerCase().contains(filter) ||
                  user.id.toLowerCase().contains(filter))
                user,
          ];
          return AlertDialog(
            title: Text(context.l10n.assignRole),
            content: SizedBox(
              width: 360,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.l10n.searchUserHint,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (value) =>
                        setState(() => filter = value.trim().toLowerCase()),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final user in visible)
                          ListTile(
                            dense: true,
                            leading: MxcAvatar(
                              client: room.client,
                              name: user.nickOrDisplayname,
                              avatarUrl: user.avatarUrl,
                              radius: 14,
                            ),
                            title: Text(
                              user.nickOrDisplayname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              user.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.of(context).pop(user),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.cancel),
              ),
            ],
          );
        },
      ),
    );
    if (picked != null) await _setPower(picked, 50);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<User>>(
      future: _participants,
      initialData: room.getParticipants(),
      builder: (context, snapshot) {
        final members = snapshot.data ?? <User>[];
        final own = room.ownPowerLevel.level;
        final canManage = room.canChangePowerLevel;
        final elevated =
            [
              for (final user in members)
                if (user.membership == Membership.join &&
                    user.powerLevel.level > 0)
                  user,
            ]..sort((a, b) {
              final byPower = b.powerLevel.level.compareTo(a.powerLevel.level);
              if (byPower != 0) return byPower;
              return a.nickOrDisplayname.toLowerCase().compareTo(
                b.nickOrDisplayname.toLowerCase(),
              );
            });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.military_tech_outlined),
              title: Text(context.l10n.roles),
              trailing: canManage
                  ? IconButton(
                      tooltip: context.l10n.assignRole,
                      icon: const Icon(Icons.person_add_alt_outlined),
                      onPressed: _busy ? null : () => _assignRole(members),
                    )
                  : null,
            ),
            for (final user in elevated)
              ListTile(
                dense: true,
                leading: MxcAvatar(
                  client: room.client,
                  name: user.nickOrDisplayname,
                  avatarUrl: user.avatarUrl,
                  radius: 14,
                ),
                title: Text(
                  user.nickOrDisplayname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  user.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Own role and stronger members are read-only; assignable
                // levels are capped at the own power level.
                trailing: DropdownButton<int>(
                  value: user.powerLevel.level,
                  onChanged:
                      _busy ||
                          !canManage ||
                          user.id == room.client.userID ||
                          user.powerLevel.level >= own
                      ? null
                      : (value) {
                          if (value != null && value != user.powerLevel.level) {
                            _setPower(user, value);
                          }
                        },
                  items: [
                    for (final level in {
                      0,
                      50,
                      100,
                      user.powerLevel.level,
                    }.toList()..sort())
                      if (level <= own || level == user.powerLevel.level)
                        DropdownMenuItem(
                          value: level,
                          child: Text(_roleLabel(context, level)),
                        ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PermissionsSection extends StatefulWidget {
  const _PermissionsSection({required this.room});

  final Room room;

  @override
  State<_PermissionsSection> createState() => _PermissionsSectionState();
}

class _PermissionsSectionState extends State<_PermissionsSection> {
  bool _busy = false;

  Room get room => widget.room;

  /// Everyone may inspect the permissions; only users allowed to change
  /// the power levels get live dropdowns.
  bool get _canEdit => room.canChangeStateEvent(EventTypes.RoomPowerLevels);

  Map<String, Object?> get _powerLevels => Map<String, Object?>.from(
    room.getState(EventTypes.RoomPowerLevels)?.content ?? {},
  );

  /// Reads the level at [key], optionally nested one map deep (`events`,
  /// `notifications`).
  int _levelOf(String key, int fallback, {String? within}) {
    final Object? value;
    if (within == null) {
      value = _powerLevels[key];
    } else {
      final nested = _powerLevels[within];
      value = nested is Map ? nested[key] : null;
    }
    return value is int ? value : fallback;
  }

  Future<void> _setLevel(String key, int level, {String? within}) async {
    setState(() => _busy = true);
    try {
      final content = _powerLevels;
      if (within == null) {
        content[key] = level;
      } else {
        final nested = Map<String, Object?>.from(content[within] as Map? ?? {});
        nested[key] = level;
        content[within] = nested;
      }
      await room.client.setRoomStateWithKey(
        room.id,
        EventTypes.RoomPowerLevels,
        '',
        content,
      );
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

  Widget _row(
    BuildContext context,
    String label,
    String key,
    int fallback, {
    String? within,
  }) {
    final current = _levelOf(key, fallback, within: within);
    final levels = {0, 50, 100, current}.toList()..sort();
    String levelLabel(int level) => switch (level) {
      0 => context.l10n.member,
      50 => context.l10n.moderator,
      100 => context.l10n.admin,
      _ => level.toString(),
    };
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: DropdownButton<int>(
        value: current,
        onChanged: _busy || !_canEdit
            ? null
            : (value) {
                if (value != null && value != current) {
                  _setLevel(key, value, within: within);
                }
              },
        items: [
          for (final level in levels)
            DropdownMenuItem(value: level, child: Text(levelLabel(level))),
        ],
      ),
    );
  }

  /// A per-event-type override row: state events fall back to
  /// `state_default`, message events to `events_default`.
  Widget _eventRow(
    BuildContext context,
    String label,
    String type, {
    bool isState = true,
  }) => _row(
    context,
    label,
    type,
    isState ? _levelOf('state_default', 50) : _levelOf('events_default', 0),
    within: 'events',
  );

  /// Event types with curated rows; any other override present in the
  /// room's power levels still gets a raw row below so nothing configured
  /// is ever hidden.
  static const _curatedEventTypes = {
    'm.reaction',
    'm.sticker',
    'm.room.redaction',
    'm.call.invite',
    pollStartType,
    EventTypes.RoomName,
    EventTypes.RoomTopic,
    EventTypes.RoomAvatar,
    EventTypes.RoomPinnedEvents,
    EventTypes.RoomCanonicalAlias,
    EventTypes.RoomJoinRules,
    EventTypes.GuestAccess,
    EventTypes.HistoryVisibility,
    EventTypes.RoomPowerLevels,
    EventTypes.Encryption,
    EventTypes.RoomTombstone,
    EventTypes.SpaceChild,
    'm.room.server_acl',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final eventOverrides = _powerLevels['events'];
    final uncurated = [
      if (eventOverrides is Map)
        for (final key in eventOverrides.keys)
          if (key is String && !_curatedEventTypes.contains(key)) key,
    ]..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined),
          title: Text(l10n.permissions),
        ),
        _row(context, l10n.defaultRole, 'users_default', 0),
        _row(context, l10n.sendMessages, 'events_default', 0),
        _row(context, l10n.invite, 'invite', 0),
        _row(context, l10n.kick, 'kick', 50),
        _row(context, l10n.ban, 'ban', 50),
        _row(context, l10n.removeMessages, 'redact', 50),
        _row(context, l10n.changeSettings, 'state_default', 50),
        _row(context, l10n.notifyEveryone, 'room', 50, within: 'notifications'),
        _eventRow(context, l10n.addReaction, 'm.reaction', isState: false),
        _eventRow(context, l10n.sticker, 'm.sticker', isState: false),
        _eventRow(context, l10n.createPoll, pollStartType, isState: false),
        _eventRow(
          context,
          l10n.deleteOwnMessages,
          'm.room.redaction',
          isState: false,
        ),
        _eventRow(context, l10n.startCalls, 'm.call.invite', isState: false),
        _eventRow(context, l10n.rename, EventTypes.RoomName),
        _eventRow(context, l10n.editTopic, EventTypes.RoomTopic),
        _eventRow(context, l10n.changeImage, EventTypes.RoomAvatar),
        _eventRow(context, l10n.pinnedMessages, EventTypes.RoomPinnedEvents),
        _eventRow(context, l10n.roomAddress, EventTypes.RoomCanonicalAlias),
        _eventRow(context, l10n.changeAccess, EventTypes.RoomJoinRules),
        _eventRow(context, l10n.guestAccess, EventTypes.GuestAccess),
        _eventRow(
          context,
          l10n.changeHistoryVisibility,
          EventTypes.HistoryVisibility,
        ),
        _eventRow(context, l10n.changePermissions, EventTypes.RoomPowerLevels),
        _eventRow(context, l10n.enableEncryptionTitle, EventTypes.Encryption),
        _eventRow(context, l10n.upgradeRoom, EventTypes.RoomTombstone),
        _eventRow(context, l10n.serverAcl, 'm.room.server_acl'),
        if (widget.room.isSpace)
          _eventRow(context, l10n.manageSpaceRooms, EventTypes.SpaceChild),
        // Overrides this room defines beyond the curated list, labeled by
        // their raw event type.
        for (final type in uncurated) _eventRow(context, type, type),
      ],
    );
  }
}

/// Banned members with an unban action; hidden while nobody is banned.
class _BannedSection extends StatefulWidget {
  const _BannedSection({required this.room});

  final Room room;

  @override
  State<_BannedSection> createState() => _BannedSectionState();
}

class _BannedSectionState extends State<_BannedSection> {
  bool _busy = false;

  /// Cached: a new future per build would reset the FutureBuilder on every
  /// rebuild and refetch the member list.
  late Future<List<User>> _participants = widget.room.requestParticipants();

  Future<void> _unban(User user) async {
    setState(() => _busy = true);
    try {
      await user.unban();
      _participants = widget.room.requestParticipants();
      if (mounted) setState(() {});
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
    return FutureBuilder<List<User>>(
      future: _participants,
      initialData: widget.room.getParticipants(),
      builder: (context, snapshot) {
        final banned = [
          for (final user in snapshot.data ?? <User>[])
            if (user.membership == Membership.ban) user,
        ];
        if (banned.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(context.l10n.bannedUsers),
            ),
            for (final user in banned)
              ListTile(
                dense: true,
                leading: MxcAvatar(
                  client: widget.room.client,
                  name: user.nickOrDisplayname,
                  avatarUrl: user.avatarUrl,
                  radius: 14,
                ),
                title: Text(
                  user.nickOrDisplayname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  user.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: TextButton(
                  onPressed: _busy ? null : () => _unban(user),
                  child: Text(context.l10n.unban),
                ),
              ),
          ],
        );
      },
    );
  }
}
