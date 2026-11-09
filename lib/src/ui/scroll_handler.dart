import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/core.dart';
import 'package:xterm/src/ui/scroll_unit.dart';

/// Whether the program in the terminal wants the scroll for itself.
///
/// The alternate screen buffer has no scrollback to scroll, and a program
/// that reports the wheel wants the wheel — both mean the scroll is the
/// program's and not the terminal's.
///
/// The one answer to this question in the package: the handler outside the
/// scrollable forwards the scroll to the program when it is true, and the
/// handler inside it scrolls the scrollback when it is not, and the two must
/// not disagree about which is which.
bool terminalWantsScroll(Terminal terminal) {
  if (terminal.isUsingAltBuffer) return true;
  final mode = terminal.mouseMode;
  return mode != MouseMode.none && mode.reportScroll;
}

/// Handles scrolling gestures when the terminal application declares support
/// for mouse tracking (alt screen buffer or mouse mode with scroll reporting).
///
/// When the terminal is in alternate screen buffer, there is no scrollback, so
/// scroll gestures are converted to escape sequences (mouse wheel events or
/// arrow key simulation).
///
/// When the terminal is in main screen buffer but has enabled mouse scroll
/// reporting, scroll gestures are forwarded to the application as mouse events
/// and the inner scrollable is suppressed (via [NeverScrollableScrollPhysics]
/// in [TerminalView]).
///
/// When neither condition is met, normal scrollback scrolling is used.
class TerminalScrollGestureHandler extends StatefulWidget {
  const TerminalScrollGestureHandler({
    super.key,
    required this.terminal,
    required this.getCellOffset,
    required this.getLineHeight,
    this.simulateScroll = true,
    this.readOnly = false,
    required this.child,
  });

  final Terminal terminal;

  /// Whether the program is left alone: a scroll it asked for is not sent.
  final bool readOnly;

  /// Returns the cell offset for the pixel offset.
  final CellOffset Function(Offset) getCellOffset;

  /// Returns the pixel height of lines in the terminal.
  final double Function() getLineHeight;

  /// Whether to simulate scroll events in the terminal when the application
  /// doesn't declare it supports mouse wheel events. true by default as it
  /// is the default behavior of most terminals.
  final bool simulateScroll;

  final Widget child;

  @override
  State<TerminalScrollGestureHandler> createState() =>
      _TerminalScrollGestureHandlerState();
}

class _TerminalScrollGestureHandlerState
    extends State<TerminalScrollGestureHandler> {
  var isAltBuffer = false;
  var lastPointerPosition = Offset.zero;
  var _mouseMode = MouseMode.none;

  final _lines = TerminalScrollLines();
  double? _lastTouchY;

  /// Whether scroll events should be intercepted and forwarded to the terminal
  /// instead of being handled by the inner scrollable.
  bool get _shouldForwardScroll => terminalWantsScroll(widget.terminal);

  bool _isTouchPointer(PointerDeviceKind kind) {
    return kind == PointerDeviceKind.touch || kind == PointerDeviceKind.stylus;
  }

  @override
  void initState() {
    widget.terminal.addListener(_onTerminalUpdated);
    isAltBuffer = widget.terminal.isUsingAltBuffer;
    _mouseMode = widget.terminal.mouseMode;
    super.initState();
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_onTerminalUpdated);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TerminalScrollGestureHandler oldWidget) {
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onTerminalUpdated);
      widget.terminal.addListener(_onTerminalUpdated);
      isAltBuffer = widget.terminal.isUsingAltBuffer;
      _mouseMode = widget.terminal.mouseMode;
    }
    super.didUpdateWidget(oldWidget);
  }

  void _onTerminalUpdated() {
    final newIsAltBuffer = widget.terminal.isUsingAltBuffer;
    final newMouseMode = widget.terminal.mouseMode;
    if (isAltBuffer != newIsAltBuffer || _mouseMode != newMouseMode) {
      isAltBuffer = newIsAltBuffer;
      _mouseMode = newMouseMode;
      _lines.reset();
      _lastTouchY = null;
      setState(() {});
    }
  }

  /// Process a raw scroll delta from [PointerScrollEvent], accumulating
  /// fractional scrolls and dispatching discrete scroll events per line.
  void _handleScrollDelta(
    double dy, {
    bool fromTouch = false,
    bool fromTrackpad = false,
  }) {
    final lineHeight = widget.getLineHeight();
    if (lineHeight <= 0) return;

    // A finger on the screen moves three lines of travel for each line it
    // reports; one on a trackpad, a line of travel for a line.
    final pixelsPerLine = fromTouch
        ? lineHeight * 3
        : fromTrackpad
        ? lineHeight
        : TerminalScrollUnit.pixelsPerLine ??
              lineHeight;
    final lines = _lines.add(dy, pixelsPerLine);
    for (var i = 0; i < lines.abs(); i++) {
      _sendScrollEvent(lines < 0);
    }
  }

  /// Send a single scroll event to the terminal. The event is first offered to
  /// terminal mouse reporting, and if that does not consume it and
  /// [simulateScroll] is enabled, this falls back to sending up/down arrow
  /// keys.
  ///
  /// The fallback is decided by whether `mouseInput` reported the wheel, not by
  /// whether mouse mode is on. An application can have mouse mode enabled in a
  /// form that does not report scrolling, and it still gets the arrow keys.
  void _sendScrollEvent(bool up) {
    final position = widget.getCellOffset(lastPointerPosition);
    final handled = widget.terminal.mouseInput(
      up ? TerminalMouseButton.wheelUp : TerminalMouseButton.wheelDown,
      TerminalMouseButtonState.down,
      position,
    );

    if (!handled && widget.simulateScroll) {
      widget.terminal.keyInput(
        up ? TerminalKey.arrowUp : TerminalKey.arrowDown,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldForwardScroll || widget.readOnly) {
      return widget.child;
    }

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          lastPointerPosition = event.localPosition;
          // The resolver gives a signal to the first listener that asks for
          // it, and this is the one that asks: the program in the terminal
          // wanted the wheel, and the scrollable inside has been told not to
          // scroll.
          GestureBinding.instance.pointerSignalResolver.register(
            event,
            (event) {
              event.respond(allowPlatformDefault: false);
              _handleScrollDelta((event as PointerScrollEvent).scrollDelta.dy);
            },
          );
        }
      },
      // A trackpad's scroll is a pan, never a scroll signal: without this the
      // program asking for the wheel got nothing from one.
      onPointerPanZoomUpdate: (event) {
        lastPointerPosition = event.localPosition;
        _handleScrollDelta(-event.localPanDelta.dy, fromTrackpad: true);
      },
      onPointerDown: (event) {
        lastPointerPosition = event.localPosition;
        if (_isTouchPointer(event.kind)) {
          _lastTouchY = event.position.dy;
        }
      },
      onPointerMove: (event) {
        if (_lastTouchY != null && _isTouchPointer(event.kind)) {
          final dy = _lastTouchY! - event.position.dy;
          lastPointerPosition = event.localPosition;
          _handleScrollDelta(dy, fromTouch: true);
          _lastTouchY = event.position.dy;
        }
      },
      onPointerUp: (event) {
        _lastTouchY = null;
      },
      onPointerCancel: (event) {
        _lastTouchY = null;
      },
      child: widget.child,
    );
  }
}

/// Scrolls the terminal's scrollback with the wheel, by whole lines.
///
/// Inside the [Scrollable] on purpose. A pointer signal is resolved by the
/// first listener that is hit, and the listener a [Scrollable] puts around
/// its viewport is deeper than the one around the scrollable itself — so
/// being inside is what lets this take the wheel before the scrollable does,
/// and that is the only way to scroll by whole lines rather than by whatever
/// number of pixels the platform's wheel happens to be.
///
/// The other half of the scroll is [TerminalScrollGestureHandler], outside the
/// scrollable, which forwards the scroll to the program in the terminal when
/// the program asked for the wheel. Only one of the two is ever asked to
/// scroll: this one when the program did not.
class TerminalScrollbackHandler extends StatefulWidget {
  const TerminalScrollbackHandler({
    super.key,
    required this.terminal,
    required this.controller,
    required this.getLineHeight,
    required this.enabled,
    required this.child,
  });

  /// The terminal being shown: another one starts with nothing pending.
  final Terminal terminal;

  /// The scroll controller of the scrollable this scrolls.
  final ScrollController controller;

  /// Returns the pixel height of lines in the terminal.
  final double Function() getLineHeight;

  /// Whether this is the one that takes the scroll.
  ///
  /// False when the program in the terminal asked for the wheel itself, which
  /// is the same question [terminalWantsScroll] answers.
  final bool enabled;

  final Widget child;

  @override
  State<TerminalScrollbackHandler> createState() =>
      _TerminalScrollbackHandlerState();
}

class _TerminalScrollbackHandlerState extends State<TerminalScrollbackHandler> {
  final _lines = TerminalScrollLines();

  @override
  void didUpdateWidget(covariant TerminalScrollbackHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.terminal != widget.terminal ||
        oldWidget.controller != widget.controller ||
        oldWidget.enabled != widget.enabled) {
      _lines.reset();
    }
  }

  /// Whether the scrollback can move the way [dy] asks. At an end the wheel
  /// is left to whatever scrolls around the terminal, as a scrollable leaves
  /// it.
  bool _canScroll(double dy) {
    if (dy == 0 || !widget.controller.hasClients) return false;
    final position = widget.controller.position;
    return dy < 0
        ? position.pixels > position.minScrollExtent
        : position.pixels < position.maxScrollExtent;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        if (!widget.enabled || !_canScroll(event.scrollDelta.dy)) return;
        // The resolver gives a signal to the first listener that asks for it.
        // This is the first one asked — it is inside the scrollable, and the
        // scrollable's own listener is further out — so the scrollable never
        // scrolls by its own pixels and this scrolls by whole lines instead.
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          (event) {
            event.respond(allowPlatformDefault: false);
            _scrollBy((event as PointerScrollEvent).scrollDelta.dy);
          },
        );
      },
      child: widget.child,
    );
  }

  void _scrollBy(double pixels) {
    final lineHeight = widget.getLineHeight();
    if (lineHeight <= 0) return;
    final pixelsPerLine =
        TerminalScrollUnit.pixelsPerLine ?? lineHeight;
    final lines = _lines.add(pixels, pixelsPerLine);
    if (lines == 0 || !widget.controller.hasClients) return;
    widget.controller.position.pointerScroll(lines * lineHeight);
  }
}
