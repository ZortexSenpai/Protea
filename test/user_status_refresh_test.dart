// A status message lives in an extended profile field, which never travels
// over sync — and the SDK keeps profiles in its database for a day, so a
// plain refetch reads the stale row straight back. That left the member list
// showing an old status while the chat title, fed by the presence status
// message, already showed the new one.
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/src/widgets/user_banner.dart';

import 'fake_client.dart';

/// Points the fake homeserver's profile endpoint for [userId] at [status].
void _serveStatus(String userId, String status) {
  FakeMatrixApi
          .currentApi!
          .api['GET']!['/client/v3/profile/${Uri.encodeComponent(userId)}'] =
      (dynamic req) => {
        'displayname': 'Statused',
        'chat.commet.profile_status': status,
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('status resolution prefers the profile fields', () {
    // Presence is only the fallback when no profile field is set.
    expect(
      resolveUserStatus(profileStatus: 'profile', presenceStatusMsg: 'pres'),
      'profile',
    );
    expect(
      resolveUserStatus(profileStatus: null, presenceStatusMsg: 'pres'),
      'pres',
    );
    expect(
      resolveUserStatus(profileStatus: '   ', presenceStatusMsg: 'pres'),
      'pres',
    );
    expect(resolveUserStatus(profileStatus: '', presenceStatusMsg: ''), isNull);
    expect(resolveUserStatus(), isNull);
  });

  test('profile status fields are read in priority order', () {
    String? status(Map<String, Object?> fields) =>
        statusFromProfile(ProfileInformation.fromJson(fields));

    const msc = {'text': 'In a meeting', 'emoji': '🔴'};
    const stable = {'text': 'On holiday', 'emoji': '🌴'};
    expect(
      status({
        'org.matrix.msc4426.status': msc,
        'm.status': stable,
        'chat.commet.profile_status': 'commet',
      }),
      '🔴 In a meeting',
    );
    expect(
      status({'m.status': stable, 'chat.commet.profile_status': 'commet'}),
      '🌴 On holiday',
    );
    // An empty MSC4426 object falls through to the next field.
    expect(
      status({
        'org.matrix.msc4426.status': {'text': '', 'emoji': ''},
        'm.status': {'text': 'text only'},
        'chat.commet.profile_status': 'commet',
      }),
      'text only',
    );
    expect(
      status({
        'm.status': {'emoji': '🌴'},
      }),
      '🌴',
    );
    expect(status({'chat.commet.profile_status': 'commet'}), 'commet');
    expect(status({}), isNull);
  });

  test('a dropped profile is refetched past the SDK profile cache', () async {
    const userId = '@status:fake';
    final client = await buildFakeClient();
    addTearDown(() => client.dispose(closeDatabase: true));

    _serveStatus(userId, 'old status');
    expect(await fetchUserStatus(client, userId), 'old status');

    // The server-side value changes with nothing to announce it.
    _serveStatus(userId, 'new status');
    expect(
      await fetchUserStatus(client, userId),
      'old status',
      reason: 'a fresh cache entry is served without hitting the server',
    );

    dropCachedUserProfile(userId);
    expect(await fetchUserStatus(client, userId), 'new status');
  });

  test('a presence status change drops the cached profile', () async {
    const userId = '@presence-status:fake';
    final client = await buildFakeClient(name: 'Protea-hints');
    final subscription = watchProfileHints(client);
    addTearDown(subscription.cancel);
    addTearDown(() => client.dispose(closeDatabase: true));

    _serveStatus(userId, 'old status');
    expect(await fetchUserStatus(client, userId), 'old status');

    // First presence sighting: nothing to compare against, so nothing is
    // dropped and the cached profile still stands.
    client.onPresenceChanged.add(
      CachedPresence(PresenceType.online, 0, 'old status', true, userId),
    );
    await Future<void>.delayed(Duration.zero);
    _serveStatus(userId, 'new status');
    expect(await fetchUserStatus(client, userId), 'old status');

    // The user edits their status: Protea writes it to both the presence and
    // the profile field, so the presence update is the hint to refetch.
    client.onPresenceChanged.add(
      CachedPresence(PresenceType.online, 0, 'new status', true, userId),
    );
    await Future<void>.delayed(Duration.zero);
    expect(await fetchUserStatus(client, userId), 'new status');
  });

  test('a presence heartbeat alone does not drop the cached profile', () async {
    const userId = '@heartbeat:fake';
    final client = await buildFakeClient(name: 'Protea-heartbeat');
    final subscription = watchProfileHints(client);
    addTearDown(subscription.cancel);
    addTearDown(() => client.dispose(closeDatabase: true));

    _serveStatus(userId, 'old status');
    expect(await fetchUserStatus(client, userId), 'old status');

    for (final lastActiveAgo in [0, 5000, 20000]) {
      client.onPresenceChanged.add(
        CachedPresence(
          PresenceType.online,
          lastActiveAgo,
          'old status',
          true,
          userId,
        ),
      );
    }
    await Future<void>.delayed(Duration.zero);
    _serveStatus(userId, 'new status');
    expect(
      await fetchUserStatus(client, userId),
      'old status',
      reason: 'only a changed status or presence should cost a refetch',
    );
  });
}
