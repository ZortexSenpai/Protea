import 'dart:async';

import 'package:flutter/material.dart';

/// Shared animation timings so every surface of the app moves the same way.
abstract final class Motion {
  /// Hover feedback, small fades.
  static const quick = Duration(milliseconds: 120);

  /// Bars, panels and sections appearing or collapsing.
  static const short = Duration(milliseconds: 200);

  /// Pane and page switches.
  static const medium = Duration(milliseconds: 250);

  static const easeOut = Curves.easeOutCubic;
  static const ease = Curves.easeInOutCubic;
}

/// Route transition: a quick fade with a hint of upward motion, used on all
/// platforms instead of the platform defaults (zoom on Android/Linux, slide
/// on iOS) so pushed pages feel light and consistent.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.easeOut,
      reverseCurve: Motion.easeOut.flipped,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Cross-fades between panes when the child's key changes — used for the
/// chat pane on room switches and the channel list on space switches.
class PaneSwitcher extends StatelessWidget {
  const PaneSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.short,
      switchInCurve: Motion.easeOut,
      switchOutCurve: Motion.easeOut.flipped,
      child: child,
    );
  }
}

/// A vertically collapsible wrapper: keeps [child] mounted and animates it
/// open or closed, clipping the overflow while it moves.
class AnimatedCollapse extends StatelessWidget {
  const AnimatedCollapse({
    super.key,
    required this.collapsed,
    required this.child,
    this.axis = Axis.vertical,
    this.alignment = Alignment.topCenter,
  });

  final bool collapsed;
  final Widget child;
  final Axis axis;

  /// Which edge the content stays anchored to while it collapses.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        duration: Motion.short,
        curve: Motion.easeOut,
        alignment: alignment,
        heightFactor: axis == Axis.vertical ? (collapsed ? 0 : 1) : null,
        widthFactor: axis == Axis.horizontal ? (collapsed ? 0 : 1) : null,
        child: child,
      ),
    );
  }
}

/// A panel or bar that slides open when [child] is non-null and slides
/// closed when it becomes null. The outgoing child stays mounted until the
/// close animation has finished, so it visibly slides out instead of
/// leaving a shrinking hole.
class CollapsiblePanel extends StatefulWidget {
  const CollapsiblePanel({
    super.key,
    required this.child,
    this.axis = Axis.horizontal,
    this.alignment = Alignment.centerLeft,
  });

  /// The panel content, or null to close the panel.
  final Widget? child;
  final Axis axis;

  /// Which edge the content stays anchored to while it moves.
  final AlignmentGeometry alignment;

  @override
  State<CollapsiblePanel> createState() => _CollapsiblePanelState();
}

class _CollapsiblePanelState extends State<CollapsiblePanel> {
  Widget? _retained;
  Timer? _evict;

  @override
  void initState() {
    super.initState();
    _retained = widget.child;
  }

  @override
  void didUpdateWidget(CollapsiblePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null) {
      _retained = widget.child;
      _evict?.cancel();
      _evict = null;
    } else if (oldWidget.child != null) {
      // Keep the outgoing content on screen for the close animation.
      _evict?.cancel();
      _evict = Timer(Motion.short, () {
        if (mounted) setState(() => _retained = null);
      });
    }
  }

  @override
  void dispose() {
    _evict?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final retained = _retained;
    return AnimatedCollapse(
      collapsed: widget.child == null,
      axis: widget.axis,
      alignment: widget.alignment,
      child: retained ?? const SizedBox.shrink(),
    );
  }
}

/// Fades its child in when it enters the tree (removal is instant) — for
/// hover toolbars and other transient chrome that should appear softly but
/// vanish immediately.
class FadeIn extends StatefulWidget {
  const FadeIn({super.key, required this.child});

  final Widget child;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: Motion.quick,
      child: widget.child,
    );
  }
}
