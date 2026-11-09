// Video attachments render as an inline player preview (play button and
// duration badge) instead of a generic file tile. Playback itself needs the
// native mpv library, so the test stops at the preview.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/widgets/event_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

void main() {
  testWidgets('video messages render an inline player preview', (
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
                      content: {
                        'msgtype': 'm.video',
                        'body': 'cat.mp4',
                        'url': 'mxc://fake/video1',
                        'info': {
                          'mimetype': 'video/mp4',
                          'duration': 42000,
                          'w': 1280,
                          'h': 720,
                          'size': 123456,
                        },
                      },
                      senderId: fakeUserId,
                      eventId: '\$video',
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

    // The player preview replaces the old file tile: play button plus
    // duration badge, no filename text.
    expect(find.byType(EventVideo), findsOneWidget);
    expect(find.byTooltip(l10n.playVideo), findsOneWidget);
    expect(find.text('0:42'), findsOneWidget);
    expect(find.text('cat.mp4'), findsNothing);

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
