import 'package:flutter_test/flutter_test.dart';

import 'package:xterm/xterm.dart';

void main() {
  test('Can instantiate Terminal', () {
    final terminal = Terminal(maxLines: 10000);
    terminal.write('hello');
  });
}
