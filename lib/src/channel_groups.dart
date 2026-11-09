import 'dart:math';

import 'package:matrix/matrix.dart';

/// Per-user channel groups and manual ordering, stored in the same account
/// data events as VirtualChat (`vc.channel_groups`, `vc.channel_order`,
/// `vc.space_order`) so both clients stay in sync. Groups are scoped per
/// view: a space room id, or 'home' for the Home section.
const channelGroupsEvent = 'vc.channel_groups';
const channelOrderEvent = 'vc.channel_order';
const spaceOrderEvent = 'vc.space_order';

String channelGroupScope(String? spaceId) => spaceId ?? 'home';

class ChannelGroup {
  ChannelGroup({required this.id, required this.name, required this.roomIds});

  final String id;
  String name;
  List<String> roomIds;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'roomIds': roomIds};

  static ChannelGroup? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final roomIds = json['roomIds'];
    if (id is! String || name is! String || roomIds is! List) return null;
    return ChannelGroup(
      id: id,
      name: name,
      roomIds: roomIds.whereType<String>().toList(),
    );
  }
}

String newGroupId() {
  final random = Random().nextInt(0x7fffffff).toRadixString(36);
  final time = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  return 'grp_${time}_$random';
}

Map<String, Object?> _scopesOf(Client client, String eventType) {
  final scopes = client.accountData[eventType]?.content['scopes'];
  return scopes is Map<String, Object?> ? scopes : {};
}

/// The user's channel groups for [spaceId] (null = Home).
List<ChannelGroup> channelGroupsFor(Client client, String? spaceId) {
  final raw = _scopesOf(client, channelGroupsEvent)[channelGroupScope(spaceId)];
  if (raw is! List) return [];
  return raw.map(ChannelGroup.fromJson).nonNulls.toList();
}

/// The user's manual order of ungrouped channels for [spaceId].
List<String> channelOrderFor(Client client, String? spaceId) {
  final raw = _scopesOf(client, channelOrderEvent)[channelGroupScope(spaceId)];
  if (raw is! List) return [];
  return raw.whereType<String>().toList();
}

/// The user's manual order of the spaces rail.
List<String> spaceOrderOf(Client client) {
  final raw = client.accountData[spaceOrderEvent]?.content['order'];
  if (raw is! List) return [];
  return raw.whereType<String>().toList();
}

/// Applies a saved [order]: known ids first (in saved order), remaining
/// items after in their default order — VirtualChat semantics.
List<T> applyOrder<T>(
  List<T> items,
  List<String> order,
  String Function(T) idOf,
) {
  if (order.isEmpty) return items;
  final byId = {for (final item in items) idOf(item): item};
  final seen = <String>{};
  final ordered = <T>[
    for (final id in order)
      if (byId[id] case final T item)
        if (seen.add(id)) item,
  ];
  for (final item in items) {
    if (!seen.contains(idOf(item))) ordered.add(item);
  }
  return ordered;
}

/// Optimistically updates the local account data copy so the UI reflects
/// the change immediately; the sync echo confirms it.
void _setLocal(Client client, String eventType, Map<String, Object?> content) {
  client.accountData[eventType] = BasicEvent(type: eventType, content: content);
}

Future<void> saveChannelGroups(
  Client client,
  String? spaceId,
  List<ChannelGroup> groups,
) async {
  final scopes = Map<String, Object?>.from(
    _scopesOf(client, channelGroupsEvent),
  );
  scopes[channelGroupScope(spaceId)] = [
    for (final group in groups) group.toJson(),
  ];
  final content = {'scopes': scopes};
  _setLocal(client, channelGroupsEvent, content);
  await client.setAccountData(client.userID!, channelGroupsEvent, content);
}

Future<void> saveChannelOrder(
  Client client,
  String? spaceId,
  List<String> order,
) async {
  final scopes = Map<String, Object?>.from(
    _scopesOf(client, channelOrderEvent),
  );
  scopes[channelGroupScope(spaceId)] = order;
  final content = {'scopes': scopes};
  _setLocal(client, channelOrderEvent, content);
  await client.setAccountData(client.userID!, channelOrderEvent, content);
}

Future<void> saveSpaceOrder(Client client, List<String> order) async {
  final content = {'order': order};
  _setLocal(client, spaceOrderEvent, content);
  await client.setAccountData(client.userID!, spaceOrderEvent, content);
}
