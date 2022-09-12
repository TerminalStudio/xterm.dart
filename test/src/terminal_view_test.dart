import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import '../_fixture/_fixture.dart';

void main() {
  testWidgets('Golden test', (WidgetTester tester) async {
    final terminal = Terminal();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TerminalView(terminal),
      ),
    ));

    terminal.write(TestFixtures.htop_80x25_3s());
    await tester.pump();

    await expectLater(
      find.byType(TerminalView),
      matchesGoldenFile('_goldens/htop_80x25_3s.png'),
    );
  });
}
