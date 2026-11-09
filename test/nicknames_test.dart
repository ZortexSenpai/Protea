// Nicknames are private per-account labels for other users, stored in
// account data, that replace display names (and unnamed DM room names).
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/src/nicknames.dart';

import 'fake_client.dart';

const _bob = '@bob:fake';
const _dmId = '!dm:fake';

void main() {
  late Client client;

  setUp(() async {
    client = await buildFakeClient();
    await client.handleSync(
      SyncUpdate(
        nextBatch: 'dm',
        accountData: [
          BasicEvent(
            type: 'm.direct',
            content: {
              _bob: [_dmId],
            },
          ),
        ],
        rooms: RoomsUpdate(
          join: {
            _dmId: JoinedRoomUpdate(
              state: [
                for (final (userId, name) in [
                  (fakeUserId, 'Me'),
                  (_bob, 'Bob'),
                ])
                  MatrixEvent(
                    type: EventTypes.RoomMember,
                    content: {'membership': 'join', 'displayname': name},
                    senderId: userId,
                    stateKey: userId,
                    eventId: '\$member$userId',
                    originServerTs: DateTime.now(),
                  ),
              ],
            ),
          },
        ),
      ),
    );
  });

  tearDown(() => client.dispose(closeDatabase: false));

  test('a nickname replaces the display name and DM room name', () async {
    final room = client.getRoomById(_dmId)!;
    final bob = room.unsafeGetUserFromMemoryOrFallback(_bob);
    expect(bob.nickOrDisplayname, 'Bob');
    expect(room.nickOrDisplayname, 'Bob');

    final revision = nicknamesRevision.value;
    await setNickname(client, _bob, '  Bobby  ');
    expect(nicknamesRevision.value, greaterThan(revision));
    expect(nicknameOf(client, _bob), 'Bobby');
    expect(bob.nickOrDisplayname, 'Bobby');
    expect(room.nickOrDisplayname, 'Bobby');
    expect(client.accountData[nicknamesAccountData]?.content, {
      'nicknames': {_bob: 'Bobby'},
    });
  });

  test('a blank nickname removes it', () async {
    await setNickname(client, _bob, 'Bobby');
    await setNickname(client, _bob, '   ');
    expect(nicknameOf(client, _bob), isNull);
    expect(nicknamesOf(client), isEmpty);
    final room = client.getRoomById(_dmId)!;
    expect(
      room.unsafeGetUserFromMemoryOrFallback(_bob).nickOrDisplayname,
      'Bob',
    );
  });

  test('malformed account data is ignored', () async {
    client.accountData[nicknamesAccountData] = BasicEvent(
      type: nicknamesAccountData,
      content: {
        'nicknames': {_bob: 42, '@carol:fake': 'Caz', '@dave:fake': ''},
      },
    );
    expect(nicknamesOf(client), {'@carol:fake': 'Caz'});
  });
}
