// The chat wraps messages in a SelectionArea, but a code block sits in a
// WidgetSpan inside flutter_html's paragraphs — a nesting that drops
// selection events before they reach the code text (framework limitation,
// reproducible in pure Flutter). HtmlMessage gives code blocks their own
// selection scope and renders them with a selectable Text.rich instead of
// flutter_highlight's raw RichText; this drives the full flow: drag-select
// the code, copy it, and check the clipboard.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:protea/src/widgets/html_message.dart';

void main() {
  testWidgets(
    'code block text can be selected and copied inside a SelectionArea',
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              child: HtmlMessage(
                html:
                    '<pre><code class="language-dart">'
                    'void main() {}'
                    '</code></pre>',
              ),
            ),
          ),
        ),
      );

      final codeText = find.textContaining('void main', findRichText: true);
      expect(codeText, findsOneWidget);

      // Mouse-drag across the code line, like a user selecting it.
      final rect = tester.getRect(codeText);
      final gesture = await tester.startGesture(
        Offset(rect.left + 1, rect.center.dy),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveTo(Offset(rect.right - 1, rect.center.dy));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(copied, isNotEmpty);
      expect(copied.last, contains('void main'));
    },
  );
}
