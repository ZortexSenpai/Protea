import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'mxc_avatar.dart';

/// Fetches the presence of [userId] once and rebuilds on every later update.
class PresenceBuilder extends StatefulWidget {
  const PresenceBuilder({
    super.key,
    required this.client,
    required this.userId,
    required this.builder,
  });

  final Client client;
  final String userId;
  final Widget Function(BuildContext context, CachedPresence? presence) builder;

  @override
  State<PresenceBuilder> createState() => _PresenceBuilderState();
}

class _PresenceBuilderState extends State<PresenceBuilder> {
  CachedPresence? _presence;
  StreamSubscription<CachedPresence>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.client.onPresenceChanged.stream.listen((presence) {
      if (presence.userid == widget.userId && mounted) {
        setState(() => _presence = presence);
      }
    });
    _fetch();
  }

  @override
  void didUpdateWidget(PresenceBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _presence = null;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    try {
      final presence = await widget.client.fetchCurrentPresence(widget.userId);
      if (mounted) setState(() => _presence ??= presence);
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _presence);
}

/// A small colored dot showing whether a user is online, away or offline.
class PresenceDot extends StatelessWidget {
  const PresenceDot({
    super.key,
    required this.client,
    required this.userId,
    this.size = 10,
  });

  final Client client;
  final String userId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PresenceBuilder(
      client: client,
      userId: userId,
      builder: (context, presence) {
        final color = switch (presence?.presence) {
          PresenceType.online => const Color(0xFF43A047),
          PresenceType.unavailable => const Color(0xFFF9A825),
          _ => colorScheme.outlineVariant,
        };
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.surface, width: 1.5),
          ),
        );
      },
    );
  }
}

/// An avatar with a presence dot in the bottom-right corner.
class PresenceAvatar extends StatelessWidget {
  const PresenceAvatar({
    super.key,
    required this.client,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.radius = 20,
  });

  final Client client;
  final String userId;
  final String name;
  final Uri? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MxcAvatar(
            client: client,
            name: name,
            avatarUrl: avatarUrl,
            radius: radius,
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: PresenceDot(
              client: client,
              userId: userId,
              size: radius * 0.55,
            ),
          ),
        ],
      ),
    );
  }
}

/// A one-line textual presence status, e.g. "Online" or "Last seen 5 m ago".
class PresenceLabel extends StatelessWidget {
  const PresenceLabel({
    super.key,
    required this.client,
    required this.userId,
    this.style,
  });

  final Client client;
  final String userId;
  final TextStyle? style;

  static String _text(CachedPresence presence) {
    final base = switch (presence.presence) {
      PresenceType.online => 'Online',
      PresenceType.unavailable => 'Away',
      PresenceType.offline =>
        presence.lastActiveTimestamp == null
            ? 'Offline'
            : 'Last seen ${_relative(presence.lastActiveTimestamp!)}',
    };
    final status = presence.statusMsg;
    return status == null || status.isEmpty ? base : '$base — $status';
  }

  static String _relative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    return PresenceBuilder(
      client: client,
      userId: userId,
      builder: (context, presence) => presence == null
          ? const SizedBox.shrink()
          : Text(
              _text(presence),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}
