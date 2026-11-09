import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

/// A program on the alternate screen, and what it is sent.
Future<(List<String>, double)> pumpProgram(WidgetTester tester, {bool readOnly = false}) async {
  final outputs = <String>[];
  final terminal = Terminal(onOutput: outputs.add);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: TerminalView(terminal, readOnly: readOnly))),
  );
  terminal.write('\x1b[?1049h');
  await tester.pump();
  final state = tester.state<TerminalViewState>(find.byType(TerminalView));
  return (outputs, state.renderTerminal.lineHeight);
}

Future<void> pan(WidgetTester tester, double dy) async {
  final pointer = TestPointer(1, PointerDeviceKind.trackpad);
  const at = Offset(100, 300);
  await tester.sendEventToBinding(pointer.panZoomStart(at));
  await tester.sendEventToBinding(pointer.panZoomUpdate(at, pan: Offset(0, dy)));
  await tester.sendEventToBinding(pointer.panZoomEnd());
  await tester.pump();
}

void main() {
  testWidgets('a trackpad scrolls a program that has the alternate screen', (tester) async {
    final (outputs, lineHeight) = await pumpProgram(tester);
    // Fingers down by two lines and a half: the content follows them, so the
    // program is scrolled up two lines.
    await pan(tester, lineHeight * 2.5);
    expect(outputs.join(), '\x1b[A\x1b[A');
  });

  testWidgets('a notch of the wheel is three lines to the program', (tester) async {
    final notch = {TargetPlatform.macOS: 40.0, TargetPlatform.windows: 100.0, TargetPlatform.linux: 53.0};
    final (outputs, _) = await pumpProgram(tester);
    await tester.sendEventToBinding(
      PointerScrollEvent(position: const Offset(100, 300), scrollDelta: Offset(0, notch[defaultTargetPlatform]!)),
    );
    await tester.pump();
    expect(outputs.join(), '\x1b[B\x1b[B\x1b[B');
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('a read-only terminal sends the program no scroll', (tester) async {
    final (outputs, lineHeight) = await pumpProgram(tester, readOnly: true);
    await pan(tester, lineHeight * 3);
    await tester.sendEventToBinding(
      const PointerScrollEvent(position: Offset(100, 300), scrollDelta: Offset(0, 100)),
    );
    await tester.pump();
    expect(outputs, isEmpty);
  });
}
