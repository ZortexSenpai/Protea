import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// Rooms pinned with the `m.favourite` tag, sorted by the tag's order value
/// (the spec-standard way to favorite rooms, shared with other clients).
List<Room> pinnedRooms(Iterable<Room> rooms) {
  return rooms.where((room) => room.isFavourite).toList()..sort((a, b) {
    final orderA = a.tags[TagType.favourite]?.order ?? 1.0;
    final orderB = b.tags[TagType.favourite]?.order ?? 1.0;
    final result = orderA.compareTo(orderB);
    return result != 0 ? result : a.id.compareTo(b.id);
  });
}

/// Pins or unpins [room]; new pins go to the end of the pinned section.
Future<void> togglePinned(Room room) async {
  if (room.isFavourite) {
    await room.removeTag(TagType.favourite);
  } else {
    final count = room.client.rooms.where((other) => other.isFavourite).length;
    await room.addTag(TagType.favourite, order: (count + 1) / (count + 2));
  }
}

/// Persists a manual order for the pinned rooms as evenly spaced tag orders
/// between 0 and 1.
Future<void> savePinnedOrder(List<Room> pinned) async {
  for (var i = 0; i < pinned.length; i++) {
    await pinned[i].addTag(
      TagType.favourite,
      order: (i + 1) / (pinned.length + 1),
    );
  }
}

/// "Pinned" sidebar category whose tiles can be dragged to reorder. The
/// order is written back to the favourite tag, so it syncs across clients.
class PinnedRoomsSection extends StatefulWidget {
  const PinnedRoomsSection({
    super.key,
    required this.pinned,
    required this.tileBuilder,
  });

  final List<Room> pinned;
  final Widget Function(Room room) tileBuilder;

  @override
  State<PinnedRoomsSection> createState() => _PinnedRoomsSectionState();
}

class _PinnedRoomsSectionState extends State<PinnedRoomsSection> {
  /// Optimistic order (room ids) shown until the server-side tag update
  /// comes back through sync.
  List<String>? _localOrder;

  List<Room> get _ordered {
    final localOrder = _localOrder;
    if (localOrder == null) return widget.pinned;
    final byId = {for (final room in widget.pinned) room.id: room};
    final ordered = <Room>[];
    for (final id in localOrder) {
      final room = byId.remove(id);
      if (room != null) ordered.add(room);
    }
    return ordered..addAll(byId.values);
  }

  @override
  void didUpdateWidget(PinnedRoomsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final localOrder = _localOrder;
    if (localOrder != null &&
        listEquals(widget.pinned.map((room) => room.id).toList(), localOrder)) {
      _localOrder = null;
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final rooms = List<Room>.from(_ordered);
    final moved = rooms.removeAt(oldIndex);
    rooms.insert(newIndex, moved);
    setState(() => _localOrder = rooms.map((room) => room.id).toList());
    try {
      await savePinnedOrder(rooms);
    } catch (e) {
      if (mounted) {
        setState(() => _localOrder = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pinned.isEmpty) return const SizedBox.shrink();
    final ordered = _ordered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.push_pin_outlined,
                size: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'PINNED',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: _onReorder,
          children: [
            for (var i = 0; i < ordered.length; i++)
              ReorderableDragStartListener(
                key: ValueKey(ordered[i].id),
                index: i,
                child: widget.tileBuilder(ordered[i]),
              ),
          ],
        ),
      ],
    );
  }
}
