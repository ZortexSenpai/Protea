// Sticker packs are MSC2545 image packs: legacy proprietary packs migrate
// into im.ponies.user_emotes on first open, and packs from room state
// (as FluffyChat/Cinny/Nheko set them up) show in the picker.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/src/l10n.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/widgets/sticker_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

Widget _app(Room room, AppSettings settings) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) =>
        SettingsScope(settings: settings, child: child ?? const SizedBox()),
    home: Scaffold(
      body: StickerPickerPanel(room: room, onClose: () {}),
    ),
  );
}

void main() {
  testWidgets('legacy packs migrate to MSC2545 and room packs show up', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    late final AppSettings settings;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'stickers',
          accountData: [
            // A pre-MSC2545 Protea pack that must be migrated.
            BasicEvent(
              type: legacyStickerPacksAccountData,
              content: {
                'packs': [
                  {
                    'name': 'Old pack',
                    'stickers': [
                      {
                        'name': 'Party Cat',
                        'url': 'mxc://fake/partycat',
                        'info': {'mimetype': 'image/png'},
                      },
                    ],
                  },
                ],
              },
            ),
          ],
          rooms: RoomsUpdate(
            join: {
              '!room0:fake': JoinedRoomUpdate(
                state: [
                  // An MSC2545 room pack as FluffyChat would create it.
                  MatrixEvent(
                    type: 'im.ponies.room_emotes',
                    stateKey: 'fluffy',
                    senderId: fakeUserId,
                    eventId: '\$roompack',
                    originServerTs: DateTime.fromMillisecondsSinceEpoch(
                      1700000000000,
                    ),
                    content: {
                      'pack': {
                        'display_name': 'Fluffy pack',
                        'usage': ['sticker'],
                      },
                      'images': {
                        'fluffy-dog': {
                          'url': 'mxc://fake/fluffydog',
                          'body': 'Fluffy Dog',
                        },
                      },
                    },
                  ),
                ],
              ),
            },
          ),
        ),
      );
      settings = await AppSettings.load();
    });

    final room = client.getRoomById('!room0:fake')!;
    await tester.pumpWidget(_app(room, settings));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The migrated user pack was written to the MSC2545 account-data key…
    final userEmotesPuts = FakeMatrixApi.calledEndpoints.entries
        .where((e) => e.key.contains('account_data/im.ponies.user_emotes'))
        .expand((e) => e.value)
        .toList();
    expect(userEmotesPuts, isNotEmpty);
    final written =
        jsonDecode(userEmotesPuts.last as String) as Map<String, dynamic>;
    final images = written['images'] as Map<String, dynamic>;
    expect(images.keys, contains('party-cat'));
    expect(images['party-cat']['url'], 'mxc://fake/partycat');
    expect(images['party-cat']['usage'], ['sticker']);

    // …and the legacy key was emptied.
    final legacyPuts = FakeMatrixApi.calledEndpoints.entries
        .where(
          (e) =>
              e.key.contains('account_data/$legacyStickerPacksAccountData'),
        )
        .expand((e) => e.value)
        .toList();
    expect(legacyPuts, isNotEmpty);
    expect(jsonDecode(legacyPuts.last as String), isEmpty);

    // The picker shows both the migrated user pack and the room pack.
    expect(find.widgetWithText(ChoiceChip, 'user'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Fluffy pack'), findsOneWidget);
    expect(find.byTooltip('Party Cat'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Fluffy pack'));
    await tester.pump();
    expect(find.byTooltip('Fluffy Dog'), findsOneWidget);

    // Reopening does not migrate again: the legacy key is empty now.
    final putsBefore = FakeMatrixApi.calledEndpoints.entries
        .where((e) => e.key.contains('account_data/im.ponies.user_emotes'))
        .expand((e) => e.value)
        .length;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app(room, settings));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
    final putsAfter = FakeMatrixApi.calledEndpoints.entries
        .where((e) => e.key.contains('account_data/im.ponies.user_emotes'))
        .expand((e) => e.value)
        .length;
    expect(putsAfter, putsBefore);

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
