import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'mxc_avatar.dart';
import 'presence_indicator.dart';

/// Profile field new banners are written to, per MSC4133 extended profiles.
/// This is the key Commet, Sable and VirtualChat use, so banners set in
/// Protea show up there and vice versa.
const bannerWriteField = 'chat.commet.profile_banner';

/// Fields checked when looking up a banner, most preferred first:
/// the shared Commet key, the MSC4427 proposed stable name, Commet's legacy
/// key and Protea's own former key (banners uploaded with older builds).
const bannerReadFields = [
  bannerWriteField,
  'm.banner_uri',
  'com.commet.banner_url',
  'energy.vgt.protea.banner_url',
];

/// MSC4426 status field (unstable prefix), an object holding `text` and
/// `emoji`.
const msc4426StatusField = 'org.matrix.msc4426.status';

/// Commet's status field, a plain string.
const commetStatusField = 'chat.commet.profile_status';

/// Fields checked for the custom status text, most preferred first: the
/// MSC4426 unstable field, its stable name, then Commet's field. The
/// presence status message is the last resort (see [resolveUserStatus]).
const statusReadFields = [msc4426StatusField, 'm.status', commetStatusField];

/// Unwraps a profile field value: non-string, empty and (homeserver quirk)
/// literal-quote-wrapped values are normalised.
String? _cleanProfileString(Object? value) {
  if (value is! String) return null;
  var cleaned = value;
  if (cleaned.length >= 2 && cleaned.startsWith('"') && cleaned.endsWith('"')) {
    cleaned = cleaned.substring(1, cleaned.length - 1);
  }
  cleaned = cleaned.trim();
  return cleaned.isEmpty ? null : cleaned;
}

/// Extracts the banner mxc URL from an extended profile, or null when no
/// recognised field holds one.
Uri? bannerUrlFromProfile(ProfileInformation? profile) {
  final properties = profile?.additionalProperties;
  if (properties == null) return null;
  for (final field in bannerReadFields) {
    final value = _cleanProfileString(properties[field]);
    if (value != null && value.startsWith('mxc://')) {
      return Uri.tryParse(value);
    }
  }
  return null;
}

/// Formats one status field's value: MSC4426 objects as `emoji text`
/// (either part may be missing), plain strings as they are. Null when the
/// value holds nothing to show.
String? _statusFromValue(Object? value) {
  if (value is Map) {
    final parts = [
      _cleanProfileString(value['emoji']),
      _cleanProfileString(value['text']),
    ].nonNulls;
    return parts.isEmpty ? null : parts.join(' ');
  }
  return _cleanProfileString(value);
}

/// Extracts the custom status text from an extended profile — the first
/// non-empty field of [statusReadFields] — or null when none is set.
String? statusFromProfile(ProfileInformation? profile) {
  final properties = profile?.additionalProperties;
  if (properties == null) return null;
  for (final field in statusReadFields) {
    final value = _statusFromValue(properties[field]);
    if (value != null) return value;
  }
  return null;
}

/// In-memory cache of extended profiles per user so the sync-driven list
/// rebuilds don't refetch them. Futures are cached to dedupe parallel
/// requests; a failed lookup is evicted so it retries on a later rebuild.
final _profileCache = <String, _CachedProfile>{};

/// How long a cached profile is served before it is fetched again. Extended
/// profile fields never travel over sync, so nothing pushes someone else's
/// status edit to us — without an expiry the first value we read would stick
/// for the rest of the run.
const _profileCacheTtl = Duration(minutes: 1);

/// How old the SDK's own profile cache may be on an ordinary look-up. The
/// SDK keeps profiles in its database for a day and only marks them outdated
/// on membership events, which editing a status does not produce — so
/// without this, a refetch just reads the same stale row back.
const _profileMaxCacheAge = Duration(minutes: 15);

/// Users whose profile was dropped on purpose ([dropCachedUserProfile]):
/// their next look-up must come from the server, not from either cache. The
/// flag is cleared only once a fetch actually succeeds, so a failed attempt
/// (or a second account showing the same user) still gets a fresh copy.
final _forceRefresh = <String>{};

/// A cached profile look-up together with when it was started, so stale
/// entries can be refetched.
class _CachedProfile {
  _CachedProfile(this.profile) : fetchedAt = DateTime.now();

  final Future<ProfileInformation?> profile;
  final DateTime fetchedAt;

  bool get isFresh => DateTime.now().difference(fetchedAt) < _profileCacheTtl;
}

/// Bumped by [invalidateUserProfile] so live banner/status widgets reload.
final _profileCacheVersion = ValueNotifier<int>(0);

/// Notifies whenever a profile is invalidated (status or banner edited), so
/// widgets showing many users' profile data can refresh their caches.
ValueListenable<int> get profileUpdates => _profileCacheVersion;

/// Fetches [userId]'s extended profile, served from the cache while the
/// cached copy is still fresh.
Future<ProfileInformation?> fetchExtendedProfile(Client client, String userId) {
  final key = '${client.userID};$userId';
  final cached = _profileCache[key];
  if (cached != null && cached.isFresh) return cached.profile;
  final entry = _CachedProfile(() async {
    try {
      final profile = await client.getUserProfile(
        userId,
        maxCacheAge: _forceRefresh.contains(userId)
            ? Duration.zero
            : _profileMaxCacheAge,
      );
      _forceRefresh.remove(userId);
      return profile;
    } catch (_) {
      _profileCache.remove(key);
      return null;
    }
  }());
  _profileCache[key] = entry;
  return entry.profile;
}

/// Resolves the banner mxc URL from [userId]'s extended profile
/// ([bannerReadFields]), or null when none is set.
Future<Uri?> fetchUserBannerUrl(Client client, String userId) async =>
    bannerUrlFromProfile(await fetchExtendedProfile(client, userId));

/// Resolves the custom status text from [userId]'s extended profile
/// ([statusReadFields]), or null when none is set.
Future<String?> fetchUserStatus(Client client, String userId) async =>
    statusFromProfile(await fetchExtendedProfile(client, userId));

/// The status line to show for a user, from the two places a status can
/// live: [profileStatus] (the extended profile fields, see
/// [statusFromProfile]) and [presenceStatusMsg] (the `m.presence` status
/// message). Null when neither holds anything.
///
/// The profile fields win; the presence message is only the fallback when
/// none of them is set.
String? resolveUserStatus({String? profileStatus, String? presenceStatusMsg}) {
  for (final candidate in [profileStatus, presenceStatusMsg]) {
    final status = candidate?.trim();
    if (status != null && status.isNotEmpty) return status;
  }
  return null;
}

/// Drops [userId]'s cached extended profile (across accounts) and tells
/// visible banner/status widgets to reload, e.g. after uploading a new
/// banner.
void invalidateUserProfile(String userId) {
  dropCachedUserProfile(userId);
  _profileCacheVersion.value++;
}

/// Drops [userId]'s cached extended profile (across accounts) without asking
/// every visible widget to reload — for callers that refresh this one user
/// themselves, so a single presence update can't trigger a profile fetch for
/// every member of the room. The next look-up bypasses the SDK's cache too.
void dropCachedUserProfile(String userId) {
  _profileCache.removeWhere((key, _) => key.endsWith(';$userId'));
  _forceRefresh.add(userId);
  _profileDrops.drop(userId);
}

/// Whether [next] changed in a way that hints the user also edited their
/// status text. A presence update is the only signal we get: Protea writes
/// the status to both the presence and the profile field, but only presence
/// travels over sync. The first presence seen for a user is no hint — with
/// nothing to compare against it would force a refetch for every user the
/// first sync mentions.
bool _presenceSuggestsStatusChange(
  CachedPresence? previous,
  CachedPresence next,
) =>
    previous != null &&
    (previous.statusMsg != next.statusMsg ||
        previous.presence != next.presence);

/// Notifies whenever one user's cached profile is dropped, so widgets showing
/// that user reload while everyone else's cache is left alone. The user is
/// read from [droppedProfileUserId]; a plain [Listenable] because the same
/// user can be dropped twice in a row.
Listenable get profileDrops => _profileDrops;

/// The user whose profile was dropped in the notification being handled.
String? get droppedProfileUserId => _profileDrops.userId;

final _profileDrops = _ProfileDropNotifier();

class _ProfileDropNotifier extends ChangeNotifier {
  String? userId;

  void drop(String user) {
    userId = user;
    notifyListeners();
  }
}

/// Watches [client]'s presence stream and drops the cached profile of anyone
/// whose status message or presence changed. This runs for the whole session
/// rather than from a widget, because the hint has to be acted on even when
/// nothing showing that user is on screen — otherwise opening the member list
/// afterwards just reads the stale profile back out of the caches.
StreamSubscription<CachedPresence> watchProfileHints(Client client) {
  final seen = <String, CachedPresence>{};
  return client.onPresenceChanged.stream.listen((presence) {
    final previous = seen[presence.userid];
    seen[presence.userid] = presence;
    if (_presenceSuggestsStatusChange(previous, presence)) {
      dropCachedUserProfile(presence.userid);
    }
  });
}

/// Draws [child] on top of the user's profile banner (when one is set) —
/// akin to Discord's nameplates. The banner covers the whole tile; a
/// subtle fade toward the left keeps the leading name readable without
/// leaving a bare stripe behind it.
class UserBannerBackground extends StatefulWidget {
  const UserBannerBackground({
    super.key,
    required this.client,
    required this.userId,
    required this.child,
    this.opacity = 0.7,
  });

  final Client client;
  final String userId;
  final Widget child;

  /// Peak opacity of the banner at the right edge.
  final double opacity;

  @override
  State<UserBannerBackground> createState() => _UserBannerBackgroundState();
}

class _UserBannerBackgroundState extends State<UserBannerBackground> {
  Uri? _bannerUrl;

  @override
  void initState() {
    super.initState();
    _profileCacheVersion.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(UserBannerBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _bannerUrl = null;
      _load();
    }
  }

  @override
  void dispose() {
    _profileCacheVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final userId = widget.userId;
    final url = await fetchUserBannerUrl(widget.client, userId);
    // Discard stale results: the row may have been recycled to another
    // user while this fetch was in flight.
    if (mounted && userId == widget.userId && url != _bannerUrl) {
      setState(() => _bannerUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannerUrl = _bannerUrl;
    if (bannerUrl == null) return widget.child;
    return Stack(
      children: [
        Positioned.fill(
          child: ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.35 * widget.opacity),
                Colors.white.withValues(alpha: widget.opacity),
              ],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: MxcImage(
              client: widget.client,
              uri: bannerUrl,
              // Scale keeps the full image server-side; cover crops it
              // client-side so it fills the whole tile.
              thumbnailWidth: 320,
              thumbnailHeight: 180,
              thumbnailMethod: ThumbnailMethod.scale,
              fit: BoxFit.cover,
              placeholder: (_) => const SizedBox.shrink(),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Builds with the user's [presence] and resolved [status] — the first
/// profile field of [statusReadFields] that is set, or their presence status
/// message when none is (see [resolveUserStatus]). Reloads the profile when
/// it is invalidated or dropped, so status edits show up live.
class UserStatusBuilder extends StatefulWidget {
  const UserStatusBuilder({
    super.key,
    required this.client,
    required this.userId,
    required this.builder,
  });

  final Client client;
  final String userId;
  final Widget Function(
    BuildContext context,
    CachedPresence? presence,
    String? status,
  )
  builder;

  @override
  State<UserStatusBuilder> createState() => _UserStatusBuilderState();
}

class _UserStatusBuilderState extends State<UserStatusBuilder> {
  String? _status;

  @override
  void initState() {
    super.initState();
    _profileCacheVersion.addListener(_load);
    profileDrops.addListener(_onProfileDropped);
    _load();
  }

  /// Reloads when this user's profile was dropped, e.g. because their
  /// presence hinted they edited their status.
  void _onProfileDropped() {
    if (droppedProfileUserId == widget.userId) _load();
  }

  @override
  void didUpdateWidget(UserStatusBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _status = null;
      _load();
    }
  }

  @override
  void dispose() {
    profileDrops.removeListener(_onProfileDropped);
    _profileCacheVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final userId = widget.userId;
    final status = await fetchUserStatus(widget.client, userId);
    // Discard stale results (see the banner loader above).
    if (mounted && userId == widget.userId && status != _status) {
      setState(() => _status = status);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PresenceBuilder(
      client: widget.client,
      userId: widget.userId,
      builder: (context, presence) => widget.builder(
        context,
        presence,
        resolveUserStatus(
          profileStatus: _status,
          presenceStatusMsg: presence?.statusMsg,
        ),
      ),
    );
  }
}

/// The user's status as a single line (see [UserStatusBuilder]), collapsing
/// to nothing when none is set.
class UserStatusText extends StatelessWidget {
  const UserStatusText({
    super.key,
    required this.client,
    required this.userId,
    this.style,
  });

  final Client client;
  final String userId;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return UserStatusBuilder(
      client: client,
      userId: userId,
      builder: (context, presence, status) {
        if (status == null) return const SizedBox.shrink();
        return Text(
          status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}
