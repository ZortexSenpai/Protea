import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import 'mxc_avatar.dart';

/// MSC2545 account-data type holding the user's personal image pack.
/// Stickers stored here show up in FluffyChat, Cinny, Nheko & co, and
/// packs those clients set up show up in Protea.
const userEmotesAccountData = 'im.ponies.user_emotes';

/// MSC2545 state-event type for a room's image packs. Must be registered
/// in the client's importantStateEvents, or partially-loaded rooms drop it
/// and room packs silently vanish from the pickers.
const roomEmotesStateType = 'im.ponies.room_emotes';

/// Protea's pre-MSC2545 sticker pack store. Migrated into
/// [userEmotesAccountData] on first use and left empty so old sessions
/// don't resurrect it.
const legacyStickerPacksAccountData = 'energy.vgt.protea.sticker_packs';

/// The user's own MSC2545 image pack, parsed from account data.
ImagePackContent userStickerPack(Client client) =>
    client.accountData[userEmotesAccountData]?.parsedImagePackContent ??
    ImagePackContent.fromJson({});

/// Persists [pack] as the user's MSC2545 pack. The local account-data
/// cache is updated optimistically so reopening the picker shows the
/// change before the next sync echoes it back.
Future<void> saveUserStickerPack(Client client, ImagePackContent pack) async {
  final json = pack.toJson();
  await client.setAccountData(client.userID!, userEmotesAccountData, json);
  client.accountData[userEmotesAccountData] = BasicEvent(
    type: userEmotesAccountData,
    content: json,
  );
}

/// Whether [image] counts as a sticker under MSC2545 usage rules: an
/// image (or pack) without a usage list is both emote and sticker.
bool isStickerUsage(ImagePackContent pack, ImagePackImageContent image) {
  final usage = image.usage ?? pack.pack.usage;
  return usage == null || usage.contains(ImagePackUsage.sticker);
}

String _shortcodeFor(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^a-z0-9_-]'), '');
  return slug.isEmpty ? 'sticker' : slug;
}

/// Adds [image] to [pack] under a shortcode derived from [name], suffixing
/// on collision.
void addImageToPack(
  ImagePackContent pack,
  String name,
  ImagePackImageContent image,
) {
  final base = _shortcodeFor(name);
  var shortcode = base;
  var suffix = 2;
  while (pack.images.containsKey(shortcode)) {
    shortcode = '$base-${suffix++}';
  }
  pack.images[shortcode] = image;
}

/// One-time migration of the legacy proprietary sticker packs into the
/// MSC2545 user pack. No-op when the legacy key is empty or missing.
Future<void> migrateLegacyStickerPacks(Client client) async {
  final legacy = client.accountData[legacyStickerPacksAccountData]?.content;
  final legacyPacks = legacy?.tryGetList<Map<String, Object?>>('packs');
  if (legacyPacks == null || legacyPacks.isEmpty) return;
  // The merge overwrites im.ponies.user_emotes, so it must start from the
  // server's current version: wait for a sync so a pack another client
  // created while Protea was closed can't be clobbered by a stale copy.
  if (client.onSync.value == null) {
    await client.onSync.stream.first;
  }
  final pack = userStickerPack(client);
  for (final packJson in legacyPacks) {
    final stickers =
        packJson.tryGetList<Map<String, Object?>>('stickers') ?? const [];
    for (final stickerJson in stickers) {
      final name = stickerJson.tryGet<String>('name');
      final url = Uri.tryParse(stickerJson.tryGet<String>('url') ?? '');
      if (name == null || url == null || url.scheme != 'mxc') continue;
      if (pack.images.values.any((image) => image.url == url)) continue;
      addImageToPack(
        pack,
        name,
        ImagePackImageContent(
          url: url,
          body: name,
          info: stickerJson.tryGetMap<String, Object?>('info'),
          usage: [ImagePackUsage.sticker],
        ),
      );
    }
  }
  await saveUserStickerPack(client, pack);
  // Account data cannot be deleted, so the legacy key is left empty.
  await client.setAccountData(
    client.userID!,
    legacyStickerPacksAccountData,
    {},
  );
  client.accountData[legacyStickerPacksAccountData] = BasicEvent(
    type: legacyStickerPacksAccountData,
    content: {},
  );
}

/// The sticker picker as an embeddable panel (shown above the composer,
/// not as a popup); tapping a sticker sends it to [room], then [onClose]
/// fires. Shows every MSC2545 pack visible to the room: the user's own
/// pack, packs from subscribed emote rooms and this room's own packs.
class StickerPickerPanel extends StatefulWidget {
  const StickerPickerPanel({
    super.key,
    required this.room,
    required this.onClose,
  });

  final Room room;
  final VoidCallback onClose;

  @override
  State<StickerPickerPanel> createState() => _StickerPickerPanelState();
}

class _StickerPickerPanelState extends State<StickerPickerPanel> {
  var _packIndex = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Merges any pre-MSC2545 packs into the user pack; refreshes the grid
    // when that actually moved something.
    migrateLegacyStickerPacks(widget.room.client).then((_) {
      if (mounted) setState(() {});
    }, onError: (_) {});
  }

  Future<void> _send(String shortcode, ImagePackImageContent image) async {
    setState(() => _busy = true);
    try {
      await widget.room.sendEvent({
        'body': image.body ?? shortcode,
        'url': image.url.toString(),
        'info': image.info ?? <String, Object?>{},
      }, type: EventTypes.Sticker);
      if (mounted) widget.onClose();
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
    final packs = widget.room
        .getImagePacks(ImagePackUsage.sticker)
        .entries
        .toList();
    final packIndex = _packIndex.clamp(0, packs.isEmpty ? 0 : packs.length - 1);
    final images = packs.isEmpty
        ? const <MapEntry<String, ImagePackImageContent>>[]
        : packs[packIndex].value.images.entries.toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text(
                  context.l10n.stickers,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  tooltip: context.l10n.managePacks,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await showStickerPackManager(context, widget.room.client);
                    if (mounted) setState(() {});
                  },
                ),
                IconButton(
                  tooltip: context.l10n.close,
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
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
                        label: Text(
                          packs[i].value.pack.displayName ?? packs[i].key,
                        ),
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
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      context.l10n.noStickerPacksHint,
                      textAlign: TextAlign.center,
                    ),
                  )
                : images.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(context.l10n.packEmpty),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      final shortcode = images[index].key;
                      final image = images[index].value;
                      return Tooltip(
                        message: image.body ?? shortcode,
                        child: InkWell(
                          onTap: _busy ? null : () => _send(shortcode, image),
                          child: MxcImage(
                            client: widget.room.client,
                            uri: image.url,
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
    );
  }
}

/// Opens the manager for the user's own MSC2545 pack: add stickers
/// (uploaded from image files) and remove them. Room packs are managed by
/// their rooms, not here.
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
  late final ImagePackContent _pack = userStickerPack(widget.client);
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await saveUserStickerPack(widget.client, _pack);
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

  Future<void> _addSticker() async {
    final picked = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: context.l10n.images,
          extensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp'],
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
        addImageToPack(
          _pack,
          name,
          ImagePackImageContent(
            url: mxc,
            body: name,
            info: {'mimetype': picked.mimeType, 'size': bytes.length},
            usage: [ImagePackUsage.sticker],
          ),
        );
      });
      await _save();
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
    // Only images usable as stickers are shown; emote-only images stay in
    // the pack untouched.
    final stickers = _pack.images.entries
        .where((entry) => isStickerUsage(_pack, entry.value))
        .toList();
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
                    context.l10n.myStickers,
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
                    tooltip: context.l10n.close,
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
                padding: const EdgeInsets.all(16),
                children: [
                  if (stickers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        context.l10n.packEmpty,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in stickers)
                          Tooltip(
                            message: entry.value.body ?? entry.key,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: MxcImage(
                                    client: widget.client,
                                    uri: entry.value.url,
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
                                              () => _pack.images.remove(
                                                entry.key,
                                              ),
                                            );
                                            await _save();
                                          },
                                    child: const Icon(Icons.cancel, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _busy ? null : _addSticker,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(context.l10n.addSticker),
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
