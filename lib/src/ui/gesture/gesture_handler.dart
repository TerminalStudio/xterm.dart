import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:xterm/src/core/mouse/button.dart';
import 'package:xterm/src/core/mouse/button_state.dart';
import 'package:xterm/src/terminal_view.dart';
import 'package:xterm/src/ui/controller.dart';
import 'package:xterm/src/ui/gesture/gesture_detector.dart';
import 'package:xterm/src/ui/pointer_input.dart';
import 'package:xterm/src/ui/render.dart';
import 'package:xterm/src/ui/selection_mode.dart';
import 'package:xterm/src/core/buffer/line.dart';
import 'package:xterm/src/core/buffer/cell_offset.dart';

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
    this.readOnly = false,
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

  final bool readOnly;

  @override
  State<TerminalGestureHandler> createState() => _TerminalGestureHandlerState();
}

class _TerminalGestureHandlerState extends State<TerminalGestureHandler> {
  TerminalViewState get terminalView => widget.terminalView;

  RenderTerminal get renderTerminal => terminalView.renderTerminal;

  DragStartDetails? _lastDragStartDetails;

  LongPressStartDetails? _lastLongPressStartDetails;

  bool _isShiftPressed = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.shiftLeft || 
          event.logicalKey == LogicalKeyboardKey.shiftRight) {
        _isShiftPressed = true;
        return false;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.shiftLeft || 
          event.logicalKey == LogicalKeyboardKey.shiftRight) {
        _isShiftPressed = false;
        return false;
      }
    }
    return false;
  }

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
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onDoubleTapDown: onDoubleTapDown,
    );
  }

  bool get _shouldSendTapEvent =>
      !widget.readOnly &&
      widget.terminalController.shouldSendPointerInput(PointerInput.tap);

  void _tapDown(
    GestureTapDownCallback? callback,
    TapDownDetails details,
    TerminalMouseButton button, {
    bool forceCallback = false,
  }) {
    // Check if the terminal should and can handle the tap down event.
    var handled = false;
    if (_shouldSendTapEvent) {
      handled = renderTerminal.mouseEvent(
        button,
        TerminalMouseButtonState.down,
        details.localPosition,
      );
    }
    // If the event was not handled by the terminal, use the supplied callback.
    if (!handled || forceCallback) {
      callback?.call(details);
    }
  }

  void _tapUp(
    GestureTapUpCallback? callback,
    TapUpDetails details,
    TerminalMouseButton button, {
    bool forceCallback = false,
  }) {
    var handled = false;
    if (_shouldSendTapEvent) {
      handled = renderTerminal.mouseEvent(
        button,
        TerminalMouseButtonState.up,
        details.localPosition,
      );
    }
    // If the event was not handled by the terminal, use the supplied callback.
    if (!handled || forceCallback) {
      callback?.call(details);
    }
  }

  void onTapDown(TapDownDetails details) {
    final position = renderTerminal.getCellOffset(details.localPosition);
    if (position == null) return;

    if (_isShiftPressed) {
      final currentSelection = widget.terminalController.selection;
      final cursorX = terminalView.widget.terminal.buffer.cursorX;
      final cursorY = terminalView.widget.terminal.buffer.cursorY;
      
      final anchorPosition = currentSelection != null 
          ? currentSelection.begin 
          : CellOffset(cursorX, cursorY);
          
      final anchor = terminalView.widget.terminal.buffer.createAnchorFromOffset(anchorPosition);
      final positionAnchor = terminalView.widget.terminal.buffer.createAnchorFromOffset(position);

      if (currentSelection != null) {
        final isReversed = currentSelection.begin.y > currentSelection.end.y || 
            (currentSelection.begin.y == currentSelection.end.y && 
             currentSelection.begin.x > currentSelection.end.x);
             
        if (isReversed) {
          widget.terminalController.setSelection(
            positionAnchor,
            anchor,
            mode: SelectionMode.shift,
          );
        } else {
          widget.terminalController.setSelection(
            anchor,
            positionAnchor,
            mode: SelectionMode.shift,
          );
        }
      } else {
        if (anchorPosition.y < position.y || (anchorPosition.y == position.y && anchorPosition.x < position.x)) {
          widget.terminalController.setSelection(
            anchor,
            positionAnchor,
            mode: SelectionMode.shift,
          );
        } else {
          widget.terminalController.setSelection(
            positionAnchor,
            anchor,
            mode: SelectionMode.shift,
          );
        }
      }
    } else {
      final anchor = terminalView.widget.terminal.buffer.createAnchorFromOffset(position);
      widget.terminalController.setSelection(
        anchor,
        anchor,
        mode: SelectionMode.line,
      );
    }
  }

  void onSingleTapUp(TapUpDetails details) {
    _tapUp(widget.onSingleTapUp, details, TerminalMouseButton.left);
  }

  void onSecondaryTapDown(TapDownDetails details) {
    _tapDown(widget.onSecondaryTapDown, details, TerminalMouseButton.right);
  }

  void onSecondaryTapUp(TapUpDetails details) {
    _tapUp(widget.onSecondaryTapUp, details, TerminalMouseButton.right);
  }

  void onTertiaryTapDown(TapDownDetails details) {
    _tapDown(widget.onTertiaryTapDown, details, TerminalMouseButton.middle);
  }

  void onTertiaryTapUp(TapUpDetails details) {
    _tapUp(widget.onTertiaryTapUp, details, TerminalMouseButton.right);
  }

  void onDoubleTapDown(TapDownDetails details) {
    final position = renderTerminal.getCellOffset(details.localPosition);
    if (position == null) return;

    // Use the word selection functionality from RenderTerminal
    renderTerminal.selectWord(details.localPosition);
  }

  void onLongPressStart(LongPressStartDetails details) {
    _lastLongPressStartDetails = details;
    final position = renderTerminal.getCellOffset(details.localPosition);
    if (position == null) return;

    final anchor = terminalView.widget.terminal.buffer.createAnchorFromOffset(position);

    widget.terminalController.setSelection(
      anchor,
      anchor,
      mode: SelectionMode.block,
    );
  }

  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final position = renderTerminal.getCellOffset(details.localPosition);
    if (position == null) return;

    final selection = widget.terminalController.selection;
    if (selection == null) return;

    final anchor = terminalView.widget.terminal.buffer.createAnchorFromOffset(position);
    final beginAnchor = selection.begin is CellAnchor
        ? selection.begin as CellAnchor
        : terminalView.widget.terminal.buffer.createAnchorFromOffset(selection.begin);

    // Maintain the same selection direction as the current selection
    final isReversed = selection.begin.y > selection.end.y || 
        (selection.begin.y == selection.end.y && 
         selection.begin.x > selection.end.x);
         
    if (isReversed) {
      widget.terminalController.setSelection(
        anchor,
        beginAnchor,
        mode: SelectionMode.block,
      );
    } else {
      widget.terminalController.setSelection(
        beginAnchor,
        anchor,
        mode: SelectionMode.block,
      );
    }
  }

  void onDragStart(DragStartDetails details) {
    _lastDragStartDetails = details;
    final position = renderTerminal.getCellOffset(details.localPosition);
    if (position == null) return;

    if (_isShiftPressed) {
      // Get the current selection if it exists
      final currentSelection = widget.terminalController.selection;
      final cursorX = terminalView.widget.terminal.buffer.cursorX;
      final cursorY = terminalView.widget.terminal.buffer.cursorY;
      
      // If there's an existing selection, use its start point as the anchor
      final anchorPosition = currentSelection != null 
          ? currentSelection.begin 
          : CellOffset(cursorX, cursorY);
          
      final anchor = terminalView.widget.terminal.buffer.createAnchorFromOffset(anchorPosition);
      final positionAnchor = terminalView.widget.terminal.buffer.createAnchorFromOffset(position);

      // Always maintain the same selection direction as the current selection
      if (currentSelection != null) {
        final isReversed = currentSelection.begin.y > currentSelection.end.y || 
            (currentSelection.begin.y == currentSelection.end.y && 
             currentSelection.begin.x > currentSelection.end.x);
             
        if (isReversed) {
          widget.terminalController.setSelection(
            positionAnchor,
            anchor,
            mode: SelectionMode.shift,
          );
        } else {
          widget.terminalController.setSelection(
            anchor,
            positionAnchor,
            mode: SelectionMode.shift,
          );
        }
      } else {
        // For new selections, ensure begin is before end
        if (anchorPosition.y < position.y || (anchorPosition.y == position.y && anchorPosition.x < position.x)) {
          widget.terminalController.setSelection(
            anchor,
            positionAnchor,
            mode: SelectionMode.shift,
          );
        } else {
          widget.terminalController.setSelection(
            positionAnchor,
            anchor,
            mode: SelectionMode.shift,
          );
        }
      }
    } else {
      // Normal selection
      final anchor = terminalView.widget.terminal.buffer.createAnchorFromOffset(position);
      widget.terminalController.setSelection(
        anchor,
        anchor,
        mode: SelectionMode.line,
      );
    }
  }

  void onDragUpdate(DragUpdateDetails details) {
    final position = renderTerminal.getCellOffset(details.localPosition);
    if (position == null) return;

    final selection = widget.terminalController.selection;
    if (selection == null) return;

    if (_isShiftPressed) {
      // Get the current selection's start point as the anchor
      final anchorPosition = selection.begin;
      final anchor = terminalView.widget.terminal.buffer.createAnchorFromOffset(anchorPosition);
      final positionAnchor = terminalView.widget.terminal.buffer.createAnchorFromOffset(position);

      // Maintain the same selection direction as the current selection
      final isReversed = selection.begin.y > selection.end.y || 
          (selection.begin.y == selection.end.y && 
           selection.begin.x > selection.end.x);
           
      if (isReversed) {
        widget.terminalController.setSelection(
          positionAnchor,
          anchor,
          mode: SelectionMode.shift,
        );
      } else {
        widget.terminalController.setSelection(
          anchor,
          positionAnchor,
          mode: SelectionMode.shift,
        );
      }
    } else {
      // Normal selection
      final anchor = terminalView.widget.terminal.buffer.createAnchorFromOffset(position);
      final beginAnchor = selection.begin is CellAnchor
          ? selection.begin as CellAnchor
          : terminalView.widget.terminal.buffer.createAnchorFromOffset(selection.begin);
      widget.terminalController.setSelection(
        beginAnchor,
        anchor,
        mode: SelectionMode.line,
      );
    }
  }
}
