import 'package:flutter/widgets.dart';
// import 'package:xterm/buffer/line/line.dart';
import 'package:xterm/terminal/terminal.dart';

class TermialView extends StatefulWidget {
  const TermialView(this.terminal, {Key? key}) : super(key: key);

  final Terminal terminal;

  @override
  State<TermialView> createState() => TermialViewState();
}

class TermialViewState extends State<TermialView> {
  @override
  void initState() {
    super.initState();
    widget.terminal.addListener(_onTerminalChanged);
  }

  @override
  void didUpdateWidget(TermialView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onTerminalChanged);
      widget.terminal.addListener(_onTerminalChanged);
    }
  }

  @override
  dispose() {
    widget.terminal.removeListener(_onTerminalChanged);
    super.dispose();
  }

  void _onTerminalChanged() {}

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemExtent: 20,
      cacheExtent: 1200,
      itemCount: widget.terminal.buffer.height,
      itemBuilder: (context, index) {
        return Text('line $index');
      },
    );
  }
}

class TerminalLineView extends StatelessWidget {
  const TerminalLineView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TerminalLinePainter(),
    );
  }
}

class _TerminalLinePainter extends CustomPainter {
  // final BufferLine line;

  // _TerminalLinePainter(this.line);

  _TerminalLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // final len = line.data.getTrimmedLength();
    // final paint = Paint()
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = 1
    //   ..color = Colors.black;
    // final path = Path();
    // final start = Offset(0, 0);
    // final end = Offset(len, 0);
    // path.moveTo(start.dx, start.dy);
    // path.lineTo(end.dx, end.dy);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
