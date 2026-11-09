import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';
import 'package:pdfrx/pdfrx.dart';

import '../event_body.dart';
import '../l10n.dart';

/// PDFs larger than this are not offered for preview.
const _maxPdfPreviewBytes = 20 * 1024 * 1024;

/// Whether [event] is a PDF attachment small enough to preview.
///
/// The renderer only ever runs inside the pushed [PdfViewerPage]: pdfrx
/// widgets inside the timeline crash Flutter 3.44's semantics pipeline when
/// the surrounding bubble churns (hover, syncs).
bool isPdfPreviewable(Event event) {
  final size = event.infoMap['size'];
  if (size is! int || size > _maxPdfPreviewBytes) return false;
  if (event.infoMap['mimetype'] == 'application/pdf') return true;
  final filename = event.attachmentName;
  return filename.toLowerCase().endsWith('.pdf');
}

/// Full-screen PDF viewer with copyable title bar actions.
class PdfViewerPage extends StatefulWidget {
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
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final _controller = PdfViewerController();

  int _pageCount = 0;
  int _pageNumber = 1;

  void _goToPage(int pageNumber) {
    if (pageNumber < 1 || pageNumber > _pageCount) return;
    // The viewer reports back through onPageChanged, which updates the field.
    _controller.goToPage(pageNumber: pageNumber);
  }

  /// Draggable scroll thumb, labelled with the page it would land on.
  Widget _buildScrollThumb(
    BuildContext context,
    Size thumbSize,
    int? pageNumber,
    PdfViewerController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.secondaryContainer,
      elevation: 2,
      borderRadius: BorderRadius.circular(6),
      child: Center(
        child: Text(
          '${pageNumber ?? ''}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.onSave != null)
            IconButton(
              tooltip: context.l10n.saveFile,
              icon: const Icon(Icons.download_outlined),
              onPressed: widget.onSave,
            ),
        ],
        // Single-page documents have nothing to select between.
        bottom: _pageCount > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(PdfPageSelector.height),
                child: PdfPageSelector(
                  pageCount: _pageCount,
                  pageNumber: _pageNumber,
                  onPageSelected: _goToPage,
                ),
              )
            : null,
      ),
      body: PdfViewer.data(
        widget.bytes,
        sourceName: widget.title,
        controller: _controller,
        params: PdfViewerParams(
          onViewerReady: (document, controller) {
            if (!mounted) return;
            setState(() {
              _pageCount = document.pages.length;
              _pageNumber = controller.pageNumber ?? 1;
            });
          },
          onPageChanged: (pageNumber) {
            if (!mounted || pageNumber == null || pageNumber == _pageNumber) {
              return;
            }
            setState(() => _pageNumber = pageNumber);
          },
          viewerOverlayBuilder: (context, size, handleLinkTap) => [
            PdfViewerScrollThumb(
              controller: _controller,
              orientation: ScrollbarOrientation.right,
              thumbSize: const Size(32, 36),
              thumbBuilder: _buildScrollThumb,
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick page selector, shaped like the browsers' PDF toolbars: an editable
/// page number, the page count beside it, and arrows for stepping one at a
/// time.
class PdfPageSelector extends StatefulWidget {
  const PdfPageSelector({
    super.key,
    required this.pageCount,
    required this.pageNumber,
    required this.onPageSelected,
  });

  /// Height the selector asks for as an app bar's bottom.
  static const height = 48.0;

  final int pageCount;
  final int pageNumber;
  final ValueChanged<int> onPageSelected;

  @override
  State<PdfPageSelector> createState() => _PdfPageSelectorState();
}

class _PdfPageSelectorState extends State<PdfPageSelector> {
  late final _fieldController = TextEditingController(
    text: '${widget.pageNumber}',
  );
  final _focusNode = FocusNode();

  /// Page asked for but not yet confirmed by the viewer. Submitting unfocuses
  /// the field, and reverting to [PdfPageSelector.pageNumber] in that instant
  /// would flash the old page number until the jump completes.
  int? _requestedPage;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(PdfPageSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scrolling the document moves the page under the field, but never while
    // someone is part-way through typing a different one.
    if (widget.pageNumber != oldWidget.pageNumber) {
      // The viewer has spoken; where it landed wins over what was asked for.
      _requestedPage = null;
      if (!_focusNode.hasFocus) _resetField();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _fieldController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // Typing replaces the number instead of appending to it.
      _fieldController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _fieldController.text.length,
      );
    } else {
      // An abandoned edit reverts rather than lingering as a wrong number.
      _resetField();
    }
  }

  void _resetField() =>
      _fieldController.text = '${_requestedPage ?? widget.pageNumber}';

  void _submit(String value) {
    final page = int.tryParse(value.trim());
    if (page == null) {
      _resetField();
      return;
    }
    final target = page.clamp(1, widget.pageCount);
    _requestedPage = target;
    _fieldController.text = '$target';
    if (target != widget.pageNumber) widget.onPageSelected(target);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainer,
      child: SizedBox(
        height: PdfPageSelector.height,
        child: Row(
          children: [
            const SizedBox(width: 4),
            IconButton(
              tooltip: context.l10n.previousPage,
              icon: const Icon(Icons.chevron_left),
              onPressed: widget.pageNumber > 1
                  ? () => widget.onPageSelected(widget.pageNumber - 1)
                  : null,
            ),
            SizedBox(
              width: 56,
              child: Tooltip(
                message: context.l10n.goToPage,
                child: TextField(
                  controller: _fieldController,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: _submit,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.ofPages(widget.pageCount),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            IconButton(
              tooltip: context.l10n.nextPage,
              icon: const Icon(Icons.chevron_right),
              onPressed: widget.pageNumber < widget.pageCount
                  ? () => widget.onPageSelected(widget.pageNumber + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
