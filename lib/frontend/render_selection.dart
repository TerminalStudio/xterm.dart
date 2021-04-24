import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/frontend/cell_size.dart';
import 'package:xterm/frontend/renderer.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/terminal/terminal.dart';

class RenderSelection implements TerminalRenderer {
  RenderSelection({
    required this.terminal,
    required this.charSize,
  });

  final Terminal terminal;
  final CellSize charSize;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSelection(canvas);
  }

  void _paintSelection(Canvas canvas) {
    final paint = Paint()..color = Colors.white.withOpacity(0.3);

    for (var y = 0; y < terminal.viewHeight; y++) {
      final offsetY = y * charSize.cellHeight;
      final absoluteY = terminal.buffer.convertViewLineToRawLine(y) -
          terminal.buffer.scrollOffsetFromBottom;

      for (var x = 0; x < terminal.viewWidth; x++) {
        var cellCount = 0;

        while (
            terminal.selection.contains(Position(x + cellCount, absoluteY)) &&
                x + cellCount < terminal.viewWidth) {
          cellCount++;
        }

        if (cellCount == 0) {
          continue;
        }

        final offsetX = x * charSize.cellWidth;
        final effectWidth = cellCount * charSize.cellWidth;
        final effectHeight = charSize.cellHeight;

        canvas.drawRect(
          Rect.fromLTWH(offsetX, offsetY, effectWidth, effectHeight),
          paint,
        );

        x += cellCount;
      }
    }
  }
}
