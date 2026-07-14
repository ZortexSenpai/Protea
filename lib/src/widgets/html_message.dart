import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders the formatted (`org.matrix.custom.html`) body of a message:
/// bold, italic, strikethrough, code, quotes, lists and links.
class HtmlMessage extends StatelessWidget {
  const HtmlMessage({super.key, required this.html});

  final String html;

  /// Removes the quoted fallback block of rich replies; the bubble already
  /// renders its own reply preview.
  static String _stripReplyFallback(String html) => html.replaceFirst(
        RegExp(r'<mx-reply>.*?</mx-reply>', dotAll: true),
        '',
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Html(
      data: _stripReplyFallback(html),
      shrinkWrap: true,
      onLinkTap: (url, attributes, element) {
        if (url != null) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
        'p': Style(margin: Margins.zero),
        'code': Style(
          backgroundColor: colorScheme.surface.withValues(alpha: 0.5),
          fontFamily: 'monospace',
        ),
        'pre': Style(
          backgroundColor: colorScheme.surface.withValues(alpha: 0.5),
          padding: HtmlPaddings.all(8),
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
