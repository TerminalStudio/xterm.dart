import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/src/core/mouse/button.dart';
import 'package:xterm/src/core/mouse/button_state.dart';
import 'package:xterm/src/terminal_view.dart';
import 'package:xterm/src/ui/controller.dart';
import 'package:xterm/src/ui/gesture/gesture_detector.dart';
import 'package:xterm/src/ui/pointer_input.dart';
import 'package:xterm/src/ui/render.dart';

class TerminalGestureHandler extends StatefulWidget {
  const TerminalGestureHandler({
    super.key,
    required this.terminalView,
    required this.terminalController,
    this.child,
    this.onTapUp,
    this.onSingleTapUp,
    this.onTapDown,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onTertiaryTapDown,
    this.onTertiaryTapUp,
  });

  final TerminalViewState terminalView;

  final TerminalController terminalController;

  final Widget? child;

  final GestureTapUpCallback? onTapUp;

  final GestureTapUpCallback? onSingleTapUp;

  final GestureTapDownCallback? onTapDown;

  final GestureTapDownCallback? onSecondaryTapDown;

  final GestureTapUpCallback? onSecondaryTapUp;

  final GestureTapDownCallback? onTertiaryTapDown;

  final GestureTapUpCallback? onTertiaryTapUp;

  @override
  State<TerminalGestureHandler> createState() => _TerminalGestureHandlerState();
}

class _TerminalGestureHandlerState extends State<TerminalGestureHandler> {
  TerminalViewState get terminalView => widget.terminalView;

  RenderTerminal get renderTerminal => terminalView.renderTerminal;

  DragStartDetails? _lastDragStartDetails;

  LongPressStartDetails? _lastLongPressStartDetails;

  @override
  Widget build(BuildContext context) {
    return TerminalGestureDetector(
      child: widget.child,
      onTapUp: widget.onTapUp,
      onSingleTapUp: onSingleTapUp,
      onTapDown: onTapDown,
      onSecondaryTapDown: onSecondaryTapDown,
      onSecondaryTapUp: onSecondaryTapUp,
      onTertiaryTapDown: onSecondaryTapDown,
      onTertiaryTapUp: onSecondaryTapUp,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      // onLongPressUp: onLongPressUp,
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onDoubleTapDown: onDoubleTapDown,
    );
  }

  bool get _shouldSendTapEvent =>
      widget.terminalController.shouldSendPointerInput(PointerInput.tap);

  void onTapDown(TapDownDetails details) {
    widget.onTapDown?.call(details);
    if (_shouldSendTapEvent) {
      renderTerminal.mouseEvent(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        details.localPosition,
      );
    }
  }

  void onSingleTapUp(TapUpDetails details) {
    widget.onSingleTapUp?.call(details);
    if (_shouldSendTapEvent) {
      renderTerminal.mouseEvent(
        TerminalMouseButton.left,
        TerminalMouseButtonState.up,
        details.localPosition,
      );
    }
  }

  void onSecondaryTapDown(TapDownDetails details) {
    widget.onSecondaryTapDown?.call(details);
    if (_shouldSendTapEvent) {
      renderTerminal.mouseEvent(
        TerminalMouseButton.right,
        TerminalMouseButtonState.down,
        details.localPosition,
      );
    }
  }

  void onSecondaryTapUp(TapUpDetails details) {
    widget.onSecondaryTapUp?.call(details);
    if (_shouldSendTapEvent) {
      renderTerminal.mouseEvent(
        TerminalMouseButton.right,
        TerminalMouseButtonState.up,
        details.localPosition,
      );
    }
  }

  void onTertiaryTapDown(TapDownDetails details) {
    widget.onTertiaryTapDown?.call(details);
    if (_shouldSendTapEvent) {
      renderTerminal.mouseEvent(
        TerminalMouseButton.middle,
        TerminalMouseButtonState.down,
        details.localPosition,
      );
    }
  }

  void onTertiaryTapUp(TapUpDetails details) {
    widget.onTertiaryTapUp?.call(details);
    if (_shouldSendTapEvent) {
      renderTerminal.mouseEvent(
        TerminalMouseButton.middle,
        TerminalMouseButtonState.up,
        details.localPosition,
      );
    }
  }

  void onDoubleTapDown(TapDownDetails details) {
    renderTerminal.selectWord(details.localPosition);
  }

  void onLongPressStart(LongPressStartDetails details) {
    _lastLongPressStartDetails = details;
    renderTerminal.selectWord(details.localPosition);
  }

  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    renderTerminal.selectWord(
      _lastLongPressStartDetails!.localPosition,
      details.localPosition,
    );
  }

  // void onLongPressUp() {}

  void onDragStart(DragStartDetails details) {
    _lastDragStartDetails = details;

    details.kind == PointerDeviceKind.mouse
        ? renderTerminal.selectCharacters(details.localPosition)
        : renderTerminal.selectWord(details.localPosition);
  }

  void onDragUpdate(DragUpdateDetails details) {
    renderTerminal.selectCharacters(
      _lastDragStartDetails!.localPosition,
      details.localPosition,
    );
  }
}
