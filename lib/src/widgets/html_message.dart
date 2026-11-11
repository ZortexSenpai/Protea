import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:highlight/highlight.dart' show Node, highlight;
import 'package:highlight/languages/all.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher.dart';

import '../emoji_shortcodes.dart';
import '../nicknames.dart';
import '../svg.dart';
import 'mxc_avatar.dart';
import 'user_profile_card.dart';

/// Render size for a message that is just one emoji or one custom emote.
const jumboEmojiSize = 48.0;

/// Extracts the user ID from a `matrix.to` or `matrix:` user link, or null
/// when the link points at anything else.
String? mentionUserId(String? href) {
  if (href == null) return null;
  final uri = Uri.tryParse(href);
  if (uri == null) return null;
  String? target;
  if (uri.host == 'matrix.to') {
    var fragment = uri.fragment;
    if (fragment.startsWith('/')) fragment = fragment.substring(1);
    try {
      target = Uri.decodeComponent(fragment);
    } on ArgumentError {
      return null;
    }
  } else if (uri.isScheme('matrix') && uri.path.startsWith('u/')) {
    target = '@${uri.path.substring(2)}';
  }
  if (target == null) return null;
  final query = target.indexOf('?');
  if (query != -1) target = target.substring(0, query);
  return target.startsWith('@') && target.contains(':') ? target : null;
}

/// Renders the formatted (`org.matrix.custom.html`) body of a message:
/// headings, bold, italic, strikethrough, quotes, lists, links, mention
/// pills and syntax-highlighted code blocks.
class HtmlMessage extends StatelessWidget {
  const HtmlMessage({super.key, required this.html, this.client, this.room});

  final String html;

  /// When set, `matrix.to` user links render as tappable mention pills that
  /// open the profile card.
  final Client? client;

  /// When set, profile cards opened from mention pills show the user's role
  /// in this room.
  final Room? room;

  /// Removes the quoted fallback block of rich replies; the bubble already
  /// renders its own reply preview.
  static String _stripReplyFallback(String html) =>
      html.replaceFirst(RegExp(r'<mx-reply>.*?</mx-reply>', dotAll: true), '');

  /// True when [html] (already stripped of the reply fallback) is nothing
  /// but a single custom emote, optionally wrapped in a paragraph.
  static bool _isSingleEmote(String html) => RegExp(
    r'^<img[^>]*data-mx-emoticon[^>]*>$',
  ).hasMatch(html.replaceAll(RegExp(r'</?p>'), '').trim());

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Style heading(double size) => Style(
      fontSize: FontSize(size),
      fontWeight: FontWeight.w700,
      margin: Margins.symmetric(vertical: 4),
    );
    final client = this.client;
    final data = _stripReplyFallback(html);
    // Jumbo: a message that is just one emoji or one custom emote renders
    // it large, like the plain-text message path does for bare emoji.
    final jumbo = data.contains('data-mx-emoticon')
        ? _isSingleEmote(data)
        : isSingleEmoji(data.replaceAll(RegExp(r'<[^>]*>'), ''));
    return Html(
      data: data,
      shrinkWrap: true,
      extensions: [
        if (client != null) _MentionExtension(client, room),
        if (client != null)
          _EmoticonExtension(client, size: jumbo ? jumboEmojiSize : 24),
        const _LinkExtension(),
        _SpoilerExtension(),
        _CodeBlockExtension(),
      ],
      onLinkTap: (url, attributes, element) {
        if (url != null) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: jumbo ? FontSize(jumboEmojiSize) : null,
        ),
        'p': Style(margin: Margins.zero),
        'h1': heading(26),
        'h2': heading(22),
        'h3': heading(19),
        'h4': heading(17),
        'h5': heading(15),
        'h6': heading(14),
        'ul': Style(margin: Margins.only(left: 4, top: 2, bottom: 2)),
        'ol': Style(margin: Margins.only(left: 4, top: 2, bottom: 2)),
        'code': Style(
          backgroundColor: colorScheme.surface.withValues(alpha: 0.5),
          fontFamily: 'monospace',
        ),
        'blockquote': Style(
          margin: Margins.only(left: 0, top: 4, bottom: 4),
          padding: HtmlPaddings.only(left: 8),
          border: Border(
            left: BorderSide(color: colorScheme.primary, width: 3),
          ),
        ),
        'a': Style(
          color: colorScheme.primary,
          textDecoration: TextDecoration.none,
        ),
      },
    );
  }
}

/// Replaces flutter_html's built-in `a` handler, which leaves the mouse
/// cursor as the default arrow; this one shows a click cursor on hover.
class _LinkExtension extends HtmlExtension {
  const _LinkExtension();

  @override
  Set<String> get supportedTags => {'a'};

  @override
  bool matches(ExtensionContext context) =>
      context.elementName == 'a' && context.attributes.containsKey('href');

  @override
  StyledElement prepare(
    ExtensionContext context,
    List<StyledElement> children,
  ) {
    return InteractiveElement(
      name: context.elementName,
      children: children,
      href: context.attributes['href'],
      style: Style(
        color: Colors.blue,
        textDecoration: TextDecoration.underline,
      ),
      node: context.node,
      elementId: context.id,
    );
  }

  @override
  InlineSpan build(ExtensionContext context) {
    void onTap() => context.parser.internalOnAnchorTap?.call(
      (context.styledElement! as InteractiveElement).href,
      context.attributes,
      context.element,
    );
    return TextSpan(
      children: context.inlineSpanChildren!
          .map((child) => _clickable(context, child, onTap))
          .toList(),
    );
  }

  InlineSpan _clickable(
    ExtensionContext context,
    InlineSpan child,
    VoidCallback onTap,
  ) {
    if (child is! TextSpan) {
      return WidgetSpan(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: (child as WidgetSpan).child,
          ),
        ),
      );
    }
    return TextSpan(
      text: child.text,
      children: child.children
          ?.map((span) => _clickable(context, span, onTap))
          .toList(),
      recognizer: TapGestureRecognizer()..onTap = onTap,
      mouseCursor: SystemMouseCursors.click,
      style: context.styledElement?.style.generateTextStyle() ?? child.style,
      semanticsLabel: child.semanticsLabel,
      locale: child.locale,
      spellOut: child.spellOut,
    );
  }
}

/// Renders `matrix.to`/`matrix:` user links as tappable mention pills that
/// open the profile card.
class _MentionExtension extends TagExtension {
  _MentionExtension(Client client, Room? room)
    : super(
        tagsToExtend: {'a'},
        builder: (extensionContext) {
          final userId = mentionUserId(extensionContext.attributes['href'])!;
          final text = extensionContext.element?.text.trim() ?? '';
          final nickname = nicknameOf(client, userId);
          return _MentionPill(
            client: client,
            room: room,
            userId: userId,
            label: nickname != null
                ? (text.startsWith('@') ? '@$nickname' : nickname)
                : text.isEmpty
                ? userId
                : text,
          );
        },
      );

  @override
  bool matches(ExtensionContext context) =>
      context.elementName == 'a' &&
      mentionUserId(context.attributes['href']) != null;
}

class _MentionPill extends StatelessWidget {
  const _MentionPill({
    required this.client,
    required this.room,
    required this.userId,
    required this.label,
  });

  final Client client;
  final Room? room;
  final String userId;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Mentions of the current user stand out more than other pills.
    final isSelf = userId == client.userID;
    return InkWell(
      onTap: () => showUserProfileCard(
        context,
        client: client,
        userId: userId,
        room: room,
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelf
              ? colorScheme.primary
              : colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelf ? colorScheme.onPrimary : colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Renders custom emotes (MSC2545: `<img data-mx-emoticon src="mxc://…">`,
/// as sent by Element, Commet or FluffyChat) inline at text height.
/// flutter_html's built-in image handler only understands http and data
/// URIs, so without this the emotes render as nothing at all.
class _EmoticonExtension extends TagExtension {
  _EmoticonExtension(Client client, {required double size})
    : super(
        tagsToExtend: {'img'},
        builder: (extensionContext) {
          final attributes = extensionContext.attributes;
          final alt = attributes['alt'] ?? attributes['title'] ?? '';
          final src = Uri.tryParse(attributes['src'] ?? '');
          // Never fetch non-mxc images: remote http images in messages
          // would leak the reader's IP to an arbitrary server.
          if (src == null || !src.isScheme('mxc')) return Text(alt);
          // Emotes are marked data-mx-emoticon; some older clients only
          // send a small height attribute. Other mxc images fall back to
          // their alt text.
          final height = int.tryParse(attributes['height'] ?? '');
          final isEmote =
              attributes.containsKey('data-mx-emoticon') ||
              (height != null && height <= 64);
          if (!isEmote) return Text(alt);
          return InlineEmote(client: client, uri: src, name: alt, size: size);
        },
      );
}

/// A custom emote image, with its shortcode as tooltip and as fallback
/// while loading or when the fetch fails. [size] is the display height:
/// text height normally, [jumboEmojiSize] in emote-only messages. Also
/// used by the reaction chips for custom emoji reactions (MSC4027).
class InlineEmote extends StatefulWidget {
  const InlineEmote({
    super.key,
    required this.client,
    required this.uri,
    required this.name,
    required this.size,
  });

  final Client client;
  final Uri uri;
  final String name;
  final double size;

  @override
  State<InlineEmote> createState() => _InlineEmoteState();
}

class _InlineEmoteState extends State<InlineEmote> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(InlineEmote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final uri = widget.uri;
    try {
      // The original file, not a thumbnail: thumbnailing loses animation
      // (Synapse ignores MSC2705's animated flag), and emotes are small.
      // On failure fall back to a static thumbnail, 2x the jumbo size so
      // both display sizes share one cache entry.
      final bytes =
          await fetchMxcOriginal(widget.client, uri) ??
          await fetchMxcThumbnail(
            widget.client,
            uri,
            width: jumboEmojiSize * 2,
            height: jumboEmojiSize * 2,
            method: ThumbnailMethod.scale,
          );
      // Discard stale results: the widget may have been recycled to
      // another emote while this fetch was in flight.
      if (bytes != null && mounted && widget.uri == uri) {
        setState(() => _bytes = bytes);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final image = bytes == null
        ? SizedBox.square(dimension: widget.size)
        : memoryImage(
            bytes,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (_) => Text(widget.name),
          );
    // No name, no tooltip: an empty tooltip renders as a bare hover bubble.
    if (widget.name.isEmpty) return image;
    return Tooltip(message: widget.name, child: image);
  }
}

/// Renders `<pre><code class="language-x">` blocks with syntax highlighting.
class _CodeBlockExtension extends TagExtension {
  _CodeBlockExtension()
    : super(
        tagsToExtend: {'pre'},
        builder: (extensionContext) {
          final element = extensionContext.element;
          final codeChild = element != null && element.children.isNotEmpty
              ? element.children.first
              : null;
          final code = (codeChild ?? element)?.text ?? '';
          final match = RegExp(
            r'language-([\w+#-]+)',
          ).firstMatch(codeChild?.className ?? '');
          return _CodeBlock(code: code.trimRight(), language: match?.group(1));
        },
      );
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, this.language});

  final String code;
  final String? language;

  /// Common fence names that differ from the highlight registry's keys
  /// (e.g. C# is registered as 'cs').
  static const _languageAliases = {
    'c#': 'cs',
    'csharp': 'cs',
    'c++': 'cpp',
    'c': 'cpp',
    'js': 'javascript',
    'jsx': 'javascript',
    'mjs': 'javascript',
    'ts': 'typescript',
    'tsx': 'typescript',
    'py': 'python',
    'sh': 'bash',
    'zsh': 'bash',
    'yml': 'yaml',
    'rs': 'rust',
    'kt': 'kotlin',
    'golang': 'go',
    'html': 'xml',
    'htm': 'xml',
    'docker': 'dockerfile',
    'md': 'markdown',
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = dark ? atomOneDarkTheme : atomOneLightTheme;
    final raw = language?.toLowerCase();
    final resolved = raw == null ? null : (_languageAliases[raw] ?? raw);
    final knownLanguage = resolved != null && allLanguages.containsKey(resolved)
        ? resolved
        : 'plaintext';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          color: theme['root']?.backgroundColor,
          // The code block sits in a WidgetSpan inside flutter_html's text
          // paragraphs; selection does not survive that nesting (nested
          // selection containers around a scrollable drop the events before
          // they reach the text). A selection scope of its own makes the
          // code selectable — independently of the surrounding message.
          child: SelectionContainer.disabled(
            child: SelectionArea(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  // Text.rich instead of flutter_highlight's HighlightView:
                  // its raw RichText never registers as selectable.
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: theme['root']?.color,
                      ),
                      children: _highlightSpans(code, knownLanguage, theme),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Syntax-highlighted spans for [code], mirroring HighlightView's
  /// node-to-span conversion.
  static List<TextSpan> _highlightSpans(
    String code,
    String language,
    Map<String, TextStyle> theme,
  ) {
    // Flutter renders tab characters poorly in monospace text; expand them
    // like HighlightView did.
    code = code.replaceAll('\t', ' ' * 8);
    List<TextSpan> convert(List<Node> nodes) => [
      for (final node in nodes)
        if (node.value != null)
          TextSpan(
            text: node.value,
            style: node.className == null ? null : theme[node.className],
          )
        else if (node.children != null)
          TextSpan(
            children: convert(node.children!),
            style: theme[node.className],
          ),
    ];
    return convert(highlight.parse(code, language: language).nodes ?? []);
  }
}

/// Renders `<span data-mx-spoiler>` as hidden text that reveals on click.
class _SpoilerExtension extends TagExtension {
  _SpoilerExtension()
    : super(
        tagsToExtend: {'span'},
        builder: (extensionContext) =>
            _SpoilerText(text: extensionContext.element?.text ?? ''),
      );

  @override
  bool matches(ExtensionContext context) =>
      context.elementName == 'span' &&
      context.attributes.containsKey('data-mx-spoiler');
}

class _SpoilerText extends StatefulWidget {
  const _SpoilerText({required this.text});

  final String text;

  @override
  State<_SpoilerText> createState() => _SpoilerTextState();
}

class _SpoilerTextState extends State<_SpoilerText> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _revealed = !_revealed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _revealed
              ? colorScheme.surface.withValues(alpha: 0.4)
              : colorScheme.onSurface,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          widget.text,
          style: TextStyle(color: _revealed ? null : Colors.transparent),
        ),
      ),
    );
  }
}
