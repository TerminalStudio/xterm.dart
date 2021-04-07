import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:xterm/frontend/char_size.dart';
import 'package:xterm/frontend/helpers.dart';
import 'package:xterm/frontend/input_behavior.dart';
import 'package:xterm/frontend/input_behaviors.dart';
import 'package:xterm/frontend/input_listener.dart';
import 'package:xterm/frontend/oscillator.dart';
import 'package:xterm/frontend/terminal_painters.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/theme/terminal_style.dart';

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
  final blinkOscillator = Oscillator.ms(600);

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
    blinkOscillator.start();
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
    blinkOscillator.stop();
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
        child: Stack(
          children: <Widget>[
            CustomPaint(
              painter: TerminalPainter(
                terminal: widget.terminal,
                style: widget.style,
                blinkOscillator: blinkOscillator,
                charSize: _cellSize,
              ),
            ),
            Positioned(
              child: CursorView(
                terminal: widget.terminal,
                cellSize: _cellSize,
                focusNode: widget.focusNode,
                blinkOscillator: blinkOscillator,
              ),
              width: _cellSize.cellWidth,
              height: _cellSize.cellHeight,
              left: _getCursorOffset().dx,
              top: _getCursorOffset().dy,
            ),
          ],
        ),
        color:
            Color(widget.terminal.theme.background).withOpacity(widget.opacity),
      ),
    );
  }

  Offset _getCursorOffset() {
    final screenCursorY =
        widget.terminal.cursorY + widget.terminal.scrollOffset;
    final offsetX = _cellSize.cellWidth * widget.terminal.cursorX;
    final offsetY = _cellSize.cellHeight * screenCursorY;

    return Offset(offsetX, offsetY);
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

class CursorView extends StatefulWidget {
  final CellSize cellSize;
  final Terminal terminal;
  final FocusNode? focusNode;
  final Oscillator blinkOscillator;
  CursorView({
    required this.terminal,
    required this.cellSize,
    required this.focusNode,
    required this.blinkOscillator,
  });

  @override
  State<StatefulWidget> createState() => _CursorViewState();
}

class _CursorViewState extends State<CursorView> {
  bool get focused {
    return widget.focusNode?.hasFocus ?? false;
  }

  var _isOscillatorCallbackRegistered = false;

  @override
  void initState() {
    widget.blinkOscillator.addListener(onOscillatorTick);

    widget.terminal.addListener(onTerminalChange);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CursorPainter(
        visible: _isCursorVisible(),
        focused: focused,
        charSize: widget.cellSize,
        blinkVisible: widget.blinkOscillator.value,
        cursorColor: widget.terminal.theme.cursor,
      ),
    );
  }

  bool _isCursorVisible() {
    final screenCursorY =
        widget.terminal.cursorY + widget.terminal.scrollOffset;
    if (screenCursorY < 0 || screenCursorY >= widget.terminal.viewHeight) {
      return false;
    }
    return widget.terminal.showCursor;
  }

  @override
  void dispose() {
    widget.terminal.removeListener(onTerminalChange);
    widget.blinkOscillator.removeListener(onOscillatorTick);

    super.dispose();
  }

  void onTerminalChange() {
    if (!mounted) {
      return;
    }
    setState(() {
      if (_isCursorVisible() /*&& widget.terminal.blinkingCursor*/ && focused) {
        if (!_isOscillatorCallbackRegistered) {
          _isOscillatorCallbackRegistered = true;
          widget.blinkOscillator.addListener(onOscillatorTick);
        }
      } else {
        if (_isOscillatorCallbackRegistered) {
          _isOscillatorCallbackRegistered = false;
          widget.blinkOscillator.removeListener(onOscillatorTick);
        }
      }
    });
  }

  void onOscillatorTick() {
    setState(() {});
  }
}
