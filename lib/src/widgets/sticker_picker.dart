import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'mxc_avatar.dart';

/// Account-data type storing the user's sticker packs. Sent stickers are
/// standard `m.sticker` events, so they render everywhere; the packs
/// themselves sync between Protea sessions via account data.
const stickerPacksAccountData = 'energy.vgt.protea.sticker_packs';

class StickerPack {
  StickerPack({required this.name, required this.stickers});

  String name;
  final List<Sticker> stickers;

  Map<String, Object?> toJson() => {
    'name': name,
    'stickers': [for (final sticker in stickers) sticker.toJson()],
  };
}

class Sticker {
  Sticker({required this.name, required this.url, this.info});

  final String name;
  final String url;
  final Map<String, Object?>? info;

  Map<String, Object?> toJson() => {
    'name': name,
    'url': url,
    if (info != null) 'info': info,
  };
}

List<StickerPack> loadStickerPacks(Client client) {
  final content = client.accountData[stickerPacksAccountData]?.content;
  final raw = content?.tryGetList<Map<String, Object?>>('packs') ?? [];
  final packs = <StickerPack>[];
  for (final packJson in raw) {
    final stickers = <Sticker>[];
    for (final stickerJson
        in packJson.tryGetList<Map<String, Object?>>('stickers') ?? []) {
      final name = stickerJson.tryGet<String>('name');
      final url = stickerJson.tryGet<String>('url');
      if (name == null || url == null) continue;
      stickers.add(
        Sticker(
          name: name,
          url: url,
          info: stickerJson.tryGetMap<String, Object?>('info'),
        ),
      );
    }
    packs.add(
      StickerPack(
        name: packJson.tryGet<String>('name') ?? 'Pack',
        stickers: stickers,
      ),
    );
  }
  return packs;
}

Future<void> saveStickerPacks(Client client, List<StickerPack> packs) =>
    client.setAccountData(client.userID!, stickerPacksAccountData, {
      'packs': [for (final pack in packs) pack.toJson()],
    });

/// Opens the sticker picker; tapping a sticker sends it to [room].
Future<void> showStickerPicker(BuildContext context, Room room) => showDialog(
  context: context,
  builder: (_) => StickerPickerDialog(room: room),
);

class StickerPickerDialog extends StatefulWidget {
  const StickerPickerDialog({super.key, required this.room});

  final Room room;

  @override
  State<StickerPickerDialog> createState() => _StickerPickerDialogState();
}

class _StickerPickerDialogState extends State<StickerPickerDialog> {
  var _packIndex = 0;
  bool _busy = false;

  Future<void> _send(Sticker sticker) async {
    setState(() => _busy = true);
    try {
      await widget.room.sendEvent({
        'body': sticker.name,
        'url': sticker.url,
        'info': sticker.info ?? <String, Object?>{},
      }, type: EventTypes.Sticker);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final packs = loadStickerPacks(widget.room.client);
    final packIndex = _packIndex.clamp(0, packs.isEmpty ? 0 : packs.length - 1);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Stickers',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Manage packs',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      await showStickerPackManager(context, widget.room.client);
                      if (mounted) setState(() {});
                    },
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (packs.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (var i = 0; i < packs.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(packs[i].name),
                          selected: i == packIndex,
                          onSelected: (_) => setState(() => _packIndex = i),
                        ),
                      ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Flexible(
              child: packs.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No sticker packs yet.\nUse "Manage packs" to create '
                        'one and add images to it.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : packs[packIndex].stickers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('This pack is empty.'),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: packs[packIndex].stickers.length,
                      itemBuilder: (context, index) {
                        final sticker = packs[packIndex].stickers[index];
                        return Tooltip(
                          message: sticker.name,
                          child: InkWell(
                            onTap: _busy ? null : () => _send(sticker),
                            child: MxcImage(
                              client: widget.room.client,
                              uri: Uri.parse(sticker.url),
                              thumbnailWidth: 192,
                              thumbnailHeight: 192,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the pack management dialog: create/delete packs, add/remove
/// stickers (uploaded from image files).
Future<void> showStickerPackManager(BuildContext context, Client client) =>
    showDialog(
      context: context,
      builder: (_) => StickerPackManagerDialog(client: client),
    );

class StickerPackManagerDialog extends StatefulWidget {
  const StickerPackManagerDialog({super.key, required this.client});

  final Client client;

  @override
  State<StickerPackManagerDialog> createState() =>
      _StickerPackManagerDialogState();
}

class _StickerPackManagerDialogState extends State<StickerPackManagerDialog> {
  late final List<StickerPack> _packs = loadStickerPacks(widget.client);
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await saveStickerPacks(widget.client, _packs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createPack() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New sticker pack'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Pack name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    setState(() => _packs.add(StickerPack(name: name, stickers: [])));
    await _save();
  }

  Future<void> _addSticker(StickerPack pack) async {
    final picked = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Images',
          extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
        ),
      ],
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      final mxc = await widget.client.uploadContent(
        bytes,
        filename: picked.name,
      );
      final name = picked.name.split('.').first;
      setState(() {
        pack.stickers.add(
          Sticker(
            name: name,
            url: mxc.toString(),
            info: {'mimetype': picked.mimeType, 'size': bytes.length},
          ),
        );
      });
      await _save();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Sticker packs',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                children: [
                  for (final pack in _packs) ...[
                    ListTile(
                      dense: true,
                      title: Text(
                        pack.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${pack.stickers.length} '
                        '${pack.stickers.length == 1 ? 'sticker' : 'stickers'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Add sticker',
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            onPressed: _busy ? null : () => _addSticker(pack),
                          ),
                          IconButton(
                            tooltip: 'Delete pack',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() => _packs.remove(pack));
                                    await _save();
                                  },
                          ),
                        ],
                      ),
                    ),
                    if (pack.stickers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final sticker in pack.stickers)
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: MxcImage(
                                      client: widget.client,
                                      uri: Uri.parse(sticker.url),
                                      thumbnailWidth: 112,
                                      thumbnailHeight: 112,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: InkWell(
                                      onTap: _busy
                                          ? null
                                          : () async {
                                              setState(
                                                () => pack.stickers.remove(
                                                  sticker,
                                                ),
                                              );
                                              await _save();
                                            },
                                      child: const Icon(Icons.cancel, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    const Divider(),
                  ],
                  TextButton.icon(
                    onPressed: _busy ? null : _createPack,
                    icon: const Icon(Icons.add),
                    label: const Text('New pack'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
