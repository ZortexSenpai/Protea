import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Sheets larger than this are cut off in the preview.
const xlsxMaxRows = 5000;
const xlsxMaxColumns = 200;

/// One worksheet as display strings: [rows] is dense (row-major, padded to
/// [columnCount]), with empty strings for blank cells.
class XlsxSheet {
  XlsxSheet({
    required this.name,
    required this.rows,
    required this.columnCount,
    this.truncated = false,
  });

  final String name;
  final List<List<String>> rows;
  final int columnCount;

  /// Whether rows or columns beyond the preview limits were dropped.
  final bool truncated;
}

/// Reads the cell values of an Office Open XML workbook (.xlsx) for
/// display. Elements are matched by local name in any namespace, since
/// some writers prefix them (`x:sheet`). Only values are extracted — no formulas, styling or merged
/// cells — with dates, percentages and booleans formatted the way a
/// spreadsheet app would show them. Throws [FormatException] for files
/// that are not a readable workbook.
List<XlsxSheet> parseXlsx(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('Not an xlsx file');
  }

  XmlDocument? read(String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    // Some writers prefix the parts with a byte order mark.
    final text = utf8.decode(file.content, allowMalformed: true);
    return XmlDocument.parse(
      text.startsWith('\uFEFF') ? text.substring(1) : text,
    );
  }

  final workbook = read('xl/workbook.xml');
  if (workbook == null) throw const FormatException('Not an xlsx file');

  final date1904 = workbook
      .findAllElements('workbookPr', namespaceUri: '*')
      .any((e) => _truthy(e.getAttribute('date1904')));

  // Sheet name → part path, through the workbook relationships.
  final targets = <String, String>{};
  for (final rel
      in read(
            'xl/_rels/workbook.xml.rels',
          )?.findAllElements('Relationship', namespaceUri: '*') ??
          const <XmlElement>[]) {
    final id = rel.getAttribute('Id');
    final target = rel.getAttribute('Target');
    if (id == null || target == null) continue;
    targets[id] = target.startsWith('/') ? target.substring(1) : 'xl/$target';
  }

  final sharedStrings = [
    for (final item
        in read(
              'xl/sharedStrings.xml',
            )?.findAllElements('si', namespaceUri: '*') ??
            const <XmlElement>[])
      _richText(item),
  ];
  final styles = _readStyles(read('xl/styles.xml'));

  final sheets = <XlsxSheet>[];
  var index = 0;
  for (final sheet in workbook.findAllElements('sheet', namespaceUri: '*')) {
    index++;
    final name = sheet.getAttribute('name') ?? 'Sheet$index';
    final relId = sheet.attributes
        .where((a) => a.name.local == 'id')
        .map((a) => a.value)
        .firstOrNull;
    final path = targets[relId] ?? 'xl/worksheets/sheet$index.xml';
    final document = read(path);
    if (document == null) continue;
    sheets.add(_readSheet(name, document, sharedStrings, styles, date1904));
  }
  return sheets;
}

bool _truthy(String? value) => value == '1' || value == 'true';

/// Concatenated text of a shared or inline string, skipping phonetic runs.
String _richText(XmlElement element) => element
    .findAllElements('t', namespaceUri: '*')
    .where((t) => t.parentElement?.name.local != 'rPh')
    .map((t) => t.innerText)
    .join();

enum _Kind { general, date, percent }

/// Display kind per cell style index (`s` attribute).
List<_Kind> _readStyles(XmlDocument? styles) {
  if (styles == null) return const [];
  final custom = <int, String>{
    for (final format in styles.findAllElements('numFmt', namespaceUri: '*'))
      ?int.tryParse(format.getAttribute('numFmtId') ?? ''):
          format.getAttribute('formatCode') ?? '',
  };
  final cellXfs = styles
      .findAllElements('cellXfs', namespaceUri: '*')
      .firstOrNull;
  if (cellXfs == null) return const [];
  return [
    for (final xf in cellXfs.findElements('xf', namespaceUri: '*'))
      _kindOf(int.tryParse(xf.getAttribute('numFmtId') ?? '') ?? 0, custom),
  ];
}

_Kind _kindOf(int id, Map<int, String> custom) {
  // Built-in formats: 9/10 are percentages, 14–22 and 45–47 dates/times.
  if (id == 9 || id == 10) return _Kind.percent;
  if ((id >= 14 && id <= 22) || (id >= 45 && id <= 47)) return _Kind.date;
  final code = custom[id];
  if (code == null) return _Kind.general;
  // Ignore quoted literals, bracketed colors/locales and escaped chars.
  final bare = code
      .replaceAll(RegExp(r'"[^"]*"'), '')
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .replaceAll(RegExp(r'\\.'), '');
  if (bare.contains('%')) return _Kind.percent;
  if (RegExp('[dmyhs]', caseSensitive: false).hasMatch(bare)) {
    return _Kind.date;
  }
  return _Kind.general;
}

/// Zero-based column index of a cell reference like "AB12".
int? _columnOf(String? reference) {
  if (reference == null) return null;
  var column = 0;
  var letters = 0;
  for (final unit in reference.toUpperCase().codeUnits) {
    if (unit < 65 || unit > 90) break;
    column = column * 26 + (unit - 64);
    letters++;
  }
  return letters == 0 ? null : column - 1;
}

XlsxSheet _readSheet(
  String name,
  XmlDocument document,
  List<String> sharedStrings,
  List<_Kind> styles,
  bool date1904,
) {
  final rows = <List<String>>[];
  var columnCount = 0;
  var truncated = false;
  for (final row in document.findAllElements('row', namespaceUri: '*')) {
    final rowIndex = (int.tryParse(row.getAttribute('r') ?? '') ?? 0) - 1;
    final target = rowIndex >= 0 ? rowIndex : rows.length;
    if (target >= xlsxMaxRows) {
      truncated = true;
      break;
    }
    final cells = <String>[];
    for (final cell in row.findElements('c', namespaceUri: '*')) {
      final column = _columnOf(cell.getAttribute('r')) ?? cells.length;
      if (column >= xlsxMaxColumns) {
        truncated = true;
        continue;
      }
      final text = _cellText(cell, sharedStrings, styles, date1904);
      if (text.isEmpty) continue;
      while (cells.length <= column) {
        cells.add('');
      }
      cells[column] = text;
    }
    if (cells.isEmpty) continue;
    while (rows.length <= target) {
      rows.add(const []);
    }
    rows[target] = cells;
    if (cells.length > columnCount) columnCount = cells.length;
  }
  return XlsxSheet(
    name: name,
    rows: [
      for (final row in rows)
        [...row, for (var i = row.length; i < columnCount; i++) ''],
    ],
    columnCount: columnCount,
    truncated: truncated,
  );
}

String _cellText(
  XmlElement cell,
  List<String> sharedStrings,
  List<_Kind> styles,
  bool date1904,
) {
  final type = cell.getAttribute('t');
  if (type == 'inlineStr') {
    final inline = cell.getElement('is', namespaceUri: '*');
    return inline == null ? '' : _richText(inline);
  }
  final value = cell.getElement('v', namespaceUri: '*')?.innerText ?? '';
  if (value.isEmpty) return '';
  switch (type) {
    case 's':
      final index = int.tryParse(value);
      return index != null && index < sharedStrings.length
          ? sharedStrings[index]
          : '';
    case 'b':
      return value == '1' ? 'TRUE' : 'FALSE';
    case 'str' || 'e':
      return value;
  }
  final number = double.tryParse(value);
  if (number == null) return value;
  final style = int.tryParse(cell.getAttribute('s') ?? '') ?? 0;
  final kind = style < styles.length ? styles[style] : _Kind.general;
  return switch (kind) {
    _Kind.date => _formatDate(number, date1904),
    _Kind.percent => '${_formatNumber(number * 100)}%',
    _Kind.general => _formatNumber(number),
  };
}

/// Numbers without float noise or a trailing ".0" (0.1 + 0.2 → "0.3").
String _formatNumber(double number) {
  if (number == number.truncateToDouble() && number.abs() < 1e15) {
    return number.toInt().toString();
  }
  final text = double.parse(number.toStringAsPrecision(15)).toString();
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// Serial day numbers (days since 1899-12-30, or 1904-01-01) as ISO-style
/// date, time or date-time.
String _formatDate(double serial, bool date1904) {
  final epoch = date1904 ? DateTime.utc(1904) : DateTime.utc(1899, 12, 30);
  final date = epoch.add(
    Duration(milliseconds: (serial * Duration.millisecondsPerDay).round()),
  );
  String two(int n) => n.toString().padLeft(2, '0');
  final day = '${date.year}-${two(date.month)}-${two(date.day)}';
  final time = '${two(date.hour)}:${two(date.minute)}';
  final seconds = date.second != 0 ? ':${two(date.second)}' : '';
  final hasDate = serial.abs() >= 1;
  final hasTime = serial != serial.truncateToDouble();
  if (hasDate && hasTime) return '$day $time$seconds';
  if (hasTime) return '$time$seconds';
  return day;
}

/// Spreadsheet column label for a zero-based index (0 → A, 26 → AA).
String xlsxColumnLabel(int index) {
  var label = '';
  var n = index + 1;
  while (n > 0) {
    final rem = (n - 1) % 26;
    label = String.fromCharCode(65 + rem) + label;
    n = (n - 1) ~/ 26;
  }
  return label;
}
