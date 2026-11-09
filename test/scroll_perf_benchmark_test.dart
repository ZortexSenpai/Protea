// Wall-clock benchmark for timeline scroll/rebuild costs (prints timings;
// only sanity assertions). Drives the real RoomPage via the fake-client
// harness, mirroring app_semantics_fuzz_test's setup.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/smooth_scroll.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

var _counter = 0;

MatrixEvent _message(String body, {bool html = false}) => MatrixEvent(
  type: 'm.room.message',
  content: {
    'msgtype': 'm.text',
    'body': body,
    if (html) ...{
      'format': 'org.matrix.custom.html',
      'formatted_body':
          '<b>$body</b> with a <a href="https://example.com">link</a>, '
          '<code>some code</code> and <em>emphasis</em> 😀',
    },
  },
  senderId: fakeUserId,
  eventId: '\$msg${_counter++}',
  originServerTs: DateTime.fromMillisecondsSinceEpoch(
    1700000000000 + (_counter) * 60000,
  ),
);

Future<void> _sync(Client client, Map<String, JoinedRoomUpdate> join) {
  return client.handleSync(
    SyncUpdate(
      nextBatch: 'batch${_counter++}',
      rooms: RoomsUpdate(join: join),
    ),
  );
}

JoinedRoomUpdate _update(List<MatrixEvent> events) => JoinedRoomUpdate(
  timeline: TimelineUpdate(events: events),
  state: [
    MatrixEvent(
      type: 'm.room.member',
      content: {'membership': 'join', 'displayname': 'Test'},
      senderId: fakeUserId,
      eventId: '\$member${_counter++}',
      originServerTs: DateTime.fromMillisecondsSinceEpoch(1500000000000),
      stateKey: fakeUserId,
    ),
  ],
);

void main() {
  testWidgets('large timeline scroll and rebuild cost', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    late final AppSettings settings;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      // A large chat with plenty of loaded history.
      await _sync(client, {
        '!room0:fake': _update([
          for (var i = 0; i < 1500; i++)
            _message('history message $i', html: i % 4 == 0),
        ]),
      });
      settings = await AppSettings.load();
    });
    addTearDown(() async {
      await tester.runAsync(() => client.dispose(closeDatabase: true));
    });

    final room = client.getRoomById('!room0:fake')!;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => SettingsScope(
          settings: settings,
          child: SmoothScrolling(
            enabled: true,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: RoomPage(room: room),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('history message'), findsWidgets);

    // Scroll cost with a big loaded timeline (position listener runs per
    // scroll notification).
    final listCenter = tester.getCenter(find.byType(RoomPage));
    final pointer = TestPointer(9, PointerDeviceKind.mouse);
    pointer.hover(listCenter);
    var watch = Stopwatch();
    var worstFrameMs = 0.0;
    for (var i = 0; i < 30; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
      watch = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      watch.stop();
      final frameMs = watch.elapsedMicroseconds / 1000;
      if (frameMs > worstFrameMs) worstFrameMs = frameMs;
    }
    await tester.pumpAndSettle();

    // Receipts-churn rebuild with a big loaded timeline; SDK sync handling
    // and UI rebuild timed separately.
    var sdkMs = 0.0;
    var uiMs = 0.0;
    for (var i = 0; i < 10; i++) {
      watch = Stopwatch()..start();
      await tester.runAsync(
        () => _sync(client, {
          '!room0:fake': JoinedRoomUpdate(
            ephemeral: [
              BasicEvent(
                type: 'm.receipt',
                content: {
                  '\$msg1': {
                    'm.read': {
                      '@reader$i:fake': {'ts': 1700000000000 + i},
                    },
                  },
                },
              ),
            ],
          ),
        }),
      );
      watch.stop();
      sdkMs += watch.elapsedMicroseconds / 1000;
      watch = Stopwatch()..start();
      await tester.pump();
      watch.stop();
      uiMs += watch.elapsedMicroseconds / 1000;
    }
    final receiptSyncMs = (sdkMs + uiMs) / 10;

    // ignore: avoid_print
    print(
      'BENCH-LARGE worst scroll frame:       '
      '${worstFrameMs.toStringAsFixed(1)}ms\n'
      'BENCH-LARGE receipts-only rebuild:    '
      '${receiptSyncMs.toStringAsFixed(1)}ms/frame '
      '(sdk ${(sdkMs / 10).toStringAsFixed(1)}ms, '
      'ui ${(uiMs / 10).toStringAsFixed(1)}ms)',
    );

    // Tear the UI down, then drain in-flight SDK work (profile requests for
    // the receipt readers) before the harness checks for stray timers —
    // same dance as app_semantics_fuzz_test.
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('timeline rebuild and scroll cost', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    late final AppSettings settings;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      // A busy room: 60 messages, half of them formatted HTML.
      await _sync(client, {
        '!room0:fake': _update([
          for (var i = 0; i < 60; i++)
            _message('message number $i', html: i.isEven),
        ]),
        '!other:fake': _update([_message('other room message')]),
      });
      settings = await AppSettings.load();
    });
    addTearDown(() async {
      await tester.runAsync(() => client.dispose(closeDatabase: true));
    });

    final room = client.getRoomById('!room0:fake')!;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => SettingsScope(
          settings: settings,
          child: SmoothScrolling(
            enabled: true,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: RoomPage(room: room),
      ),
    );
    // Let the timeline load (it is fetched asynchronously).
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('message number'), findsWidgets);

    // 1. Rebuild triggered by a sync for an UNRELATED room.
    var watch = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => _sync(client, {
          '!other:fake': _update([_message('noise $i')]),
        }),
      );
      await tester.pump();
    }
    watch.stop();
    final unrelatedSyncMs = watch.elapsedMicroseconds / 1000 / 10;

    // 2. Rebuild triggered by a sync for the open room.
    watch = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => _sync(client, {
          '!room0:fake': _update([_message('new in room $i', html: true)]),
        }),
      );
      await tester.pump();
    }
    watch.stop();
    final roomSyncMs = watch.elapsedMicroseconds / 1000 / 10;

    // 2b. Rebuild triggered by a receipts-only sync for the open room (the
    // frequent case in a busy room: receipts/typing churn, no new events).
    watch = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => _sync(client, {
          '!room0:fake': JoinedRoomUpdate(
            ephemeral: [
              BasicEvent(
                type: 'm.receipt',
                content: {
                  '\$msg1': {
                    'm.read': {
                      '@reader$i:fake': {
                        'ts': 1700000000000 + i,
                      },
                    },
                  },
                },
              ),
            ],
          ),
        }),
      );
      await tester.pump();
    }
    watch.stop();
    final receiptSyncMs = watch.elapsedMicroseconds / 1000 / 10;

    // 3. Scrolling through history: wheel ticks with per-frame pumps.
    final listCenter = tester.getCenter(find.byType(RoomPage));
    final pointer = TestPointer(7, PointerDeviceKind.mouse);
    pointer.hover(listCenter);
    var worstFrameMs = 0.0;
    for (var i = 0; i < 30; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
      watch = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      watch.stop();
      final frameMs = watch.elapsedMicroseconds / 1000;
      if (frameMs > worstFrameMs) worstFrameMs = frameMs;
    }
    await tester.pumpAndSettle();

    // ignore: avoid_print
    print(
      'BENCH unrelated-room sync rebuild: '
      '${unrelatedSyncMs.toStringAsFixed(1)}ms/frame\n'
      'BENCH open-room sync rebuild:      '
      '${roomSyncMs.toStringAsFixed(1)}ms/frame\n'
      'BENCH receipts-only sync rebuild:  '
      '${receiptSyncMs.toStringAsFixed(1)}ms/frame\n'
      'BENCH worst scroll frame:          '
      '${worstFrameMs.toStringAsFixed(1)}ms',
    );
  });
}
