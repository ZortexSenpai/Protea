import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:pdfrx/pdfrx.dart';

import '../l10n.dart';

/// PDFs larger than this are not downloaded automatically for a preview.
const _maxPdfPreviewBytes = 20 * 1024 * 1024;

bool _isPdf(Event event) {
  if (event.infoMap['mimetype'] == 'application/pdf') return true;
  final filename = event.content.tryGet<String>('filename') ?? event.body;
  return filename.toLowerCase().endsWith('.pdf');
}

/// Inline first-page preview of a PDF attachment; tapping opens the full
/// document viewer.
class PdfFilePreview extends StatefulWidget {
  const PdfFilePreview({super.key, required this.event, this.onSave});

  final Event event;
  final VoidCallback? onSave;

  /// Whether [event] is a PDF small enough to preview.
  static bool isPreviewable(Event event) {
    final size = event.infoMap['size'];
    return size is int && size <= _maxPdfPreviewBytes && _isPdf(event);
  }

  @override
  State<PdfFilePreview> createState() => _PdfFilePreviewState();
}

class _PdfFilePreviewState extends State<PdfFilePreview> {
  /// Downloaded documents by event id, so scrolling does not re-download.
  static final _cache = <String, Uint8List>{};
  static const _maxCacheEntries = 10;

  Uint8List? _bytes;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PdfFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.eventId != widget.event.eventId) {
      _bytes = null;
      _error = false;
      _load();
    }
  }

  Future<void> _load() async {
    final cached = _cache[widget.event.eventId];
    if (cached != null) {
      _bytes = cached;
      return;
    }
    try {
      final file = await widget.event.downloadAndDecryptAttachment();
      if (_cache.length >= _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      _cache[widget.event.eventId] = file.bytes;
      if (mounted) setState(() => _bytes = file.bytes);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  String get _filename =>
      widget.event.content.tryGet<String>('filename') ?? widget.event.body;

  void _openViewer() {
    final bytes = _bytes;
    if (bytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          title: _filename,
          bytes: bytes,
          onSave: widget.onSave,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final bytes = _bytes;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 200,
          height: 260,
          child: bytes == null
              ? Container(
                  color: colorScheme.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Material(
                  color: colorScheme.surfaceContainerHigh,
                  child: InkWell(
                    onTap: _openViewer,
                    child: IgnorePointer(
                      child: PdfDocumentViewBuilder(
                        documentRef: PdfDocumentRefData(
                          bytes,
                          sourceName: widget.event.eventId,
                        ),
                        builder: (context, document) => document == null
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : PdfPageView(document: document, pageNumber: 1),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Full-screen PDF viewer with copyable title bar actions.
class PdfViewerPage extends StatelessWidget {
  const PdfViewerPage({
    super.key,
    required this.title,
    required this.bytes,
    this.onSave,
  });

  final String title;
  final Uint8List bytes;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (onSave != null)
            IconButton(
              tooltip: context.l10n.saveFile,
              icon: const Icon(Icons.download_outlined),
              onPressed: onSave,
            ),
        ],
      ),
      body: PdfViewer.data(
        bytes,
        sourceName: title,
        params: const PdfViewerParams(),
      ),
    );
  }
}
