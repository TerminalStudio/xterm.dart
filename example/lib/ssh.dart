import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/cupertino.dart';
import 'package:xterm/next.dart';

const host = 'localhost';
const port = 22;
const username = '<your username>';
const password = '<your password>';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'xterm.dart demo',
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
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

class _MyHomePageState extends State<MyHomePage> {
  final terminal = Terminal(maxLines: 10000);

  SSHClient? client;

  SSHSession? session;

  final controller = ScrollController();

  @override
  void initState() {
    super.initState();
    initTerminal();
  }

  Future<void> initTerminal() async {
    client = SSHClient(
      await SSHSocket.connect(host, port),
      username: username,
      onPasswordRequest: () => password,
    );

    session = await client!.shell(
      pty: SSHPtyConfig(
        width: terminal.viewWidth,
        height: terminal.viewHeight,
      ),
    );

    session!.stdout
        .cast<List<int>>()
        .transform(Utf8Decoder())
        .listen(terminal.write);

    session!.stderr
        .cast<List<int>>()
        .transform(Utf8Decoder())
        .listen(terminal.write);

    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      session!.resizeTerminal(width, height, pixelWidth, pixelHeight);
    };

    terminal.onOutput = (data) {
      session!.write(utf8.encode(data) as Uint8List);
    };
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(host),
        backgroundColor: CupertinoColors.systemGrey.withOpacity(0.5),
      ),
      child: SafeArea(
        child: TerminalView(
          terminal,
        ),
      ),
    );
  }
}
