import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:xterm/buffer/cell.dart';
import 'package:xterm/frontend/char_size.dart';
import 'package:xterm/frontend/helpers.dart';
import 'package:xterm/frontend/input_listener.dart';
import 'package:xterm/frontend/input_map.dart';
import 'package:xterm/frontend/mouse_listener.dart';
import 'package:xterm/frontend/oscillator.dart';
import 'package:xterm/frontend/text_layout_cache.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/terminal/terminal.dart';

typedef ResizeHandler = void Function(int width, int height);

const _kDefaultFontFamily = [
  'Droid Sans Mono',
  'Noto Sans Mono',
  'Roboto Mono',
  'Consolas',
  'Noto Sans Mono CJK SC',
  'Noto Sans Mono CJK TC',
  'Noto Sans Mono CJK KR',
  'Noto Sans Mono CJK JP',
  'Noto Sans Mono CJK HK',
  'monospace',
  'Noto Color Emoji',
  'Noto Sans Symbols',
  'Roboto',
  'Ubuntu',
  'Cantarell',
  'DejaVu Sans',
  'Liberation Sans',
  'Arial',
  'Droid Sans Fallback',
  'sans-serif',
];

class TerminalView extends StatefulWidget {
  TerminalView({
    Key key,
    @required this.terminal,
    this.onResize,
    this.fontSize = 16,
    this.fontFamily = _kDefaultFontFamily,
    this.fontWidthScaleFactor = 1.0,
    this.fontHeightScaleFactor = 1.1,
  }) : super(key: key ?? ValueKey(terminal));

  final Terminal terminal;
  final ResizeHandler onResize;

  final double fontSize;
  final double fontWidthScaleFactor;
  final double fontHeightScaleFactor;
  final List<String> fontFamily;

  CharSize getCharSize() {
    final testString = 'xxxxxxxxxx' * 1000;
    final text = Text(
      testString,
      style: TextStyle(
        fontFamilyFallback: _kDefaultFontFamily,
        fontSize: fontSize,
      ),
    );
    final size = textSize(text);

    final width = (size.width / testString.length);
    final height = size.height;

    final effectWidth = width * fontWidthScaleFactor;
    final effectHeight = size.height * fontHeightScaleFactor;

    // final ls

    return CharSize(
      width: width,
      height: height,
      effectWidth: effectWidth,
      effectHeight: effectHeight,
      letterSpacing: effectWidth - width,
      lineSpacing: effectHeight - height,
    );
  }

  @override
  _TerminalViewState createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  final oscillator = Oscillator.ms(600);
  final focusNode = FocusNode();
  var focused = false;

  int _lastTerminalWidth;
  int _lastTerminalHeight;
  CharSize _charSize;

  void onTerminalChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void onTick() {
    widget.terminal.refresh();
  }

  @override
  void initState() {
    // oscillator.start();
    // oscillator.addListener(onTick);
    _charSize = widget.getCharSize();
    widget.terminal.addListener(onTerminalChange);
    super.initState();
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    widget.terminal.addListener(onTerminalChange);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    // oscillator.stop();
    // oscillator.removeListener(onTick);

    widget.terminal.removeListener(onTerminalChange);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = Container(
      constraints: BoxConstraints.expand(),
      color: Color(widget.terminal.colorScheme.background.value),
      child: CustomPaint(
        painter: TerminalPainter(
          terminal: widget.terminal,
          view: widget,
          oscillator: oscillator,
          focused: focused,
          charSize: _charSize,
        ),
      ),
    );

    result = GestureDetector(
      child: result,
      behavior: HitTestBehavior.deferToChild,
      dragStartBehavior: DragStartBehavior.down,
      onTapDown: (detail) {
        focusNode.requestFocus();
        final pos = detail.localPosition;
        final offset = getMouseOffset(pos.dx, pos.dy);
        widget.terminal.mouseMode.onTap(widget.terminal, offset);
        widget.terminal.refresh();
      },
      onPanStart: (detail) {
        final pos = detail.localPosition;
        final offset = getMouseOffset(pos.dx, pos.dy);
        widget.terminal.mouseMode.onPanStart(widget.terminal, offset);
        widget.terminal.refresh();
      },
      onPanUpdate: (detail) {
        final pos = detail.localPosition;
        final offset = getMouseOffset(pos.dx, pos.dy);
        widget.terminal.mouseMode.onPanUpdate(widget.terminal, offset);
        widget.terminal.refresh();
      },
    );

    return InputListener(
      onKeyStroke: onKeyStroke,
      onInput: onInput,
      onFocus: onFocus,
      focusNode: focusNode,
      autofocus: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: MouseListener(
          onScroll: onScroll,
          child: LayoutBuilder(builder: (context, constraints) {
            onResize(constraints.maxWidth, constraints.maxHeight);
            return result;
          }),
        ),
      ),
    );
  }

  Position getMouseOffset(double px, double py) {
    final col = (px / _charSize.effectWidth).floor();
    final row = (py / _charSize.effectHeight).floor();

    final x = col;
    final y = widget.terminal.buffer.convertViewLineToRawLine(row) -
        widget.terminal.buffer.scrollOffset;

    return Position(x, y);
  }

  void onResize(double width, double height) {
    final termWidth = (width / _charSize.effectWidth).floor();
    final termHeight = (height / _charSize.effectHeight).floor();

    if (_lastTerminalWidth != termWidth || _lastTerminalHeight != termHeight) {
      _lastTerminalWidth = termWidth;
      _lastTerminalHeight = termHeight;

      // print('($termWidth, $termHeight)');

      if (widget.onResize != null) {
        widget.onResize(termWidth, termHeight);
      }

      // SchedulerBinding.instance.addPostFrameCallback((_) {
      //   widget.terminal.resize(termWidth, termHeight);
      // });

      Future.delayed(Duration.zero).then((_) {
        widget.terminal.resize(termWidth, termHeight);
      });
    }
  }

  void onInput(String input) {
    widget.terminal.onInput(input);
  }

  void onKeyStroke(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) {
      return;
    }

    final key = inputMap(event.logicalKey);
    widget.terminal.debug.onMsg(key);
    if (key != null) {
      widget.terminal.input(
        key,
        ctrl: event.isControlPressed,
        alt: event.isAltPressed,
        shift: event.isShiftPressed,
      );
    }

    widget.terminal.buffer.setScrollOffset(0);
  }

  void onFocus(bool focused) {
    this.focused = focused;
    widget.terminal.debug.onMsg('focused $focused');
    widget.terminal.refresh();
  }

  void onScroll(Offset offset) {
    final delta = math.max(1, offset.dy.abs() ~/ 10);

    if (offset.dy > 0) {
      widget.terminal.buffer.screenScrollDown(delta);
    } else if (offset.dy < 0) {
      widget.terminal.buffer.screenScrollUp(delta);
    }
  }
}

final textLayoutCache = TextLayoutCache(TextDirection.ltr, 1024);

class TerminalPainter extends CustomPainter {
  TerminalPainter({
    this.terminal,
    this.view,
    this.oscillator,
    this.focused,
    this.charSize,
  });

  final Terminal terminal;
  final TerminalView view;
  final Oscillator oscillator;
  final bool focused;
  final CharSize charSize;

  @override
  void paint(Canvas canvas, Size size) {
    paintBackground(canvas);

    // if (oscillator.value) {
    // }

    if (terminal.showCursor) {
      paintCursor(canvas);
    }

    paintText(canvas);
    // or paintTextFast(canvas);

    paintSelection(canvas);
  }

  void paintBackground(Canvas canvas) {
    final lines = terminal.getVisibleLines();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final offsetY = i * charSize.effectHeight;
      final cellCount = math.min(terminal.viewWidth, line.length);

      for (var i = 0; i < cellCount; i++) {
        final cell = line.getCell(i);

        if (cell.attr == null || cell.width == 0) {
          continue;
        }

        final offsetX = i * charSize.effectWidth;
        final effectWidth = charSize.effectWidth * cell.width + 1;
        final effectHeight = charSize.effectHeight + 1;

        final bgColor =
            cell.attr.inverse ? cell.attr.fgColor : cell.attr.bgColor;

        if (bgColor == null) {
          continue;
        }

        final paint = Paint()..color = Color(bgColor.value);
        canvas.drawRect(
          Rect.fromLTWH(offsetX, offsetY, effectWidth, effectHeight),
          paint,
        );
      }
    }
  }

  void paintSelection(Canvas canvas) {
    for (var y = 0; y < terminal.viewHeight; y++) {
      final offsetY = y * charSize.effectHeight;
      final absoluteY = terminal.buffer.convertViewLineToRawLine(y) -
          terminal.buffer.scrollOffset;

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

        final offsetX = x * charSize.effectWidth;
        final effectWidth = cellCount * charSize.effectWidth;
        final effectHeight = charSize.effectHeight;

        final paint = Paint()..color = Colors.white.withOpacity(0.3);
        canvas.drawRect(
          Rect.fromLTWH(offsetX, offsetY, effectWidth, effectHeight),
          paint,
        );

        x += cellCount;
      }
    }
  }

  void paintText(Canvas canvas) {
    final lines = terminal.getVisibleLines();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final offsetY = i * charSize.effectHeight;
      final cellCount = math.min(terminal.viewWidth, line.length);

      for (var i = 0; i < cellCount; i++) {
        final cell = line.getCell(i);

        if (cell.attr == null || cell.width == 0) {
          continue;
        }

        final offsetX = i * charSize.effectWidth;
        paintCell(canvas, cell, offsetX, offsetY);
      }
    }
  }

  void paintTextFast(Canvas canvas) {
    final lines = terminal.getVisibleLines();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final offsetY = i * charSize.effectHeight;
      final cellCount = math.min(terminal.viewWidth, line.length);

      final builder = StringBuffer();
      for (var i = 0; i < cellCount; i++) {
        final cell = line.getCell(i);

        if (cell.attr == null || cell.width == 0) {
          continue;
        }

        if (cell.codePoint == null) {
          builder.write(' ');
        } else {
          builder.writeCharCode(cell.codePoint);
        }

        // final offsetX = i * charSize.effectWidth;
        // paintCell(canvas, cell, offsetX, offsetY);
      }

      final style = TextStyle(
        // color: color,
        // fontWeight: cell.attr.bold ? FontWeight.bold : FontWeight.normal,
        // fontStyle: cell.attr.italic ? FontStyle.italic : FontStyle.normal,
        fontSize: view.fontSize,
        letterSpacing: charSize.letterSpacing,
        fontFeatures: [FontFeature.tabularFigures()],
        // decoration:
        //     cell.attr.underline ? TextDecoration.underline : TextDecoration.none,
        fontFamilyFallback: _kDefaultFontFamily,
      );

      final span = TextSpan(
        text: builder.toString(),
        style: style,
      );

      final tp = textLayoutCache.getOrPerformLayout(span);

      tp.paint(canvas, Offset(0, offsetY));
    }
  }

  void paintCell(Canvas canvas, Cell cell, double offsetX, double offsetY) {
    if (cell.codePoint == null || cell.attr.invisible) {
      return;
    }

    final cellColor = cell.attr.inverse
        ? cell.attr.bgColor ?? terminal.colorScheme.background
        : cell.attr.fgColor;

    var color = Color(cellColor.value);

    if (cell.attr.faint) {
      color = color.withOpacity(0.5);
    }

    final style = TextStyle(
      color: color,
      fontWeight: cell.attr.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: cell.attr.italic ? FontStyle.italic : FontStyle.normal,
      fontSize: view.fontSize,
      decoration:
          cell.attr.underline ? TextDecoration.underline : TextDecoration.none,
      fontFamilyFallback: _kDefaultFontFamily,
    );

    final span = TextSpan(
      text: String.fromCharCode(cell.codePoint),
      style: style,
    );

    final tp = textLayoutCache.getOrPerformLayout(span);

    tp.paint(canvas, Offset(offsetX, offsetY));
  }

  void paintCursor(Canvas canvas) {
    final screenCursorY = terminal.cursorY + terminal.scrollOffset;
    if (screenCursorY < 0 || screenCursorY >= terminal.viewHeight) {
      return;
    }

    final char = terminal.buffer.getCellUnderCursor();
    final width =
        char != null ? charSize.effectWidth * char.width : charSize.effectWidth;

    final offsetX = charSize.effectWidth * terminal.cursorX;
    final offsetY = charSize.effectHeight * screenCursorY;
    final paint = Paint()
      ..color = Color(terminal.colorScheme.cursor.value)
      ..strokeWidth = focused ? 0.0 : 1.0
      ..style = focused ? PaintingStyle.fill : PaintingStyle.stroke;
    canvas.drawRect(
        Rect.fromLTWH(offsetX, offsetY, width, charSize.effectHeight), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // print('shouldRepaint');
    return terminal.dirty;
  }
}
