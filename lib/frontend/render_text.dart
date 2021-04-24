import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/cell_flags.dart';
import 'package:xterm/frontend/renderer.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/theme/terminal_style.dart';
import 'package:xterm/util/bit_flags.dart';

import 'cell_size.dart';
import 'cache.dart';

class RenderText implements TerminalRenderer {
  RenderText({
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

    _paintText(canvas);
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

    var paragraph = textLayoutCache.getLayoutFromCache(cellHash);
    if (paragraph != null) {
      canvas.drawParagraph(paragraph, Offset(offsetX, offsetY));
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

    paragraph = textLayoutCache.performAndCacheLayout(
        String.fromCharCode(codePoint), styleToUse, cellHash);

    canvas.drawParagraph(paragraph, Offset(offsetX, offsetY));
  }
}
