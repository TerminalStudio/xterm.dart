import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:xterm/buffer/cell_flags.dart';
// import 'package:flutter/widgets.dart';
import 'package:xterm/next/core/cell.dart';
import 'package:xterm/next/core/line.dart';
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
          textStyle: widget.textStyle,
          charMetrics: charMetrics,
          cache: paragraphCache,
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
    required this.textStyle,
    required this.charMetrics,
    required this.cache,
  }) : super(key: key);

  final BufferLine line;

  final TerminalTheme theme;

  final List<Color> palette;

  final TerminalStyle textStyle;

  final CharMetrics charMetrics;

  final ParagraphCache cache;

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
  }

  void paintBackground(Canvas canvas, Size size) {
    final step = widget.charMetrics.width;

    final line = widget.line;

    for (var i = 0; i < line.length; i++) {
      final cellColor = line.getBackground(i);

      final colorType = cellColor & CellColor.typeMask;
      final colorValue = cellColor & CellColor.valueMask;

      late Color color;

      switch (colorType) {
        case CellColor.normal:
          color = widget.theme.background;
          break;
        case CellColor.named:
        case CellColor.palette:
          color = widget.palette[colorValue];
          break;
        case CellColor.rgb:
        default:
          color = Color(cellColor | 0xFF000000);
          break;
      }

      final paint = Paint()..color = color;
      canvas.drawRect(Rect.fromLTWH(i * step, 0, step + 1, size.height), paint);
    }
  }

  void paintForeground(Canvas canvas, Size size) {
    final step = widget.charMetrics.width;
    final cache = widget.cache;
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

        final colorType = cellData.foreground & CellColor.typeMask;
        final colorValue = cellData.foreground & CellColor.valueMask;

        late Color color;
        switch (colorType) {
          case CellColor.normal:
            color = widget.theme.foreground;
            break;
          case CellColor.named:
          case CellColor.palette:
            color = widget.palette[colorValue];
            break;
          case CellColor.rgb:
          default:
            color = Color(cellData.foreground | 0xFF000000);
            break;
        }

        final style = textStyle.toTextStyle(
          color: color,
          bold: cellData.flags & CellFlags.bold != 0,
          italic: cellData.flags & CellFlags.italic != 0,
          underline: cellData.flags & CellFlags.underline != 0,
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

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
