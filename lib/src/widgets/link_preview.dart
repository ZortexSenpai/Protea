import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mxc_avatar.dart';

/// Compact URL preview card for the first link in a message, using the
/// homeserver's `preview_url` endpoint (with an in-memory cache).
class LinkPreview extends StatefulWidget {
  const LinkPreview({super.key, required this.client, required this.url});

  final Client client;
  final String url;

  /// The first http(s) link in [text], or null.
  static String? firstLinkOf(String text) =>
      RegExp(r'https?://[^\s<>()"]+').firstMatch(text)?.group(0);

  @override
  State<LinkPreview> createState() => _LinkPreviewState();
}

class _LinkPreviewState extends State<LinkPreview> {
  /// url → preview; null means "failed / none", missing key means unknown.
  static final _cache = <String, PreviewForUrl?>{};
  static const _maxCacheEntries = 200;

  PreviewForUrl? _preview;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LinkPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _preview = null;
      _loaded = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (_cache.containsKey(widget.url)) {
      _preview = _cache[widget.url];
      _loaded = true;
      return;
    }
    PreviewForUrl? preview;
    try {
      preview = await widget.client.getUrlPreviewAuthed(Uri.parse(widget.url));
    } catch (_) {
      preview = null;
    }
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[widget.url] = preview;
    if (mounted) {
      setState(() {
        _preview = preview;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    if (!_loaded || preview == null) return const SizedBox.shrink();
    final title = preview.additionalProperties['og:title'] as String?;
    final description =
        preview.additionalProperties['og:description'] as String?;
    final siteName = preview.additionalProperties['og:site_name'] as String?;
    if (title == null && description == null && preview.ogImage == null) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => launchUrl(
          Uri.parse(widget.url),
          mode: LaunchMode.externalApplication,
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (preview.ogImage != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: MxcImage(
                      client: widget.client,
                      uri: preview.ogImage!,
                      thumbnailWidth: 112,
                      thumbnailHeight: 112,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      siteName ?? Uri.parse(widget.url).host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (title != null)
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (description != null)
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
