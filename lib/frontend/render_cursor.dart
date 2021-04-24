import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/frontend/cell_size.dart';
import 'package:xterm/frontend/oscillator.dart';
import 'package:xterm/frontend/renderer.dart';
import 'package:xterm/terminal/terminal.dart';

class RenderCursor implements TerminalRenderer {
  RenderCursor({
    required this.blink,
    required this.terminal,
    required this.charSize,
    required this.hasFocus,
  });

  final Oscillator blink;
  final Terminal terminal;
  final CellSize charSize;
  final bool hasFocus;

  @override
  void paint(Canvas canvas, Size size) {
    if (_vislble) {
      _paintCursor(canvas);
    }
  }

  void _paintCursor(Canvas canvas) {
    final paint = Paint()
      ..color = _color
      ..strokeWidth = hasFocus ? 0.0 : 1.0
      ..style = hasFocus ? PaintingStyle.fill : PaintingStyle.stroke;

    final offset = _getCursorOffset();

    final rect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      charSize.cellWidth,
      charSize.cellHeight,
    );

    canvas.drawRect(rect, paint);
  }

  bool get _vislble {
    if (blink.value == false) {
      return false;
    }

    final screenCursorY = terminal.cursorY + terminal.scrollOffset;

    if (screenCursorY < 0 || screenCursorY >= terminal.viewHeight) {
      return false;
    }

    return terminal.showCursor;
  }

  Offset _getCursorOffset() {
    final screenCursorY = terminal.cursorY + terminal.scrollOffset;
    final offsetX = charSize.cellWidth * terminal.cursorX;
    final offsetY = charSize.cellHeight * screenCursorY;

    return Offset(offsetX, offsetY);
  }

  Color get _color {
    return Color(terminal.theme.cursor);
  }
}
