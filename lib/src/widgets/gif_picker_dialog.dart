import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../settings.dart';
import '../pages/settings_page.dart';

/// A GIF from the Klipy API: a small preview and the full-size file.
typedef PickedGif = ({String url, String previewUrl, String title});

/// Opens the GIF picker and returns the chosen GIF, or null.
Future<PickedGif?> showGifPicker(BuildContext context, Client client) =>
    showDialog<PickedGif>(
      context: context,
      builder: (_) => GifPickerDialog(client: client),
    );

class GifPickerDialog extends StatefulWidget {
  const GifPickerDialog({super.key, required this.client});

  final Client client;

  @override
  State<GifPickerDialog> createState() => _GifPickerDialogState();
}

class _GifPickerDialogState extends State<GifPickerDialog> {
  static const _baseUrl = 'https://api.klipy.com/api/v1';
  static const _perPage = 30;

  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  final List<PickedGif> _results = [];
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

  void _onScroll() {
    if (_loading || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetch(page: _page + 1, append: true);
    }
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetch(page: 1));
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
        String? urlOf(dynamic size) => size is Map<String, dynamic>
            ? (size['gif']?['url'] as String?)
            : null;
        final preview =
            urlOf(file['sm']) ?? urlOf(file['xs']) ?? urlOf(file['hd']);
        final full =
            urlOf(file['hd']) ?? (file['gif']?['url'] as String?) ?? preview;
        if (preview == null || full == null) continue;
        gifs.add((
          url: full,
          previewUrl: preview,
          title: (item['title'] as String?) ?? 'gif',
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

  Widget _buildMissingKey(BuildContext context) {
    final settings = SettingsScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gif_box_outlined, size: 48),
          const SizedBox(height: 12),
          const Text(
            'GIF search needs a free Klipy API key.\n'
            'Get one at klipy.com and add it in the settings.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              showSettingsDialog(
                context,
                client: widget.client,
                settings: settings,
              );
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = _apiKey.isNotEmpty;
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
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      autofocus: true,
                      enabled: hasKey,
                      decoration: const InputDecoration(
                        hintText: 'Search GIFs…',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: _onQueryChanged,
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
              child: !hasKey
                  ? _buildMissingKey(context)
                  : _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text('No GIFs found.'),
                    )
                  : GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                          ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final gif = _results[index];
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(gif),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              gif.previewUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Colors.black12,
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (hasKey && _loading && _results.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}
