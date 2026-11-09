import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

/// Account-data type storing the user's private nicknames for other users,
/// as `{"nicknames": {"@user:server": "Nickname"}}`. Nicknames are only
/// visible to the account that set them and sync between Protea sessions
/// via account data, like favorite GIFs.
const nicknamesAccountData = 'energy.vgt.protea.nicknames';

/// Bumped whenever a nickname changes locally, so the home layout rebuilds
/// right away instead of waiting for the sync echo.
final nicknamesRevision = ValueNotifier<int>(0);

Map<String, String> nicknamesOf(Client client) {
  final raw = client.accountData[nicknamesAccountData]?.content['nicknames'];
  if (raw is! Map) return {};
  return {
    for (final entry in raw.entries)
      if (entry.key is String &&
          entry.value is String &&
          (entry.value as String).trim().isNotEmpty)
        entry.key as String: (entry.value as String).trim(),
  };
}

String? nicknameOf(Client client, String userId) => nicknamesOf(client)[userId];

/// Sets (or, for a null/blank [nickname], removes) the nickname for
/// [userId]. The local account data copy is updated optimistically so the
/// UI reflects the change immediately; the sync echo confirms it.
Future<void> setNickname(Client client, String userId, String? nickname) async {
  final nicknames = nicknamesOf(client);
  final trimmed = nickname?.trim() ?? '';
  if (trimmed.isEmpty) {
    nicknames.remove(userId);
  } else {
    nicknames[userId] = trimmed;
  }
  final content = {'nicknames': nicknames};
  client.accountData[nicknamesAccountData] = BasicEvent(
    type: nicknamesAccountData,
    content: content,
  );
  nicknamesRevision.value++;
  await client.setAccountData(client.userID!, nicknamesAccountData, content);
}

extension NicknameUser on User {
  /// The user's nickname if one is set, otherwise their display name.
  String get nickOrDisplayname =>
      nicknameOf(room.client, id) ?? calcDisplayname();
}

extension NicknameRoom on Room {
  /// The room's display name, with the partner's nickname for direct chats
  /// that have no explicit name.
  String get nickOrDisplayname {
    final partner = directChatMatrixID;
    if (partner != null && name.isEmpty && canonicalAlias.isEmpty) {
      final nickname = nicknameOf(client, partner);
      if (nickname != null) return nickname;
    }
    return getLocalizedDisplayname();
  }
}
