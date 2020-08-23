import 'package:async/async.dart';
import 'package:xterm/terminal/terminal.dart';

// bool _isOscTerminator(int codePoint) {
//   final terminator = {0x07, 0x00};
//   // final terminator = {0x07, 0x5c};
//   return terminator.contains(codePoint);
// }

Future<List<String>> _parseOsc(
  StreamQueue<int> queue,
  Set<int> terminators,
) async {
  final params = <String>[];
  final param = StringBuffer();

  while (true) {
    final char = await queue.next;

    if (terminators.contains(char)) {
      params.add(param.toString());
      break;
    }

    const semicolon = 59;
    if (char == semicolon) {
      params.add(param.toString());
      param.clear();
      continue;
    }

    param.writeCharCode(char);
  }

  return params;
}

Future<void> oscHandler(StreamQueue<int> queue, Terminal terminal) async {
  final params = await _parseOsc(queue, terminal.platform.oscTerminators);
  terminal.debug.onOsc(params);

  if (params.isEmpty) {
    terminal.debug.onError('osc with no params');
    return;
  }

  if (params.length < 2) {
    return;
  }

  final ps = params[0];
  final pt = params[1];

  switch (ps) {
    case '0':
    case '2':
      if (terminal.onTitleChange != null) {
        terminal.onTitleChange(pt);
      }
      break;
    case '1':
      if (terminal.onIconChange != null) {
        terminal.onIconChange(pt);
      }
      break;
    default:
      terminal.debug.onError('unknown osc ps: $ps');
  }
}
