// The Discord-style link card lays out every kind of content (site, author,
// title, description, facts, large image or thumbnail, footer) without
// overflowing, in a narrow bubble as well as at its full width.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/site_previews.dart';
import 'package:protea/src/widgets/link_preview.dart';

import 'fake_client.dart';

const _pullRequest = Embed(
  url: 'https://github.com/o/r/pull/7',
  siteName: 'GitHub · o/r',
  author: 'someone',
  authorUrl: 'https://github.com/someone',
  title: 'Make the link previews look like the ones everyone knows #7',
  description: 'A long body.\n\nWith several paragraphs of text in it.',
  stats: [
    (kind: EmbedStatKind.pullMerged, value: null),
    (kind: EmbedStatKind.comments, value: '12'),
  ],
  color: Color(0xFF8B949E),
);

final _video = Embed(
  url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  siteName: 'YouTube',
  author: 'Rick Astley',
  title: 'Never Gonna Give You Up',
  image: EmbedImage(
    Uri.parse('https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg'),
    width: 16,
    height: 9,
    video: true,
  ),
  color: const Color(0xFFFF0033),
);

final _article = Embed(
  url: 'https://en.wikipedia.org/wiki/Rick_Astley',
  siteName: 'Wikipedia',
  title: 'Rick Astley',
  description: 'Richard Paul Astley is an English singer. ' * 6,
  image: EmbedImage(
    Uri.parse('https://upload.wikimedia.org/rick.jpg'),
    layout: EmbedImageLayout.thumbnail,
  ),
);

final _post = Embed(
  url: 'https://bsky.app/profile/bsky.app/post/x',
  siteName: 'Bluesky',
  author: 'Bluesky (@bsky.app)',
  description: 'Short post',
  timestamp: DateTime.utc(2024, 10, 17, 7, 6),
);

void main() {
  late Client client;

  Future<void> pumpCards(WidgetTester tester, double width) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final embed in [_pullRequest, _video, _article, _post])
                    EmbedCard(embed: embed, client: client),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Network images fail in tests and show their error icon.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  testWidgets('cards lay out at full width and in a narrow bubble', (
    tester,
  ) async {
    await tester.runAsync(() async => client = await buildFakeClient());
    for (final width in [600.0, 220.0]) {
      await pumpCards(tester, width);
      expect(tester.takeException(), isNull, reason: 'width $width');

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l10n.embedStateMerged), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Rick Astley'), findsNWidgets(2));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('Short post'), findsOneWidget);

      // Never wider than the cap, even with room to spare.
      for (final card in tester.widgetList(find.byType(EmbedCard))) {
        final size = tester.getSize(find.byWidget(card));
        expect(size.width, lessThanOrEqualTo(EmbedCard.maxWidth));
      }
      // The video keeps its 16:9 shape.
      final video = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.play_arrow_rounded),
              matching: find.byType(AspectRatio),
            )
            .first,
      );
      expect(video.width / video.height, closeTo(16 / 9, 0.01));
    }
    await tester.runAsync(() => client.dispose(closeDatabase: true));
  });
}
