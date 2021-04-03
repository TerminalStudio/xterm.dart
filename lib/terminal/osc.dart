import 'dart:collection';

import 'package:xterm/terminal/terminal.dart';

// bool _isOscTerminator(int codePoint) {
//   final terminator = {0x07, 0x00};
//   // final terminator = {0x07, 0x5c};
//   return terminator.contains(codePoint);
// }

List<String>? _parseOsc(Queue<int> queue, Set<int> terminators) {
  // TODO: add tests for cases such as incomplete sequence.

  final params = <String>[];
  final param = StringBuffer();

  // Keep track of how many characters should be taken from the queue.
  var readOffset = 0;

  while (true) {
    // The sequence isn't completed, just ignore it.
    if (queue.length <= readOffset) {
      return null;
    }

    final char = queue.elementAt(readOffset++);

    // final char = queue.removeFirst();

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

  // The sequence is complete. So we consume it from the queue.
  for (var i = 0; i < readOffset; i++) {
    queue.removeFirst();
  }

  return params;
}

/// OSC - Operating System Command: sequence starting with ESC ] (7bit) or OSC
/// (\x9D, 8bit)
bool oscHandler(Queue<int> queue, Terminal terminal) {
  final params = _parseOsc(queue, terminal.platform.oscTerminators);

  if (params == null) {
    return false;
  }

  terminal.debug.onOsc(params);

  if (params.isEmpty) {
    terminal.debug.onError('osc with no params');
    return true;
  }

  if (params.length < 2) {
    return true;
  }

  final ps = params[0];
  final pt = params[1];

  switch (ps) {
    case '0':
    case '2':
      terminal.onTitleChange(pt);
      break;
    case '1':
      terminal.onIconChange(pt);
      break;
    default:
      terminal.debug.onError('unknown osc ps: $ps');
  }

  return true;
}
