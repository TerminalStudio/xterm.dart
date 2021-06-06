import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:xterm/buffer/line/line.dart';
import 'package:xterm/buffer/cell_flags.dart';
import 'package:xterm/frontend/char_size.dart';
import 'package:xterm/frontend/helpers.dart';
import 'package:xterm/frontend/input_behavior.dart';
import 'package:xterm/frontend/input_behaviors.dart';
import 'package:xterm/frontend/input_listener.dart';
import 'package:xterm/frontend/oscillator.dart';
import 'package:xterm/frontend/cache.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/terminal/terminal_ui_interaction.dart';
import 'package:xterm/theme/terminal_style.dart';
import 'package:xterm/util/bit_flags.dart';
import 'package:xterm/util/hash_values.dart';

class TerminalView extends StatefulWidget {
  TerminalView({
    Key? key,
    required this.terminal,
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

  final TerminalUiInteraction terminal;
  final FocusNode focusNode;
  final bool autofocus;
  final ScrollController scrollController;

  final TerminalStyle style;
  final double opacity;

  final InputBehavior inputBehavior;

  // get the dimensions of a rendered character
  CellSize measureCellSize(double fontSize) {
    final testString = 'xxxxxxxxxx' * 1000;

    final text = Text(
      testString,
      maxLines: 1,
      style: (style.textStyleProvider != null)
          ? style.textStyleProvider!(
              fontSize: fontSize,
            )
          : TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: style.fontFamily,
              fontSize: fontSize,
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
    _terminalScrollExtent =
        _cellSize.cellHeight * widget.terminal.scrollOffsetFromTop;

    if (mounted) {
      setState(() {});
    }
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
    _cellSize = widget.measureCellSize(widget.style.fontSize);

    widget.terminal.addListener(onTerminalChange);

    super.initState();
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    oldWidget.terminal.removeListener(onTerminalChange);
    widget.terminal.addListener(onTerminalChange);

    if (oldWidget.style != widget.style) {
      _cellSize = widget.measureCellSize(widget.style.fontSize);
      updateTerminalSize();
    }

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
          onWidgetSize(constraints.maxWidth, constraints.maxHeight);
          // use flutter's Scrollable to manage scrolling to better integrate
          // with widgets such as Scrollbar.
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              onScroll(notification.metrics.pixels);
              return false;
            },
            child: Scrollable(
              controller: widget.scrollController,
              viewportBuilder: (context, offset) {
                final position = widget.scrollController.position;

                /// use [_EmptyScrollActivity] to suppress unexpected behaviors
                /// that come from [applyViewportDimension].
                if (position is ScrollActivityDelegate) {
                  position.beginActivity(
                    _EmptyScrollActivity(position as ScrollActivityDelegate),
                  );
                }

                // set viewport height.
                offset.applyViewportDimension(constraints.maxHeight);

                if (widget.terminal.isReady) {
                  final minScrollExtent = 0.0;

                  final maxScrollExtent = math.max(
                      0.0,
                      _cellSize.cellHeight * widget.terminal.bufferHeight -
                          constraints.maxHeight);

                  // set how much the terminal can scroll
                  offset.applyContentDimensions(
                      minScrollExtent, maxScrollExtent);

                  // syncronize pending terminal scroll extent to ScrollController
                  if (_terminalScrollExtent != null) {
                    position.correctPixels(_terminalScrollExtent!);
                    _terminalScrollExtent = null;
                  }
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
        if (widget.terminal.selection?.isEmpty ?? true) {
          InputListener.of(context)!.requestKeyboard();
        } else {
          widget.terminal.clearSelection();
        }
        final pos = detail.localPosition;
        final offset = getMouseOffset(pos.dx, pos.dy);
        widget.terminal.onMouseTap(offset);
        widget.terminal.refresh();
      },
      onPanStart: (detail) {
        final pos = detail.localPosition;
        final offset = getMouseOffset(pos.dx, pos.dy);
        widget.terminal.onPanStart(offset);
        widget.terminal.refresh();
      },
      onPanUpdate: (detail) {
        final pos = detail.localPosition;
        final offset = getMouseOffset(pos.dx, pos.dy);
        widget.terminal.onPanUpdate(offset);
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
        color: Color(widget.terminal.backgroundColor).withOpacity(
          widget.opacity,
        ),
      ),
    );
  }

  /// Get global cell position from mouse position.
  Position getMouseOffset(double px, double py) {
    final col = (px / _cellSize.cellWidth).floor();
    final row = (py / _cellSize.cellHeight).floor();

    final x = col;
    final y = widget.terminal.convertViewLineToRawLine(row) -
        widget.terminal.scrollOffsetFromBottom;

    return Position(x, y);
  }

  double? _width;
  double? _height;

  void onWidgetSize(double width, double height) {
    if (!widget.terminal.isReady) {
      return;
    }

    _width = width;
    _height = height;

    updateTerminalSize();
  }

  int? _lastTerminalWidth;
  int? _lastTerminalHeight;

  void updateTerminalSize() {
    assert(_width != null);
    assert(_height != null);

    final termWidth = (_width! / _cellSize.cellWidth).floor();
    final termHeight = (_height! / _cellSize.cellHeight).floor();

    if (_lastTerminalWidth == termWidth && _lastTerminalHeight == termHeight) {
      return;
    }

    _lastTerminalWidth = termWidth;
    _lastTerminalHeight = termHeight;

    widget.terminal.resize(termWidth, termHeight);
  }

  TextEditingValue? onInput(TextEditingValue value) {
    return widget.inputBehavior.onTextEdit(value, widget.terminal);
  }

  void onKeyStroke(RawKeyEvent event) {
    // TODO: find a way to stop scrolling immediately after key stroke.
    widget.inputBehavior.onKeyStroke(event, widget.terminal);
    widget.terminal.setScrollOffsetFromBottom(0);
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
    widget.terminal.setScrollOffsetFromBottom(bottomOffset);
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

  final TerminalUiInteraction terminal;
  final TerminalView view;
  final Oscillator oscillator;
  final bool focused;
  final CellSize charSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (!terminal.isReady) {
      return;
    }
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
    final selection = terminal.selection;
    if (selection == null) {
      return;
    }
    final paint = Paint()..color = Colors.white.withOpacity(0.3);

    for (var y = 0; y < terminal.terminalHeight; y++) {
      final offsetY = y * charSize.cellHeight;
      final absoluteY = terminal.convertViewLineToRawLine(y) -
          terminal.scrollOffsetFromBottom;

      for (var x = 0; x < terminal.terminalWidth; x++) {
        var cellCount = 0;

        while (selection.contains(Position(x + cellCount, absoluteY)) &&
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
    final fontSize = view.style.fontSize;
    if (textLayoutCacheFontSize != fontSize) {
      textLayoutCache.clear();
      textLayoutCacheFontSize = fontSize;
    }
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

    final style = (view.style.textStyleProvider != null)
        ? view.style.textStyleProvider!(
            color: color,
            fontSize: fontSize,
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
            fontSize: fontSize,
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
            fontFamilyFallback: view.style.fontFamily,
          );

    final span = TextSpan(
      text: String.fromCharCode(codePoint),
      // text: codePointCache.getOrConstruct(cell.codePoint),
      style: style,
    );

    // final tp = textLayoutCache.getOrPerformLayout(span);
    tp = textLayoutCache.performAndCacheLayout(span, cellHash);

    tp.paint(canvas, Offset(offsetX, offsetY));
  }

  void _paintCursor(Canvas canvas) {
    final screenCursorY = terminal.cursorY + terminal.scrollOffsetFromBottom;
    if (screenCursorY < 0 || screenCursorY >= terminal.terminalHeight) {
      return;
    }

    final width = charSize.cellWidth *
        (terminal.currentLine?.cellGetWidth(terminal.cursorX).clamp(1, 2) ?? 1);

    final offsetX = charSize.cellWidth * terminal.cursorX;
    final offsetY = charSize.cellHeight * screenCursorY;
    final paint = Paint()
      ..color = Color(terminal.cursorColor)
      ..strokeWidth = focused ? 0.0 : 1.0
      ..style = focused ? PaintingStyle.fill : PaintingStyle.stroke;

    canvas.drawRect(
        Rect.fromLTWH(offsetX, offsetY, width, charSize.cellHeight), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    /// paint only when the terminal has changed since last paint.
    return terminal.dirty;
  }
}

/// A scroll activity that does nothing. Used to suppress unexpected behaviors
/// from [Scrollable] during viewport building process.
class _EmptyScrollActivity extends IdleScrollActivity {
  _EmptyScrollActivity(ScrollActivityDelegate delegate) : super(delegate);

  @override
  void applyNewDimensions() {}

  /// set [isScrolling] to ture to prevent flutter from calling the old scroll
  /// activity.
  @override
  final isScrolling = true;

  void dispatchScrollStartNotification(
      ScrollMetrics metrics, BuildContext? context) {}

  void dispatchScrollUpdateNotification(
      ScrollMetrics metrics, BuildContext context, double scrollDelta) {}

  void dispatchOverscrollNotification(
      ScrollMetrics metrics, BuildContext context, double overscroll) {}

  void dispatchScrollEndNotification(
      ScrollMetrics metrics, BuildContext context) {}
}
