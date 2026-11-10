// The app icon badge (macOS Dock, Windows taskbar) shows what waits across
// all accounts: unread notification counts plus pending invitations,
// updated by every sync — including the echo of a room being read.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/src/client_manager.dart';
import 'package:protea/src/dock_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

SyncUpdate _unread(String batch, String roomId, int count) => SyncUpdate(
  nextBatch: batch,
  rooms: RoomsUpdate(
    join: {
      roomId: JoinedRoomUpdate(
        unreadNotifications: UnreadNotificationCounts(notificationCount: count),
      ),
    },
  ),
);

void main() {
  testWidgets(
    'the app icon badge follows unread counts and invites',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      late final Client client;
      late final SharedPreferences prefs;
      await tester.runAsync(() async {
        client = await buildFakeClient();
        prefs = await SharedPreferences.getInstance();
      });
      final manager = ClientManager.forTesting(prefs, [client]);

      const channel = MethodChannel('protea/dock');
      final sent = <int>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'setBadgeCount');
        sent.add(call.arguments as int);
        return null;
      });

      final service = DockBadgeService(manager, channel: channel)..init();
      // Whatever the fake server's initial sync left unread.
      expect(sent, [
        pendingCount([client]),
      ]);
      final baseline = sent.single;

      Future<void> sync(SyncUpdate update) => tester.runAsync(() async {
        await client.handleSync(update);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await sync(_unread('b1', '!badge:fake', 3));
      expect(sent.last, baseline + 3);

      await sync(
        SyncUpdate(
          nextBatch: 'b2',
          rooms: RoomsUpdate(
            invite: {
              '!invite:fake': InvitedRoomUpdate(
                inviteState: [
                  StrippedStateEvent(
                    type: 'm.room.member',
                    content: {'membership': 'invite'},
                    senderId: '@other:fake',
                    stateKey: fakeUserId,
                  ),
                ],
              ),
            },
          ),
        ),
      );
      expect(sent.last, baseline + 4);

      // A sync that changes nothing does not cross the channel again.
      final calls = sent.length;
      await sync(SyncUpdate(nextBatch: 'b3'));
      expect(sent, hasLength(calls));

      // The room gets read (here or on another device).
      await sync(_unread('b4', '!badge:fake', 0));
      expect(sent.last, baseline + 1);

      service.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );

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
    },
    variant: TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );
}
