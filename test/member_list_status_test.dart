// A status can live in several places: the extended profile fields
// (MSC4426's `m.status` and Commet's `chat.commet.profile_status`) and the
// `m.presence` status message. The profile fields win; presence is only the
// fallback. The member list and the chat title must agree on that order.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

const _peer = '@peer:fake';

void main() {
  testWidgets('member list prefers the profile status over presence', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    late final AppSettings settings;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      final api = FakeMatrixApi.currentApi!.api;
      // The MSC4426 field outranks Commet's and the presence message.
      api['GET']!['/client/v3/profile/${Uri.encodeComponent(_peer)}'] =
          (dynamic req) => {
            'displayname': 'Peer',
            'org.matrix.msc4426.status': {
              'text': 'Discombobulating...',
              'emoji': '🌀',
            },
            'chat.commet.profile_status': 'Trinity, Help!',
          };
      api['GET']!['/client/v3/presence/${Uri.encodeComponent(_peer)}/status'] =
          (dynamic req) => {
            'presence': 'online',
            'status_msg': 'From presence',
            'currently_active': true,
          };
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'b1',
          rooms: RoomsUpdate(
            join: {
              '!room0:fake': JoinedRoomUpdate(
                // A complete member list keeps requestParticipants local
                // instead of hitting the fake server's canned response.
                summary: RoomSummary.fromJson({
                  'm.joined_member_count': 2,
                  'm.invited_member_count': 0,
                }),
                state: [
                  MatrixEvent(
                    type: 'm.room.member',
                    content: {'membership': 'join', 'displayname': 'Me'},
                    senderId: fakeUserId,
                    eventId: '\$me',
                    originServerTs: DateTime.fromMillisecondsSinceEpoch(1),
                    stateKey: fakeUserId,
                  ),
                  MatrixEvent(
                    type: 'm.room.member',
                    content: {'membership': 'join', 'displayname': 'Peer'},
                    senderId: _peer,
                    eventId: '\$peer',
                    originServerTs: DateTime.fromMillisecondsSinceEpoch(2),
                    stateKey: _peer,
                  ),
                ],
              ),
            },
          ),
        ),
      );
      settings = await AppSettings.load();
      await settings.setShowMemberList(true);
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
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('🌀 Discombobulating...'), findsOneWidget);
    expect(find.text('Trinity, Help!'), findsNothing);
    expect(find.text('From presence'), findsNothing);

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
