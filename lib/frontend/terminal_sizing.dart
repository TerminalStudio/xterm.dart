import 'package:flutter/widgets.dart';
import 'package:xterm/frontend/cell_size.dart';
import 'package:xterm/xterm.dart';

class TerminalSizingLayer extends StatefulWidget {
  TerminalSizingLayer({
    required this.terminal,
    required this.cellSize,
    required this.child,
    this.onResize,
  });

  final Terminal terminal;
  final CellSize cellSize;
  final Widget child;

  final void Function(int, int)? onResize;

  @override
  _TerminalSizingLayerState createState() => _TerminalSizingLayerState();
}

class _TerminalSizingLayerState extends State<TerminalSizingLayer> {
  int? _lastTerminalWidth;
  int? _lastTerminalHeight;

  void _onViewportSize(double width, double height) {
    final termWidth = width ~/ widget.cellSize.cellWidth;
    final termHeight = height ~/ widget.cellSize.cellHeight;

    if (_lastTerminalWidth == termWidth && _lastTerminalHeight == termHeight) {
      return;
    }

    _lastTerminalWidth = termWidth;
    _lastTerminalHeight = termHeight;

    widget.onResize?.call(termWidth, termHeight);
    widget.terminal.resize(termWidth, termHeight);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _onViewportSize(constraints.maxWidth, constraints.maxHeight);
        return widget.child;
      },
    );
  }
}
