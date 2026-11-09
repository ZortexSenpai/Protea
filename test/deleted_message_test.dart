// Deleted (redacted) messages render as an inert placeholder pill: no
// hover quick actions, no context menu, nothing to interact with.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

void main() {
  testWidgets('redacted messages are inert placeholders', (tester) async {
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
                      content: {'msgtype': 'm.text', 'body': 'doomed'},
                      senderId: fakeUserId,
                      eventId: '\$doomed',
                      originServerTs: DateTime.fromMillisecondsSinceEpoch(
                        1700000000000,
                      ),
                    ),
                    MatrixEvent(
                      type: 'm.room.message',
                      content: {'msgtype': 'm.text', 'body': 'kept'},
                      senderId: fakeUserId,
                      eventId: '\$kept',
                      originServerTs: DateTime.fromMillisecondsSinceEpoch(
                        1700000060000,
                      ),
                    ),
                    MatrixEvent(
                      type: 'm.room.redaction',
                      content: {'redacts': '\$doomed'},
                      redacts: '\$doomed',
                      senderId: fakeUserId,
                      eventId: '\$redact',
                      originServerTs: DateTime.fromMillisecondsSinceEpoch(
                        1700000120000,
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

    // The deleted message shows the placeholder naming the original
    // sender, not its old body.
    final senderName = room
        .unsafeGetUserFromMemoryOrFallback(fakeUserId)
        .calcDisplayname();
    final placeholder = l10n.messageDeletedFrom(senderName);
    expect(find.text(placeholder), findsOneWidget);
    expect(find.text('doomed'), findsNothing);
    expect(find.text('kept'), findsOneWidget);

    // Hovering an intact message shows the quick actions...
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 12,
    );
    await mouse.addPointer(location: tester.getCenter(find.text('kept')));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    bool actionsVisible() => tester
        .widgetList<Opacity>(
          find.ancestor(
            of: find.byTooltip(l10n.addReaction),
            matching: find.byType(Opacity),
          ),
        )
        .any((widget) => widget.opacity == 1);
    expect(actionsVisible(), isTrue);

    // ...but hovering the deleted one shows none.
    await mouse.moveTo(tester.getCenter(find.text(placeholder)));
    await tester.pumpAndSettle();
    expect(actionsVisible(), isFalse);

    // Right-clicking the deleted message opens no context menu.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(placeholder)),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text(l10n.reply), findsNothing);
    expect(find.text(l10n.copyText), findsNothing);

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
