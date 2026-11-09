import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  testWidgets('a terminal shows one scrollbar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerminalView(Terminal(), hideScrollBar: false)),
      ),
    );
    expect(find.byWidgetPredicate((w) => w is RawScrollbar), findsOneWidget);
  }, variant: TargetPlatformVariant.desktop());
}
