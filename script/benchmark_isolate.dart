import 'dart:isolate';

import 'dart:typed_data';

const messageCount = 6000;

void main() async {
  await benchmark();

  final sw = Stopwatch();

  sw.start();

  await benchmark();

  sw.stop();

  print('$messageCount messages in ${sw.elapsedMilliseconds} ms.');
}

Future<void> benchmark() async {
  final rp = ReceivePort();
  await Isolate.spawn(workerIsolate, rp.sendPort);
  await rp.take(messageCount).toList();
}

class MockTerminalState {
  final height = 0;
  final scrollOffsetFromBottom = 0;

  final viewHeight = 0;
  final viewWidth = 0;

  final cursorX = 0;
  final cursorY = 0;

  final lines = List.generate(50, (_) => ByteData(120 * 16));
}

void workerIsolate(SendPort port) {
  for (var i = 0; i < messageCount; i++) {
    port.send(MockTerminalState());
  }

  port.send(null);
}
