import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'motion.dart';

/// Replaces the discrete mouse-wheel jumps of every scrollable below it
/// with short animated glides ("smooth scrolling").
///
/// Flutter applies wheel deltas instantly ([Scrollable] calls
/// [ScrollPosition.pointerScroll] with no animation hook), so this works in
/// two parts:
///
///  * A [ScrollConfiguration] hands every scrollable base physics that
///    reject user offsets, so the scrollables themselves never claim wheel
///    events from the [PointerSignalResolver].
///  * A [Listener] registers as the fallback handler for those events; it
///    hit-tests for the innermost scrollable viewport under the cursor and
///    animates its [ScrollPosition] toward the accumulated target.
///
/// Scrollables with explicit [AlwaysScrollableScrollPhysics] keep native
/// wheel handling (they still claim the event first). Trackpads keep their
/// native feel: pan-zoom gestures switch the subtree back to the default
/// scroll pipeline, and scroll events with small smooth deltas are applied
/// unanimated.
class SmoothScrolling extends StatefulWidget {
  const SmoothScrolling({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<SmoothScrolling> createState() => _SmoothScrollingState();
}

class _SmoothScrollingState extends State<SmoothScrolling>
    with TickerProviderStateMixin {
  /// Deltas at or above this are discrete wheel ticks (the Linux embedder
  /// reports lines-times-multiplier per tick); smaller ones are smooth
  /// trackpad or high-resolution wheel input and stay unanimated.
  static const _discreteDelta = 20.0;

  /// Wheel smoothing pauses while a trackpad is in use: its pan gestures
  /// need the native drag pipeline, which the intercepting physics disable.
  bool _trackpadMode = false;

  /// In-flight glide target per scroll position, so rapid wheel ticks
  /// accumulate into one longer glide instead of restarting from the
  /// current pixels each time.
  final _glideTarget = Expando<double>('smooth scroll glide target');

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (event.kind == PointerDeviceKind.trackpad) {
      if (!_trackpadMode) setState(() => _trackpadMode = true);
      return;
    }
    if (_trackpadMode) {
      // A mouse wheel is back; this event scrolls natively (the subtree is
      // still unlocked), smoothing resumes with the next one.
      setState(() => _trackpadMode = false);
      return;
    }
    // Register as a candidate handler. The resolver prefers the innermost
    // registrant, so any scrollable that still accepts user offsets
    // (explicit AlwaysScrollableScrollPhysics) wins and keeps its native
    // behavior; we only receive events nothing else claimed.
    GestureBinding.instance.pointerSignalResolver.register(event, _handleWheel);
  }

  void _handleWheel(PointerEvent event) {
    final scrollEvent = event as PointerScrollEvent;
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      scrollEvent.position,
      scrollEvent.viewId,
    );
    // Innermost viewport first; fall through to outer ones that can still
    // move, mirroring how nested scrollables hand wheel events upward.
    for (final entry in result.path) {
      final target = entry.target;
      ScrollPosition? position;
      AxisDirection? axisDirection;
      if (target is RenderViewportBase) {
        // ListView, GridView, CustomScrollView, shrink-wrapped lists, …
        if (target.offset case final ScrollPosition offset) {
          position = offset;
          axisDirection = target.axisDirection;
        }
      } else if (target is RenderEditable) {
        // Multi-line text fields scroll their content vertically.
        if (target.offset case final ScrollPosition offset) {
          position = offset;
          axisDirection = target.maxLines == 1
              ? AxisDirection.right
              : AxisDirection.down;
        }
      } else if (target is RenderAbstractViewport) {
        // SingleChildScrollView's viewport type is private; duck-type its
        // offset and axisDirection.
        try {
          position = (target as dynamic).offset as ScrollPosition;
          axisDirection = (target as dynamic).axisDirection as AxisDirection;
        } catch (_) {
          continue;
        }
      } else if (target is RenderBox) {
        // Over a childless stretch of a scrollable (the empty area of a
        // short chat, content scrolled out of range) the viewport itself is
        // not in the hit path — only the Scrollable's opaque gesture
        // detector wrapping it is. Native wheel handling works there for
        // the same reason; follow the wrapper chain down to the viewport.
        final viewport = _descendToViewport(target);
        if (viewport == null) continue;
        if (viewport.offset case final ScrollPosition offset) {
          position = offset;
          axisDirection = viewport.axisDirection;
        }
      } else {
        continue;
      }
      final pos = position;
      if (pos == null ||
          axisDirection == null ||
          !pos.hasPixels ||
          !pos.hasContentDimensions) {
        continue;
      }
      final delta = _deltaFor(scrollEvent, axisDirection);
      if (delta == 0) continue;
      final base = _glideTarget[pos] ?? pos.pixels;
      final glideTo = clampDouble(
        base + delta,
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if (glideTo == pos.pixels) continue;
      if (delta.abs() < _discreteDelta) {
        // Smooth input; apply it directly like the framework would.
        pos.pointerScroll(delta);
      } else {
        _glideTarget[pos] = glideTo;
        _glide(pos, glideTo).whenComplete(() {
          if (_glideTarget[pos] == glideTo) {
            _glideTarget[pos] = null;
          }
        });
      }
      return;
    }
  }

  /// Follows a chain of single-child wrappers (gesture detectors, listeners,
  /// pointer filters — all the boxes [Scrollable] puts around its viewport)
  /// down to the viewport itself. Returns null when the chain branches or
  /// ends first, so unrelated hit-path entries are left alone.
  RenderViewportBase? _descendToViewport(RenderBox target) {
    RenderObject? node = target;
    for (var i = 0; i < 12 && node != null; i++) {
      if (node is RenderViewportBase) return node;
      if (node is! RenderObjectWithChildMixin<RenderObject>) return null;
      node = node.child;
    }
    return null;
  }

  /// Starts (or retargets) a glide toward [to]. Uses a scroll activity that
  /// keeps accepting pointer events — [ScrollPosition.animateTo]'s activity
  /// makes [Scrollable] ignore pointers, which would hide the viewport from
  /// the hit test of any follow-up wheel tick arriving mid-glide.
  Future<void> _glide(ScrollPosition position, double to) {
    if (position is! ScrollActivityDelegate) {
      return position.animateTo(
        to,
        duration: Motion.medium,
        curve: Motion.easeOut,
      );
    }
    final activity = _GlideScrollActivity(
      position as ScrollActivityDelegate,
      from: position.pixels,
      to: to,
      duration: Motion.medium,
      curve: Motion.easeOut,
      vsync: this,
    );
    position.beginActivity(activity);
    return activity.done;
  }

  /// The signed scroll delta for a viewport pointing in [axisDirection],
  /// with the same axis-flip modifier handling as [Scrollable].
  double _deltaFor(PointerScrollEvent event, AxisDirection axisDirection) {
    final flipAxes =
        event.kind == PointerDeviceKind.mouse &&
        HardwareKeyboard.instance.logicalKeysPressed.any(
          ScrollConfiguration.of(context).pointerAxisModifiers.contains,
        );
    var axis = axisDirectionToAxis(axisDirection);
    if (flipAxes) axis = flipAxis(axis);
    final delta = switch (axis) {
      Axis.horizontal => event.scrollDelta.dx,
      Axis.vertical => event.scrollDelta.dy,
    };
    return axisDirectionIsReversed(axisDirection) ? -delta : delta;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: _onPointerSignal,
      onPointerPanZoomStart: (_) {
        if (!_trackpadMode) setState(() => _trackpadMode = true);
      },
      child: ScrollConfiguration(
        behavior: _trackpadMode
            ? const MaterialScrollBehavior()
            : const _WheelInterceptScrollBehavior(),
        child: widget.child,
      ),
    );
  }
}

/// Default behavior, except every scrollable gets [_WheelInterceptPhysics]
/// as its base physics and a scrollbar that still works with them.
class _WheelInterceptScrollBehavior extends MaterialScrollBehavior {
  const _WheelInterceptScrollBehavior();

  /// The [ClampingScrollPhysics] parent supplies boundary conditions and
  /// ballistic snap-back: without a parent the physics have neither, so a
  /// content shrink mid-glide could strand the position past the end of the
  /// content, leaving the scrollable stuck until an opposite wheel tick.
  /// [NeverScrollableScrollPhysics]' user-offset rejection is unaffected.
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const _WheelInterceptPhysics(parent: ClampingScrollPhysics());

  /// The framework scrollbar refuses thumb drags and track taps whenever the
  /// physics reject user offsets ([RawScrollbarState.handleThumbPressUpdate]
  /// checks [ScrollPhysics.shouldAcceptUserOffset]) — which
  /// [_WheelInterceptPhysics] must do to keep wheel events away from the
  /// scrollables. Build a scrollbar that drives the position directly.
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        switch (getPlatform(context)) {
          case TargetPlatform.linux:
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
            return _DraggableScrollbar(
              controller: details.controller,
              child: child,
            );
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
            return child;
        }
    }
  }
}

/// A Material-look scrollbar whose thumb drag and track taps move the
/// [ScrollPosition] through [ScrollPosition.jumpTo]/[ScrollPosition.animateTo]
/// (which ignore physics) instead of the user-offset pipeline that
/// [_WheelInterceptPhysics] blocks.
class _DraggableScrollbar extends RawScrollbar {
  const _DraggableScrollbar({super.controller, required super.child});

  @override
  RawScrollbarState<_DraggableScrollbar> createState() =>
      _DraggableScrollbarState();
}

class _DraggableScrollbarState extends RawScrollbarState<_DraggableScrollbar> {
  late final AnimationController _hoverController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(updateScrollbarPainter);

  bool _dragging = false;
  bool _hovering = false;

  /// Pointer offset and thumb track offset at the start of the active drag.
  Offset? _dragStartPointer;
  double? _dragStartThumbOffset;

  ScrollPosition? get _targetPosition {
    final controller =
        widget.controller ?? PrimaryScrollController.maybeOf(context);
    if (controller == null || !controller.hasClients) return null;
    return controller.position;
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  void updateScrollbarPainter() {
    // The Material desktop scrollbar palette (idle/hover/drag), derived from
    // the active color scheme so custom themes are respected.
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final dark = colorScheme.brightness == Brightness.dark;
    final idle = onSurface.withValues(alpha: dark ? 0.3 : 0.1);
    final hover = onSurface.withValues(alpha: dark ? 0.65 : 0.5);
    final drag = onSurface.withValues(alpha: dark ? 0.75 : 0.6);
    scrollbarPainter
      ..color = _dragging
          ? drag
          : Color.lerp(idle, hover, _hoverController.value)!
      ..textDirection = Directionality.of(context)
      ..thickness = 8
      ..radius = const Radius.circular(8)
      ..crossAxisMargin = 2
      ..minLength = 48
      ..padding = MediaQuery.paddingOf(context)
      ..ignorePointer = !enableGestures;
  }

  @override
  void handleThumbPressStart(Offset localPosition) {
    super.handleThumbPressStart(localPosition);
    _dragStartPointer = localPosition;
    _dragStartThumbOffset = scrollbarPainter.getThumbScrollOffset();
    _dragging = true;
    updateScrollbarPainter();
  }

  @override
  void handleThumbPressUpdate(Offset localPosition) {
    super.handleThumbPressUpdate(localPosition);
    final position = _targetPosition;
    final startPointer = _dragStartPointer;
    final startThumbOffset = _dragStartThumbOffset;
    if (position == null || startPointer == null || startThumbOffset == null) {
      return;
    }
    // Same track-to-scroll mapping as the framework's thumb drag, so the
    // thumb tracks the pointer exactly.
    final primaryDelta = switch (position.axisDirection) {
      AxisDirection.up => startPointer.dy - localPosition.dy,
      AxisDirection.down => localPosition.dy - startPointer.dy,
      AxisDirection.left => startPointer.dx - localPosition.dx,
      AxisDirection.right => localPosition.dx - startPointer.dx,
    };
    final target = clampDouble(
      scrollbarPainter.getTrackToScroll(startThumbOffset + primaryDelta),
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) position.jumpTo(target);
  }

  @override
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    super.handleThumbPressEnd(localPosition, velocity);
    _dragStartPointer = null;
    _dragStartThumbOffset = null;
    _dragging = false;
    updateScrollbarPainter();
  }

  @override
  void handleTrackTapDown(TapDownDetails details) {
    super.handleTrackTapDown(details);
    final position = _targetPosition;
    final box = context.findRenderObject() as RenderBox?;
    final extent = position == null
        ? 0.0
        : position.maxScrollExtent - position.minScrollExtent;
    if (position == null || box == null || !box.hasSize || extent <= 0) {
      return;
    }
    // Page towards the tap. The tap side is decided by scroll fraction (the
    // painted thumb offset is private), which can only misjudge taps within
    // half a thumb length of the thumb.
    final vertical =
        axisDirectionToAxis(position.axisDirection) == Axis.vertical;
    final trackLength = vertical ? box.size.height : box.size.width;
    final tapOffset = vertical
        ? details.localPosition.dy
        : details.localPosition.dx;
    if (trackLength <= 0) return;
    var tapFraction = clampDouble(tapOffset / trackLength, 0, 1);
    if (axisDirectionIsReversed(position.axisDirection)) {
      tapFraction = 1 - tapFraction;
    }
    final scrollFraction =
        (position.pixels - position.minScrollExtent) / extent;
    // Same increment as ScrollIncrementType.page.
    final page = 0.8 * position.viewportDimension;
    position.animateTo(
      clampDouble(
        position.pixels + (tapFraction > scrollFraction ? page : -page),
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
    );
  }

  @override
  void handleHover(PointerHoverEvent event) {
    super.handleHover(event);
    final over = isPointerOverScrollbar(
      event.position,
      event.kind,
      forHover: true,
    );
    if (over != _hovering) {
      _hovering = over;
      over ? _hoverController.forward() : _hoverController.reverse();
    }
  }

  @override
  void handleHoverExit(PointerExitEvent event) {
    super.handleHoverExit(event);
    if (_hovering) {
      _hovering = false;
      _hoverController.reverse();
    }
  }
}

/// A [DrivenScrollActivity] that keeps the viewport hit-testable while it
/// runs, so consecutive wheel ticks can find the scrollable mid-glide and
/// accumulate instead of being dropped.
class _GlideScrollActivity extends DrivenScrollActivity {
  _GlideScrollActivity(
    super.delegate, {
    required super.from,
    required super.to,
    required super.duration,
    required super.curve,
    required super.vsync,
  });

  @override
  bool get shouldIgnorePointer => false;
}

/// Rejects user offsets so scrollables neither claim wheel events nor
/// start drag gestures, while programmatic and accessibility-driven
/// scrolling (animateTo, ensureVisible) keeps working. Scrollbar dragging
/// also consults [shouldAcceptUserOffset], so [_DraggableScrollbar] bypasses
/// the user-offset pipeline entirely.
class _WheelInterceptPhysics extends NeverScrollableScrollPhysics {
  const _WheelInterceptPhysics({super.parent});

  @override
  _WheelInterceptPhysics applyTo(ScrollPhysics? ancestor) =>
      _WheelInterceptPhysics(parent: buildParent(ancestor));

  @override
  bool get allowImplicitScrolling => true;
}
