import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../motion.dart';
import '../settings.dart';
import '../pages/settings_page.dart';

/// A GIF from the Klipy API: a small preview, the full-size file and the
/// width/height ratio (1 when unknown).
typedef PickedGif = ({
  String url,
  String previewUrl,
  String title,
  double ratio,
  // Dimensions and byte size of [url], when the provider reported them. They
  // travel in the event when the GIF is sent through the proxy, since nothing
  // downloads the file to measure it.
  int? width,
  int? height,
  int? size,
});

/// Account-data type storing the user's favorite GIFs (the star button in
/// the picker, Discord-style). Favorites sync between Protea sessions via
/// account data, like sticker packs.
const favoriteGifsAccountData = 'energy.vgt.protea.favorite_gifs';

List<PickedGif> loadFavoriteGifs(Client client) {
  final content = client.accountData[favoriteGifsAccountData]?.content;
  final raw = content?.tryGetList<Map<String, Object?>>('gifs') ?? [];
  final gifs = <PickedGif>[];
  for (final json in raw) {
    final url = json.tryGet<String>('url');
    if (url == null) continue;
    final ratio = json.tryGet<num>('ratio')?.toDouble();
    int? intOf(String key) {
      final value = json.tryGet<num>(key);
      return value == null || value <= 0 ? null : value.toInt();
    }

    gifs.add((
      url: url,
      previewUrl: json.tryGet<String>('preview_url') ?? url,
      title: json.tryGet<String>('title') ?? 'gif',
      // Favorites saved by older builds carry no ratio; show them square.
      ratio: ratio == null || ratio <= 0 ? 1.0 : ratio,
      width: intOf('w'),
      height: intOf('h'),
      size: intOf('size'),
    ));
  }
  return gifs;
}

Future<void> saveFavoriteGifs(Client client, List<PickedGif> gifs) =>
    client.setAccountData(client.userID!, favoriteGifsAccountData, {
      'gifs': [
        for (final gif in gifs)
          {
            'url': gif.url,
            'preview_url': gif.previewUrl,
            'title': gif.title,
            'ratio': gif.ratio,
            'w': ?gif.width,
            'h': ?gif.height,
            'size': ?gif.size,
          },
      ],
    });

enum _GifView { trending, favorites }

/// The GIF picker as an embeddable panel (shown above the composer, not as
/// a popup): [onPicked] fires with the chosen GIF, [onClose] when the user
/// dismisses the panel.
class GifPickerPanel extends StatefulWidget {
  const GifPickerPanel({
    super.key,
    required this.client,
    required this.onPicked,
    required this.onClose,
  });

  final Client client;
  final ValueChanged<PickedGif> onPicked;
  final VoidCallback onClose;

  @override
  State<GifPickerPanel> createState() => _GifPickerPanelState();
}

class _GifPickerPanelState extends State<GifPickerPanel> {
  static const _baseUrl = 'https://api.klipy.com/api/v1';
  static const _perPage = 30;

  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  final List<PickedGif> _results = [];
  late final List<PickedGif> _favorites = loadFavoriteGifs(widget.client);
  var _view = _GifView.trending;
  var _page = 1;
  var _hasMore = true;
  var _loading = false;
  var _fetchVersion = 0;
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _scrollController.addListener(_onScroll);
      if (_apiKey.isEmpty && _favorites.isNotEmpty) {
        // Favorites work without a Klipy key; start there instead of on
        // the key hint when there is something to show.
        _view = _GifView.favorites;
      }
      _fetch(page: 1);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _apiKey => SettingsScope.of(context).klipyApiKey.trim();

  bool get _searching => _queryController.text.trim().isNotEmpty;

  void _onScroll() {
    if (_loading || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetch(page: _page + 1, append: true);
    }
  }

  void _onQueryChanged(String _) {
    // Entering or leaving search mode swaps the grid immediately; results
    // for the new query arrive after the debounce.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetch(page: 1));
  }

  void _selectView(_GifView view) {
    _debounce?.cancel();
    setState(() {
      _view = view;
      _queryController.clear();
    });
    if (view == _GifView.trending && _results.isEmpty) _fetch(page: 1);
  }

  bool _isFavorite(PickedGif gif) =>
      _favorites.any((favorite) => favorite.url == gif.url);

  Future<void> _toggleFavorite(PickedGif gif) async {
    setState(() {
      final index = _favorites.indexWhere(
        (favorite) => favorite.url == gif.url,
      );
      if (index >= 0) {
        _favorites.removeAt(index);
      } else {
        // Newest first, like Discord.
        _favorites.insert(0, gif);
      }
    });
    try {
      await saveFavoriteGifs(widget.client, _favorites);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _fetch({required int page, bool append = false}) async {
    final apiKey = _apiKey;
    if (apiKey.isEmpty) return;
    final version = ++_fetchVersion;
    setState(() => _loading = true);
    try {
      final query = _queryController.text.trim();
      final endpoint = query.isEmpty
          ? '$_baseUrl/$apiKey/gifs/trending?per_page=$_perPage&page=$page'
          : '$_baseUrl/$apiKey/gifs/search'
                '?q=${Uri.encodeQueryComponent(query)}'
                '&per_page=$_perPage&page=$page';
      final response = await widget.client.httpClient.get(Uri.parse(endpoint));
      if (!mounted || version != _fetchVersion) return;
      if (response.statusCode != 200) {
        throw Exception('Klipy returned HTTP ${response.statusCode}');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items =
          ((json['data'] as Map<String, dynamic>?)?['data'] as List?) ??
          const [];
      final gifs = <PickedGif>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final file = item['file'];
        if (file is! Map<String, dynamic>) continue;
        // Klipy serves each size as a bag of encodings; only the gif one
        // is of interest, with the dimensions and size that come with it.
        ({String url, int? width, int? height, int? size})? fileOf(
          dynamic variant,
        ) {
          if (variant is! Map<String, dynamic>) return null;
          final gif = variant['gif'];
          if (gif is! Map<String, dynamic>) return null;
          final url = gif['url'];
          if (url is! String || url.isEmpty) return null;
          int? intOf(Object? value) =>
              value is num && value > 0 ? value.toInt() : null;
          return (
            url: url,
            width: intOf(gif['width']),
            height: intOf(gif['height']),
            size: intOf(gif['size']),
          );
        }

        final preview =
            fileOf(file['sm']) ?? fileOf(file['xs']) ?? fileOf(file['hd']);
        // The md variant keeps sends fast — hd GIFs are several MB that
        // would be downloaded from Klipy and re-uploaded to the
        // homeserver — while still looking sharp at timeline size.
        final full =
            fileOf(file['md']) ?? fileOf(file['hd']) ?? fileOf(file) ?? preview;
        if (preview == null || full == null) continue;
        final ratioSource = preview.width != null && preview.height != null
            ? preview
            : full;
        gifs.add((
          url: full.url,
          previewUrl: preview.url,
          title: (item['title'] as String?) ?? 'gif',
          ratio: ratioSource.width != null && ratioSource.height != null
              ? ratioSource.width! / ratioSource.height!
              : 1.0,
          width: full.width,
          height: full.height,
          size: full.size,
        ));
      }
      setState(() {
        if (!append) _results.clear();
        _results.addAll(gifs);
        _page = page;
        _hasMore = gifs.length == _perPage;
      });
    } catch (e) {
      if (mounted && version == _fetchVersion) {
        setState(() => _hasMore = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted && version == _fetchVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildHint({
    required IconData icon,
    required String text,
    Widget? action,
  }) {
    // Scrollable so the hint also fits the height-capped composer panel.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<PickedGif> gifs, {ScrollController? controller}) {
    // Two-column masonry, each GIF at its own aspect ratio instead of
    // cropped into a square cell. Every GIF goes to the currently shorter
    // column; deterministic over the (append-only) list, so rebuilds and
    // pagination keep existing tiles in place.
    const columnCount = 2;
    final columns = List.generate(columnCount, (_) => <PickedGif>[]);
    final heights = List.filled(columnCount, 0.0);
    for (final gif in gifs) {
      var target = 0;
      for (var i = 1; i < columnCount; i++) {
        if (heights[i] < heights[target]) target = i;
      }
      columns[target].add(gif);
      // Relative height at equal column width.
      heights[target] += 1 / gif.ratio;
    }
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < columnCount; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  for (final gif in columns[i])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AspectRatio(
                        aspectRatio: gif.ratio,
                        child: _GifTile(
                          gif: gif,
                          favorite: _isFavorite(gif),
                          onPick: () => widget.onPicked(gif),
                          onToggleFavorite: () => _toggleFavorite(gif),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemote(BuildContext context) {
    if (_apiKey.isEmpty) {
      final settings = SettingsScope.of(context);
      return _buildHint(
        icon: Icons.gif_box_outlined,
        text: context.l10n.gifSearchNeedsKlipyKey,
        action: FilledButton(
          onPressed: () {
            widget.onClose();
            showSettingsDialog(
              context,
              client: widget.client,
              settings: settings,
            );
          },
          child: Text(context.l10n.openSettings),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _loading
              ? const CircularProgressIndicator()
              : Text(context.l10n.noGifsFound),
        ),
      );
    }
    return _buildGrid(_results, controller: _scrollController);
  }

  Widget _buildFavorites(BuildContext context) {
    if (_favorites.isEmpty) {
      return _buildHint(
        icon: Icons.star_outline_rounded,
        text: context.l10n.noFavoriteGifsHint,
      );
    }
    return _buildGrid(_favorites);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasKey = _apiKey.isNotEmpty;
    final showFavorites = !_searching && _view == _GifView.favorites;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text(l10n.gifs, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  tooltip: l10n.close,
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _queryController,
              autofocus: hasKey,
              enabled: hasKey,
              decoration: InputDecoration(
                hintText: l10n.searchGifs,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(l10n.trending),
                    selected: !_searching && _view == _GifView.trending,
                    onSelected: (_) => _selectView(_GifView.trending),
                  ),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.star_rounded, size: 18),
                  label: Text(l10n.favorites),
                  selected: showFavorites,
                  onSelected: (_) => _selectView(_GifView.favorites),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Flexible(
            // Cross-fade between the favorites grid and the remote
            // (trending/search) grid, like the app's other pane switches.
            child: PaneSwitcher(
              child: KeyedSubtree(
                key: ValueKey(showFavorites),
                child: showFavorites
                    ? _buildFavorites(context)
                    : _buildRemote(context),
              ),
            ),
          ),
          if (!showFavorites && hasKey && _loading && _results.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}

/// One GIF in the grid: the preview fades in when loaded, and hovering
/// reveals a star button to add or remove it from the favorites (a
/// long-press toggles it on touch screens).
class _GifTile extends StatefulWidget {
  const _GifTile({
    required this.gif,
    required this.favorite,
    required this.onPick,
    required this.onToggleFavorite,
  });

  final PickedGif gif;
  final bool favorite;
  final VoidCallback onPick;
  final VoidCallback onToggleFavorite;

  @override
  State<_GifTile> createState() => _GifTileState();
}

class _GifTileState extends State<_GifTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colorScheme.surfaceContainerHigh),
            Image.network(
              widget.gif.previewUrl,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: Motion.quick,
                  child: child,
                );
              },
              errorBuilder: (_, _, _) =>
                  Icon(Icons.broken_image_outlined, color: colorScheme.outline),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onPick,
                onLongPress: widget.onToggleFavorite,
              ),
            ),
            if (_hovered || widget.favorite)
              Positioned(
                top: 4,
                right: 4,
                child: FadeIn(
                  child: IconButton(
                    tooltip: widget.favorite
                        ? l10n.removeFromFavorites
                        : l10n.addToFavorites,
                    onPressed: widget.onToggleFavorite,
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      // Fixed scrim colors: the button sits on the image,
                      // not on a themed surface.
                      backgroundColor: Colors.black45,
                      foregroundColor: widget.favorite
                          ? Colors.amber
                          : Colors.white,
                      minimumSize: const Size(28, 28),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      widget.favorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
