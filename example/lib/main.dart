import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xterm/flutter.dart';
import 'package:xterm/xterm.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xterm.dart demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class FakeTerminalBackend extends TerminalBackend {
  final _exitCodeCompleter = Completer<int>();
  // ignore: close_sinks
  final _outStream = StreamController<String>();

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  void init() {
    _outStream.sink.add('xterm.dart demo');
    _outStream.sink.add('\r\n');
    _outStream.sink.add('\$ ');
  }

  @override
  Stream<String> get out => _outStream.stream;

  @override
  void resize(int width, int height, int pixelWidth, int pixelHeight) {
    // NOOP
  }

  @override
  void write(String input) {
    if (input.length <= 0) {
      return;
    }
    // in a "real" terminal emulation you would connect onInput to the backend
    // (like a pty or ssh connection) that then handles the changes in the
    // terminal.
    // As we don't have a connected backend here we simulate the changes by
    // directly writing to the terminal.
    if (input == '\r') {
      _outStream.sink.add('\r\n');
      _outStream.sink.add('\$ ');
    } else if (input.codeUnitAt(0) == 127) {
      // Backspace handling
      _outStream.sink.add('\b \b');
    } else {
      _outStream.sink.add(input);
    }
  }

  @override
  void terminate() {
    //NOOP
  }

  @override
  void ackProcessed() {
    //NOOP
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final terminal = Terminal(
    backend: FakeTerminalBackend(),
    maxLines: 10000,
  );

  void onInput(String input) {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: TerminalView(
          terminal: terminal,
          style: TerminalStyle(fontFamily: ['Cascadia Mono']),
        ),
      ),
    );
  }
}
