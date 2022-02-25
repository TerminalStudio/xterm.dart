import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pty/pty.dart';
import 'package:xterm/flutter.dart';
import 'package:xterm/xterm.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xterm.dart demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LocalTerminal(),
    );
  }
}

class LocalTerminalBackend extends TerminalBackend {
  LocalTerminalBackend();

  final pty = PseudoTerminal.start(
    '/system/bin/sh',
    [],
    blocking: false,
    environment: Platform.environment,
  );

  @override
  Future<int> get exitCode => pty.exitCode;

  @override
  void init() {
    pty.init();
  }

  @override
  Stream<String> get out => pty.out;

  @override
  void resize(int width, int height, int pixelWidth, int pixelHeight) {
    pty.resize(width, height);
  }

  @override
  void write(String input) {
    pty.write(input);
  }

  @override
  void terminate() {
    // client.disconnect('terminate');
  }

  @override
  void ackProcessed() {
    // NOOP
  }
}

class LocalTerminal extends StatefulWidget {
  const LocalTerminal({Key? key}) : super(key: key);

  @override
  _LocalTerminalState createState() => _LocalTerminalState();
}

class _LocalTerminalState extends State<LocalTerminal> {
  final terminal = Terminal(maxLines: 10000, backend: LocalTerminalBackend());

  @override
  void initState() {
    super.initState();
  }

  void onInput(String input) {
    print('input: $input');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: TerminalView(
          terminal: terminal,
        ),
      ),
    );
  }
}
