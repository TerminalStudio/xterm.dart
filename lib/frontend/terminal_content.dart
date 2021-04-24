import 'package:flutter/material.dart';
import 'package:xterm/frontend/cell_size.dart';
import 'package:xterm/frontend/oscillator.dart';
import 'package:xterm/frontend/render_cursor.dart';
import 'package:xterm/frontend/render_selection.dart';
import 'package:xterm/frontend/render_text.dart';
import 'package:xterm/frontend/renderer.dart';
import 'package:xterm/theme/terminal_style.dart';
import 'package:xterm/xterm.dart';

class TerminalContent extends StatefulWidget {
  TerminalContent({
    required this.terminal,
    required this.style,
    required this.cellSize,
    required this.opacity,
    required this.focusNode,
    required this.autofocus,
  });

  final Terminal terminal;
  final TerminalStyle style;
  final CellSize cellSize;
  final double opacity;
  final FocusNode focusNode;
  final bool autofocus;

  @override
  _TerminalContentState createState() => _TerminalContentState();
}

class _TerminalContentState extends State<TerminalContent> {
  final blinkOscillator = Oscillator.ms(600);

  var _needSetState = true;

  void _onTerminalChange() {
    if (_needSetState) {
      setState(() {});
      _needSetState = false;
    }
  }

  void _onPaint() {
    _needSetState = true;
  }

  @override
  void initState() {
    // measureCellSize is expensive so we cache the result.
    widget.terminal.addListener(_onTerminalChange);
    super.initState();
  }

  @override
  void didUpdateWidget(TerminalContent oldWidget) {
    oldWidget.terminal.removeListener(_onTerminalChange);
    widget.terminal.addListener(_onTerminalChange);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    blinkOscillator.stop();
    widget.terminal.removeListener(_onTerminalChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints.expand(),
      color: Color(widget.terminal.theme.background).withOpacity(
        widget.opacity,
      ),
      child: CustomPaint(
        painter: TerminalPainter(
          terminal: widget.terminal,
          onPaint: _onPaint,
          layers: [
            RenderText(
              terminal: widget.terminal,
              style: widget.style,
              charSize: widget.cellSize,
            ),
            RenderSelection(
              terminal: widget.terminal,
              charSize: widget.cellSize,
            ),
            RenderCursor(
              terminal: widget.terminal,
              charSize: widget.cellSize,
              blink: blinkOscillator,
              hasFocus: widget.focusNode.hasFocus,
            ),
          ],
        ),
      ),
    );
  }
}

class TerminalPainter extends CustomPainter {
  TerminalPainter({
    required this.terminal,
    required this.layers,
    this.onPaint,
  });

  final Terminal terminal;
  final List<TerminalRenderer> layers;
  final void Function()? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint?.call();
    for (var layer in layers) {
      layer.paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return terminal.consumeDirty();
  }
}
