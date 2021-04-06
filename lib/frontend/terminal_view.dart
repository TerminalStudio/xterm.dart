import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/cell_flags.dart';
import 'package:xterm/frontend/char_size.dart';
import 'package:xterm/frontend/helpers.dart';
import 'package:xterm/frontend/input_behavior.dart';
import 'package:xterm/frontend/input_behaviors.dart';
import 'package:xterm/frontend/input_listener.dart';
import 'package:xterm/frontend/oscillator.dart';
import 'package:xterm/frontend/cache.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/theme/terminal_style.dart';
import 'package:xterm/utli/bit_flags.dart';
import 'package:xterm/utli/hash_values.dart';

typedef TerminalResizeHandler = void Function(int width, int height);

class TerminalView extends StatefulWidget {
  TerminalView({
    Key? key,
    required this.terminal,
    this.onResize,
    this.style = const TerminalStyle(),
    this.opacity = 1.0,
    FocusNode? focusNode,
    this.autofocus = false,
    ScrollController? scrollController,
    InputBehavior? inputBehavior,
  })  : focusNode = focusNode ?? FocusNode(),
        scrollController = scrollController ?? ScrollController(),
        inputBehavior = inputBehavior ?? InputBehaviors.platform,
        super(key: key ?? ValueKey(terminal));

  final Terminal terminal;
  final TerminalResizeHandler? onResize;
  final FocusNode focusNode;
  final bool autofocus;
  final ScrollController scrollController;

  final TerminalStyle style;
  final double opacity;

  final InputBehavior inputBehavior;

  // get the dimensions of a rendered character
  CellSize measureCellSize() {
    final testString = 'xxxxxxxxxx' * 1000;

    final text = Text(
      testString,
      style: (style.textStyleProvider != null)
          ? style.textStyleProvider!(
              fontSize: style.fontSize,
            )
          : TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: style.fontFamily,
              fontSize: style.fontSize,
            ),
    );

    final size = textSize(text);

    final charWidth = (size.width / testString.length);
    final charHeight = size.height;

    final cellWidth = charWidth * style.fontWidthScaleFactor;
    final cellHeight = size.height * style.fontHeightScaleFactor;

    return CellSize(
      charWidth: charWidth,
      charHeight: charHeight,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      letterSpacing: cellWidth - charWidth,
      lineSpacing: cellHeight - charHeight,
    );
  }

  @override
  _TerminalViewState createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  /// blinking cursor and blinking character
  final oscillator = Oscillator.ms(600);

  bool get focused {
    return widget.focusNode.hasFocus;
  }

  late CellSize _cellSize;

  /// Scroll position from the terminal. Not null if terminal scroll extent has
  /// been updated and needs to be syncronized to flutter side.
  double? _terminalScrollExtent;

  void onTerminalChange() {
    if (!mounted) {
      return;
    }

    _terminalScrollExtent =
        _cellSize.cellHeight * widget.terminal.buffer.scrollOffsetFromTop;

    setState(() {});
  }

  // listen to oscillator to update mouse blink etc.
  // void onTick() {
  //   widget.terminal.refresh();
  // }

  @override
  void initState() {
    // oscillator.start();
    // oscillator.addListener(onTick);

    // measureCellSize is expensive so we cache the result.
    _cellSize = widget.measureCellSize();

    widget.terminal.addListener(onTerminalChange);

    super.initState();
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    oldWidget.terminal.removeListener(onTerminalChange);
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
    return InputListener(
      listenKeyStroke: widget.inputBehavior.acceptKeyStroke,
      onKeyStroke: onKeyStroke,
      onTextInput: onInput,
      onAction: onAction,
      onFocus: onFocus,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      initEditingState: widget.inputBehavior.initEditingState,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: LayoutBuilder(builder: (context, constraints) {
          onSize(constraints.maxWidth, constraints.maxHeight);
          // use flutter's Scrollable to manage scrolling to better integrate
          // with widgets such as Scrollbar.
          return NotificationListener<UserScrollNotification>(
            onNotification: (_) {
              onScroll(_.metrics.pixels);
              return false;
            },
            child: Scrollable(
              controller: widget.scrollController,
              viewportBuilder: (context, offset) {
                // set viewport height.
                offset.applyViewportDimension(constraints.maxHeight);

                final minScrollExtent = 0.0;

                final maxScrollExtent = math.max(
                    0.0,
                    _cellSize.cellHeight * widget.terminal.buffer.height -
                        constraints.maxHeight);

                // set how much the terminal can scroll
                offset.applyContentDimensions(minScrollExtent, maxScrollExtent);

                // syncronize terminal scroll extent to ScrollController
                if (_terminalScrollExtent != null) {
                  widget.scrollController.position.correctPixels(
                    _terminalScrollExtent!,
                  );
                  _terminalScrollExtent = null;
                }

                return buildTerminal(context);
              },
            ),
          );
        }),
      ),
    );
  }

  Widget buildTerminal(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      dragStartBehavior: DragStartBehavior.down,
      onDoubleTapDown: (details) {
        print('details : $details');
      },
      onTapDown: (detail) {
        if (widget.terminal.selection.isEmpty) {
          InputListener.of(context)!.requestKeyboard();
        } else {
          widget.terminal.selection.clear();
        }
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
      child: Container(
        constraints: BoxConstraints.expand(),
        child: CustomPaint(
          painter: TerminalPainter(
            terminal: widget.terminal,
            view: widget,
            oscillator: oscillator,
            focused: focused,
            charSize: _cellSize,
          ),
        ),
        color:
            Color(widget.terminal.theme.background).withOpacity(widget.opacity),
      ),
    );
  }

  /// Get global cell position from mouse position.
  Position getMouseOffset(double px, double py) {
    final col = (px / _cellSize.cellWidth).floor();
    final row = (py / _cellSize.cellHeight).floor();

    final x = col;
    final y = widget.terminal.buffer.convertViewLineToRawLine(row) -
        widget.terminal.buffer.scrollOffsetFromBottom;

    return Position(x, y);
  }

  int? _lastTerminalWidth;
  int? _lastTerminalHeight;

  void onSize(double width, double height) {
    final termWidth = (width / _cellSize.cellWidth).floor();
    final termHeight = (height / _cellSize.cellHeight).floor();

    if (_lastTerminalWidth != termWidth || _lastTerminalHeight != termHeight) {
      _lastTerminalWidth = termWidth;
      _lastTerminalHeight = termHeight;

      // print('($termWidth, $termHeight)');

      widget.onResize?.call(termWidth, termHeight);

      SchedulerBinding.instance!.addPostFrameCallback((_) {
        widget.terminal.resize(termWidth, termHeight);
      });

      // Future.delayed(Duration.zero).then((_) {
      //   widget.terminal.resize(termWidth, termHeight);
      // });
    }
  }

  TextEditingValue? onInput(TextEditingValue value) {
    return widget.inputBehavior.onTextEdit(value, widget.terminal);
  }

  void onKeyStroke(RawKeyEvent event) {
    widget.inputBehavior.onKeyStroke(event, widget.terminal);
    widget.terminal.buffer.setScrollOffsetFromBottom(0);
  }

  void onFocus(bool focused) {
    SchedulerBinding.instance!.addPostFrameCallback((_) {
      widget.terminal.refresh();
    });
  }

  void onAction(TextInputAction action) {
    widget.inputBehavior.onAction(action, widget.terminal);
  }

  // synchronize flutter scroll offset to terminal
  void onScroll(double offset) {
    final topOffset = (offset / _cellSize.cellHeight).ceil();
    final bottomOffset = widget.terminal.invisibleHeight - topOffset;

    setState(() {
      widget.terminal.buffer.setScrollOffsetFromBottom(bottomOffset);
    });
  }
}

class TerminalPainter extends CustomPainter {
  TerminalPainter({
    required this.terminal,
    required this.view,
    required this.oscillator,
    required this.focused,
    required this.charSize,
  });

  final Terminal terminal;
  final TerminalView view;
  final Oscillator oscillator;
  final bool focused;
  final CellSize charSize;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas);

    // if (oscillator.value) {
    // }

    if (terminal.showCursor) {
      _paintCursor(canvas);
    }

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

  TextPainter _createAndStoreTextPainter(String char, Color color,
      {bool bold = false,
      bool italic = false,
      bool underline = false,
      int? cellHash = null}) {
    TextPainter? result;
    final style = (view.style.textStyleProvider != null)
        ? view.style.textStyleProvider!(
            color: color,
            fontSize: view.style.fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            decoration:
                underline ? TextDecoration.underline : TextDecoration.none,
          )
        : TextStyle(
            color: color,
            fontSize: view.style.fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            decoration:
                underline ? TextDecoration.underline : TextDecoration.none,
            fontFamily: 'monospace',
            fontFamilyFallback: view.style.fontFamily,
          );

    final span = TextSpan(
      text: char,
      style: style,
    );

    if (cellHash != null) {
      result = textLayoutCache.performAndCacheLayout(span, cellHash);
    } else {
      result = TextPainter(text: span, textDirection: TextDirection.ltr);
      result.layout();
    }

    return result;
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

    tp = _createAndStoreTextPainter(String.fromCharCode(codePoint), color,
        bold: flags.hasFlag(CellFlags.bold),
        italic: flags.hasFlag(CellFlags.italic),
        underline: flags.hasFlag(CellFlags.underline),
        cellHash: cellHash);
    tp.paint(canvas, Offset(offsetX, offsetY));
  }

  void _paintCursor(Canvas canvas) {
    final screenCursorY = terminal.cursorY + terminal.scrollOffset;
    if (screenCursorY < 0 || screenCursorY >= terminal.viewHeight) {
      return;
    }

    final width = charSize.cellWidth *
        terminal.buffer.currentLine.cellGetWidth(terminal.cursorX).clamp(1, 2);

    final offsetX = charSize.cellWidth * terminal.cursorX;
    final offsetY = charSize.cellHeight * screenCursorY;
    final paint = Paint()
      ..color = Color(terminal.theme.cursor)
      ..strokeWidth = focused ? 0.0 : 1.0
      ..style = focused ? PaintingStyle.fill : PaintingStyle.stroke;

    canvas.drawRect(
        Rect.fromLTWH(offsetX, offsetY, width, charSize.cellHeight), paint);
    if (terminal.composingString != '') {
      final tp = _createAndStoreTextPainter(
          terminal.composingString, Color(terminal.theme.background));
      tp.paint(canvas, Offset(offsetX, offsetY));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    /// paint only when the terminal has changed since last paint.
    return terminal.dirty;
  }
}
