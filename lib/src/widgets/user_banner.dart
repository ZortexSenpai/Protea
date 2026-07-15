import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'mxc_avatar.dart';

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

/// Fields checked for the custom status text, most preferred first.
/// `chat.commet.profile_status` is what Commet writes.
const statusReadFields = ['chat.commet.profile_status'];

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

/// Extracts the custom status text from an extended profile, or null when
/// none is set.
String? statusFromProfile(ProfileInformation? profile) {
  final properties = profile?.additionalProperties;
  if (properties == null) return null;
  for (final field in statusReadFields) {
    final value = _cleanProfileString(properties[field]);
    if (value != null) return value;
  }
  return null;
}

/// In-memory cache of extended profiles per user so the sync-driven list
/// rebuilds don't refetch them. Futures are cached to dedupe parallel
/// requests; a failed lookup is evicted so it retries on a later rebuild.
final _profileCache = <String, Future<ProfileInformation?>>{};

/// Bumped by [invalidateUserProfile] so live banner/status widgets reload.
final _profileCacheVersion = ValueNotifier<int>(0);

/// Fetches [userId]'s extended profile through the cache.
Future<ProfileInformation?> fetchExtendedProfile(Client client, String userId) {
  final key = '${client.userID};$userId';
  return _profileCache[key] ??= () async {
    try {
      return await client.getUserProfile(userId);
    } catch (_) {
      _profileCache.remove(key);
      return null;
    }
  }();
}

/// Resolves the banner mxc URL from [userId]'s extended profile
/// ([bannerReadFields]), or null when none is set.
Future<Uri?> fetchUserBannerUrl(Client client, String userId) async =>
    bannerUrlFromProfile(await fetchExtendedProfile(client, userId));

/// Resolves the custom status text from [userId]'s extended profile
/// ([statusReadFields]), or null when none is set.
Future<String?> fetchUserStatus(Client client, String userId) async =>
    statusFromProfile(await fetchExtendedProfile(client, userId));

/// Drops [userId]'s cached extended profile (across accounts) and tells
/// visible banner/status widgets to reload, e.g. after uploading a new
/// banner.
void invalidateUserProfile(String userId) {
  _profileCache.removeWhere((key, _) => key.endsWith(';$userId'));
  _profileCacheVersion.value++;
}

/// Draws [child] on top of the user's profile banner (when one is set),
/// fading the image out toward the left so leading text stays readable —
/// akin to Discord's nameplates.
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
    final url = await fetchUserBannerUrl(widget.client, widget.userId);
    if (mounted && url != _bannerUrl) setState(() => _bannerUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final bannerUrl = _bannerUrl;
    if (bannerUrl == null) return widget.child;
    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: ShaderMask(
              // The mask wraps the image's own box (not the whole tile), so
              // the banner fades in smoothly from its left edge instead of
              // popping in mid-tile with a visible seam.
              shaderCallback: (rect) => LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: widget.opacity),
                ],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: MxcImage(
                client: widget.client,
                uri: bannerUrl,
                // Scale keeps the full image (no server-side crop); the
                // image sizes to the tile height at its natural aspect.
                thumbnailWidth: 320,
                thumbnailHeight: 180,
                thumbnailMethod: ThumbnailMethod.scale,
                fit: BoxFit.fitHeight,
                expand: false,
                placeholder: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// The user's custom status text ([statusReadFields]) as a single line,
/// collapsing to nothing while loading or when no status is set.
class UserStatusText extends StatefulWidget {
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
  State<UserStatusText> createState() => _UserStatusTextState();
}

class _UserStatusTextState extends State<UserStatusText> {
  String? _status;

  @override
  void initState() {
    super.initState();
    _profileCacheVersion.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(UserStatusText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _status = null;
      _load();
    }
  }

  @override
  void dispose() {
    _profileCacheVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final status = await fetchUserStatus(widget.client, widget.userId);
    if (mounted && status != _status) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    return Text(
      status,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}
