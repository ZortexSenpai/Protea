// Desktop notifications must be dismissed once their room is read (in the
// app or on another device) — lingering ones keep the launcher's unread
// badge alive on Linux.
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/src/client_manager.dart';
import 'package:protea/src/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final shown = <int>[];
  final cancelled = <int>[];

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async => shown.add(id);

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      cancelled.add(id);

  @override
  Future<void> cancelAll() async {}
}

void main() {
  testWidgets('notifications are dismissed when the room is read', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    late final SharedPreferences prefs;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      prefs = await SharedPreferences.getInstance();
    });
    final manager = ClientManager.forTesting(prefs, [client]);
    final plugin = _FakePlugin();
    final service = NotificationService(manager, plugin: plugin);
    await tester.runAsync(service.init);

    // A message in a room nobody is reading -> a notification shows.
    await tester.runAsync(() async {
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'b1',
          rooms: RoomsUpdate(
            join: {
              '!room0:fake': JoinedRoomUpdate(
                unreadNotifications: UnreadNotificationCounts(
                  notificationCount: 1,
                ),
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: 'm.room.message',
                      content: {'msgtype': 'm.text', 'body': 'ping'},
                      senderId: '@other:fake',
                      eventId: '\$ping',
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
      final room = client.getRoomById('!room0:fake')!;
      final event = await room.getEventById('\$ping');
      client.onNotification.add(event!);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(plugin.shown, isNotEmpty);
    expect(plugin.cancelled, isEmpty);

    // The room gets read on another device: the sync echoes a zero
    // notification count and the shown notification is dismissed.
    await tester.runAsync(() async {
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'b2',
          rooms: RoomsUpdate(
            join: {
              '!room0:fake': JoinedRoomUpdate(
                unreadNotifications: UnreadNotificationCounts(
                  notificationCount: 0,
                ),
              ),
            },
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(plugin.cancelled.toSet(), plugin.shown.toSet());

    // Reading locally dismisses immediately as well.
    plugin.shown.clear();
    plugin.cancelled.clear();
    await tester.runAsync(() async {
      final room = client.getRoomById('!room0:fake')!;
      final event = await room.getEventById('\$ping');
      client.onNotification.add(event!);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(plugin.shown, isNotEmpty);
    NotificationService.clearRoomNotifications('!room0:fake');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(plugin.cancelled.toSet(), plugin.shown.toSet());

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
