// Rich link previews for common sites: which links each site claims, how
// its public API's answer becomes a card, and when the homeserver's generic
// preview takes over or fills in. The API answers below are trimmed copies of
// real ones.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:protea/src/site_previews.dart';

/// Answers each request whose URL starts with a key with that key's JSON;
/// anything else is a 404. Records what was asked.
MockClient _api(Map<String, Object?> answers, [List<Uri>? requests]) =>
    MockClient((request) async {
      requests?.add(request.url);
      for (final MapEntry(:key, :value) in answers.entries) {
        if (request.url.toString().startsWith(key)) {
          return http.Response.bytes(utf8.encode(jsonEncode(value)), 200);
        }
      }
      return http.Response('not found', 404);
    });

Future<Embed?> _load(
  String url,
  MockClient client, {
  Map<String, Object?>? homeserver,
}) {
  final uri = Uri.parse(url);
  return loadEmbed(
    url,
    site: PreviewSite.of(uri),
    client: client,
    homeserver: () async => homeserver,
  );
}

void main() {
  group('PreviewSite.of', () {
    final cases = <String, PreviewSite?>{
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ': PreviewSite.youtube,
      'https://youtube.com/watch?v=dQw4w9WgXcQ&t=42s': PreviewSite.youtube,
      'https://m.youtube.com/watch?v=dQw4w9WgXcQ': PreviewSite.youtube,
      'https://music.youtube.com/watch?v=dQw4w9WgXcQ': PreviewSite.youtube,
      'https://youtu.be/dQw4w9WgXcQ?si=abc': PreviewSite.youtube,
      'https://www.youtube.com/shorts/dQw4w9WgXcQ': PreviewSite.youtube,
      'https://www.youtube.com/live/dQw4w9WgXcQ': PreviewSite.youtube,
      'https://www.youtube.com/@RickAstleyYT': null,
      'https://www.youtube.com/watch?v=tooShort': null,
      'https://www.reddit.com/r/FlutterDev/comments/abc123/some_title/':
          PreviewSite.reddit,
      'https://old.reddit.com/r/FlutterDev/comments/abc123': PreviewSite.reddit,
      'https://www.reddit.com/user/someone/comments/abc123/x/':
          PreviewSite.reddit,
      'https://www.reddit.com/r/FlutterDev/': null,
      'https://www.reddit.com/r/FlutterDev/s/ShareCode': null,
      'https://x.com/jack/status/20': PreviewSite.x,
      'https://twitter.com/jack/status/20?s=46': PreviewSite.x,
      'https://mobile.twitter.com/jack/status/20/photo/1': PreviewSite.x,
      'https://x.com/jack': null,
      'https://bsky.app/profile/bsky.app/post/3l6oveex3ii2l':
          PreviewSite.bluesky,
      'https://bsky.app/profile/bsky.app': null,
      'https://github.com/flutter/flutter': PreviewSite.github,
      'https://github.com/flutter/flutter/': PreviewSite.github,
      'https://github.com/flutter/flutter/issues/1': PreviewSite.github,
      'https://github.com/flutter/flutter/pull/1/files': PreviewSite.github,
      'https://github.com/flutter/flutter/blob/master/README.md': null,
      'https://github.com/settings/profile': null,
      'https://github.com/flutter': null,
      'https://gist.github.com/someone/abc': null,
      'https://en.wikipedia.org/wiki/Rick_Astley': PreviewSite.wikipedia,
      'https://de.m.wikipedia.org/wiki/AC/DC': PreviewSite.wikipedia,
      'https://en.wikipedia.org/w/index.php?title=X': null,
      'https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC':
          PreviewSite.spotify,
      'https://open.spotify.com/intl-de/album/6N9PS4QXF1D0OWPk0Sxtb4':
          PreviewSite.spotify,
      'https://open.spotify.com/search/rick': null,
      'https://soundcloud.com/forss/flickermood': PreviewSite.soundcloud,
      'https://soundcloud.com/discover/sets/x': null,
      'https://soundcloud.com/forss': null,
      'https://vimeo.com/76979871': PreviewSite.vimeo,
      'https://vimeo.com/channels/staffpicks/76979871': PreviewSite.vimeo,
      'https://vimeo.com/staff': null,
      'https://example.com/watch?v=dQw4w9WgXcQ': null,
      'https://notyoutube.com/watch?v=dQw4w9WgXcQ': null,
      'ftp://github.com/flutter/flutter': null,
    };
    for (final MapEntry(key: url, value: site) in cases.entries) {
      test('$url → ${site?.name}', () {
        expect(PreviewSite.of(Uri.parse(url)), site);
      });
    }
  });

  test('a YouTube video becomes a video card with its channel', () async {
    final requests = <Uri>[];
    final embed = await _load(
      'https://youtu.be/dQw4w9WgXcQ?si=tracking',
      _api({
        'https://www.youtube.com/oembed': {
          'title': 'Rick Astley - Never Gonna Give You Up',
          'author_name': 'Rick Astley',
          'author_url': 'https://www.youtube.com/@RickAstleyYT',
          'thumbnail_url': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        },
      }, requests),
    );
    expect(embed!.title, 'Rick Astley - Never Gonna Give You Up');
    expect(embed.author, 'Rick Astley');
    expect(embed.authorUrl, 'https://www.youtube.com/@RickAstleyYT');
    expect(embed.siteName, 'YouTube');
    expect(embed.url, 'https://youtu.be/dQw4w9WgXcQ?si=tracking');
    expect(embed.image!.video, isTrue);
    expect(embed.image!.layout, EmbedImageLayout.large);
    expect(embed.image!.aspectRatio, 16 / 9);
    // The site is asked about the canonical link, without the tracking id.
    expect(
      requests.single.queryParameters['url'],
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
  });

  test('a Reddit post takes its image from the homeserver', () async {
    final embed = await _load(
      'https://old.reddit.com/r/IAmA/comments/z1c9z/i_am_barack_obama/',
      _api({
        'https://www.reddit.com/oembed': {
          'title': 'I am Barack Obama, President of the United States -- AMA',
          'author_name': 'PresidentObama',
        },
      }),
      homeserver: {
        'og:title': 'Reddit - Dive into anything',
        'og:description': 'Not the post',
        'og:image': 'mxc://example.org/post',
        'og:image:width': 1200,
        'og:image:height': 630,
      },
    );
    expect(embed!.siteName, 'Reddit · r/IAmA');
    expect(embed.author, 'u/PresidentObama');
    expect(embed.title, startsWith('I am Barack Obama'));
    expect(embed.image!.uri, Uri.parse('mxc://example.org/post'));
    // Only the image: the homeserver's text for Reddit is often a login wall.
    expect(embed.description, isNull);
  });

  test('an X post shows its text, author and date', () async {
    final embed = await _load(
      'https://x.com/jack/status/20',
      _api({
        'https://publish.twitter.com/oembed': {
          'author_name': 'jack',
          'author_url': 'https://x.com/jack',
          'html':
              '<blockquote class="twitter-tweet"><p lang="en" dir="ltr">just '
              'setting up my twttr<br>&amp; more</p>&mdash; jack (@jack) '
              '<a href="https://x.com/jack/status/20">March 21, 2006</a>'
              '</blockquote>',
        },
      }),
    );
    expect(embed!.description, 'just setting up my twttr\n& more');
    expect(embed.author, 'jack (@jack)');
    expect(embed.footer, 'March 21, 2006');
    expect(embed.title, isNull);
  });

  test('a Bluesky post keeps its timestamp as a date', () async {
    final embed = await _load(
      'https://bsky.app/profile/bsky.app/post/3l6oveex3ii2l',
      _api({
        'https://embed.bsky.app/oembed': {
          'author_name': 'Bluesky (@bsky.app)',
          'author_url': 'https://bsky.app/profile/bsky.app',
          'html':
              '<blockquote class="bluesky-embed"><p lang="en">We&#39;re so '
              'excited</p>&mdash; <a href="https://bsky.app/profile/x">'
              'Bluesky (@bsky.app)</a> <a href="https://bsky.app/profile/x/'
              'post/y">2024-10-17T07:06:51.491Z</a></blockquote>',
        },
      }),
    );
    expect(embed!.description, "We're so excited");
    expect(embed.timestamp, DateTime.utc(2024, 10, 17, 7, 6, 51, 491));
  });

  test('a GitHub repository shows its stars, forks and language', () async {
    final embed = await _load(
      'https://github.com/flutter/flutter',
      _api({
        'https://api.github.com/repos/flutter/flutter': {
          'full_name': 'flutter/flutter',
          'description': 'Flutter makes it easy and fast to build apps.',
          'stargazers_count': 170213,
          'forks_count': 28712,
          'language': 'Dart',
        },
      }),
    );
    expect(embed!.title, 'flutter/flutter');
    expect(embed.stats.map((stat) => stat.kind), [
      EmbedStatKind.stars,
      EmbedStatKind.forks,
      EmbedStatKind.language,
    ]);
    expect(embed.stats.last.value, 'Dart');
    expect(embed.image!.uri.host, 'opengraph.githubassets.com');
  });

  group('GitHub issue and pull request states', () {
    Future<EmbedStatKind?> stateOf(Map<String, Object?> issue) async {
      final embed = await _load(
        'https://github.com/o/r/issues/7',
        _api({
          'https://api.github.com/repos/o/r/issues/7': {
            'title': 'Something',
            'user': {'login': 'someone'},
            'comments': 0,
            ...issue,
          },
        }),
      );
      return embed?.stats.first.kind;
    }

    test('issues', () async {
      expect(await stateOf({'state': 'open'}), EmbedStatKind.issueOpen);
      expect(
        await stateOf({'state': 'closed', 'state_reason': 'completed'}),
        EmbedStatKind.issueClosed,
      );
      expect(
        await stateOf({'state': 'closed', 'state_reason': 'not_planned'}),
        EmbedStatKind.issueNotPlanned,
      );
    });

    test('pull requests', () async {
      const pull = {'url': 'x', 'merged_at': null};
      expect(
        await stateOf({'state': 'open', 'pull_request': pull}),
        EmbedStatKind.pullOpen,
      );
      expect(
        await stateOf({'state': 'open', 'draft': true, 'pull_request': pull}),
        EmbedStatKind.pullDraft,
      );
      expect(
        await stateOf({'state': 'closed', 'pull_request': pull}),
        EmbedStatKind.pullClosed,
      );
      expect(
        await stateOf({
          'state': 'closed',
          'pull_request': {'merged_at': '2024-01-01T00:00:00Z'},
        }),
        EmbedStatKind.pullMerged,
      );
    });
  });

  test('a GitHub issue card drops template comments from the body', () async {
    final embed = await _load(
      'https://github.com/o/r/issues/7',
      _api({
        'https://api.github.com/repos/o/r/issues/7': {
          'title': 'Crash on start',
          'state': 'open',
          'comments': 3,
          'user': {
            'login': 'someone',
            'html_url': 'https://github.com/someone',
          },
          'body':
              '<!-- Describe the bug -->\r\n## What happens\r\nIt crashes.\n\n\n\nEvery time.',
        },
      }),
    );
    expect(embed!.title, 'Crash on start #7');
    expect(embed.siteName, 'GitHub · o/r');
    expect(embed.author, 'someone');
    expect(embed.description, 'What happens\nIt crashes.\n\nEvery time.');
    expect(embed.stats.last, (kind: EmbedStatKind.comments, value: '3'));
  });

  test('a Wikipedia article with a slash in its title', () async {
    final requests = <Uri>[];
    final embed = await _load(
      'https://de.m.wikipedia.org/wiki/AC/DC',
      _api({
        'https://de.wikipedia.org/api/rest_v1/page/summary/': {
          'title': 'AC/DC',
          'extract': 'AC/DC ist eine Hard-Rock-Band.',
          'thumbnail': {
            'source': 'https://upload.wikimedia.org/acdc.jpg',
            'width': 320,
            'height': 213,
          },
        },
      }, requests),
    );
    expect(
      requests.single.toString(),
      'https://de.wikipedia.org/api/rest_v1/page/summary/AC%2FDC',
    );
    expect(embed!.title, 'AC/DC');
    expect(embed.description, 'AC/DC ist eine Hard-Rock-Band.');
    expect(embed.image!.layout, EmbedImageLayout.thumbnail);
  });

  test('Spotify takes the artist line from the homeserver', () async {
    final embed = await _load(
      'https://open.spotify.com/intl-de/track/4uLU6hMCjMI75M1A2tKUQC?si=x',
      _api({
        'https://open.spotify.com/oembed': {
          'title': 'Never Gonna Give You Up',
          'thumbnail_url': 'https://image-cdn.spotifycdn.com/image/abc',
          'thumbnail_width': 300,
          'thumbnail_height': 300,
        },
      }),
      homeserver: {
        'og:title': 'Never Gonna Give You Up',
        'og:description': 'Rick Astley · Song · 1987',
        'og:image': 'mxc://example.org/cover',
      },
    );
    expect(embed!.description, 'Rick Astley · Song · 1987');
    // The site's own cover stays.
    expect(embed.image!.uri.host, 'image-cdn.spotifycdn.com');
  });

  test('a Vimeo video shows its duration and a sharper thumbnail', () async {
    final embed = await _load(
      'https://vimeo.com/76979871',
      _api({
        'https://vimeo.com/api/oembed.json': {
          'title': 'The New Vimeo Player',
          'author_name': 'Vimeo',
          'duration': 62,
          'width': 480,
          'height': 270,
          'thumbnail_url':
              'https://i.vimeocdn.com/video/452001751-d_295x166?region=us',
        },
      }),
    );
    expect(embed!.stats.single, (kind: EmbedStatKind.duration, value: '1:02'));
    expect(
      embed.image!.uri.toString(),
      'https://i.vimeocdn.com/video/452001751-d_640x360?region=us',
    );
  });

  group('falling back to the homeserver', () {
    const openGraph = {
      'og:title': 'Generic title',
      'og:site_name': 'Example',
      'og:image': 'mxc://example.org/card',
      'og:image:width': 1200,
      'og:image:height': 630,
    };

    test('when the site has nothing for the link', () async {
      final embed = await _load(
        'https://github.com/o/gone',
        _api({}),
        homeserver: openGraph,
      );
      expect(embed!.title, 'Generic title');
      expect(embed.color, isNull);
    });

    test('when the site request throws', () async {
      final embed = await _load(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        MockClient((_) => throw http.ClientException('offline')),
        homeserver: openGraph,
      );
      expect(embed!.title, 'Generic title');
    });

    test('when the site is switched off', () async {
      final requests = <Uri>[];
      final embed = await loadEmbed(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        site: null,
        client: _api({}, requests),
        homeserver: () async => openGraph,
      );
      expect(embed!.title, 'Generic title');
      expect(requests, isEmpty);
    });

    test('and nothing at all when neither has a preview', () async {
      expect(
        await _load('https://example.com/', _api({}), homeserver: null),
        isNull,
      );
      expect(
        await _load('https://example.com/', _api({}), homeserver: {}),
        isNull,
      );
    });
  });

  group('generic cards from OpenGraph', () {
    test('wide images go under the text, others beside it', () {
      EmbedImageLayout? layoutFor(int? width, int? height) =>
          embedFromOpenGraph('https://example.com/', {
            'og:title': 't',
            'og:image': 'mxc://example.org/i',
            'og:image:width': ?width,
            'og:image:height': ?height,
          })!.image!.layout;
      expect(layoutFor(1200, 630), EmbedImageLayout.large);
      expect(layoutFor(200, 200), EmbedImageLayout.thumbnail);
      expect(layoutFor(300, 100), EmbedImageLayout.thumbnail);
      expect(layoutFor(null, null), EmbedImageLayout.thumbnail);
    });

    test('images the homeserver did not re-host are left out', () {
      final embed = embedFromOpenGraph('https://example.com/a', {
        'og:title': 't',
        'og:image': 'https://tracker.example/pixel.png',
      });
      expect(embed!.image, isNull);
      expect(embed.siteName, 'example.com');
    });
  });
}
