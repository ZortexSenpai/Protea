import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:html/dom.dart' show DocumentFragment;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// What a link preview card shows, whether it was built from the homeserver's
/// generic `preview_url` answer or from a [PreviewSite]'s own API.
class Embed {
  const Embed({
    required this.url,
    this.siteName,
    this.author,
    this.authorUrl,
    this.title,
    this.description,
    this.stats = const [],
    this.footer,
    this.timestamp,
    this.image,
    this.color,
  });

  /// Where tapping the card goes: the previewed link itself.
  final String url;
  final String? siteName;
  final String? author;
  final String? authorUrl;
  final String? title;
  final String? description;

  /// Small facts under the description (stars, issue state, duration, …).
  final List<EmbedStat> stats;

  /// Free text at the bottom, e.g. a post's date as the site formats it.
  final String? footer;

  /// A date at the bottom, formatted for the user's locale.
  final DateTime? timestamp;
  final EmbedImage? image;

  /// The accent bar's color; null uses the theme's.
  final Color? color;

  Embed copyWith({String? description, EmbedImage? image}) => Embed(
    url: url,
    siteName: siteName,
    author: author,
    authorUrl: authorUrl,
    title: title,
    description: description ?? this.description,
    stats: stats,
    footer: footer,
    timestamp: timestamp,
    image: image ?? this.image,
    color: color,
  );
}

enum EmbedImageLayout {
  /// Full card width under the text.
  large,

  /// A small square to the right of the text.
  thumbnail,
}

class EmbedImage {
  const EmbedImage(
    this.uri, {
    this.width,
    this.height,
    this.layout = EmbedImageLayout.large,
    this.video = false,
  });

  /// `mxc://` when the homeserver re-hosted it, otherwise the site's
  /// `https://` CDN URL.
  final Uri uri;
  final int? width;
  final int? height;
  final EmbedImageLayout layout;

  /// Draws a play button over the image.
  final bool video;

  double? get aspectRatio {
    final width = this.width;
    final height = this.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }
}

enum EmbedStatKind {
  stars,
  forks,
  language,
  comments,
  duration,
  issueOpen,
  issueClosed,
  issueNotPlanned,
  pullOpen,
  pullDraft,
  pullMerged,
  pullClosed,
}

/// One fact on a card; [value] is already formatted for display (the state
/// kinds carry none, the card labels them).
typedef EmbedStat = ({EmbedStatKind kind, String? value});

/// Sites whose links get a richer card built from the site's own public API
/// (none of them needs an API key). The request goes from this device to the
/// site, so each can be switched off in the settings, which falls back to the
/// homeserver's generic preview.
enum PreviewSite {
  youtube('YouTube', Color(0xFFFF0033), ['youtube.com', 'youtu.be']),
  reddit('Reddit', Color(0xFFFF4500), ['reddit.com']),
  x('X', Color(0xFF1D9BF0), ['x.com', 'twitter.com']),
  bluesky('Bluesky', Color(0xFF1185FE), ['bsky.app']),
  github('GitHub', Color(0xFF8B949E), ['github.com']),
  wikipedia('Wikipedia', Color(0xFFA2A9B1), ['wikipedia.org']),
  spotify('Spotify', Color(0xFF1ED760), ['open.spotify.com']),
  soundcloud('SoundCloud', Color(0xFFFF5500), ['soundcloud.com']),
  vimeo('Vimeo', Color(0xFF17D5FF), ['vimeo.com']);

  const PreviewSite(this.label, this.color, this.domains);

  final String label;
  final Color color;

  /// Shown in the settings so it is clear which links a switch covers.
  final List<String> domains;

  /// The site whose rich preview applies to [url], or null.
  static PreviewSite? of(Uri url) {
    if (url.scheme != 'https' && url.scheme != 'http') return null;
    try {
      for (final site in values) {
        if (site._matches(url)) return site;
      }
    } catch (_) {
      // Undecodable query or path: leave it to the homeserver.
    }
    return null;
  }

  bool _matches(Uri url) => switch (this) {
    youtube => _youtubeVideo(url) != null,
    reddit => _redditPost(url) != null,
    x => _tweet(url) != null,
    bluesky => _bskyPost(url) != null,
    github => _githubTarget(url) != null,
    wikipedia => _wikipediaArticle(url) != null,
    spotify => _spotifyItem(url) != null,
    soundcloud => _soundcloudItem(url),
    vimeo => _vimeoVideo(url),
  };

  /// Whether the homeserver's image fills in when the site's API has none
  /// (oEmbed answers for posts carry no media).
  bool get _imageFromHomeserver => this == reddit || this == bluesky;

  /// Whether the homeserver's description fills in when the site's API has
  /// none (Spotify's oEmbed lacks the "Artist · Song · Year" line).
  bool get _descriptionFromHomeserver => this == spotify;

  /// The rich card for [url], or null when the site has none for it (deleted
  /// post, rate limit, network error, …).
  Future<Embed?> fetch(Uri url, http.Client client) => switch (this) {
    youtube => _fetchYoutube(url, client),
    reddit => _fetchReddit(url, client),
    x => _fetchTweet(url, client),
    bluesky => _fetchBskyPost(url, client),
    github => _fetchGithub(url, client),
    wikipedia => _fetchWikipedia(url, client),
    spotify => _fetchSpotify(url, client),
    soundcloud => _fetchSoundcloud(url, client),
    vimeo => _fetchVimeo(url, client),
  };
}

/// The preview card for [url]: [site]'s rich card when one is given and its
/// API answers, otherwise the generic card from the [homeserver]'s
/// `preview_url` (whose OpenGraph map it returns). The homeserver also fills
/// in what some sites' APIs leave out.
Future<Embed?> loadEmbed(
  String url, {
  PreviewSite? site,
  required http.Client client,
  required Future<Map<String, Object?>?> Function() homeserver,
}) async {
  Embed? embed;
  if (site != null) {
    try {
      embed = await site.fetch(Uri.parse(url), client);
    } catch (_) {
      embed = null;
    }
    if (embed != null) {
      final wantsImage = embed.image == null && site._imageFromHomeserver;
      final wantsDescription =
          embed.description == null && site._descriptionFromHomeserver;
      if (!wantsImage && !wantsDescription) return embed;
    }
  }
  Map<String, Object?>? openGraph;
  try {
    openGraph = await homeserver();
  } catch (_) {
    openGraph = null;
  }
  final generic = openGraph == null ? null : embedFromOpenGraph(url, openGraph);
  if (embed == null) return generic;
  return embed.copyWith(
    description: embed.description == null && site!._descriptionFromHomeserver
        ? generic?.description
        : null,
    image: embed.image == null && site!._imageFromHomeserver
        ? generic?.image
        : null,
  );
}

/// The generic card for [url] from the homeserver's `preview_url` answer
/// (the OpenGraph tags it scraped), or null when there is nothing to show.
Embed? embedFromOpenGraph(String url, Map<String, Object?> og) {
  final title = _string(og, 'og:title');
  final description = _string(og, 'og:description');
  final imageUri = Uri.tryParse(_string(og, 'og:image') ?? '');
  // Only images the homeserver re-hosted: fetching anything else would tell
  // the linked site who is reading the chat.
  final image = imageUri != null && imageUri.scheme == 'mxc'
      ? _openGraphImage(
          imageUri,
          _int(og, 'og:image:width'),
          _int(og, 'og:image:height'),
        )
      : null;
  if (title == null && description == null && image == null) return null;
  return Embed(
    url: url,
    siteName: _string(og, 'og:site_name') ?? Uri.tryParse(url)?.host,
    title: title,
    description: description,
    image: image,
  );
}

/// Wide images (a site's social card) go under the text, anything else (logos,
/// avatars, unknown sizes) next to it.
EmbedImage _openGraphImage(Uri uri, int? width, int? height) {
  final large =
      width != null && height != null && width >= 400 && width >= height * 1.3;
  return EmbedImage(
    uri,
    width: width,
    height: height,
    layout: large ? EmbedImageLayout.large : EmbedImageLayout.thumbnail,
  );
}

// ---------------------------------------------------------------------------
// Shared helpers

const _timeout = Duration(seconds: 10);

Future<Map<String, Object?>?> _getJson(http.Client client, Uri uri) async {
  final response = await client
      .get(uri, headers: const {'Accept': 'application/json'})
      .timeout(_timeout);
  if (response.statusCode != 200) return null;
  final body = jsonDecode(utf8.decode(response.bodyBytes));
  return body is Map<String, Object?> ? body : null;
}

String? _string(Map<String, Object?>? json, String key) {
  final value = json?[key];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _int(Map<String, Object?>? json, String key) => switch (json?[key]) {
  final int value => value,
  final num value => value.toInt(),
  final String value => int.tryParse(value),
  _ => null,
};

Map<String, Object?>? _map(Map<String, Object?>? json, String key) =>
    switch (json?[key]) {
      final Map<String, Object?> value => value,
      _ => null,
    };

/// [url]'s host is [domain] or one of its subdomains.
bool _onDomain(Uri url, String domain) =>
    url.host == domain || url.host.endsWith('.$domain');

/// Path segments without the empty one a trailing slash leaves.
List<String> _segments(Uri url) =>
    url.pathSegments.where((segment) => segment.isNotEmpty).toList();

/// [html] parsed, with `<br>` turned into line breaks its text keeps.
DocumentFragment _fragment(String html) => html_parser.parseFragment(
  html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n'),
);

String? _nonEmpty(String? text) {
  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// The visible text of an HTML snippet, with line breaks kept.
String? _htmlText(String? html) =>
    html == null ? null : _nonEmpty(_fragment(html).text);

final _compact = NumberFormat.compact();

String _count(int value) => _compact.format(value);

// ---------------------------------------------------------------------------
// YouTube (oEmbed)

final _youtubeIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

({String id, bool short})? _youtubeVideo(Uri url) {
  String? id;
  var short = false;
  final segments = _segments(url);
  if (_onDomain(url, 'youtu.be')) {
    id = segments.firstOrNull;
  } else if (_onDomain(url, 'youtube.com') ||
      _onDomain(url, 'youtube-nocookie.com')) {
    if (segments.firstOrNull == 'watch') {
      id = url.queryParameters['v'];
    } else if (segments.length >= 2 &&
        const {'shorts', 'live', 'embed', 'v'}.contains(segments.first)) {
      id = segments[1];
      short = segments.first == 'shorts';
    }
  }
  if (id == null || !_youtubeIdPattern.hasMatch(id)) return null;
  return (id: id, short: short);
}

Future<Embed?> _fetchYoutube(Uri url, http.Client client) async {
  final video = _youtubeVideo(url)!;
  final json = await _getJson(
    client,
    Uri.https('www.youtube.com', '/oembed', {
      'format': 'json',
      'url': 'https://www.youtube.com/watch?v=${video.id}',
    }),
  );
  final title = _string(json, 'title');
  if (title == null) return null;
  // hqdefault is 4:3 with the video letterboxed in it; the card crops it back
  // to the video's own shape.
  final thumbnail =
      _string(json, 'thumbnail_url') ??
      'https://i.ytimg.com/vi/${video.id}/hqdefault.jpg';
  return Embed(
    url: url.toString(),
    siteName: PreviewSite.youtube.label,
    author: _string(json, 'author_name'),
    authorUrl: _string(json, 'author_url'),
    title: title,
    image: EmbedImage(
      Uri.parse(thumbnail),
      width: video.short ? 9 : 16,
      height: video.short ? 16 : 9,
      video: true,
    ),
    color: PreviewSite.youtube.color,
  );
}

// ---------------------------------------------------------------------------
// Reddit (oEmbed; the JSON API refuses clients without OAuth)

({String community, String id})? _redditPost(Uri url) {
  if (!_onDomain(url, 'reddit.com')) return null;
  final segments = _segments(url);
  if (segments.length < 4 || segments[2] != 'comments') return null;
  final community = switch (segments[0]) {
    'r' => 'r/${segments[1]}',
    'u' || 'user' => 'u/${segments[1]}',
    _ => null,
  };
  if (community == null) return null;
  return (community: community, id: segments[3]);
}

Future<Embed?> _fetchReddit(Uri url, http.Client client) async {
  final post = _redditPost(url)!;
  final json = await _getJson(
    client,
    Uri.https('www.reddit.com', '/oembed', {
      'url': 'https://www.reddit.com/${post.community}/comments/${post.id}/',
    }),
  );
  final title = _string(json, 'title');
  if (title == null) return null;
  final author = _string(json, 'author_name');
  return Embed(
    url: url.toString(),
    siteName: '${PreviewSite.reddit.label} · ${post.community}',
    author: author == null ? null : 'u/$author',
    authorUrl: author == null ? null : 'https://www.reddit.com/user/$author',
    title: title,
    color: PreviewSite.reddit.color,
  );
}

// ---------------------------------------------------------------------------
// X / Twitter and Bluesky (oEmbed: the post is a blockquote of HTML)

/// The post text and the trailing date link of an oEmbed blockquote.
({String? text, String? date}) _quotePost(String? html) {
  if (html == null) return (text: null, date: null);
  final fragment = _fragment(html);
  return (
    text: _nonEmpty(fragment.querySelector('p')?.text),
    date: _nonEmpty(fragment.querySelectorAll('a').lastOrNull?.text),
  );
}

({String user, String id})? _tweet(Uri url) {
  if (!_onDomain(url, 'x.com') && !_onDomain(url, 'twitter.com')) return null;
  final segments = _segments(url);
  final status = segments.indexOf('status');
  if (status < 1 || status + 1 >= segments.length) return null;
  final id = segments[status + 1];
  if (int.tryParse(id) == null) return null;
  return (user: segments[status - 1], id: id);
}

Future<Embed?> _fetchTweet(Uri url, http.Client client) async {
  final tweet = _tweet(url)!;
  final json = await _getJson(
    client,
    Uri.https('publish.twitter.com', '/oembed', {
      'omit_script': '1',
      'dnt': 'true',
      'url': 'https://twitter.com/${tweet.user}/status/${tweet.id}',
    }),
  );
  final post = _quotePost(_string(json, 'html'));
  if (post.text == null) return null;
  final name = _string(json, 'author_name');
  final authorUrl = _string(json, 'author_url');
  final handle = Uri.tryParse(authorUrl ?? '')?.pathSegments.lastOrNull;
  return Embed(
    url: url.toString(),
    siteName: PreviewSite.x.label,
    author: name == null
        ? null
        : handle == null
        ? name
        : '$name (@$handle)',
    authorUrl: authorUrl,
    description: post.text,
    footer: post.date,
    color: PreviewSite.x.color,
  );
}

/// The post's canonical link (without tracking query), or null.
String? _bskyPost(Uri url) {
  if (url.host != 'bsky.app') return null;
  final segments = _segments(url);
  if (segments.length < 4 ||
      segments[0] != 'profile' ||
      segments[2] != 'post') {
    return null;
  }
  return 'https://bsky.app/profile/${segments[1]}/post/${segments[3]}';
}

Future<Embed?> _fetchBskyPost(Uri url, http.Client client) async {
  final post = _bskyPost(url)!;
  final json = await _getJson(
    client,
    Uri.https('embed.bsky.app', '/oembed', {'url': post}),
  );
  final quote = _quotePost(_string(json, 'html'));
  if (quote.text == null) return null;
  return Embed(
    url: url.toString(),
    siteName: PreviewSite.bluesky.label,
    author: _string(json, 'author_name'),
    authorUrl: _string(json, 'author_url'),
    description: quote.text,
    timestamp: DateTime.tryParse(quote.date ?? ''),
    color: PreviewSite.bluesky.color,
  );
}

// ---------------------------------------------------------------------------
// GitHub (REST API; 60 unauthenticated requests per hour and IP)

/// First path segments that are GitHub pages rather than an owner.
const _githubReserved = {
  'about',
  'apps',
  'codespaces',
  'collections',
  'contact',
  'customer-stories',
  'enterprise',
  'events',
  'explore',
  'features',
  'issues',
  'login',
  'marketplace',
  'new',
  'notifications',
  'orgs',
  'organizations',
  'pricing',
  'pulls',
  'search',
  'security',
  'settings',
  'signup',
  'site',
  'sponsors',
  'team',
  'topics',
  'trending',
};

({String owner, String repo, int? number})? _githubTarget(Uri url) {
  if (url.host != 'github.com' && url.host != 'www.github.com') return null;
  final segments = _segments(url);
  if (segments.length < 2 || _githubReserved.contains(segments[0])) {
    return null;
  }
  final owner = segments[0];
  final repo = segments[1].replaceFirst(RegExp(r'\.git$'), '');
  if (segments.length == 2) return (owner: owner, repo: repo, number: null);
  if (segments.length >= 4 &&
      (segments[2] == 'issues' || segments[2] == 'pull')) {
    final number = int.tryParse(segments[3]);
    if (number != null) return (owner: owner, repo: repo, number: number);
  }
  // Files, commits, releases, …: the homeserver's preview of the page.
  return null;
}

Future<Embed?> _fetchGithub(Uri url, http.Client client) async {
  final target = _githubTarget(url)!;
  final number = target.number;
  final repoPath = '/repos/${target.owner}/${target.repo}';
  if (number == null) {
    final json = await _getJson(client, Uri.https('api.github.com', repoPath));
    final fullName = _string(json, 'full_name');
    if (fullName == null) return null;
    final language = _string(json, 'language');
    return Embed(
      url: url.toString(),
      siteName: PreviewSite.github.label,
      title: fullName,
      description: _string(json, 'description'),
      stats: [
        (
          kind: EmbedStatKind.stars,
          value: _count(_int(json, 'stargazers_count') ?? 0),
        ),
        (
          kind: EmbedStatKind.forks,
          value: _count(_int(json, 'forks_count') ?? 0),
        ),
        if (language != null) (kind: EmbedStatKind.language, value: language),
      ],
      // GitHub's own social card for the repository (the hash part of the
      // path only busts caches; any value works).
      image: EmbedImage(
        Uri.https('opengraph.githubassets.com', '/1/$fullName'),
        width: 1200,
        height: 600,
      ),
      color: PreviewSite.github.color,
    );
  }

  // The issues endpoint answers for pull requests too.
  final json = await _getJson(
    client,
    Uri.https('api.github.com', '$repoPath/issues/$number'),
  );
  final title = _string(json, 'title');
  if (json == null || title == null) return null;
  final closed = _string(json, 'state') == 'closed';
  final pull = _map(json, 'pull_request');
  final state = pull != null
      ? _string(pull, 'merged_at') != null
            ? EmbedStatKind.pullMerged
            : closed
            ? EmbedStatKind.pullClosed
            : json['draft'] == true
            ? EmbedStatKind.pullDraft
            : EmbedStatKind.pullOpen
      : !closed
      ? EmbedStatKind.issueOpen
      : _string(json, 'state_reason') == 'not_planned'
      ? EmbedStatKind.issueNotPlanned
      : EmbedStatKind.issueClosed;
  final comments = _int(json, 'comments') ?? 0;
  final user = _map(json, 'user');
  return Embed(
    url: url.toString(),
    siteName: '${PreviewSite.github.label} · ${target.owner}/${target.repo}',
    author: _string(user, 'login'),
    authorUrl: _string(user, 'html_url'),
    title: '$title #$number',
    description: _githubBody(_string(json, 'body')),
    stats: [
      (kind: state, value: null),
      if (comments > 0) (kind: EmbedStatKind.comments, value: _count(comments)),
    ],
    color: PreviewSite.github.color,
  );
}

/// An issue body without the HTML comments issue templates are full of and
/// without markdown heading markers (the card shows plain text).
String? _githubBody(String? body) {
  if (body == null) return null;
  final cleaned = body
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return cleaned.isEmpty ? null : cleaned;
}

// ---------------------------------------------------------------------------
// Wikipedia (REST page summary)

final _wikipediaHost = RegExp(r'^([a-z0-9-]+)(?:\.m)?\.wikipedia\.org$');

({String language, String title})? _wikipediaArticle(Uri url) {
  final language = _wikipediaHost.firstMatch(url.host)?.group(1);
  final segments = _segments(url);
  if (language == null || segments.length < 2 || segments[0] != 'wiki') {
    return null;
  }
  // Titles may contain slashes ("AC/DC"), which split the path.
  return (language: language, title: segments.sublist(1).join('/'));
}

Future<Embed?> _fetchWikipedia(Uri url, http.Client client) async {
  final article = _wikipediaArticle(url)!;
  final json = await _getJson(
    client,
    Uri.parse(
      'https://${article.language}.wikipedia.org/api/rest_v1/page/summary/'
      '${Uri.encodeComponent(article.title)}',
    ),
  );
  final title = _string(json, 'title');
  if (title == null) return null;
  final thumbnail = _map(json, 'thumbnail');
  final source = _string(thumbnail, 'source');
  return Embed(
    url: url.toString(),
    siteName: PreviewSite.wikipedia.label,
    title: title,
    description: _string(json, 'extract'),
    image: source == null
        ? null
        : EmbedImage(
            Uri.parse(source),
            width: _int(thumbnail, 'width'),
            height: _int(thumbnail, 'height'),
            layout: EmbedImageLayout.thumbnail,
          ),
    color: PreviewSite.wikipedia.color,
  );
}

// ---------------------------------------------------------------------------
// Spotify, SoundCloud, Vimeo (oEmbed)

const _spotifyTypes = {
  'track',
  'album',
  'playlist',
  'artist',
  'episode',
  'show',
};

String? _spotifyItem(Uri url) {
  if (url.host != 'open.spotify.com') return null;
  var segments = _segments(url);
  // Localized links: open.spotify.com/intl-de/track/…
  if (segments.firstOrNull?.startsWith('intl-') ?? false) {
    segments = segments.sublist(1);
  }
  if (segments.length < 2 || !_spotifyTypes.contains(segments[0])) return null;
  return 'https://open.spotify.com/${segments[0]}/${segments[1]}';
}

Future<Embed?> _fetchSpotify(Uri url, http.Client client) async {
  final json = await _getJson(
    client,
    Uri.https('open.spotify.com', '/oembed', {'url': _spotifyItem(url)!}),
  );
  final title = _string(json, 'title');
  if (title == null) return null;
  final thumbnail = _string(json, 'thumbnail_url');
  return Embed(
    url: url.toString(),
    siteName: PreviewSite.spotify.label,
    title: title,
    image: thumbnail == null
        ? null
        : EmbedImage(
            Uri.parse(thumbnail),
            width: _int(json, 'thumbnail_width'),
            height: _int(json, 'thumbnail_height'),
            layout: EmbedImageLayout.thumbnail,
          ),
    color: PreviewSite.spotify.color,
  );
}

const _soundcloudReserved = {
  'charts',
  'discover',
  'feed',
  'jobs',
  'messages',
  'notifications',
  'pages',
  'people',
  'search',
  'settings',
  'stream',
  'terms-of-use',
  'upload',
  'you',
};

bool _soundcloudItem(Uri url) {
  if (url.host != 'soundcloud.com' &&
      url.host != 'www.soundcloud.com' &&
      url.host != 'm.soundcloud.com') {
    return false;
  }
  final segments = _segments(url);
  return segments.length >= 2 && !_soundcloudReserved.contains(segments[0]);
}

Future<Embed?> _fetchSoundcloud(Uri url, http.Client client) async {
  final json = await _getJson(
    client,
    Uri.https('soundcloud.com', '/oembed', {
      'format': 'json',
      'url': 'https://soundcloud.com${url.path}',
    }),
  );
  final title = _string(json, 'title');
  if (title == null) return null;
  final thumbnail = _string(json, 'thumbnail_url');
  return Embed(
    url: url.toString(),
    siteName: PreviewSite.soundcloud.label,
    author: _string(json, 'author_name'),
    authorUrl: _string(json, 'author_url'),
    title: title,
    // SoundCloud descriptions are HTML.
    description: _htmlText(_string(json, 'description')),
    image: thumbnail == null
        ? null
        : EmbedImage(Uri.parse(thumbnail), layout: EmbedImageLayout.thumbnail),
    color: PreviewSite.soundcloud.color,
  );
}

final _digits = RegExp(r'^\d+$');

bool _vimeoVideo(Uri url) =>
    _onDomain(url, 'vimeo.com') && _segments(url).any(_digits.hasMatch);

Future<Embed?> _fetchVimeo(Uri url, http.Client client) async {
  final json = await _getJson(
    client,
    Uri.https('vimeo.com', '/api/oembed.json', {'url': url.toString()}),
  );
  final title = _string(json, 'title');
  if (title == null) return null;
  // The oEmbed thumbnail is 295px wide; Vimeo's CDN renders any size.
  final thumbnail = _string(
    json,
    'thumbnail_url',
  )?.replaceFirst(RegExp(r'_\d+x\d+(?=\?|$)'), '_640x360');
  final duration = _int(json, 'duration');
  return Embed(
    url: url.toString(),
    siteName: PreviewSite.vimeo.label,
    author: _string(json, 'author_name'),
    authorUrl: _string(json, 'author_url'),
    title: title,
    description: _string(json, 'description'),
    stats: [
      if (duration != null && duration > 0)
        (kind: EmbedStatKind.duration, value: _duration(duration)),
    ],
    image: thumbnail == null
        ? null
        : EmbedImage(
            Uri.parse(thumbnail),
            width: _int(json, 'width'),
            height: _int(json, 'height'),
            video: true,
          ),
    color: PreviewSite.vimeo.color,
  );
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest'
      : '$minutes:$rest';
}
