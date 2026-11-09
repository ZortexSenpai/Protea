// Spreadsheet previews: parseXlsx reads cell values out of the workbook's
// XML parts (shared strings, inline strings, booleans, dates, percentages,
// sparse cells, multiple sheets) and XlsxViewerPage renders them as a grid
// with sheet tabs.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protea/src/l10n.dart';
import 'package:protea/src/widgets/xlsx_preview.dart';
import 'package:protea/src/xlsx.dart';

Uint8List _workbook() {
  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('xl/workbook.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Budget" sheetId="1" r:id="rId1"/>
    <sheet name="Notes" sheetId="2" r:id="rId2"/>
  </sheets>
</workbook>''');
  add('xl/_rels/workbook.xml.rels', '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Target="/xl/worksheets/other.xml"/>
</Relationships>''');
  add('xl/sharedStrings.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <si><t>Item</t></si>
  <si><r><t>Ren</t></r><r><t>t</t></r></si>
</sst>''');
  add('xl/styles.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <numFmts><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/></numFmts>
  <cellXfs>
    <xf numFmtId="0"/>
    <xf numFmtId="164"/>
    <xf numFmtId="9"/>
  </cellXfs>
</styleSheet>''');
  add('xl/worksheets/sheet1.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1" t="inlineStr"><is><t>Amount</t></is></c>
    </row>
    <row r="2">
      <c r="A2" t="s"><v>1</v></c>
      <c r="B2"><v>1200.5</v></c>
      <c r="C2" s="1"><v>45292</v></c>
      <c r="D2" s="2"><v>0.25</v></c>
      <c r="E2" t="b"><v>1</v></c>
    </row>
    <row r="4">
      <c r="C4"><v>0.30000000000000004</v></c>
    </row>
  </sheetData>
</worksheet>''');
  add('xl/worksheets/other.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData><row r="1"><c r="A1" t="str"><v>hello</v></c></row></sheetData>
</worksheet>''');
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('parseXlsx reads values, formats and layout', () {
    final sheets = parseXlsx(_workbook());
    expect(sheets.map((s) => s.name), ['Budget', 'Notes']);

    final budget = sheets.first;
    expect(budget.columnCount, 5);
    expect(budget.rows, [
      ['Item', 'Amount', '', '', ''],
      ['Rent', '1200.5', '2024-01-01', '25%', 'TRUE'],
      ['', '', '', '', ''],
      ['', '', '0.3', '', ''],
    ]);
    expect(sheets[1].rows, [
      ['hello'],
    ]);
  });

  test('parseXlsx handles prefixed elements and a byte order mark', () {
    final archive = Archive();
    void add(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    const main = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
    const rels =
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    add(
      'xl/workbook.xml',
      '<x:workbook xmlns:x="$main" xmlns:r="$rels"><x:sheets>'
          '<x:sheet name="Tracker" sheetId="1" r:id="R1"/>'
          '</x:sheets></x:workbook>',
    );
    add(
      'xl/_rels/workbook.xml.rels',
      '\uFEFF<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="R1" Target="/xl/worksheets/a.xml"/>'
          '</Relationships>',
    );
    add(
      'xl/worksheets/a.xml',
      '<x:worksheet xmlns:x="$main"><x:sheetData><x:row r="1">'
          '<x:c r="B1" t="inlineStr"><x:is><x:t>Status</x:t></x:is></x:c>'
          '</x:row></x:sheetData></x:worksheet>',
    );
    final sheets = parseXlsx(Uint8List.fromList(ZipEncoder().encode(archive)));
    expect(sheets.single.name, 'Tracker');
    expect(sheets.single.rows, [
      ['', 'Status'],
    ]);
  });

  test('parseXlsx rejects non-workbooks', () {
    expect(
      () => parseXlsx(Uint8List.fromList(utf8.encode('not a zip'))),
      throwsFormatException,
    );
  });

  test('column labels', () {
    expect(xlsxColumnLabel(0), 'A');
    expect(xlsxColumnLabel(25), 'Z');
    expect(xlsxColumnLabel(26), 'AA');
    expect(xlsxColumnLabel(701), 'ZZ');
    expect(xlsxColumnLabel(702), 'AAA');
  });

  testWidgets('viewer shows the grid and switches sheets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: XlsxViewerPage(title: 'budget.xlsx', bytes: _workbook()),
      ),
    );
    // Parsing runs in an isolate; give it real time to finish.
    for (var i = 0; i < 20 && find.text('Rent').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('2024-01-01'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('Rent'), findsNothing);
  });
}
