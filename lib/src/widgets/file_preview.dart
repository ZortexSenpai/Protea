import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/languages/all.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';

/// Auto-preview is skipped for files larger than this (they would have to
/// be downloaded in full just to render a snippet).
const _maxPreviewBytes = 300 * 1024;

/// Lines shown inline before the preview is truncated.
const _previewLineCount = 12;

const _textExtensions = {
  'bash',
  'c',
  'cc',
  'cfg',
  'conf',
  'cpp',
  'cs',
  'css',
  'csv',
  'dart',
  'dockerfile',
  'env',
  'go',
  'gradle',
  'h',
  'hpp',
  'htm',
  'html',
  'ini',
  'java',
  'js',
  'json',
  'jsx',
  'kt',
  'log',
  'lua',
  'makefile',
  'markdown',
  'md',
  'php',
  'pl',
  'properties',
  'py',
  'r',
  'rb',
  'rs',
  'sh',
  'sql',
  'swift',
  'tex',
  'toml',
  'ts',
  'tsx',
  'txt',
  'xml',
  'yaml',
  'yml',
  'zsh',
};

/// Common fence names that differ from the highlight registry's keys.
const _languageAliases = {
  'cs': 'cs',
  'c': 'cpp',
  'h': 'cpp',
  'hpp': 'cpp',
  'cc': 'cpp',
  'js': 'javascript',
  'jsx': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'py': 'python',
  'sh': 'bash',
  'zsh': 'bash',
  'yml': 'yaml',
  'rs': 'rust',
  'kt': 'kotlin',
  'md': 'markdown',
  'html': 'xml',
  'htm': 'xml',
  'log': 'plaintext',
  'txt': 'plaintext',
  'csv': 'plaintext',
  'env': 'bash',
  'conf': 'ini',
  'cfg': 'ini',
  'toml': 'ini',
  'properties': 'ini',
};

String _filenameOf(Event event) =>
    event.content.tryGet<String>('filename') ?? event.body;

String? _extensionOf(Event event) {
  final filename = _filenameOf(event).toLowerCase();
  final dot = filename.lastIndexOf('.');
  if (dot == -1 || dot == filename.length - 1) {
    // Extensionless well-known names like 'Dockerfile' or 'Makefile'.
    return _textExtensions.contains(filename) ? filename : null;
  }
  return filename.substring(dot + 1);
}

String _languageFor(Event event) {
  final extension = _extensionOf(event) ?? 'txt';
  final resolved = _languageAliases[extension] ?? extension;
  return allLanguages.containsKey(resolved) ? resolved : 'plaintext';
}

/// Inline preview of a text-based file attachment: the first few lines,
/// syntax highlighted; tapping opens the full content in a viewer page.
class TextFilePreview extends StatefulWidget {
  const TextFilePreview({super.key, required this.event, this.onSave});

  final Event event;

  /// Invoked by the viewer's save button (wired to the room's attachment
  /// saving flow).
  final VoidCallback? onSave;

  /// Whether [event] is a text-based attachment small enough to preview.
  static bool isPreviewable(Event event) {
    final size = event.infoMap['size'];
    if (size is! int || size > _maxPreviewBytes) return false;
    final mime = event.infoMap['mimetype'];
    if (mime is String &&
        (mime.startsWith('text/') ||
            mime == 'application/json' ||
            mime == 'application/xml' ||
            mime == 'application/x-yaml' ||
            mime == 'application/yaml' ||
            mime == 'application/toml')) {
      return true;
    }
    final extension = _extensionOf(event);
    return extension != null && _textExtensions.contains(extension);
  }

  @override
  State<TextFilePreview> createState() => _TextFilePreviewState();
}

class _TextFilePreviewState extends State<TextFilePreview> {
  /// Decoded file contents by event id, so scrolling does not re-download.
  static final _cache = <String, String>{};
  static const _maxCacheEntries = 50;

  String? _text;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TextFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.eventId != widget.event.eventId) {
      _text = null;
      _error = false;
      _load();
    }
  }

  Future<void> _load() async {
    final cached = _cache[widget.event.eventId];
    if (cached != null) {
      _text = cached;
      return;
    }
    try {
      final file = await widget.event.downloadAndDecryptAttachment();
      final text = utf8.decode(file.bytes, allowMalformed: true);
      if (_cache.length >= _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      _cache[widget.event.eventId] = text;
      if (mounted) setState(() => _text = text);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _openViewer() {
    final text = _text;
    if (text == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextFileViewerPage(
          title: _filenameOf(widget.event),
          text: text,
          language: _languageFor(widget.event),
          onSave: widget.onSave,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return const SizedBox.shrink();
    final text = _text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = dark ? atomOneDarkTheme : atomOneLightTheme;
    final background = theme['root']?.backgroundColor;
    if (text == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          height: 48,
          width: 320,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final lines = const LineSplitter().convert(text);
    final truncated = lines.length > _previewLineCount;
    final snippet = lines.take(_previewLineCount).join('\n');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: background,
            child: InkWell(
              onTap: _openViewer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: HighlightView(
                      truncated ? '$snippet\n…' : snippet,
                      language: _languageFor(widget.event),
                      theme: theme,
                      padding: const EdgeInsets.all(10),
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen viewer for a text attachment with copy and save actions.
class TextFileViewerPage extends StatelessWidget {
  const TextFileViewerPage({
    super.key,
    required this.title,
    required this.text,
    required this.language,
    this.onSave,
  });

  final String title;
  final String text;
  final String language;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = dark ? atomOneDarkTheme : atomOneLightTheme;
    return Scaffold(
      backgroundColor: theme['root']?.backgroundColor,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: context.l10n.copy,
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.copiedToClipboard)),
              );
            },
          ),
          if (onSave != null)
            IconButton(
              tooltip: context.l10n.saveFile,
              icon: const Icon(Icons.download_outlined),
              onPressed: onSave,
            ),
        ],
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HighlightView(
              text,
              language: language,
              theme: theme,
              padding: const EdgeInsets.all(16),
              textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
