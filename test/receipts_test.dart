// Read receipts arrive as ephemeral sync data and reach the bubbles through
// a page-level ValueNotifier (no full page rebuild); this guards the whole
// path: sync -> notifier -> per-bubble receipts row.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

MatrixEvent _message(String body, String eventId, int ts) => MatrixEvent(
  type: 'm.room.message',
  content: {'msgtype': 'm.text', 'body': body},
  senderId: fakeUserId,
  eventId: eventId,
  originServerTs: DateTime.fromMillisecondsSinceEpoch(ts),
);

void main() {
  testWidgets('a read receipt renders under the message it points at', (
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
                    _message('older message', '\$older', 1700000000000),
                    _message('newest message', '\$target', 1700000060000),
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
    expect(find.text('newest message'), findsOneWidget);

    bool readByTooltip() =>
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is Tooltip &&
                  (widget.message?.contains('Read by Reader') ?? false),
            )
            .evaluate()
            .isNotEmpty;
    expect(readByTooltip(), isFalse);

    // Another user's read receipt for the newest message arrives.
    await tester.runAsync(
      () => client.handleSync(
        SyncUpdate(
          nextBatch: 'b2',
          rooms: RoomsUpdate(
            join: {
              '!room0:fake': JoinedRoomUpdate(
                ephemeral: [
                  BasicEvent(
                    type: 'm.receipt',
                    content: {
                      '\$target': {
                        'm.read': {
                          '@reader:fake': {'ts': 1700000070000},
                        },
                      },
                    },
                  ),
                ],
              ),
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(readByTooltip(), isTrue);

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
