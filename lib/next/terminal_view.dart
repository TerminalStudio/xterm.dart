import 'dart:ui';

import 'package:flutter/material.dart';
// import 'package:flutter/widgets.dart';
import 'package:xterm/next/core/cell.dart';
import 'package:xterm/next/core/line.dart';
import 'package:xterm/next/terminal.dart';
import 'package:xterm/next/ui/palette_builder.dart';
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
  var _palette = <Color>[];

  void _rebuildPalette() {
    _palette = PaletteBuilder(widget.theme).build();
  }

  @override
  void initState() {
    super.initState();
    _rebuildPalette();
    // widget.terminal.addListener(_onTerminalChanged);
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.terminal != widget.terminal) {
      // oldWidget.terminal.removeListener(_onTerminalChanged);
      // widget.terminal.addListener(_onTerminalChanged);
    }
    if (oldWidget.theme != widget.theme) {
      _rebuildPalette();
    }
  }

  @override
  dispose() {
    // widget.terminal.removeListener(_onTerminalChanged);
    super.dispose();
  }

  void _onTerminalChanged() {}

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.black,
      fontSize: 12,
      height: 1.5,
      fontFamily: 'monospace',
      fontFamilyFallback: [
        'Menlo',
        'Monaco',
        'Consolas',
        'Liberation Mono',
        'Courier New',
        'monospace',
      ],
    );
    final builder = ParagraphBuilder(style.getParagraphStyle());
    builder.pushStyle(style.getTextStyle());
    builder.addText('m');

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));
    print(paragraph.longestLine);

    final lines = widget.terminal.lines;
    return ListView.builder(
      padding: widget.padding,
      itemExtent: 20,
      cacheExtent: 1200,
      itemCount: lines.length,
      itemBuilder: (context, index) {
        return TerminalLineView(lines[index]);
      },
    );
  }
}

class TerminalLineView extends StatelessWidget {
  const TerminalLineView(this.line, {Key? key}) : super(key: key);

  final BufferLine line;

  @override
  Widget build(BuildContext context) {
    // TextField
    return CustomPaint(
      painter: _TerminalLinePainter(line),
    );
  }
}

class _TerminalLinePainter extends CustomPainter {
  final BufferLine line;

  final List<Color> palette;

  _TerminalLinePainter(this.line, this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    final step = 7.2;

    for (var i = 0; i < line.length; i++) {
      final backgroundCellColor = line.getBackground(i);

      late int backgroundColor;

      switch (backgroundCellColor & CellColor.mask) {
        case CellColor.normal:
          backgroundColor = Colors.grey.value;
          break;
        case CellColor.named:
          backgroundColor = Colors.blue.value;
          break;
        case CellColor.palette:
          backgroundColor = Colors.red.value;
          break;
        case CellColor.rgb:
        default:
          // color = Colors.green.value;
          backgroundColor = backgroundCellColor | 0xFF000000;
          break;
      }

      final paint = Paint()..color = Color(backgroundColor);
      canvas.drawRect(Rect.fromLTWH(i * step, 0, 20, size.height), paint);
    }

    final style = TextStyle(
      color: Colors.black,
      fontSize: 12,
      height: 1.5,
      fontFamily: 'monospace',
      fontFamilyFallback: [
        'Menlo',
        'Monaco',
        'Consolas',
        'Liberation Mono',
        'Courier New',
        'monospace',
      ],
    );
    final builder = ParagraphBuilder(style.getParagraphStyle());
    builder.pushStyle(style.getTextStyle());
    builder.addText(line.toString());

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));
    canvas.drawParagraph(paragraph, Offset.zero);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
