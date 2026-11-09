import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

/// A terminal with scrollback, and the scroll controller that shows it.
Future<(ScrollController, double)> pumpTerminal(WidgetTester tester) async {
  final terminal = Terminal(maxLines: 1000);
  final scroll = ScrollController();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TerminalView(
          terminal,
          controller: TerminalController(),
          scrollController: scroll,
        ),
      ),
    ),
  );
  terminal.write('line\n' * 50);
  await tester.pump();

  final state = tester.state<TerminalViewState>(find.byType(TerminalView));
  return (scroll, state.renderTerminal.lineHeight);
}

Future<void> wheel(WidgetTester tester, double dy) async {
  await tester.sendEventToBinding(
    PointerScrollEvent(position: const Offset(100, 300), scrollDelta: Offset(0, dy)),
  );
  await tester.pump();
}

void main() {
  // What one notch of the wheel is, in each engine's logical pixels.
  final notch = {TargetPlatform.macOS: 40.0, TargetPlatform.windows: 100.0, TargetPlatform.linux: 53.0};

  testWidgets('a notch of the wheel scrolls the scrollback three lines', (tester) async {
    final (scroll, lineHeight) = await pumpTerminal(tester);
    final before = scroll.position.pixels;
    await wheel(tester, -notch[defaultTargetPlatform]!);
    expect(before - scroll.position.pixels, closeTo(3 * lineHeight, 0.001));
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('the scrollback is scrolled by whole lines', (tester) async {
    final (scroll, lineHeight) = await pumpTerminal(tester);
    final before = scroll.position.pixels;

    // A high-resolution wheel's fifth of a notch is not yet a line.
    await wheel(tester, -8);
    expect(scroll.position.pixels, before);

    // Another fifth makes 0.6 + 0.6 lines: one, at the line height.
    await wheel(tester, -8);
    expect(before - scroll.position.pixels, closeTo(lineHeight, 0.001));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('at the end of the scrollback the wheel goes to the page', (tester) async {
    final page = ScrollController();
    final terminal = Terminal(maxLines: 1000)..write('line\n' * 50);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: page,
            children: [
              const SizedBox(height: 200),
              SizedBox(height: 300, child: TerminalView(terminal)),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    page.jumpTo(100);
    await tester.pump();

    // The terminal is at its bottom already: down is the page's.
    await tester.sendEventToBinding(
      const PointerScrollEvent(position: Offset(100, 200), scrollDelta: Offset(0, 40)),
    );
    await tester.pump();
    expect(page.position.pixels, 140);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
