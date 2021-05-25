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
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class FakeTerminalBackend implements TerminalBackend {
  Completer<int> _exitCodeCompleter;
  // ignore: close_sinks
  StreamController<String> _outStream;

  FakeTerminalBackend();

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  void init() {
    _exitCodeCompleter = Completer<int>();
    _outStream = StreamController<String>();
    _outStream.sink.add('xterm.dart demo');
    _outStream.sink.add('\r\n');
    _outStream.sink.add('\$ ');
  }

  @override
  Stream<String> get out => _outStream.stream;

  @override
  void resize(int width, int height) {
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
  TerminalIsolate terminal;

  @override
  void initState() {
    super.initState();
    terminal = TerminalIsolate(
      backend: FakeTerminalBackend(),
      maxLines: 10000,
    );
    terminal.start();
  }

  void onInput(String input) {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: TerminalView(terminal: terminal),
      ),
    );
  }
}
