import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protea/src/smooth_scroll.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

Widget _wrap({required bool enabled, required Widget child}) =>
    MaterialApp(home: SmoothScrolling(enabled: enabled, child: child));

ListView _list(ScrollController controller) => ListView.builder(
  controller: controller,
  itemCount: 100,
  itemBuilder: (_, index) => SizedBox(height: 40, child: Text('$index')),
);

/// A discrete mouse-wheel tick over the widget under [finder].
Future<void> _wheel(WidgetTester tester, Finder finder, double dy) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  pointer.hover(tester.getCenter(finder));
  await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
}

/// Widget tests default to [TargetPlatform.android], where desktop
/// scrollbars are not built at all; scrollbar tests run as Linux.
final _desktop = TargetPlatformVariant.only(TargetPlatform.linux);

/// The default 800x600 test surface: the vertical scrollbar hugs the right
/// edge (thickness 8, margin 2), so its thumb is centered on x=794.
const _scrollbarX = 794.0;

/// Drags the scrollbar thumb by [dy]. The thumb must already be visible
/// (it fades in on scroll activity).
Future<void> _dragThumb(
  WidgetTester tester, {
  required double fromY,
  required double dy,
}) async {
  final gesture = await tester.startGesture(
    Offset(_scrollbarX, fromY),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.moveBy(Offset(0, dy));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('wheel input glides instead of jumping when enabled', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(enabled: true, child: _list(controller)));

    await _wheel(tester, find.byType(ListView), 120);
    await tester.pump(); // Starts the glide's ticker.
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.offset, greaterThan(0));
    expect(controller.offset, lessThan(120));

    await tester.pumpAndSettle();
    expect(controller.offset, 120);
  });

  testWidgets('glide survives the viewport resizing mid-flight', (
    tester,
  ) async {
    // Chat surfaces resize constantly (the input bar grows, a reply bar
    // appears, images load). A dimension change hands DrivenScrollActivity
    // to goBallistic, which the intercepting physics used to end instantly,
    // killing the glide partway: the wheel tick appeared to do nothing.
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var viewportHeight = 600.0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      _wrap(
        enabled: true,
        child: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                height: viewportHeight,
                child: _list(controller),
              ),
            );
          },
        ),
      ),
    );

    await _wheel(tester, find.byType(ListView), 120);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50)); // mid-glide
    expect(controller.offset, greaterThan(0));
    expect(controller.offset, lessThan(120));

    rebuild(() => viewportHeight = 500); // the input bar grew
    await tester.pumpAndSettle();
    expect(controller.offset, 120);
  });

  testWidgets('content shrinking mid-glide recovers instead of stranding', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var itemCount = 100;
    late StateSetter rebuild;
    await tester.pumpWidget(
      _wrap(
        enabled: true,
        child: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ListView.builder(
              controller: controller,
              itemCount: itemCount,
              itemBuilder: (_, index) =>
                  SizedBox(height: 40, child: Text('$index')),
            );
          },
        ),
      ),
    );

    // Glide deep into the list, then shrink the content below the target.
    for (var i = 0; i < 10; i++) {
      await _wheel(tester, find.byType(ListView), 120);
      await tester.pump(const Duration(milliseconds: 10));
    }
    rebuild(() => itemCount = 20); // max extent shrinks to 200
    await tester.pumpAndSettle();
    // One further tick must land in range — the scrollable may not respond
    // exactly at the moment of the shrink, but it must not stay dead.
    await _wheel(tester, find.byType(ListView), -120);
    await tester.pumpAndSettle();
    expect(
      controller.position.pixels,
      inInclusiveRange(0, controller.position.maxScrollExtent),
    );
  });

  testWidgets('rapid wheel ticks accumulate into one target', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(enabled: true, child: _list(controller)));

    await _wheel(tester, find.byType(ListView), 120);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await _wheel(tester, find.byType(ListView), 120);
    await tester.pumpAndSettle();
    expect(controller.offset, 240);
  });

  testWidgets('disabled keeps the native instant jump', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(enabled: false, child: _list(controller)));

    await _wheel(tester, find.byType(ListView), 120);
    expect(controller.offset, 120);
  });

  testWidgets('drives a ScrollablePositionedList (timeline)', (tester) async {
    final positions = ItemPositionsListener.create();
    await tester.pumpWidget(
      _wrap(
        enabled: true,
        child: ScrollablePositionedList.builder(
          itemCount: 100,
          itemPositionsListener: positions,
          itemBuilder: (_, index) =>
              SizedBox(height: 40, child: Text('$index')),
        ),
      ),
    );

    await _wheel(tester, find.byType(ScrollablePositionedList), 400);
    await tester.pumpAndSettle();
    final firstVisible = positions.itemPositions.value
        .map((position) => position.index)
        .reduce((a, b) => a < b ? a : b);
    expect(firstVisible, greaterThan(0));
  });

  testWidgets('scrollbar thumb can be dragged when smoothing is enabled', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(enabled: true, child: _list(controller)));

    // Reveal the thumb; at offset 10 it sits at the very top of the track.
    controller.jumpTo(10);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await _dragThumb(tester, fromY: 20, dy: 100);
    expect(controller.offset, greaterThan(300));
  }, variant: _desktop);

  testWidgets('scrollbar track tap pages the list', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(enabled: true, child: _list(controller)));

    controller.jumpTo(10);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap the track well below the thumb: pages down by 80% of the viewport.
    await tester.tapAt(const Offset(_scrollbarX, 500));
    await tester.pumpAndSettle();
    expect(controller.offset, 10 + 0.8 * 600);
  }, variant: _desktop);

  testWidgets('scrollbar thumb drags a reversed ScrollablePositionedList '
      '(chat timeline)', (tester) async {
    final positions = ItemPositionsListener.create();
    await tester.pumpWidget(
      _wrap(
        enabled: true,
        child: ScrollablePositionedList.builder(
          itemCount: 100,
          reverse: true,
          itemPositionsListener: positions,
          itemBuilder: (_, index) =>
              SizedBox(height: 40, child: Text('$index')),
        ),
      ),
    );

    // Reveal the thumb via a wheel-up tick (on a reversed list that scrolls
    // back in history), then drag it. The thumb starts at the bottom and
    // dragging it up also scrolls back in history.
    await _wheel(tester, find.byType(ScrollablePositionedList), -10);
    await tester.pumpAndSettle();

    await _dragThumb(tester, fromY: 580, dy: -200);
    final firstVisible = positions.itemPositions.value
        .map((position) => position.index)
        .reduce((a, b) => a < b ? a : b);
    expect(firstVisible, greaterThan(10));
  }, variant: _desktop);
}
