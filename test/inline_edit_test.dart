// Editing a message happens in place, Discord-style: the message's text
// turns into a field right where it is, while the composer stays free for
// new messages (and keeps its draft).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

MatrixEvent _text(String eventId, String body, String sender, int ts) =>
    MatrixEvent(
      type: 'm.room.message',
      content: {'msgtype': 'm.text', 'body': body},
      senderId: sender,
      eventId: eventId,
      originServerTs: DateTime.fromMillisecondsSinceEpoch(1700000000000 + ts),
    );

void main() {
  testWidgets('messages are edited in place, not in the composer', (
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
                  events: [_text('\$hello', 'hello', fakeUserId, 0)],
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
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await settle();
    final l10n = AppLocalizations.of(tester.element(find.byType(RoomPage)));
    final composer = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == l10n.message,
    );
    final editor = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText != l10n.message,
    );
    TextField field(Finder finder) => tester.widget<TextField>(finder);
    Future<List<Event>> edits() async => [
      for (final event in (await tester.runAsync(
        () => client.database.getEventList(room),
      ))!)
        if (event.relationshipType == RelationshipTypes.edit) event,
    ];

    // A half-written message in the composer.
    await tester.enterText(composer, 'my draft');
    await tester.pump();

    // Right-click → Edit opens the editor inside the timeline, focused and
    // holding the message's text; the composer keeps the draft.
    await tester.tap(find.text('hello'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.edit));
    await settle();
    expect(editor, findsOneWidget);
    expect(field(editor).controller!.text, 'hello');
    expect(field(editor).focusNode!.hasFocus, isTrue);
    expect(find.text(l10n.escapeToCancel), findsOneWidget);
    expect(find.text(l10n.enterToSave), findsOneWidget);
    expect(field(composer).controller!.text, 'my draft');

    // Enter saves as an m.replace of the message, closes the editor and
    // hands the keyboard back to the composer, draft untouched.
    await tester.enterText(editor, 'hello again');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle();
    expect(editor, findsNothing);
    expect(field(composer).controller!.text, 'my draft');
    expect(field(composer).focusNode!.hasFocus, isTrue);
    final sent = await edits();
    expect(sent, hasLength(1));
    expect(sent.single.relationshipEventId, '\$hello');
    expect(
      (sent.single.content['m.new_content'] as Map)['body'],
      'hello again',
    );

    // Arrow up in the empty composer opens the editor too.
    await tester.enterText(composer, '');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle();
    expect(editor, findsOneWidget);
    expect(field(editor).focusNode!.hasFocus, isTrue);
    await tester.enterText(editor, 'half-typed');
    await tester.pump();

    // A message arriving mid-edit shifts every list item by one; the
    // editor must move along with its text and the keyboard focus.
    await tester.runAsync(
      () => client.handleSync(
        SyncUpdate(
          nextBatch: 'b2',
          rooms: RoomsUpdate(
            join: {
              '!room0:fake': JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    _text('\$other', 'news', '@alice:example.com', 60000),
                  ],
                ),
              ),
            },
          ),
        ),
      ),
    );
    await settle();
    expect(find.text('news'), findsOneWidget);
    expect(editor, findsOneWidget);
    expect(field(editor).controller!.text, 'half-typed');
    expect(field(editor).focusNode!.hasFocus, isTrue);
    // Still wired to the keyboard: typing goes on without clicking back
    // into the field (tester.enterText would tap it first, hiding a lost
    // text input connection).
    tester.testTextInput.enterText('half-typed, done');
    await tester.pump();
    expect(field(editor).controller!.text, 'half-typed, done');

    // Escape cancels: nothing is sent and the composer has the keyboard.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();
    expect(editor, findsNothing);
    expect(field(composer).focusNode!.hasFocus, isTrue);
    expect(await edits(), hasLength(1));

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
