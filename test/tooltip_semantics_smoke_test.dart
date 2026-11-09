// Semantics smoke test for tooltips: Flutter 3.44's Tooltip is built on
// OverlayPortal, whose semantics grafting has known post-3.44 fixes
// upstream (flutter/flutter#186826, #186118, #186564). Shows a tooltip with
// semantics enabled, then removes/rebuilds its anchor while it is visible.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protea/src/motion.dart';

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  var pane = 0;
  var items = 20;
  bool showBar = true;

  void update(void Function() change) => setState(change);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: PaneSwitcher(
          child: ListView(
            key: ValueKey(pane),
            children: [
              if (showBar)
                Row(
                  children: [
                    IconButton(
                      tooltip: 'reply $pane',
                      icon: const Icon(Icons.reply),
                      onPressed: () {},
                    ),
                    IconButton(
                      tooltip: 'react $pane',
                      icon: const Icon(Icons.add_reaction_outlined),
                      onPressed: () {},
                    ),
                  ],
                ),
              for (var i = 0; i < items; i++)
                ListTile(
                  dense: true,
                  title: Text('item $i of pane $pane'),
                  trailing: Tooltip(
                    message: 'tip $i',
                    child: const Icon(Icons.info_outline, size: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  final linux = TargetPlatformVariant.only(TargetPlatform.linux);

  testWidgets('tooltip visible while anchor is removed', variant: linux, (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const _Harness());
    final state = tester.state<_HarnessState>(find.byType(_Harness));

    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 4,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    // Dwell on the reply button until its tooltip shows.
    await mouse.moveTo(tester.getCenter(find.byIcon(Icons.reply)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('reply 0'), findsOneWidget);

    // Remove the anchor row while the tooltip is up.
    state.update(() => state.showBar = false);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();

    // Show a list-item tooltip, then rebuild the list under it.
    state.update(() => state.showBar = true);
    await tester.pumpAndSettle();
    await mouse.moveTo(
      tester.getCenter(find.byIcon(Icons.info_outline).first),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    state.update(() => state.items = 5);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();

    // Tooltip up while the whole pane cross-fades away (PaneSwitcher).
    state.update(() => state.items = 20);
    await tester.pumpAndSettle();
    await mouse.moveTo(
      tester.getCenter(find.byIcon(Icons.info_outline).first),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    state.update(() => state.pane = 1);
    await tester.pump(const Duration(milliseconds: 30));
    await mouse.moveTo(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();

    handle.dispose();
  });
}
