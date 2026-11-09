// Room settings: the full Matrix permission set, the roles section, and
// banners for plain (non-space) rooms.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/widgets/room_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

void main() {
  testWidgets('settings expose permissions, roles and banner for rooms', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    await tester.runAsync(() async {
      client = await buildFakeClient();
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
                    content: {'membership': 'join', 'displayname': 'Mod'},
                    senderId: '@mod:fake',
                    eventId: '\$mod',
                    originServerTs: DateTime.fromMillisecondsSinceEpoch(2),
                    stateKey: '@mod:fake',
                  ),
                  MatrixEvent(
                    type: 'm.room.power_levels',
                    content: {
                      'users': {fakeUserId: 100, '@mod:fake': 50},
                      'users_default': 0,
                      'state_default': 50,
                      'events_default': 0,
                      'events': {'com.example.custom_event': 75},
                    },
                    senderId: fakeUserId,
                    eventId: '\$power',
                    originServerTs: DateTime.fromMillisecondsSinceEpoch(3),
                    stateKey: '',
                  ),
                ],
              ),
            },
          ),
        ),
      );
    });

    final room = client.getRoomById('!room0:fake')!;
    // Hydrate the partial room's state from the database, like opening the
    // room in the app does.
    await tester.runAsync(room.postLoad);
    expect(room.isSpace, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RoomSettingsDialog(room: room),
      ),
    );
    // Real-async windows so the participant list loads from the database.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RoomSettingsDialog)),
    );

    // Plain rooms can set a banner.
    expect(find.text(l10n.changeBanner), findsOneWidget);

    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // Roles category: lists the elevated member with their role.
    await tester.tap(find.text(l10n.roles));
    await settle();
    expect(find.text('Mod'), findsWidgets);
    expect(find.text(l10n.moderator), findsWidgets);

    // Notification and access choices render as wrapping pills, not
    // segmented buttons.
    await tester.tap(find.text(l10n.notifications));
    await settle();
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString().startsWith('SegmentedButton'),
      ),
      findsNothing,
    );
    await tester.tap(find.text(l10n.access));
    await settle();
    expect(find.byType(ChoiceChip), findsWidgets);

    // Permissions category covers the previously missing Matrix
    // permissions.
    await tester.tap(find.text(l10n.permissions).first);
    await settle();
    final contentList = find
        .descendant(
          of: find.byType(RoomSettingsDialog),
          matching: find.byType(Scrollable),
        )
        .last;
    for (final label in [
      l10n.defaultRole,
      l10n.notifyEveryone,
      l10n.createPoll,
      l10n.deleteOwnMessages,
      l10n.startCalls,
      l10n.changeAccess,
      l10n.guestAccess,
      l10n.changePermissions,
      l10n.changeHistoryVisibility,
      l10n.upgradeRoom,
      l10n.serverAcl,
      // An override the curated list does not know still gets a raw row.
      'com.example.custom_event',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label).first,
        120,
        scrollable: contentList,
      );
      await tester.pump();
      expect(find.text(label), findsWidgets);
    }

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
