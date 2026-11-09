// Drives the real home + room pages with a fake Matrix client and semantics
// enabled, mimicking a user mousing around right after launch — hunting the
// '!child.attached' semantics assertion seen on Linux (where AT-SPI keeps
// semantics active).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/src/client_manager.dart';
import 'package:protea/src/l10n.dart';
import 'package:protea/src/motion.dart';
import 'package:protea/src/pages/home_page.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/smooth_scroll.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

const _userId = fakeUserId;

var _eventCounter = 0;

String eventIdFor(String body) => '\$${body.replaceAll(' ', '_')}';

JoinedRoomUpdate _roomUpdate(
  String roomId, {
  required List<String> bodies,
  String? name,
  List<String> redact = const [],
  Map<String, String> edit = const {},
  bool limited = false,
}) {
  final events = <MatrixEvent>[
    if (name != null)
      MatrixEvent(
        type: 'm.room.name',
        content: {'name': name},
        senderId: _userId,
        eventId: '\$name${_eventCounter++}',
        originServerTs: DateTime.fromMillisecondsSinceEpoch(1500000000000),
        stateKey: '',
      ),
    for (final body in bodies)
      MatrixEvent(
        type: 'm.room.message',
        content: {'msgtype': 'm.text', 'body': body},
        senderId: _userId,
        // Predictable id (derived from the body) so redactions and edits
        // can target messages: eventIdFor('a msg 3').
        eventId: eventIdFor(body),
        originServerTs: DateTime.fromMillisecondsSinceEpoch(
          1700000000000 + (_eventCounter++) * 1000,
        ),
      ),
    for (final target in redact)
      MatrixEvent(
        type: 'm.room.redaction',
        content: {'redacts': target},
        redacts: target,
        senderId: _userId,
        eventId: '\$redact${_eventCounter++}',
        originServerTs: DateTime.fromMillisecondsSinceEpoch(
          1700000000000 + _eventCounter * 1000,
        ),
      ),
    for (final entry in edit.entries)
      MatrixEvent(
        type: 'm.room.message',
        content: {
          'msgtype': 'm.text',
          'body': '* ${entry.value}',
          'm.new_content': {'msgtype': 'm.text', 'body': entry.value},
          'm.relates_to': {'rel_type': 'm.replace', 'event_id': entry.key},
        },
        senderId: _userId,
        eventId: '\$edit${_eventCounter++}',
        originServerTs: DateTime.fromMillisecondsSinceEpoch(
          1700000000000 + _eventCounter * 1000,
        ),
      ),
  ];
  return JoinedRoomUpdate(
    timeline: TimelineUpdate(
      events: events,
      limited: limited,
      prevBatch: limited ? 'prevtoken' : null,
    ),
    state: [
      if (name != null)
        MatrixEvent(
          type: 'm.room.member',
          content: {'membership': 'join', 'displayname': 'Test'},
          senderId: _userId,
          eventId: '\$member${_eventCounter++}',
          originServerTs: DateTime.fromMillisecondsSinceEpoch(1500000000000),
          stateKey: _userId,
        ),
    ],
  );
}

Future<void> _sync(Client client, Map<String, JoinedRoomUpdate> join) {
  return client.handleSync(
    SyncUpdate(
      nextBatch: 'batch${_eventCounter++}',
      rooms: RoomsUpdate(join: join),
    ),
  );
}

void main() {
  final linux = TargetPlatformVariant.only(TargetPlatform.linux);

  testWidgets('home + room fuzz with semantics', variant: linux, (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'flutter.layout': 'liquid',
      'flutter.showMemberList': true,
      'flutter.messageLayout': 'cozy',
    });

    late final Client client;
    late final AppSettings settings;
    late final SharedPreferences prefs;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      await _sync(client, {
        for (var r = 0; r < 3; r++)
          '!room$r:fake': _roomUpdate(
            '!room$r:fake',
            name: 'room $r',
            bodies: [for (var i = 0; i < 30; i++) 'message $i in room $r'],
          ),
      });
      prefs = await SharedPreferences.getInstance();
      settings = await AppSettings.load();
    });
    final manager = ClientManager.forTesting(prefs, [client]);

    final handle = tester.ensureSemantics();
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(2560, 1440);
    addTearDown(tester.view.reset);

    Widget app({String account = 'a'}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          // Same route transitions as the real app.
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              for (final platform in TargetPlatform.values)
                platform: const FadeSlidePageTransitionsBuilder(),
            },
          ),
        ),
        builder: (context, child) => SettingsScope(
          settings: settings,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            child: SmoothScrolling(
              enabled: true,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
        home: KeyedSubtree(
          // The real app keys the home subtree by the active account, so
          // an account switch replaces it wholesale.
          key: ValueKey(account),
          child: HomePage(client: client, manager: manager, settings: settings),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 300));

    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 9,
    );
    await mouse.addPointer(location: const Offset(40, 120));
    addTearDown(mouse.removePointer);

    // Hover down the rail and channel list while syncs churn.
    await mouse.moveTo(const Offset(40, 400));
    await tester.pump(const Duration(milliseconds: 40));
    await _sync(client, {
      '!room0:fake': _roomUpdate('!room0:fake', bodies: ['new a', 'new b']),
    });
    await mouse.moveTo(const Offset(160, 300));
    await tester.pump(const Duration(milliseconds: 40));

    // Open room 0 and hover the timeline mid-fade while messages arrive.
    await tester.tap(find.text('room 0').last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 40));
    await _sync(client, {
      '!room0:fake': _roomUpdate('!room0:fake', bodies: ['mid fade 1']),
    });
    await tester.pump(const Duration(milliseconds: 40));
    for (var y = 200.0; y < 700; y += 60) {
      await mouse.moveTo(Offset(700, y));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await _sync(client, {
      '!room0:fake': _roomUpdate('!room0:fake', bodies: ['more 1', 'more 2']),
    });
    await tester.pump(const Duration(milliseconds: 40));

    // Wheel-glide the timeline while hovering.
    final scrollPointer = TestPointer(10, PointerDeviceKind.mouse);
    scrollPointer.hover(const Offset(700, 450));
    await tester.sendEventToBinding(scrollPointer.scroll(const Offset(0, 120)));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.sendEventToBinding(scrollPointer.scroll(const Offset(0, 120)));
    await tester.pump(const Duration(milliseconds: 30));

    // Switch to room 1 mid-glide; hover across both fading panes.
    await tester.tap(find.text('room 1').last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 30));
    await mouse.moveTo(const Offset(700, 400));
    await _sync(client, {
      '!room1:fake': _roomUpdate('!room1:fake', bodies: ['r1 new 1']),
    });
    await tester.pump(const Duration(milliseconds: 30));
    await mouse.moveTo(const Offset(650, 500));
    await tester.pump(const Duration(milliseconds: 30));

    // Resize across the wide/narrow threshold mid-churn, like the window
    // manager does right after launch.
    tester.view.physicalSize = const Size(1600, 1440); // 800 logical: narrow
    await tester.pump(const Duration(milliseconds: 30));
    await _sync(client, {
      '!room1:fake': _roomUpdate('!room1:fake', bodies: ['r1 new 2']),
    });
    await tester.pump(const Duration(milliseconds: 30));
    tester.view.physicalSize = const Size(2560, 1440); // wide again
    await tester.pump(const Duration(milliseconds: 30));

    // Hover a message row long enough for the action bar + tooltip, then
    // hover the action bar itself.
    await mouse.moveTo(const Offset(700, 450));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    final reply = find.byTooltip('Reply');
    if (reply.evaluate().isNotEmpty) {
      await mouse.moveTo(tester.getCenter(reply.first));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
    }

    // Redact and edit visible messages while hovered: items disappear and
    // change under the SelectionArea.
    await _sync(client, {
      '!room1:fake': _roomUpdate(
        '!room1:fake',
        bodies: [],
        redact: [
          eventIdFor('message 28 in room 1'),
          eventIdFor('message 29 in room 1'),
          eventIdFor('r1 new 1'),
        ],
        edit: {eventIdFor('message 27 in room 1'): 'edited body 27'},
      ),
    });
    await tester.pump(const Duration(milliseconds: 30));
    await mouse.moveTo(const Offset(700, 420));
    await tester.pump(const Duration(milliseconds: 30));

    // A limited (gappy) sync makes the SDK reset the room timeline — the
    // whole list under the SelectionArea churns at once.
    await _sync(client, {
      '!room1:fake': _roomUpdate(
        '!room1:fake',
        bodies: ['after gap 1', 'after gap 2', 'after gap 3'],
        limited: true,
      ),
    });
    await tester.pump(const Duration(milliseconds: 30));
    await mouse.moveTo(const Offset(700, 520));
    await tester.pump(const Duration(milliseconds: 30));

    // Drag-select text across several messages, and keep the selection
    // alive while messages churn underneath (new arrivals, redactions of
    // selected messages, edits).
    await mouse.moveTo(const Offset(600, 300));
    await tester.pump(const Duration(milliseconds: 20));
    await mouse.down(const Offset(600, 300));
    await tester.pump(const Duration(milliseconds: 20));
    for (var y = 320.0; y <= 560; y += 40) {
      await mouse.moveTo(Offset(640, y));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _sync(client, {
      '!room1:fake': _roomUpdate(
        '!room1:fake',
        bodies: ['during selection 1'],
        redact: [eventIdFor('after gap 2')],
      ),
    });
    await tester.pump(const Duration(milliseconds: 20));
    await mouse.moveTo(const Offset(700, 620));
    await tester.pump(const Duration(milliseconds: 16));
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 30));

    // Churn again with the finished selection still active.
    await _sync(client, {
      '!room1:fake': _roomUpdate(
        '!room1:fake',
        bodies: ['post selection 1', 'post selection 2'],
        redact: [eventIdFor('after gap 3')],
        edit: {eventIdFor('after gap 1'): 'edited after selection'},
      ),
    });
    await tester.pump(const Duration(milliseconds: 30));

    // Select again and switch rooms mid-selection so the SelectionArea
    // disappears while a drag is active.
    await mouse.down(const Offset(600, 400));
    await tester.pump(const Duration(milliseconds: 16));
    await mouse.moveTo(const Offset(650, 500));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.text('room 2').last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 30));
    await mouse.moveTo(const Offset(650, 550));
    await tester.pump(const Duration(milliseconds: 30));
    await mouse.up();
    await _sync(client, {
      '!room2:fake': _roomUpdate('!room2:fake', bodies: ['r2 fresh']),
    });
    await tester.pump(const Duration(milliseconds: 30));

    // Ghost navigation, like stale notification activations at launch:
    // full-screen room routes pushed rapid-fire over the home, mid
    // transition, while syncs churn — then an account-switch re-key that
    // replaces the whole home subtree underneath the routes.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    final pushedRooms = [
      for (var r = 0; r < 3; r++) client.getRoomById('!room$r:fake')!,
    ];
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => RoomPage(room: pushedRooms[0])),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await _sync(client, {
      '!room0:fake': _roomUpdate('!room0:fake', bodies: ['ghost 1']),
    });
    await mouse.moveTo(const Offset(600, 400));
    await tester.pump(const Duration(milliseconds: 40));
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => RoomPage(room: pushedRooms[1])),
    );
    await tester.pump(const Duration(milliseconds: 30));
    await _sync(client, {
      '!room1:fake': _roomUpdate('!room1:fake', bodies: ['ghost 2']),
    });
    await mouse.moveTo(const Offset(620, 480));
    await tester.pump(const Duration(milliseconds: 30));
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => RoomPage(room: pushedRooms[2])),
    );
    await tester.pump(const Duration(milliseconds: 30));
    // Account switch mid-push: the home subtree below the routes is
    // replaced wholesale.
    await tester.pumpWidget(app(account: 'b'));
    await tester.pump(const Duration(milliseconds: 30));
    await _sync(client, {
      '!room2:fake': _roomUpdate('!room2:fake', bodies: ['ghost 3']),
    });
    await mouse.moveTo(const Offset(640, 520));
    await tester.pumpAndSettle();

    // Pop the stacked rooms again, churning while routes fade out.
    navigator.popUntil((route) => route.isFirst);
    await tester.pump(const Duration(milliseconds: 30));
    await _sync(client, {
      '!room0:fake': _roomUpdate('!room0:fake', bodies: ['after pop']),
    });
    await mouse.moveTo(const Offset(600, 400));
    await tester.pumpAndSettle();

    // Back to room 0 mid-churn, then settle everything.
    await tester.tap(find.text('room 0').last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 30));
    await _sync(client, {
      '!room0:fake': _roomUpdate('!room0:fake', bodies: ['final']),
    });
    await tester.pumpAndSettle();

    handle.dispose();
    // Tear the UI down so nothing spawns new requests, then drain in-flight
    // SDK work. Some of it was started from the real-async setup zone, so
    // alternate real-async windows with fake-clock pumps, and leave the
    // in-memory database open (the process is about to exit anyway).
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
