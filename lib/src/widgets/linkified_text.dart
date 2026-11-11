import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A web link in plain text, without trailing punctuation ("see
/// https://example.com." links to example.com).
final webLinkPattern = RegExp(
  r'''https?://[^\s<>()\[\]{}]+[^\s<>()\[\]{}.,;:!?"']''',
);

/// Plain message text with tappable web links (formatted messages get this
/// from the HTML renderer instead).
class LinkifiedText extends StatefulWidget {
  const LinkifiedText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final _recognizers = <TapGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final matches = webLinkPattern.allMatches(text).toList();
    if (matches.isEmpty) return Text(text, style: widget.style);
    _disposeRecognizers();
    final colorScheme = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in matches) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(color: colorScheme.primary),
          recognizer: recognizer,
        ),
      );
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
