import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/cell_flags.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/theme/terminal_style.dart';
import 'package:xterm/utli/bit_flags.dart';

import 'char_size.dart';
import 'oscillator.dart';
import 'cache.dart';

class TerminalPainter extends CustomPainter {
  TerminalPainter({
    required this.terminal,
    required this.style,
    required this.charSize,
  });

  final Terminal terminal;
  final TerminalStyle style;
  final CellSize charSize;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas);

    // if (oscillator.value) {
    // }

    _paintText(canvas);

    _paintSelection(canvas);
  }

  void _paintBackground(Canvas canvas) {
    final lines = terminal.getVisibleLines();

    for (var row = 0; row < lines.length; row++) {
      final line = lines[row];
      final offsetY = row * charSize.cellHeight;
      // final cellCount = math.min(terminal.viewWidth, line.length);
      final cellCount = terminal.viewWidth;

      for (var col = 0; col < cellCount; col++) {
        final cellWidth = line.cellGetWidth(col);
        if (cellWidth == 0) {
          continue;
        }

        final cellFgColor = line.cellGetFgColor(col);
        final cellBgColor = line.cellGetBgColor(col);
        final effectBgColor = line.cellHasFlag(col, CellFlags.inverse)
            ? cellFgColor
            : cellBgColor;

        if (effectBgColor == 0x00) {
          continue;
        }

        // final cellFlags = line.cellGetFlags(i);
        // final cell = line.getCell(i);
        // final attr = cell.attr;

        final offsetX = col * charSize.cellWidth;
        final effectWidth = charSize.cellWidth * cellWidth + 1;
        final effectHeight = charSize.cellHeight + 1;

        // background color is already painted with opacity by the Container of
        // TerminalPainter so wo don't need to fallback to
        // terminal.theme.background here.

        final paint = Paint()..color = Color(effectBgColor);
        canvas.drawRect(
          Rect.fromLTWH(offsetX, offsetY, effectWidth, effectHeight),
          paint,
        );
      }
    }
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

  void _paintText(Canvas canvas) {
    final lines = terminal.getVisibleLines();

    for (var row = 0; row < lines.length; row++) {
      final line = lines[row];
      final offsetY = row * charSize.cellHeight;
      // final cellCount = math.min(terminal.viewWidth, line.length);
      final cellCount = terminal.viewWidth;

      for (var col = 0; col < cellCount; col++) {
        final width = line.cellGetWidth(col);

        if (width == 0) {
          continue;
        }

        final offsetX = col * charSize.cellWidth;
        _paintCell(canvas, line, col, offsetX, offsetY);
      }
    }
  }

  void _paintCell(
    Canvas canvas,
    BufferLine line,
    int cell,
    double offsetX,
    double offsetY,
  ) {
    final codePoint = line.cellGetContent(cell);
    final fgColor = line.cellGetFgColor(cell);
    final bgColor = line.cellGetBgColor(cell);
    final flags = line.cellGetFlags(cell);

    if (codePoint == 0 || flags.hasFlag(CellFlags.invisible)) {
      return;
    }

    // final cellHash = line.cellGetHash(cell);
    final cellHash = hashValues(codePoint, fgColor, bgColor, flags);

    var tp = textLayoutCache.getLayoutFromCache(cellHash);
    if (tp != null) {
      tp.paint(canvas, Offset(offsetX, offsetY));
      return;
    }

    final cellColor = flags.hasFlag(CellFlags.inverse) ? bgColor : fgColor;

    var color = Color(cellColor);

    if (flags & CellFlags.faint != 0) {
      color = color.withOpacity(0.5);
    }

    final styleToUse = (style.textStyleProvider != null)
        ? style.textStyleProvider!(
            color: color,
            fontSize: style.fontSize,
            fontWeight: flags.hasFlag(CellFlags.bold)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: flags.hasFlag(CellFlags.italic)
                ? FontStyle.italic
                : FontStyle.normal,
            decoration: flags.hasFlag(CellFlags.underline)
                ? TextDecoration.underline
                : TextDecoration.none,
          )
        : TextStyle(
            color: color,
            fontSize: style.fontSize,
            fontWeight: flags.hasFlag(CellFlags.bold)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: flags.hasFlag(CellFlags.italic)
                ? FontStyle.italic
                : FontStyle.normal,
            decoration: flags.hasFlag(CellFlags.underline)
                ? TextDecoration.underline
                : TextDecoration.none,
            fontFamily: 'monospace',
            fontFamilyFallback: style.fontFamily,
          );

    final span = TextSpan(
      text: String.fromCharCode(codePoint),
      // text: codePointCache.getOrConstruct(cell.codePoint),
      style: styleToUse,
    );

    // final tp = textLayoutCache.getOrPerformLayout(span);
    tp = textLayoutCache.performAndCacheLayout(span, cellHash);

    tp.paint(canvas, Offset(offsetX, offsetY));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    /// paint only when the terminal has changed since last paint.
    return terminal.dirty;
  }
}

class CursorPainter extends CustomPainter {
  final bool visible;
  final CellSize charSize;
  final bool focused;
  final bool blinkVisible;
  final int cursorColor;

  CursorPainter({
    required this.visible,
    required this.charSize,
    required this.focused,
    required this.blinkVisible,
    required this.cursorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (blinkVisible && visible) {
      _paintCursor(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is CursorPainter) {
      return blinkVisible != oldDelegate.blinkVisible ||
          focused != oldDelegate.focused ||
          visible != oldDelegate.visible ||
          charSize.cellWidth != oldDelegate.charSize.cellWidth ||
          charSize.cellHeight != oldDelegate.charSize.cellHeight;
    }
    return true;
  }

  void _paintCursor(Canvas canvas) {
    final paint = Paint()
      ..color = Color(cursorColor)
      ..strokeWidth = focused ? 0.0 : 1.0
      ..style = focused ? PaintingStyle.fill : PaintingStyle.stroke;

    canvas.drawRect(
        Rect.fromLTWH(0, 0, charSize.cellWidth, charSize.cellHeight), paint);
  }
}
