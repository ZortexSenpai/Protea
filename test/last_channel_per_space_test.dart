// Picking a space in the rail reopens the channel last opened there, and
// the choice survives a restart (per account, in SharedPreferences).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/src/client_manager.dart';
import 'package:protea/src/l10n.dart';
import 'package:protea/src/pages/home_page.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/smooth_scroll.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

var _eventCounter = 0;

MatrixEvent _state(String type, Map<String, Object?> content, {String? key}) =>
    MatrixEvent(
      type: type,
      content: content,
      senderId: fakeUserId,
      eventId: '\$state${_eventCounter++}',
      originServerTs: DateTime.fromMillisecondsSinceEpoch(1),
      stateKey: key ?? '',
    );

JoinedRoomUpdate _room(
  String name, {
  bool space = false,
  List<String> children = const [],
}) => JoinedRoomUpdate(
  state: [
    _state('m.room.create', {if (space) 'type': 'm.space'}),
    _state('m.room.name', {'name': name}),
    _state('m.room.member', {'membership': 'join'}, key: fakeUserId),
    for (final child in children)
      _state('m.space.child', {
        'via': ['fake'],
      }, key: child),
  ],
);

void main() {
  testWidgets('a space reopens the channel last opened in it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    late final AppSettings settings;
    late final SharedPreferences prefs;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'spaces-batch',
          rooms: RoomsUpdate(
            join: {
              '!alpha:fake': _room(
                'Alpha',
                space: true,
                children: ['!a1:fake', '!a2:fake', '!acat:fake'],
              ),
              '!acat:fake': _room(
                'Alpha Category',
                space: true,
                children: ['!a3:fake'],
              ),
              '!beta:fake': _room(
                'Beta',
                space: true,
                children: ['!b1:fake', '!b2:fake'],
              ),
              '!a1:fake': _room('alpha-one'),
              '!a2:fake': _room('alpha-two'),
              '!a3:fake': _room('alpha-three'),
              '!b1:fake': _room('beta-one'),
              '!b2:fake': _room('beta-two'),
              '!home:fake': _room('home-room'),
            },
          ),
        ),
      );
      prefs = await SharedPreferences.getInstance();
      settings = await AppSettings.load();
    });
    final manager = ClientManager.forTesting(prefs, [client]);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(tester.view.reset);

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
        home: HomePage(client: client, manager: manager, settings: settings),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> pickSpace(String name) async {
      await tester.tap(find.byTooltip(name));
      await settle();
    }

    // The channel list comes before the chat pane, whose header repeats
    // the open channel's name.
    Future<void> openChannel(String name) async {
      await tester.tap(find.text(name).first);
      await settle();
    }

    String? openRoomId() {
      final pages = tester.widgetList<RoomPage>(find.byType(RoomPage));
      return pages.isEmpty ? null : pages.single.room.id;
    }

    final home = AppLocalizations.of(
      tester.element(find.byType(HomePage)),
    ).home;

    // Nothing opened yet: a space starts without a channel.
    await pickSpace('Alpha');
    expect(openRoomId(), isNull);
    await openChannel('alpha-two');
    expect(openRoomId(), '!a2:fake');

    await pickSpace('Beta');
    expect(openRoomId(), isNull);
    await openChannel('beta-one');
    expect(openRoomId(), '!b1:fake');

    // Back and forth: each space reopens its own channel.
    await pickSpace('Alpha');
    expect(openRoomId(), '!a2:fake');
    await pickSpace('Beta');
    expect(openRoomId(), '!b1:fake');

    // Channels inside a sub-space category count as the space's own.
    await pickSpace('Alpha');
    await openChannel('alpha-three');
    expect(openRoomId(), '!a3:fake');
    await pickSpace('Beta');
    await pickSpace('Alpha');
    expect(openRoomId(), '!a3:fake');

    // Home remembers its last room too.
    await pickSpace(home);
    expect(openRoomId(), isNull);
    await openChannel('home-room');
    expect(openRoomId(), '!home:fake');
    await pickSpace('Beta');
    await pickSpace(home);
    expect(openRoomId(), '!home:fake');

    // Persisted per account, for the next start.
    final reloaded = await AppSettings.load();
    expect(reloaded.lastRoomFor('Protea', '!alpha:fake'), '!a3:fake');
    expect(reloaded.lastRoomFor('Protea', '!beta:fake'), '!b1:fake');
    expect(reloaded.lastRoomFor('Protea', null), '!home:fake');
    expect(reloaded.lastRoomFor('Protea-2', '!alpha:fake'), isNull);

    // A remembered channel the space no longer lists isn't reopened.
    await tester.runAsync(
      () => client.handleSync(
        SyncUpdate(
          nextBatch: 'unlink-batch',
          rooms: RoomsUpdate(
            join: {
              '!beta:fake': JoinedRoomUpdate(
                state: [_state('m.space.child', {}, key: '!b1:fake')],
              ),
            },
          ),
        ),
      ),
    );
    await pickSpace('Alpha');
    await pickSpace('Beta');
    expect(openRoomId(), isNull);

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
