// Semantics smoke test for the timeline surface: a SelectionArea wrapping a
// reversed ScrollablePositionedList whose content churns while the pane
// cross-fades — the shape of the room page, where the Flutter 3.44
// semantics pipeline and SelectionArea's microtask flush are fragile
// (flutter/flutter#184400). The Linux embedder always enables semantics.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protea/src/motion.dart';
import 'package:protea/src/smooth_scroll.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String? roomId;
  List<String>? messages; // null = timeline still loading

  void show(String? id, List<String>? msgs) {
    setState(() {
      roomId = id;
      messages = msgs;
    });
  }

  void setMessages(List<String> msgs) {
    setState(() => messages = msgs);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        child: SmoothScrolling(
          enabled: true,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 200,
              child: ListView(
                children: [
                  for (var i = 0; i < 20; i++)
                    ListTile(dense: true, title: Text('room $i'), onTap: () {}),
                ],
              ),
            ),
            Expanded(
              child: PaneSwitcher(
                child: roomId == null
                    ? const Center(
                        key: ValueKey('empty'),
                        child: Text('select a room'),
                      )
                    : _Room(key: ValueKey(roomId), messages: messages),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Room extends StatefulWidget {
  const _Room({super.key, required this.messages});

  final List<String>? messages;

  @override
  State<_Room> createState() => _RoomState();
}

class _RoomState extends State<_Room> {
  final controller = ItemScrollController();

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              messages == null
                  ? const Center(child: CircularProgressIndicator())
                  : SelectionArea(
                      child: ScrollablePositionedList.builder(
                        itemScrollController: controller,
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final row = _Bubble(
                            text: messages[index],
                            withIconSpan: index.isMultiple(5),
                          );
                          if (index.isMultiple(7)) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [const Divider(), row],
                            );
                          }
                          return row;
                        },
                      ),
                    ),
              Positioned(
                right: 16,
                bottom: 12,
                child: IgnorePointer(
                  ignoring: true,
                  child: AnimatedScale(
                    scale: 0.6,
                    duration: Motion.short,
                    child: AnimatedOpacity(
                      opacity: 0,
                      duration: Motion.short,
                      child: FloatingActionButton.small(
                        tooltip: 'jump to live',
                        onPressed: () {},
                        child: const Icon(Icons.keyboard_double_arrow_down),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 18,
          child: AnimatedOpacity(
            opacity: 0,
            duration: Motion.short,
            child: Text('someone is typing', style: TextStyle(fontSize: 11)),
          ),
        ),
        const CollapsiblePanel(axis: Axis.vertical, child: null),
        const Padding(
          padding: EdgeInsets.all(8),
          child: TextField(decoration: InputDecoration(hintText: 'message')),
        ),
      ],
    );
  }
}

extension on int {
  bool isMultiple(int of) => this % of == 0;
}

/// Mirrors _MessageBubble: hover-tracked row with rich text (time + sender +
/// body spans, sometimes a WidgetSpan icon) and a floating hover action bar.
class _Bubble extends StatefulWidget {
  const _Bubble({required this.text, required this.withIconSpan});

  final String text;
  final bool withIconSpan;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Motion.quick,
        color: _hovered ? Colors.black12 : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '[12:00] '),
                    const TextSpan(
                      text: '<sender> ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: widget.text),
                    if (widget.withIconSpan)
                      const WidgetSpan(
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.error_outline, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_hovered)
              Positioned(
                top: 0,
                right: 8,
                child: FadeIn(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'reply',
                        iconSize: 16,
                        icon: const Icon(Icons.reply),
                        onPressed: () {},
                      ),
                      IconButton(
                        tooltip: 'react',
                        iconSize: 16,
                        icon: const Icon(Icons.add_reaction_outlined),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  final linux = TargetPlatformVariant.only(TargetPlatform.linux);

  testWidgets('timeline churn under SelectionArea with semantics', variant: linux, (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(2200, 1600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _Harness());
    final state = tester.state<_HarnessState>(find.byType(_Harness));

    // The cursor sits over the timeline area, like a real launch.
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 7,
    );
    await mouse.addPointer(location: const Offset(600, 400));
    addTearDown(mouse.removePointer);

    // Open a room: spinner first, messages land mid-fade like a sync burst.
    state.show('a', null);
    await tester.pump(const Duration(milliseconds: 30));
    state.setMessages([for (var i = 0; i < 40; i++) 'a msg $i']);
    await tester.pump(const Duration(milliseconds: 30));
    await mouse.moveTo(const Offset(600, 500));
    // Backfill grows the list while it settles.
    state.setMessages([for (var i = 0; i < 80; i++) 'a msg $i']);
    await tester.pump(const Duration(milliseconds: 30));
    await mouse.moveTo(const Offset(600, 300));
    state.setMessages([for (var i = 0; i < 120; i++) 'a msg $i']);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpAndSettle();

    // Jump to the unread marker like the room page does after load.
    tester
        .state<_RoomState>(find.byType(_Room).last)
        .controller
        .jumpTo(index: 100);
    await tester.pump(const Duration(milliseconds: 16));
    state.setMessages([for (var i = 0; i < 121; i++) 'a msg $i']);
    await tester.pumpAndSettle();

    // Switch rooms mid-life: old SelectionArea fades out while the new
    // one loads and churns, with the cursor over both.
    state.show('b', null);
    await tester.pump(const Duration(milliseconds: 30));
    await mouse.moveTo(const Offset(600, 450));
    state.setMessages([for (var i = 0; i < 60; i++) 'b msg $i']);
    await tester.pump(const Duration(milliseconds: 30));
    await mouse.moveTo(const Offset(600, 350));
    state.setMessages([for (var i = 0; i < 90; i++) 'b msg $i']);
    await tester.pumpAndSettle();

    // And close the room entirely mid-churn.
    state.show(null, null);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();

    handle.dispose();
  });
}
