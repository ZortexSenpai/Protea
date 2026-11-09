// Custom emoji reactions (MSC4027) carry an mxc:// URI as the reaction key;
// the chip must render the emote image, not the raw URI text.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/widgets/html_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

const _emoteUri = 'mxc://fake/animated_emote';

MatrixEvent _message(String body, String eventId, int ts) => MatrixEvent(
  type: 'm.room.message',
  content: {'msgtype': 'm.text', 'body': body},
  senderId: fakeUserId,
  eventId: eventId,
  originServerTs: DateTime.fromMillisecondsSinceEpoch(ts),
);

MatrixEvent _reaction(
  String key,
  String eventId,
  int ts, {
  String? shortcode,
}) => MatrixEvent(
  type: 'm.reaction',
  content: {
    'm.relates_to': {
      'rel_type': 'm.annotation',
      'event_id': '\$target',
      'key': key,
    },
    'shortcode': ?shortcode,
  },
  senderId: '@reader:fake',
  eventId: eventId,
  originServerTs: DateTime.fromMillisecondsSinceEpoch(ts),
);

void main() {
  testWidgets('custom emoji reaction renders as image, not raw mxc text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    late final AppSettings settings;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'b1',
          rooms: RoomsUpdate(
            join: {
              '!room0:fake': JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    _message('reacted message', '\$target', 1700000000000),
                    _reaction('👍', '\$unicodeReaction', 1700000060000),
                    _reaction(
                      _emoteUri,
                      '\$customReaction',
                      1700000070000,
                      shortcode: ':partyparrot:',
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      settings = await AppSettings.load();
    });

    final room = client.getRoomById('!room0:fake')!;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => SettingsScope(
          settings: settings,
          child: child ?? const SizedBox.shrink(),
        ),
        home: RoomPage(room: room),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('reacted message'), findsOneWidget);

    // The unicode reaction chip still renders key and count as text.
    expect(find.text('👍 1'), findsOneWidget);

    // The custom emoji chip shows the emote image and its own count — the
    // raw mxc:// URI never appears as text anywhere.
    final emote = tester.widget<InlineEmote>(find.byType(InlineEmote));
    expect(emote.uri, Uri.parse(_emoteUri));
    expect(emote.name, ':partyparrot:');
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('mxc://'), findsNothing);

    // The emote is fetched as the original file — thumbnailing would lose
    // the animation (Synapse ignores MSC2705's animated flag).
    expect(
      FakeMatrixApi.calledEndpoints.keys,
      contains('/client/v1/media/download/fake/animated_emote'),
    );

    // Hovering a reaction chip shows the click cursor. This needs an
    // explicit cursor on the chip's InkWell — its default resolves to
    // the plain arrow on desktop — and the chips excluded from the
    // page's SelectionArea so selectable text can't override it.
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 1,
    );
    await gesture.addPointer(location: tester.getCenter(find.text('👍 1')));
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
    await gesture.removePointer();
    await tester.pump();

    // Drain in-flight SDK work before the harness checks for stray timers.
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(seconds: 31));
    await tester.runAsync(() => client.dispose(closeDatabase: false));
  });
}
