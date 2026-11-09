import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../event_body.dart';
import '../l10n.dart';
import '../xlsx.dart';

/// Workbooks larger than this are not offered for preview.
const _maxXlsxPreviewBytes = 10 * 1024 * 1024;

const _xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Whether [event] is an Excel workbook small enough to preview.
bool isXlsxPreviewable(Event event) {
  final size = event.infoMap['size'];
  if (size is! int || size > _maxXlsxPreviewBytes) return false;
  if (event.infoMap['mimetype'] == _xlsxMimeType) return true;
  return event.attachmentName.toLowerCase().endsWith('.xlsx');
}

/// Full-screen read-only spreadsheet viewer: a grid with column letters and
/// row numbers, and Excel-style sheet tabs along the bottom.
class XlsxViewerPage extends StatefulWidget {
  const XlsxViewerPage({
    super.key,
    required this.title,
    required this.bytes,
    this.onSave,
  });

  final String title;
  final Uint8List bytes;
  final VoidCallback? onSave;

  @override
  State<XlsxViewerPage> createState() => _XlsxViewerPageState();
}

class _XlsxViewerPageState extends State<XlsxViewerPage> {
  // Parsed off the UI thread: large workbooks are a lot of XML.
  late final Future<List<XlsxSheet>> _sheets = compute(parseXlsx, widget.bytes);
  int _selected = 0;

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
      ),
      body: FutureBuilder(
        future: _sheets,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(context.l10n.spreadsheetUnreadable));
          }
          final sheets = snapshot.data;
          if (sheets == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (sheets.isEmpty) {
            return Center(child: Text(context.l10n.spreadsheetEmpty));
          }
          final sheet = sheets[_selected.clamp(0, sheets.length - 1)];
          return Column(
            children: [
              if (sheet.truncated)
                MaterialBanner(
                  content: Text(
                    context.l10n.spreadsheetTruncated(
                      xlsxMaxRows,
                      xlsxMaxColumns,
                    ),
                  ),
                  actions: const [SizedBox.shrink()],
                ),
              Expanded(
                child: sheet.rows.isEmpty
                    ? Center(child: Text(context.l10n.spreadsheetEmpty))
                    : _SheetGrid(key: ValueKey(_selected), sheet: sheet),
              ),
              if (sheets.length > 1) ...[
                const Divider(height: 1),
                _SheetTabs(
                  names: [for (final sheet in sheets) sheet.name],
                  selected: _selected,
                  onSelected: (index) => setState(() => _selected = index),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SheetTabs extends StatelessWidget {
  const _SheetTabs({
    required this.names,
    required this.selected,
    required this.onSelected,
  });

  final List<String> names;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainer,
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemCount: names.length,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder: (context, index) => ChoiceChip(
            label: Text(names[index]),
            selected: index == selected,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => onSelected(index),
          ),
        ),
      ),
    );
  }
}

class _SheetGrid extends StatefulWidget {
  const _SheetGrid({super.key, required this.sheet});

  final XlsxSheet sheet;

  @override
  State<_SheetGrid> createState() => _SheetGridState();
}

class _SheetGridState extends State<_SheetGrid> {
  static const _rowHeight = 28.0;
  static const _minColumnWidth = 64.0;
  static const _maxColumnWidth = 320.0;
  static const _charWidth = 7.5;

  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  late final List<double> _columnWidths = _measureColumns();
  late final double _rowHeaderWidth = math.max(
    40,
    widget.sheet.rows.length.toString().length * 9 + 16,
  );

  /// Width per column from its longest value (sampled, so huge sheets stay
  /// cheap), clamped to a readable range.
  List<double> _measureColumns() {
    final sheet = widget.sheet;
    final longest = List.filled(sheet.columnCount, 0);
    for (final row in sheet.rows.take(500)) {
      for (var c = 0; c < row.length; c++) {
        final length = row[c].length;
        if (length > longest[c]) longest[c] = length;
      }
    }
    return [
      for (final length in longest)
        (length * _charWidth + 16).clamp(_minColumnWidth, _maxColumnWidth),
    ];
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final border = BorderSide(color: colorScheme.outlineVariant, width: 0.5);
    final headerColor = colorScheme.surfaceContainerHigh;
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final cellStyle = theme.textTheme.bodySmall;
    final totalWidth =
        _rowHeaderWidth + _columnWidths.fold<double>(0, (a, b) => a + b);

    Widget cell(
      String text,
      double width, {
      Color? color,
      TextStyle? style,
      bool center = false,
    }) => Container(
      width: width,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: center ? Alignment.center : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: color,
        border: Border(right: border, bottom: border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );

    final rows = widget.sheet.rows;
    // Both scrollbars hug the viewport edges: the vertical one listens to
    // the row list nested inside the horizontal scroll view.
    return Scrollbar(
      controller: _vertical,
      thumbVisibility: true,
      notificationPredicate: (notification) => notification.depth == 1,
      child: Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        notificationPredicate: (notification) => notification.depth == 0,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: SelectionArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      cell('', _rowHeaderWidth, color: headerColor),
                      for (var c = 0; c < _columnWidths.length; c++)
                        cell(
                          xlsxColumnLabel(c),
                          _columnWidths[c],
                          color: headerColor,
                          style: headerStyle,
                          center: true,
                        ),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _vertical,
                      itemExtent: _rowHeight,
                      itemCount: rows.length,
                      itemBuilder: (context, r) => Row(
                        children: [
                          cell(
                            '${r + 1}',
                            _rowHeaderWidth,
                            color: headerColor,
                            style: headerStyle,
                            center: true,
                          ),
                          for (var c = 0; c < _columnWidths.length; c++)
                            cell(
                              rows[r][c],
                              _columnWidths[c],
                              style: cellStyle,
                            ),
                        ],
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
