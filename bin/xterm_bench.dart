import 'package:xterm/src/terminal.dart';

void main(List<String> args) async {
  final lines = 1000;

  final terminal = Terminal(maxLines: lines);

  bench('write $lines lines', () {
    for (var i = 0; i < lines; i++) {
      terminal.write('https://github.com/TerminalStudio/dartssh2\r\n');
    }
  });

  final regexp = RegExp(
    r'[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
  );

  bench('search $lines line', () {
    var count = 0;
    for (var line in terminal.lines.toList()) {
      final matches = regexp.allMatches(line.toString());
      count += matches.length;
    }
    print('count: $count');
  });
}

void bench(String description, void Function() f) {
  final sw = Stopwatch()..start();
  f();
  print('$description took ${sw.elapsedMilliseconds}ms');
}
