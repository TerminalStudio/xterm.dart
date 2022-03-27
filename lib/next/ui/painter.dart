import 'package:flutter/material.dart';
import 'package:xterm/buffer/cell_flags.dart';
import 'package:xterm/next/core/cell.dart';
import 'package:xterm/next/core/line.dart';
import 'package:xterm/next/ui/cursor_type.dart';
import 'package:xterm/next/ui/paragraph_cache.dart';
import 'package:xterm/next/ui/terminal_text_style.dart';
import 'package:xterm/next/ui/terminal_theme.dart';

// Widget child = ListView.builder(
//   padding: widget.padding,
//   itemExtent: charMetrics.height,
//   cacheExtent: 1200,
//   itemCount: lines.length,
//   addAutomaticKeepAlives: false,
//   addRepaintBoundaries: false,
//   addSemanticIndexes: false,
//   itemBuilder: (context, index) {
//     return TerminalLineView(
//       lines[index],
//       theme: widget.theme,
//       palette: colorPalette,
//       textStyle: widget.textStyle,
//       charMetrics: charMetrics,
//       paragraphCache: paragraphCache,
//       cursorPosition: index == cursorY ? cursorX : null,
//       cursorType: widget.cursorType,
//       cursorVisible: terminal.cursorVisibleMode,
//       hasFocus: focusNode.hasFocus,
//       backgroundOpacity: widget.backgroundOpacity,
//       alwaysShowCursor: widget.alwaysShowCursor,
//     );
//   },
// );

class TerminalLineView extends StatelessWidget {
  const TerminalLineView(
    this.line, {
    Key? key,
    required this.theme,
    required this.palette,
    required this.textStyle,
    required this.charMetrics,
    required this.paragraphCache,
    this.cursorPosition,
    required this.cursorType,
    required this.cursorVisible,
    required this.hasFocus,
    this.backgroundOpacity = 1,
    this.alwaysShowCursor = false,
  }) : super(key: key);

  final BufferLine line;

  final TerminalTheme theme;

  final List<Color> palette;

  final TerminalStyle textStyle;

  final Size charMetrics;

  final ParagraphCache paragraphCache;

  final int? cursorPosition;

  final bool cursorVisible;

  final TerminalCursorType cursorType;

  final bool hasFocus;

  final double backgroundOpacity;

  final bool alwaysShowCursor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TerminalLinePainter(this),
    );
  }
}

class _TerminalLinePainter extends CustomPainter {
  final TerminalLineView widget;

  _TerminalLinePainter(this.widget);

  @override
  void paint(Canvas canvas, Size size) {
    paintBackground(canvas, size);
    paintForeground(canvas, size);
    paintCursor(canvas, size);
    // canvas.transform
    // canvas.saveLayer(bounds, paint)
  }

  void paintBackground(Canvas canvas, Size size) {
    final step = widget.charMetrics.width;

    final line = widget.line;

    final cellData = CellData.empty();

    if (widget.backgroundOpacity != 1) {
      canvas.saveLayer(null,
          Paint()..color = Color.fromRGBO(0, 0, 0, widget.backgroundOpacity));
    }

    for (var i = 0; i < line.length; i++) {
      line.getCellData(i, cellData);

      late Color color;
      final colorType = cellData.background & CellColor.typeMask;

      if (cellData.flags & CellFlags.inverse != 0) {
        color = resolveForegroundColor(cellData.foreground);
      } else if (colorType == CellColor.normal) {
        continue;
      } else {
        color = resolveBackgroundColor(cellData.background);
      }

      final paint = Paint()..color = color;
      canvas.drawRect(Rect.fromLTWH(i * step, 0, step + 1, size.height), paint);
    }

    if (widget.backgroundOpacity != 1) {
      canvas.restore();
    }
  }

  void paintForeground(Canvas canvas, Size size) {
    final step = widget.charMetrics.width;
    final cache = widget.paragraphCache;
    final line = widget.line;
    final textStyle = widget.textStyle;

    final cellData = CellData.empty();

    for (var i = 0; i < line.length; i++) {
      line.getCellData(i, cellData);

      final hash = cellData.getHash();
      final charWidth = cellData.content >> CellContent.widthShift;

      var paragraph = cache.getLayoutFromCache(hash);
      if (paragraph == null) {
        final charCode = cellData.content & CellContent.codepointMask;
        final cellFlags = cellData.flags;

        final color = cellFlags & CellFlags.inverse == 0
            ? resolveForegroundColor(cellData.foreground)
            : resolveBackgroundColor(cellData.background);

        final style = textStyle.toTextStyle(
          color: color,
          bold: cellFlags & CellFlags.bold != 0,
          italic: cellFlags & CellFlags.italic != 0,
          underline: cellFlags & CellFlags.underline != 0,
        );

        paragraph = cache.performAndCacheLayout(
            String.fromCharCode(charCode), style, hash);
      }

      canvas.drawParagraph(paragraph, Offset(i * step, 0));

      if (charWidth == 2) {
        i++;
      }
    }
  }

  void paintCursor(Canvas canvas, Size size) {
    final cursorPosition = widget.cursorPosition;

    if (cursorPosition == null) {
      return;
    }

    if (!widget.alwaysShowCursor && !widget.cursorVisible) {
      return;
    }

    final width = widget.charMetrics.width;
    final offset = cursorPosition * width;

    final paint = Paint()
      ..color = widget.theme.cursor
      ..strokeWidth = 1;

    if (!widget.hasFocus) {
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(Rect.fromLTWH(offset, 0, width, size.height), paint);
      return;
    }

    switch (widget.cursorType) {
      case TerminalCursorType.block:
        paint.style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTWH(offset, 0, width, size.height), paint);
        return;
      case TerminalCursorType.underline:
        return canvas.drawLine(
          Offset(offset, size.height - 1),
          Offset(offset + width, size.height - 1),
          paint,
        );
      case TerminalCursorType.verticalBar:
        return canvas.drawLine(
          Offset(offset, 0),
          Offset(offset, size.height),
          paint,
        );
    }
  }

  @pragma('vm:prefer-inline')
  Color resolveForegroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return widget.theme.foreground;
      case CellColor.named:
      case CellColor.palette:
        return widget.palette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  @pragma('vm:prefer-inline')
  Color resolveBackgroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return widget.theme.background;
      case CellColor.named:
      case CellColor.palette:
        return widget.palette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
