import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:xterm/frontend/cell_size.dart';
import 'package:xterm/frontend/helpers.dart';
import 'package:xterm/frontend/input/input_behavior.dart';
import 'package:xterm/frontend/input/input_behaviors.dart';
import 'package:xterm/frontend/terminal_content.dart';
import 'package:xterm/frontend/terminal_keyboard.dart';
import 'package:xterm/frontend/terminal_mouse.dart';
import 'package:xterm/frontend/terminal_scrollable.dart';
import 'package:xterm/frontend/terminal_sizing.dart';
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
    this.autofocus = false,
    FocusNode? focusNode,
    ScrollController? scrollController,
    InputBehavior? inputBehavior,
  })  : focusNode = focusNode ?? FocusNode(),
        scrollController = scrollController ?? ScrollController(),
        inputBehavior = inputBehavior ?? InputBehaviors.platform,
        super(key: key ?? ValueKey(terminal));

  final Terminal terminal;
  final TerminalResizeHandler? onResize;
  final ScrollController scrollController;

  final FocusNode focusNode;
  final bool autofocus;

  final TerminalStyle style;
  final double opacity;

  final InputBehavior inputBehavior;

  @override
  _TerminalViewState createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  late CellSize _cellSize;

  @override
  void initState() {
    _cellSize = _measureCellSize(widget.style);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TerminalView oldWidget) {
    if (oldWidget.style != widget.style) {
      _cellSize = _measureCellSize(widget.style);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TerminalKeyboardLayer(
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        terminal: widget.terminal,
        inputBehavior: widget.inputBehavior,
        child: TerminalMouseLayer(
          terminal: widget.terminal,
          cellSize: _cellSize,
          child: TerminalSizingLayer(
            terminal: widget.terminal,
            cellSize: _cellSize,
            onResize: widget.onResize,
            child: TerminalScrollable(
              terminal: widget.terminal,
              cellSize: _cellSize,
              scrollController: widget.scrollController,
              child: TerminalContent(
                terminal: widget.terminal,
                style: widget.style,
                cellSize: _cellSize,
                opacity: widget.opacity,
                focusNode: widget.focusNode,
                autofocus: widget.autofocus,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// get the dimensions of a rendered character
CellSize _measureCellSize(TerminalStyle style) {
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
