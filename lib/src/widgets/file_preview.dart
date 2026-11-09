import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/languages/all.dart';
import 'package:matrix/matrix.dart';

import '../event_body.dart';
import '../l10n.dart';
import 'pdf_preview.dart';
import 'xlsx_preview.dart';

/// Text previews are skipped for files larger than this (they would have to
/// be downloaded in full just to render).
const _maxPreviewBytes = 300 * 1024;

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

String _filenameOf(Event event) => event.attachmentName;

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

/// Whether [event] is a text-based attachment small enough to preview.
bool _isTextPreviewable(Event event) {
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

/// The "eye" on a file chip: downloads the attachment on demand (cached)
/// and opens the matching full-screen viewer — syntax-highlighted text,
/// PDF or spreadsheet.
class FilePreviewButton extends StatefulWidget {
  const FilePreviewButton({super.key, required this.event, this.onSave});

  final Event event;

  /// Invoked by the viewer's save button (wired to the room's attachment
  /// saving flow).
  final VoidCallback? onSave;

  /// Whether [event] has a viewer to offer the button for.
  static bool isPreviewable(Event event) =>
      _isTextPreviewable(event) ||
      isPdfPreviewable(event) ||
      isXlsxPreviewable(event);

  @override
  State<FilePreviewButton> createState() => _FilePreviewButtonState();
}

class _FilePreviewButtonState extends State<FilePreviewButton> {
  /// Downloaded attachments by event id, so reopening does not re-download.
  static final _cache = <String, Uint8List>{};
  static const _maxCacheEntries = 10;

  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    var bytes = _cache[widget.event.eventId];
    if (bytes == null) {
      setState(() => _busy = true);
      try {
        final file = await widget.event.downloadAndDecryptAttachment();
        bytes = file.bytes;
        if (_cache.length >= _maxCacheEntries) {
          _cache.remove(_cache.keys.first);
        }
        _cache[widget.event.eventId] = bytes;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
          setState(() => _busy = false);
        }
        return;
      }
      if (!mounted) return;
      setState(() => _busy = false);
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (isPdfPreviewable(widget.event)) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => PdfViewerPage(
            title: _filenameOf(widget.event),
            bytes: bytes!,
            onSave: widget.onSave,
          ),
        ),
      );
      return;
    }
    if (isXlsxPreviewable(widget.event)) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => XlsxViewerPage(
            title: _filenameOf(widget.event),
            bytes: bytes!,
            onSave: widget.onSave,
          ),
        ),
      );
      return;
    }
    navigator.push(
      MaterialPageRoute(
        builder: (_) => TextFileViewerPage(
          title: _filenameOf(widget.event),
          text: utf8.decode(bytes!, allowMalformed: true),
          language: _languageFor(widget.event),
          onSave: widget.onSave,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.openPreview,
      onPressed: _busy ? null : _open,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.visibility_outlined),
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
