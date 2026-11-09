// Semantics smoke test: the Linux embedder keeps accessibility semantics
// enabled, so the animation and smooth-scroll wrappers must stay clean under
// an active semantics tree (hover, wheel glides, layout-threshold resizes).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protea/src/motion.dart';
import 'package:protea/src/smooth_scroll.dart';

Future<void> _wheel(WidgetTester tester, Offset at, double dy) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  pointer.hover(at);
  await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
}

/// Mirrors the app: SmoothScrolling sits in MaterialApp.builder above the
/// Navigator; the home screen switches between a wide two-list layout and a
/// narrow one, with tooltips and badges like the spaces rail.
Widget _app({required bool wide}) {
  return MaterialApp(
    builder: (context, child) => Listener(
      behavior: HitTestBehavior.translucent,
      child: SmoothScrolling(
        enabled: true,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
    home: Builder(
      builder: (context) {
        final isWide = MediaQuery.sizeOf(context).width >= 900;
        final rail = SizedBox(
          width: 72,
          child: ListView(
            children: [
              for (var i = 0; i < 30; i++)
                Tooltip(
                  message: 'space $i',
                  child: Badge(
                    isLabelVisible: i.isEven,
                    label: Text('$i'),
                    child: InkWell(
                      onTap: () {},
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(child: Text('S$i')),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        final channels = ListView(
          children: [
            for (var i = 0; i < 60; i++)
              ListTile(dense: true, title: Text('channel $i'), onTap: () {}),
          ],
        );
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                rail,
                SizedBox(width: 280, child: channels),
                Expanded(
                  child: PaneSwitcher(
                    child: Center(
                      key: const ValueKey('empty'),
                      child: Text('select a channel'),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Protea')),
          drawer: Drawer(width: 352, child: Row(children: [rail, channels])),
          body: PaneSwitcher(
            child: Center(key: const ValueKey('empty'), child: Text('none')),
          ),
        );
      },
    ),
  );
}

void main() {
  final linux = TargetPlatformVariant.only(TargetPlatform.linux);

  testWidgets('resize + hover + wheel with semantics', variant: linux, (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(1872, 1922); // 936x961 logical
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(wide: true));
    await tester.pump(const Duration(milliseconds: 100));

    // Hover across the rail (tooltips) and lists.
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 2,
    );
    await gesture.addPointer(location: const Offset(36, 100));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.removePointer();

    // Wheel-glide the channel list and the rail.
    await _wheel(tester, const Offset(200, 400), 120);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await _wheel(tester, const Offset(200, 400), 120);
    await tester.pump(const Duration(milliseconds: 30));
    await _wheel(tester, const Offset(36, 400), 120);
    await tester.pumpAndSettle();

    // Resize across the wide/narrow threshold mid-glide.
    await _wheel(tester, const Offset(200, 400), 200);
    await tester.pump(const Duration(milliseconds: 30));
    tester.view.physicalSize = const Size(1600, 1922); // 800 logical: narrow
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1872, 1922); // wide again
    await tester.pumpAndSettle();

    handle.dispose();
  });
}
