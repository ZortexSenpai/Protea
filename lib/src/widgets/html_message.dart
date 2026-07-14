import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:highlight/languages/all.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders the formatted (`org.matrix.custom.html`) body of a message:
/// headings, bold, italic, strikethrough, quotes, lists, links and
/// syntax-highlighted code blocks.
class HtmlMessage extends StatelessWidget {
  const HtmlMessage({super.key, required this.html});

  final String html;

  /// Removes the quoted fallback block of rich replies; the bubble already
  /// renders its own reply preview.
  static String _stripReplyFallback(String html) =>
      html.replaceFirst(RegExp(r'<mx-reply>.*?</mx-reply>', dotAll: true), '');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Style heading(double size) => Style(
      fontSize: FontSize(size),
      fontWeight: FontWeight.w700,
      margin: Margins.symmetric(vertical: 4),
    );
    return Html(
      data: _stripReplyFallback(html),
      shrinkWrap: true,
      extensions: [_SpoilerExtension(), _CodeBlockExtension()],
      onLinkTap: (url, attributes, element) {
        if (url != null) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      style: {
        'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HighlightView(
              code,
              language: knownLanguage,
              theme: theme,
              padding: const EdgeInsets.all(10),
              textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
      ),
    );
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
