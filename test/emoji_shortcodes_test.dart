// `:shortcode:` text renders as the emoji it names — on display and when
// sending — while lookalikes (times, unknown names) stay untouched.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/emoji_shortcodes.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

void main() {
  test('replaceEmojiShortcodes converts known names only', () {
    expect(replaceEmojiShortcodes('look :eyes:'), 'look 👀');
    expect(replaceEmojiShortcodes(':fire: :100: :+1:'), '🔥 💯 👍');
    expect(replaceEmojiShortcodes(':EYES:'), '👀');
    expect(replaceEmojiShortcodes(':notreal:'), ':notreal:');
    expect(replaceEmojiShortcodes('meet at 12:30:45'), 'meet at 12:30:45');
    expect(replaceEmojiShortcodes('mxc://server/id'), 'mxc://server/id');
    expect(replaceEmojiShortcodes('no colons here'), 'no colons here');
    expect(replaceEmojiShortcodes(':eyes::fire:'), '👀🔥');
  });

  test('replaceEmojiShortcodes leaves URLs intact', () {
    expect(
      replaceEmojiShortcodes('see https://example.com/a:x:b/:fire: :fire:'),
      'see https://example.com/a:x:b/:fire: 🔥',
    );
    expect(
      replaceEmojiShortcodes('www.example.com/:eyes: and :eyes:'),
      'www.example.com/:eyes: and 👀',
    );
    expect(
      replaceEmojiShortcodes('hi:https://example.com/:x:'),
      'hi:https://example.com/:x:',
    );
    expect(
      replaceEmojiShortcodes(
        '<a href="https://example.com/:x:">https://example.com/:x:</a> :x:',
      ),
      '<a href="https://example.com/:x:">https://example.com/:x:</a> ❌',
    );
  });

  testWidgets('shortcodes in received messages render as emoji', (
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
                    MatrixEvent(
                      type: 'm.room.message',
                      content: {'msgtype': 'm.text', 'body': 'wow :eyes:'},
                      senderId: '@other:fake',
                      eventId: '\$shortcode',
                      originServerTs: DateTime.fromMillisecondsSinceEpoch(
                        1700000000000,
                      ),
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

    expect(find.textContaining('wow 👀', findRichText: true), findsOneWidget);
    expect(
      find.textContaining(':eyes:', findRichText: true),
      findsNothing,
    );

    // Typing an unclosed shortcode fragment offers suggestions; tapping
    // one inserts the emoji in place of the fragment.
    final composer = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText ==
              AppLocalizations.of(
                tester.element(find.byType(RoomPage)),
              ).message,
    );
    await tester.enterText(composer, 'nice :ey');
    await tester.pumpAndSettle();
    expect(find.text(':eyes:'), findsOneWidget);
    await tester.tap(find.text(':eyes:'));
    await tester.pump();
    expect(tester.widget<TextField>(composer).controller!.text, 'nice 👀 ');
    // The panel retains the outgoing tile for its close animation.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(':eyes:'), findsNothing);

    // Typing the closing colon of a known shortcode converts it right in
    // the field.
    await tester.enterText(composer, 'ok :fire:');
    await tester.pump();
    expect(tester.widget<TextField>(composer).controller!.text, 'ok 🔥');

    // Unknown or lookalike fragments neither convert nor suggest.
    await tester.enterText(composer, 'at 12:30');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(composer).controller!.text, 'at 12:30');
    expect(find.byType(ListTile), findsNothing);

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
