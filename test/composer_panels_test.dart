// The composer's emoji/GIF/sticker/poll pickers are inline panels rising
// above the input bar — not popup dialogs.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/widgets/emoji_picker.dart';
import 'package:protea/src/widgets/gif_picker_dialog.dart';
import 'package:protea/src/widgets/poll.dart';
import 'package:protea/src/widgets/sticker_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

void main() {
  testWidgets('pickers open as inline composer panels, not dialogs', (
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
                      content: {'msgtype': 'm.text', 'body': 'hi'},
                      senderId: fakeUserId,
                      eventId: '\$hi',
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
    final l10n = AppLocalizations.of(tester.element(find.byType(RoomPage)));

    // The composer hugs the bottom of the window.
    final composerField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == l10n.message,
    );
    double composerBottom() => tester.getRect(composerField).bottom;
    expect(composerBottom(), greaterThan(500));

    // Emoji: panel appears inline, no dialog route; picking inserts into
    // the composer and keeps the panel open; Esc closes it.
    await tester.tap(find.byTooltip(l10n.emoji));
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPickerPanel), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.text('😀').first);
    await tester.pump();
    final input = tester.widget<TextField>(composerField);
    expect(input.controller!.text, contains('😀'));
    expect(find.byType(EmojiPickerPanel), findsOneWidget);

    // Searching narrows the grid.
    await tester.enterText(
      find.descendant(
        of: find.byType(EmojiPickerPanel),
        matching: find.byType(TextField),
      ),
      'party',
    );
    await tester.pump();
    Finder inPanel(String emoji) => find.descendant(
      of: find.byType(EmojiPickerPanel),
      matching: find.text(emoji),
    );
    expect(inPanel('🥳'), findsOneWidget);
    expect(inPanel('😀'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPickerPanel), findsNothing);

    // GIF: inline panel, no dialog — and the panel floats over the
    // timeline: the messages must not move.
    final messagePosition = tester.getCenter(find.text('hi'));
    await tester.tap(find.byTooltip(l10n.gif));
    await tester.pumpAndSettle();
    expect(find.byType(GifPickerPanel), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.getCenter(find.text('hi')), messagePosition);
    await tester.tap(find.byTooltip(l10n.gif));
    await tester.pumpAndSettle();
    expect(find.byType(GifPickerPanel), findsNothing);

    // Sticker via the attachments menu: inline panel, no dialog.
    await tester.tap(find.byTooltip(l10n.attachments));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.sticker));
    await tester.pumpAndSettle();
    expect(find.byType(StickerPickerPanel), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    // Poll via the attachments menu replaces the sticker panel.
    await tester.tap(find.byTooltip(l10n.attachments));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.poll));
    await tester.pumpAndSettle();
    expect(find.byType(CreatePollPanel), findsOneWidget);
    expect(find.byType(StickerPickerPanel), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);

    // Clicking into the message list dismisses the panel.
    await tester.tapAt(tester.getCenter(find.text('hi')));
    await tester.pumpAndSettle();
    expect(find.byType(CreatePollPanel), findsNothing);

    // With every panel closed the composer hugs the bottom again.
    expect(composerBottom(), greaterThan(500));

    // Reaction picker from the message quick actions: an anchored popover
    // (no Dialog, no dimmed modal), dismissed by Esc.
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 11,
    );
    await mouse.addPointer(location: tester.getCenter(find.text('hi')));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.addReaction));
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPickerPanel), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPickerPanel), findsNothing);

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
