import 'package:flutter/material.dart';
import 'package:xterm/buffer/cell_flags.dart';
// import 'package:flutter/widgets.dart';
import 'package:xterm/next/core/cell.dart';
import 'package:xterm/next/core/line.dart';
import 'package:xterm/next/core/state.dart';
import 'package:xterm/next/terminal.dart';
import 'package:xterm/next/ui/char_metrics.dart';
import 'package:xterm/next/ui/palette_builder.dart';
import 'package:xterm/next/ui/paragraph_cache.dart';
import 'package:xterm/next/ui/text_style.dart';
import 'package:xterm/next/ui/theme.dart';
import 'package:xterm/next/ui/themes.dart';
// import 'package:xterm/buffer/line/line.dart';

class TerminalView extends StatefulWidget {
  const TerminalView(
    this.terminal, {
    Key? key,
    this.theme = TerminalThemes.defaultTheme,
    this.textStyle = const TerminalStyle(),
    this.padding,
    this.scrollController,
  }) : super(key: key);

  final Terminal terminal;

  final TerminalTheme theme;

  final TerminalStyle textStyle;

  final EdgeInsets? padding;

  final ScrollController? scrollController;

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  var colorPalette = <Color>[];

  final paragraphCache = ParagraphCache(1024);

  @override
  void initState() {
    _rebuildPalette();
    widget.terminal.addListener(_onTerminalChanged);
    super.initState();
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    if (oldWidget.theme != widget.theme) {
      _rebuildPalette();
      paragraphCache.clear();
    }
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onTerminalChanged);
      widget.terminal.addListener(_onTerminalChanged);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_onTerminalChanged);
    super.dispose();
  }

  void _rebuildPalette() {
    colorPalette = PaletteBuilder(widget.theme).build();
  }

  void _onTerminalChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cursorX = widget.terminal.buffer.cursorX;
    final cursorY = widget.terminal.buffer.absoluteCursorY;
    final lines = widget.terminal.lines;

    // Calculate everytime build happens, because some fonts library
    // lazily load fonts (such as google_fonts) and this can change the
    // font metrics while textStyle is still the same.
    final charMetrics = calcCharMetrics(widget.textStyle);

    return ListView.builder(
      padding: widget.padding,
      itemExtent: charMetrics.height,
      cacheExtent: 1200,
      itemCount: lines.length,
      itemBuilder: (context, index) {
        return TerminalLineView(
          lines[index],
          theme: widget.theme,
          palette: colorPalette,
          terminalState: widget.terminal,
          textStyle: widget.textStyle,
          charMetrics: charMetrics,
          paragraphCache: paragraphCache,
          cursorPosition: index == cursorY ? cursorX : null,
        );
      },
    );
  }
}

class TerminalLineView extends StatelessWidget {
  const TerminalLineView(
    this.line, {
    Key? key,
    required this.theme,
    required this.palette,
    required this.terminalState,
    required this.textStyle,
    required this.charMetrics,
    required this.paragraphCache,
    this.cursorPosition,
  }) : super(key: key);

  final BufferLine line;

  final TerminalTheme theme;

  final List<Color> palette;

  final TerminalState terminalState;

  final TerminalStyle textStyle;

  final CharMetrics charMetrics;

  final ParagraphCache paragraphCache;

  final int? cursorPosition;

  @override
  Widget build(BuildContext context) {
    // TextField
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
  }

  void paintBackground(Canvas canvas, Size size) {
    final step = widget.charMetrics.width;

    final line = widget.line;

    final cellData = CellData.empty();

    for (var i = 0; i < line.length; i++) {
      line.getCellData(i, cellData);

      final color = cellData.flags & CellFlags.inverse == 0
          ? resolveBackgroundColor(cellData.background)
          : resolveForegroundColor(cellData.foreground);

      final paint = Paint()..color = color;
      canvas.drawRect(Rect.fromLTWH(i * step, 0, step + 1, size.height), paint);
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

      final hash = cellData.hashForeground();
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

    if (!widget.terminalState.cursorVisibleMode) {
      return;
    }

    final step = widget.charMetrics.width;

    final paint = Paint()
      ..color = widget.theme.cursor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(
      Rect.fromLTWH(cursorPosition * step, 0, step, size.height),
      paint,
    );
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
