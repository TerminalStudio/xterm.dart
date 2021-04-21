import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:xterm/frontend/cell_size.dart';
import 'package:xterm/frontend/input/input_listener.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/xterm.dart';

class TerminalMouseLayer extends StatelessWidget {
  TerminalMouseLayer({
    required this.terminal,
    required this.child,
    required this.cellSize,
  });

  final Terminal terminal;
  final Widget child;
  final CellSize cellSize;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        dragStartBehavior: DragStartBehavior.down,
        onDoubleTapDown: (details) {
          print('details : $details');
        },
        onTapDown: (detail) {
          if (terminal.selection.isEmpty) {
            InputListener.of(context)!.requestKeyboard();
          } else {
            terminal.selection.clear();
          }
          final pos = detail.localPosition;
          final offset = _getMouseOffset(pos.dx, pos.dy);
          terminal.mouseMode.onTap(terminal, offset);
          terminal.refresh();
        },
        onPanStart: (detail) {
          final pos = detail.localPosition;
          final offset = _getMouseOffset(pos.dx, pos.dy);
          terminal.mouseMode.onPanStart(terminal, offset);
          terminal.refresh();
        },
        onPanUpdate: (detail) {
          final pos = detail.localPosition;
          final offset = _getMouseOffset(pos.dx, pos.dy);
          terminal.mouseMode.onPanUpdate(terminal, offset);
          terminal.refresh();
        },
        child: child,
      ),
    );
  }

  /// Get global cell position from mouse position.
  Position _getMouseOffset(double px, double py) {
    final col = px ~/ cellSize.cellWidth;
    final row = py ~/ cellSize.cellHeight;

    final x = col;
    final y = terminal.buffer.convertViewLineToRawLine(row) -
        terminal.buffer.scrollOffsetFromBottom;

    return Position(x, y);
  }
}
