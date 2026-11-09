// Home "Requests" section: every pending invitation (rooms, direct chats,
// spaces) and the user's own knocks are collected at the top of the Home
// list with inline accept/decline, instead of being mixed into the channels
// and the spaces rail.
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

StrippedStateEvent _state(
  String type,
  Map<String, Object?> content, {
  required String sender,
  String stateKey = '',
}) => StrippedStateEvent(
  type: type,
  content: content,
  senderId: sender,
  stateKey: stateKey,
);

StrippedStateEvent _member(String userId, String name) => _state(
  'm.room.member',
  {'membership': 'join', 'displayname': name},
  sender: userId,
  stateKey: userId,
);

StrippedStateEvent _invite(String sender, {bool direct = false}) => _state(
  'm.room.member',
  {'membership': 'invite', if (direct) 'is_direct': true},
  sender: sender,
  stateKey: fakeUserId,
);

/// Moves [roomId] to "joined" the way the next sync after a join would.
SyncUpdate _joined(String roomId, {List<MatrixEvent> state = const []}) =>
    SyncUpdate(
      nextBatch: 'joined-$roomId',
      rooms: RoomsUpdate(
        join: {
          roomId: JoinedRoomUpdate(
            state: [
              ...state,
              MatrixEvent(
                type: 'm.room.member',
                content: {'membership': 'join'},
                senderId: fakeUserId,
                eventId: '\$join-$roomId',
                originServerTs: DateTime.fromMillisecondsSinceEpoch(1),
                stateKey: fakeUserId,
              ),
            ],
          ),
        },
      ),
    );

void main() {
  testWidgets('Home lists open requests with inline actions', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    late final AppSettings settings;
    late final SharedPreferences prefs;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      // FakeMatrixApi's sync already holds one invite: "My Room Name".
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'requests-batch',
          rooms: RoomsUpdate(
            invite: {
              '!dm:fake': InvitedRoomUpdate(
                inviteState: [
                  _member('@alice:fake', 'Alice'),
                  _invite('@alice:fake', direct: true),
                ],
              ),
              '!space:fake': InvitedRoomUpdate(
                inviteState: [
                  _state('m.room.create', {
                    'type': 'm.space',
                  }, sender: '@bob:fake'),
                  _state('m.room.name', {
                    'name': 'Secret Space',
                  }, sender: '@bob:fake'),
                  _member('@bob:fake', 'Bob'),
                  _invite('@bob:fake'),
                ],
              ),
            },
          ),
        ),
      );
      // The SDK skips sync's knock section, so seed a knocked room directly.
      client.rooms.add(
        Room(
          id: '!knock:fake',
          membership: Membership.knock,
          client: client,
        )..setState(
          _state('m.room.name', {'name': 'Members Only'}, sender: '@bob:fake'),
        ),
      );
      prefs = await SharedPreferences.getInstance();
      settings = await AppSettings.load();
    });
    final post = FakeMatrixApi.currentApi!.api['POST']!;
    for (final roomId in ['!dm:fake', '!space:fake']) {
      post['/client/v3/rooms/${Uri.encodeComponent(roomId)}/join'] =
          (dynamic req) => {'room_id': roomId};
    }
    for (final roomId in ['!knock:fake', '!696r7674:example.com']) {
      post['/client/v3/rooms/${Uri.encodeComponent(roomId)}/leave'] =
          (dynamic req) => <String, Object?>{};
    }
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
    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));

    Finder header(int count) =>
        find.text('${l10n.requests.toUpperCase()} — $count');
    Finder tileOf(String text) =>
        find.ancestor(of: find.text(text), matching: find.byType(ListTile));
    Finder action(String tileText, String tooltip) => find.descendant(
      of: tileOf(tileText),
      matching: find.byTooltip(tooltip),
    );
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // Three invitations and a knock, each listed once.
    expect(header(4), findsOneWidget);
    expect(find.text('My Room Name'), findsOneWidget);
    expect(find.text('@alice:fake'), findsOneWidget);
    expect(find.text('${l10n.space} · ${l10n.invitedBy('Bob')}'), findsOne);
    expect(find.text(l10n.knockPending), findsOneWidget);
    // The invited space waits here, not in the spaces rail.
    expect(find.byTooltip('Secret Space'), findsNothing);
    // A knock can only be withdrawn.
    expect(action('Members Only', l10n.accept), findsNothing);

    // Declining an invitation and withdrawing a knock both leave the room.
    await tester.tap(action('My Room Name', l10n.decline));
    await tester.tap(action('Members Only', l10n.withdrawKnock));
    await settle();
    final called = FakeMatrixApi.calledEndpoints.keys;
    expect(called, contains('/client/v3/rooms/!696r7674%3Aexample.com/leave'));
    expect(called, contains('/client/v3/rooms/!knock%3Afake/leave'));

    // Accepting a direct chat joins it and opens the chat.
    await tester.tap(action('@alice:fake', l10n.accept));
    await settle();
    expect(called, contains('/client/v3/rooms/!dm%3Afake/join'));
    await tester.runAsync(() => client.handleSync(_joined('!dm:fake')));
    await settle();
    expect(
      find.byWidgetPredicate((w) => w is RoomPage && w.room.id == '!dm:fake'),
      findsOneWidget,
    );
    expect(header(3), findsOneWidget);

    // Accepting a space joins it and switches to it; once joined it shows up
    // in the rail.
    await tester.tap(action('Secret Space', l10n.accept));
    await settle();
    expect(called, contains('/client/v3/rooms/!space%3Afake/join'));
    expect(header(3), findsNothing);
    expect(find.text('Secret Space'), findsOneWidget); // channel list title
    await tester.runAsync(
      () => client.handleSync(
        _joined(
          '!space:fake',
          state: [
            MatrixEvent(
              type: 'm.room.create',
              content: {'type': 'm.space'},
              senderId: '@bob:fake',
              eventId: '\$create-space',
              originServerTs: DateTime.fromMillisecondsSinceEpoch(1),
              stateKey: '',
            ),
          ],
        ),
      ),
    );
    await settle();
    expect(find.byTooltip('Secret Space'), findsOneWidget);

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
