import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../settings.dart';
import '../site_previews.dart';
import 'linkified_text.dart';
import 'mxc_avatar.dart';

/// Preview card for the first link in a message: the site's own rich card
/// for common sites (see [PreviewSite], each switchable in the settings),
/// otherwise the homeserver's `preview_url` scrape.
class LinkPreview extends StatefulWidget {
  const LinkPreview({super.key, required this.client, required this.url});

  final Client client;
  final String url;

  /// The first http(s) link in [text], or null.
  static String? firstLinkOf(String text) =>
      webLinkPattern.firstMatch(text)?.group(0);

  @override
  State<LinkPreview> createState() => _LinkPreviewState();
}

class _LinkPreviewState extends State<LinkPreview> {
  /// Finished loads by key; a null value means "nothing to show". Kept
  /// synchronously so a bubble scrolled back into view lays out with its card
  /// at once instead of popping it in a frame later.
  static final _resolved = <String, Embed?>{};

  /// Loads in flight, shared by every bubble showing the same link.
  static final _pending = <String, Future<Embed?>>{};
  static const _maxCacheEntries = 200;
  static final _http = http.Client();

  String? _key;
  Embed? _embed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also runs when a setting changes, so switching a site off or on
    // swaps the card.
    _resolve();
  }

  @override
  void didUpdateWidget(LinkPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve();
  }

  void _resolve() {
    final url = widget.url;
    final uri = Uri.tryParse(url);
    final match = uri == null ? null : PreviewSite.of(uri);
    final site =
        match != null && SettingsScope.of(context).sitePreviewEnabled(match)
        ? match
        : null;
    final key = '${site?.name ?? '-'} $url';
    if (key == _key) return;
    _key = key;
    if (_resolved.containsKey(key)) {
      _embed = _resolved[key];
      return;
    }
    _embed = null;
    final client = widget.client;
    final load = _pending[key] ??=
        loadEmbed(
          url,
          site: site,
          client: _http,
          homeserver: () async =>
              (await client.getUrlPreviewAuthed(Uri.parse(url))).toJson(),
        ).then((embed) {
          _pending.remove(key);
          if (_resolved.length >= _maxCacheEntries) {
            _resolved.remove(_resolved.keys.first);
          }
          return _resolved[key] = embed;
        });
    load.then((embed) {
      if (mounted && _key == key) setState(() => _embed = embed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final embed = _embed;
    if (embed == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: EmbedCard(embed: embed, client: widget.client),
    );
  }
}

/// A Discord-style embed: accent bar on the left, site and author lines,
/// title, description, facts, and the image either large underneath or as a
/// thumbnail beside the text. Tapping it opens the link.
class EmbedCard extends StatelessWidget {
  const EmbedCard({super.key, required this.embed, required this.client});

  final Embed embed;

  /// Loads `mxc://` images re-hosted by the homeserver.
  final Client client;

  static const maxWidth = 432.0;
  static const _thumbnailSize = 80.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final muted = colors.onSurfaceVariant;
    final image = embed.image;
    final thumbnail = image?.layout == EmbedImageLayout.thumbnail
        ? image
        : null;
    final large = image?.layout == EmbedImageLayout.large ? image : null;
    final footer =
        embed.footer ??
        switch (embed.timestamp) {
          final timestamp? => DateFormat.yMMMd().add_Hm().format(
            timestamp.toLocal(),
          ),
          null => null,
        };

    final details = <Widget>[
      if (embed.siteName case final siteName?)
        Text(
          siteName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(color: muted),
        ),
      if (embed.author case final author?)
        _LinkText(
          author,
          url: embed.authorUrl,
          style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      if (embed.title case final title?)
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      if (embed.description case final description?)
        Text(
          description,
          // Posts are the whole point of their card; page blurbs are not.
          maxLines: embed.title == null ? 8 : 4,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: colors.onSurface),
        ),
      if (embed.stats.isNotEmpty)
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [for (final stat in embed.stats) _StatChip(stat)],
        ),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Material(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
          child: InkWell(
            onTap: () => _open(embed.url),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: embed.color ?? colors.outline,
                    width: 4,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            spacing: 4,
                            children: details,
                          ),
                        ),
                        if (thumbnail != null) ...[
                          const SizedBox(width: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox.square(
                              dimension: _thumbnailSize,
                              child: _EmbedImageView(
                                image: thumbnail,
                                client: client,
                                logicalWidth: _thumbnailSize,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (large != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: AspectRatio(
                              aspectRatio: large.aspectRatio ?? 16 / 9,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _EmbedImageView(
                                    image: large,
                                    client: client,
                                    logicalWidth: maxWidth,
                                  ),
                                  if (large.video) const _PlayBadge(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (footer != null)
                      Text(
                        footer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(color: muted),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _open(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Text that opens [url] when tapped (inside the card, which opens the
/// previewed link everywhere else).
class _LinkText extends StatelessWidget {
  const _LinkText(this.text, {required this.url, this.style});

  final String text;
  final String? url;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    final url = this.url;
    if (url == null) return label;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: () => _open(url), child: label),
    );
  }
}

class _EmbedImageView extends StatelessWidget {
  const _EmbedImageView({
    required this.image,
    required this.client,
    required this.logicalWidth,
  });

  final EmbedImage image;
  final Client client;

  /// The widest it is drawn, to decode no bigger than needed.
  final double logicalWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pixels = (logicalWidth * MediaQuery.devicePixelRatioOf(context))
        .round();
    if (image.uri.scheme == 'mxc') {
      final thumbnail = image.layout == EmbedImageLayout.thumbnail;
      return MxcImage(
        client: client,
        uri: image.uri,
        thumbnailWidth: pixels,
        thumbnailHeight: thumbnail ? pixels : (pixels * 0.75).round(),
        thumbnailMethod: thumbnail
            ? ThumbnailMethod.crop
            : ThumbnailMethod.scale,
      );
    }
    return ColoredBox(
      color: colors.surfaceContainerHigh,
      child: Image.network(
        image.uri.toString(),
        fit: BoxFit.cover,
        cacheWidth: pixels,
        errorBuilder: (_, _, _) => Center(
          child: Icon(Icons.broken_image_outlined, color: colors.outline),
        ),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.stat);

  final EmbedStat stat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // GitHub's own state colors, from its light or dark palette.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final open = Color(dark ? 0xFF3FB950 : 0xFF1A7F37);
    final done = Color(dark ? 0xFFAB7DF8 : 0xFF8250DF);
    final declined = Color(dark ? 0xFFF85149 : 0xFFCF222E);
    final (icon, color, label) = switch (stat.kind) {
      EmbedStatKind.stars => (Icons.star_border_rounded, muted, stat.value),
      EmbedStatKind.forks => (Icons.call_split_rounded, muted, stat.value),
      EmbedStatKind.language => (Icons.code_rounded, muted, stat.value),
      EmbedStatKind.comments => (
        Icons.chat_bubble_outline_rounded,
        muted,
        stat.value,
      ),
      EmbedStatKind.duration => (Icons.schedule_rounded, muted, stat.value),
      EmbedStatKind.issueOpen => (
        Icons.radio_button_checked_rounded,
        open,
        l10n.embedStateOpen,
      ),
      EmbedStatKind.issueClosed => (
        Icons.check_circle_outline_rounded,
        done,
        l10n.embedStateClosed,
      ),
      EmbedStatKind.issueNotPlanned => (
        Icons.block_rounded,
        muted,
        l10n.embedStateClosed,
      ),
      EmbedStatKind.pullOpen => (
        Icons.merge_type_rounded,
        open,
        l10n.embedStateOpen,
      ),
      EmbedStatKind.pullDraft => (
        Icons.merge_type_rounded,
        muted,
        l10n.embedStateDraft,
      ),
      EmbedStatKind.pullMerged => (
        Icons.merge_rounded,
        done,
        l10n.embedStateMerged,
      ),
      EmbedStatKind.pullClosed => (
        Icons.merge_type_rounded,
        declined,
        l10n.embedStateClosed,
      ),
    };
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Icon(icon, size: 14, color: color),
        if (label != null)
          Text(
            label,
            style: color == muted ? style : style?.copyWith(color: color),
          ),
      ],
    );
  }
}
