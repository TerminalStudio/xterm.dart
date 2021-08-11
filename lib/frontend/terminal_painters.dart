import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/buffer/cell_flags.dart';
import 'package:xterm/buffer/line/line.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/terminal/terminal_ui_interaction.dart';
import 'package:xterm/theme/terminal_style.dart';
import 'package:xterm/util/bit_flags.dart';

import 'char_size.dart';
import 'cache.dart';

class TerminalPainter extends CustomPainter {
  TerminalPainter({
    required this.terminal,
    required this.style,
    required this.charSize,
    required this.textLayoutCache,
  });

  final TerminalUiInteraction terminal;
  final TerminalStyle style;
  final CellSize charSize;
  final TextLayoutCache textLayoutCache;

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
      final cellCount = terminal.terminalWidth;

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

        // when a program reports black as background then it "really" means transparent
        if (effectBgColor == 0xFF000000) {
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

    for (var y = 0; y < terminal.terminalHeight; y++) {
      final offsetY = y * charSize.cellHeight;
      final absoluteY = terminal.convertViewLineToRawLine(y) -
          terminal.scrollOffsetFromBottom;

      for (var x = 0; x < terminal.terminalWidth; x++) {
        var cellCount = 0;

        while (
            (terminal.selection?.contains(Position(x + cellCount, absoluteY)) ??
                    false) &&
                x + cellCount < terminal.terminalWidth) {
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
      final cellCount = terminal.terminalWidth;

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

    var character = textLayoutCache.getLayoutFromCache(cellHash);
    if (character != null) {
      canvas.drawParagraph(character, Offset(offsetX, offsetY));
      return;
    }

    final cellColor = flags.hasFlag(CellFlags.inverse) ? bgColor : fgColor;

    var color = Color(cellColor);

    if (flags & CellFlags.faint != 0) {
      color = color.withOpacity(0.5);
    }

    final styleToUse = PaintHelper.getStyleToUse(
      style,
      color,
      bold: flags.hasFlag(CellFlags.bold),
      italic: flags.hasFlag(CellFlags.italic),
      underline: flags.hasFlag(CellFlags.underline),
    );

    character = textLayoutCache.performAndCacheLayout(
        String.fromCharCode(codePoint), styleToUse, cellHash);

    canvas.drawParagraph(character, Offset(offsetX, offsetY));
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
  final int textColor;
  final String composingString;
  final TextLayoutCache textLayoutCache;
  final TerminalStyle style;

  CursorPainter({
    required this.visible,
    required this.charSize,
    required this.focused,
    required this.blinkVisible,
    required this.cursorColor,
    required this.textColor,
    required this.composingString,
    required this.textLayoutCache,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    bool isVisible =
        visible && (blinkVisible || composingString != '' || !focused);
    if (isVisible) {
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
          charSize.cellHeight != oldDelegate.charSize.cellHeight ||
          composingString != oldDelegate.composingString;
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

    if (composingString != '') {
      final styleToUse = PaintHelper.getStyleToUse(style, Color(textColor));
      final character = textLayoutCache.performAndCacheLayout(
          composingString, styleToUse, null);
      canvas.drawParagraph(character, Offset(0, 0));
    }
  }
}

class PaintHelper {
  static TextStyle getStyleToUse(
    TerminalStyle style,
    Color color, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
  }) {
    return (style.textStyleProvider != null)
        ? style.textStyleProvider!(
            color: color,
            fontSize: style.fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            decoration:
                underline ? TextDecoration.underline : TextDecoration.none,
          )
        : TextStyle(
            color: color,
            fontSize: style.fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            decoration:
                underline ? TextDecoration.underline : TextDecoration.none,
            fontFamily: 'monospace',
            fontFamilyFallback: style.fontFamily,
          );
  }
}
