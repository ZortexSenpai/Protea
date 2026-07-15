import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../pages/room_page.dart';
import '../room_navigator.dart';
import '../settings.dart';
import 'initials_avatar.dart';
import 'mxc_avatar.dart';
import 'presence_indicator.dart';
import 'user_banner.dart';

/// Shows a Discord-style profile card for [userId]: banner, avatar with
/// presence, display name, user ID and status.
Future<void> showUserProfileCard(
  BuildContext context, {
  required Client client,
  required String userId,
  String? displayName,
  Uri? avatarUrl,
}) => showDialog(
  context: context,
  builder: (_) => UserProfileCard(
    client: client,
    userId: userId,
    displayName: displayName,
    avatarUrl: avatarUrl,
  ),
);

class UserProfileCard extends StatefulWidget {
  const UserProfileCard({
    super.key,
    required this.client,
    required this.userId,
    this.displayName,
    this.avatarUrl,
  });

  final Client client;
  final String userId;

  /// Optional prefill so the card renders instantly while the full profile
  /// loads in the background.
  final String? displayName;
  final Uri? avatarUrl;

  @override
  State<UserProfileCard> createState() => _UserProfileCardState();
}

class _UserProfileCardState extends State<UserProfileCard> {
  ProfileInformation? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.client.getUserProfile(widget.userId);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  Uri? get _bannerUrl => bannerUrlFromProfile(_profile);

  bool get _ignored => widget.client.ignoredUsers.contains(widget.userId);

  Future<void> _toggleIgnore() async {
    try {
      if (_ignored) {
        await widget.client.unignoreUser(widget.userId);
      } else {
        await widget.client.ignoreUser(widget.userId);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Jumps to the existing direct chat with the user (or creates one) —
  /// selected in place by the active home layout when possible, with a
  /// pushed chat page as fallback for the plain list layout.
  Future<void> _message() async {
    final navigator = Navigator.of(context);
    final encrypt = SettingsScope.of(context).encryptNewDirectChats;
    try {
      final roomId = await widget.client.startDirectChat(
        widget.userId,
        enableEncryption: encrypt,
      );
      if (!mounted) return;
      navigator.pop();
      if (RoomNavigator.instance.open(roomId)) return;
      final room = widget.client.getRoomById(roomId);
      if (room != null) {
        navigator.push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
      }
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
    final colorScheme = Theme.of(context).colorScheme;
    final displayName =
        _profile?.displayname ?? widget.displayName ?? widget.userId;
    final avatarUrl = _profile?.avatarUrl ?? widget.avatarUrl;
    final bannerUrl = _bannerUrl;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: bannerUrl != null
                      ? MxcImage(
                          client: widget.client,
                          uri: bannerUrl,
                          // Scale (not crop) so the only crop is the card's
                          // own cover fit — the server's 16:9 pre-crop made
                          // the banner blurry and doubly cropped.
                          thumbnailWidth: 800,
                          thumbnailHeight: 800,
                          thumbnailMethod: ThumbnailMethod.scale,
                          placeholder: (_) => ColoredBox(
                            color: InitialsAvatar.colorFor(displayName),
                          ),
                        )
                      : ColoredBox(color: InitialsAvatar.colorFor(displayName)),
                ),
                Positioned(
                  left: 16,
                  bottom: -36,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    child: PresenceAvatar(
                      client: widget.client,
                      userId: widget.userId,
                      name: displayName,
                      avatarUrl: avatarUrl,
                      radius: 36,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 44),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    widget.userId,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  PresenceLabel(
                    client: widget.client,
                    userId: widget.userId,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (widget.userId != widget.client.userID) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: _message,
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: Text(context.l10n.message),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _toggleIgnore,
                          icon: Icon(
                            _ignored ? Icons.person_add_outlined : Icons.block,
                            size: 18,
                          ),
                          label: Text(
                            _ignored
                                ? context.l10n.unblock
                                : context.l10n.block,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
