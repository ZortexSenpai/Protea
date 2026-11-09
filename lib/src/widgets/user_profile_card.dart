import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../nicknames.dart';
import '../pages/room_page.dart';
import '../room_navigator.dart';
import '../settings.dart';
import 'initials_avatar.dart';
import 'mxc_avatar.dart';
import 'nickname_dialog.dart';
import 'presence_indicator.dart';
import 'user_banner.dart';

/// Jumps to the existing direct chat with [userId] (or creates one) —
/// selected in place by the active home layout when possible, with a
/// pushed chat page as fallback for the plain list layout. [beforeOpen]
/// runs once the chat exists, e.g. to close the popover it was started from.
/// [focusComposer] puts the caret in the chat's message box.
Future<void> openDirectChat(
  BuildContext context,
  Client client,
  String userId, {
  VoidCallback? beforeOpen,
  bool focusComposer = false,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final encrypt = SettingsScope.of(context).encryptNewDirectChats;
  try {
    final roomId = await client.startDirectChat(
      userId,
      enableEncryption: encrypt,
    );
    beforeOpen?.call();
    if (focusComposer) ComposerFocus.instance.request(roomId);
    if (RoomNavigator.instance.open(roomId)) return;
    final room = client.getRoomById(roomId);
    if (room != null) {
      navigator.push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

/// Shows a Discord-style profile card for [userId]: banner, avatar with
/// presence, display name, user ID, status and — when opened from a room —
/// the member's role (owner, admin, moderator).
///
/// The card opens as a popover anchored next to the tapped widget
/// ([context]'s render box), not as a centered dialog: no barrier dim, and
/// a click anywhere else dismisses it.
Future<void> showUserProfileCard(
  BuildContext context, {
  required Client client,
  required String userId,
  String? displayName,
  Uri? avatarUrl,
  Room? room,
}) {
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
  final box = context.findRenderObject();
  final anchor = box is RenderBox && box.hasSize
      ? Rect.fromPoints(
          box.localToGlobal(Offset.zero, ancestor: overlay),
          box.localToGlobal(
            box.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        )
      : null;
  return showDialog(
    context: context,
    barrierColor: Colors.transparent,
    useSafeArea: false,
    builder: (_) => _ProfilePopover(
      anchor: anchor,
      child: UserProfileCard(
        client: client,
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        room: room,
      ),
    ),
  );
}

/// Places the card beside [anchor] — on whichever side has more room,
/// top-aligned with it and clamped to the screen — or centers it when no
/// anchor is available.
class _ProfilePopover extends StatelessWidget {
  const _ProfilePopover({required this.anchor, required this.child});

  final Rect? anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final anchor = this.anchor;
    if (anchor == null) return Center(child: child);
    return CustomSingleChildLayout(
      delegate: _PopoverLayout(anchor),
      child: child,
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout(this.anchor);

  final Rect anchor;

  /// Space between the anchor and the card.
  static const _gap = 12.0;

  /// Minimum distance from the screen edges.
  static const _margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final spaceRight = size.width - anchor.right;
    final fitsRight = spaceRight >= childSize.width + _gap + _margin;
    final fitsLeft = anchor.left >= childSize.width + _gap + _margin;
    final x = fitsRight || !fitsLeft
        ? anchor.right + _gap
        : anchor.left - childSize.width - _gap;
    return Offset(
      x.clamp(
        _margin,
        (size.width - childSize.width - _margin).clamp(
          _margin,
          double.infinity,
        ),
      ),
      anchor.top.clamp(
        _margin,
        (size.height - childSize.height - _margin).clamp(
          _margin,
          double.infinity,
        ),
      ),
    );
  }

  @override
  bool shouldRelayout(_PopoverLayout oldDelegate) =>
      oldDelegate.anchor != anchor;
}

class UserProfileCard extends StatefulWidget {
  const UserProfileCard({
    super.key,
    required this.client,
    required this.userId,
    this.displayName,
    this.avatarUrl,
    this.room,
  });

  final Client client;
  final String userId;

  /// Optional prefill so the card renders instantly while the full profile
  /// loads in the background.
  final String? displayName;
  final Uri? avatarUrl;

  /// When set, the card shows the user's role in this room.
  final Room? room;

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
      // The shared look-up bounds the SDK's day-long profile cache, so an
      // edited status (which never syncs) shows up.
      final profile = await fetchExtendedProfile(widget.client, widget.userId);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  Uri? get _bannerUrl => bannerUrlFromProfile(_profile);

  /// The user's role in [UserProfileCard.room], or null when the card was
  /// opened without room context or the user is not a joined member.
  PowerLevelRole? get _role {
    final room = widget.room;
    if (room == null) return null;
    final user = room.unsafeGetUserFromMemoryOrFallback(widget.userId);
    if (user.membership != Membership.join) return null;
    return user.powerLevel.role;
  }

  bool get _ignored => widget.client.ignoredUsers.contains(widget.userId);

  Future<void> _editNickname() async {
    if (await showNicknameDialog(context, widget.client, widget.userId) &&
        mounted) {
      setState(() {});
    }
  }

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

  Future<void> _message() {
    final navigator = Navigator.of(context);
    return openDirectChat(
      context,
      widget.client,
      widget.userId,
      // Closes the card popover, unless it was dismissed while the chat
      // was being created (popping then would close the wrong route).
      beforeOpen: () {
        if (mounted) navigator.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profileName =
        _profile?.displayname ?? widget.displayName ?? widget.userId;
    final nickname = nicknameOf(widget.client, widget.userId);
    final displayName = nickname ?? profileName;
    final isSelf = widget.userId == widget.client.userID;
    final avatarUrl = _profile?.avatarUrl ?? widget.avatarUrl;
    final bannerUrl = _bannerUrl;
    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(16),
      color: colorScheme.surfaceContainerHigh,
      elevation: 6,
      child: SizedBox(
        width: 340,
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
                // Discord-style status bubble in the free space right of
                // the avatar, its tail dots pointing back at the avatar.
                Positioned(
                  left: 112,
                  right: 16,
                  top: 112,
                  child: PresenceBuilder(
                    client: widget.client,
                    userId: widget.userId,
                    builder: (context, presence) {
                      final status = resolveUserStatus(
                        presenceStatusMsg: presence?.statusMsg,
                        profileStatus: statusFromProfile(_profile),
                      );
                      if (status == null) return const SizedBox.shrink();
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: _StatusBubble(status: status),
                      );
                    },
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isSelf)
                        IconButton(
                          onPressed: _editNickname,
                          tooltip: context.l10n.setNickname,
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                    ],
                  ),
                  // With a nickname set, the real display name stays visible
                  // next to the user ID.
                  Text(
                    nickname != null && nickname != profileName
                        ? '$profileName · ${widget.userId}'
                        : widget.userId,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_role case final role?) ...[
                    const SizedBox(height: 10),
                    _RoleBadge(role: role),
                  ],
                  const SizedBox(height: 12),
                  PresenceLabel(
                    client: widget.client,
                    userId: widget.userId,
                    style: Theme.of(context).textTheme.bodyMedium,
                    showStatus: false,
                  ),
                  if (!isSelf) ...[
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

/// The user's status as a speech bubble, with two shrinking dots on its
/// lower left trailing off towards the avatar.
class _StatusBubble extends StatelessWidget {
  const _StatusBubble({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Lifted a step above the card so it stands out over the banner too.
    final color = colorScheme.surfaceContainerHighest;
    const shadow = [
      BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
    ];
    Widget dot(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: shadow,
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(left: -12, bottom: -8, child: dot(6)),
        Positioned(left: -4, bottom: -2, child: dot(10)),
        Tooltip(
          message: status,
          waitDuration: const Duration(milliseconds: 500),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: shadow,
            ),
            child: Text(
              status,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
            ),
          ),
        ),
      ],
    );
  }
}

/// A compact pill naming the user's room role, e.g. "Admin".
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final PowerLevelRole role;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, label) = switch (role) {
      PowerLevelRole.owner => (
        Icons.workspace_premium_outlined,
        context.l10n.owner,
      ),
      PowerLevelRole.admin => (Icons.shield, context.l10n.admin),
      PowerLevelRole.moderator => (
        Icons.shield_outlined,
        context.l10n.moderator,
      ),
      PowerLevelRole.user => (Icons.person_outline, context.l10n.member),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
