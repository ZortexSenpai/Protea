import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:protea/src/widgets/html_message.dart';
import 'package:protea/src/widgets/linkified_text.dart';

void main() {
  Future<void> hoverAt(WidgetTester tester, Offset location) async {
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 1,
    );
    await gesture.addPointer(location: location);
    addTearDown(gesture.removePointer);
    await tester.pump();
  }

  MouseCursor? activeCursor() =>
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);

  testWidgets('HtmlMessage links show a click cursor on hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HtmlMessage(html: '<a href="https://example.com">a link</a>'),
        ),
      ),
    );
    await hoverAt(
      tester,
      tester.getCenter(find.textContaining('a link', findRichText: true)),
    );
    expect(activeCursor(), SystemMouseCursors.click);
  });

  testWidgets('LinkifiedText links show a click cursor on hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LinkifiedText('see https://example.com')),
      ),
    );
    final box = tester.getRect(
      find.textContaining('https://example.com', findRichText: true),
    );
    // Hover near the end of the line, well inside the link portion.
    await hoverAt(tester, Offset(box.right - 10, box.center.dy));
    expect(activeCursor(), SystemMouseCursors.click);
  });
}
