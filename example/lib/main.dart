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

class _MyHomePageState extends State<MyHomePage> {
  Terminal terminal;

  @override
  void initState() {
    super.initState();
    terminal = Terminal(onInput: onInput);
    terminal.write('xterm.dart demo');
    terminal.write('\r\n');
    terminal.write('\$ ');
  }

  void onInput(String input) {
    if (input == '\r') {
      terminal.write('\r\n');
      terminal.write('\$ ');
    } else {
      terminal.write(input);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: TerminalView(terminal: terminal),
      ),
    );
  }
}
