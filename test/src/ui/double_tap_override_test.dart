import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

/// `TerminalView.onDoubleTapDown` REPLACES the built-in word selection.
///
/// Replacing rather than running after it is the whole point: an embedder that
/// wants a different double-tap meaning (select the line, open a file, follow a
/// URL) would otherwise see the word selected first and its own selection land a
/// frame later — visible as a flicker, and dependent on scheduling order.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('with no handler, double-tap still selects the word', (
    tester,
  ) async {
    final terminal = Terminal();
    final controller = TerminalController();

    await _pumpTerminal(
      tester: tester,
      terminal: terminal,
      controller: controller,
    );

    terminal.write('hello world');
    await tester.pump();

    await _doubleTapAt(tester: tester, offset: const Offset(10, 5));

    // The default behaviour is untouched for every existing embedder.
    expect(controller.selection, isNotNull);
  });

  testWidgets('a handler REPLACES the word selection, and receives the cell', (
    tester,
  ) async {
    final terminal = Terminal();
    final controller = TerminalController();

    CellOffset? reportedCell;

    void onDoubleTapDown(TapDownDetails details, CellOffset cell) {
      reportedCell = cell;
    }

    await _pumpTerminal(
      tester: tester,
      terminal: terminal,
      controller: controller,
      onDoubleTapDown: onDoubleTapDown,
    );

    terminal.write('hello world');
    await tester.pump();

    await _doubleTapAt(tester: tester, offset: const Offset(10, 5));

    // The embedder was told WHERE, in cell coordinates...
    expect(reportedCell, isNotNull);

    // ...and xterm did NOT select the word behind its back. Without this, the
    // embedder's own selection is a correction rather than the only write.
    expect(controller.selection, isNull);
  });
}

Future<void> _pumpTerminal({
  required WidgetTester tester,
  required Terminal terminal,
  required TerminalController controller,
  void Function(TapDownDetails, CellOffset)? onDoubleTapDown,
}) async {
  final view = TerminalView(
    terminal,
    controller: controller,
    onDoubleTapDown: onDoubleTapDown,
  );

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));

  await tester.pump();
}

/// Two taps inside the double-tap window and slop, so xterm's detector reports a
/// double tap rather than two singles.
Future<void> _doubleTapAt({
  required WidgetTester tester,
  required Offset offset,
}) async {
  await tester.tapAt(offset);
  await tester.pump(const Duration(milliseconds: 50));

  await tester.tapAt(offset);
  await tester.pump();
}
