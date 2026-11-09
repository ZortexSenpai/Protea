// The PDF viewer's page selector: an editable page number with arrows, the
// way Chrome's and Firefox's PDF toolbars do it. The viewer itself is not
// exercised here — pdfrx needs pdfium, which the test VM has no build of.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/widgets/pdf_preview.dart';

void main() {
  Future<AppLocalizations> pumpSelector(
    WidgetTester tester, {
    required int pageCount,
    required int pageNumber,
    required List<int> selected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PdfPageSelector(
            pageCount: pageCount,
            pageNumber: pageNumber,
            onPageSelected: selected.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(PdfPageSelector)));
  }

  TextEditingController fieldOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!;

  testWidgets('the field shows the current page next to the total', (
    tester,
  ) async {
    final l10n = await pumpSelector(
      tester,
      pageCount: 24,
      pageNumber: 7,
      selected: [],
    );

    expect(fieldOf(tester).text, '7');
    expect(find.text(l10n.ofPages(24)), findsOneWidget);
    // No per-page buttons any more.
    expect(find.text('1'), findsNothing);
    expect(find.text('24'), findsNothing);
  });

  testWidgets('typing a page and submitting jumps there', (tester) async {
    final selected = <int>[];
    await pumpSelector(tester, pageCount: 24, pageNumber: 1, selected: selected);

    await tester.enterText(find.byType(TextField), '13');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(selected, [13]);
  });

  testWidgets('out-of-range and junk entries are corrected, not forwarded', (
    tester,
  ) async {
    final selected = <int>[];
    await pumpSelector(tester, pageCount: 24, pageNumber: 5, selected: selected);

    // Past the end clamps to the last page.
    await tester.enterText(find.byType(TextField), '900');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(selected, [24]);
    expect(fieldOf(tester).text, '24');

    // Zero clamps to the first page.
    await tester.enterText(find.byType(TextField), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(selected, [24, 1]);

    // Letters never reach the field, so an empty submit reverts to the page
    // last asked for rather than forwarding anything.
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(selected, [24, 1]);
    expect(fieldOf(tester).text, '1');
  });

  testWidgets('scrolling the document updates the field, editing holds it', (
    tester,
  ) async {
    final selected = <int>[];
    await pumpSelector(tester, pageCount: 24, pageNumber: 1, selected: selected);

    // The viewer reporting a new page rewrites the field...
    await pumpSelector(tester, pageCount: 24, pageNumber: 9, selected: selected);
    expect(fieldOf(tester).text, '9');

    // ...but not out from under a half-typed number.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2');
    await pumpSelector(tester, pageCount: 24, pageNumber: 10, selected: selected);
    expect(fieldOf(tester).text, '2');
  });

  testWidgets('the arrows step one page and stop at the ends', (tester) async {
    final selected = <int>[];
    var l10n = await pumpSelector(
      tester,
      pageCount: 24,
      pageNumber: 1,
      selected: selected,
    );

    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip(l10n.nextPage));
    expect(selected, [2]);

    l10n = await pumpSelector(
      tester,
      pageCount: 24,
      pageNumber: 24,
      selected: selected,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip(l10n.previousPage));
    expect(selected, [2, 23]);
  });
}
