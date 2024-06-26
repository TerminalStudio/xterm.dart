import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:example/src/virtual_keyboard.dart';
import 'package:flutter/cupertino.dart';
import 'package:xterm/utils.dart';
import 'package:xterm/xterm.dart';

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
      title: 'xterm.dart debugger',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  /// The main terminal that user interacts with
  late final terminal = Terminal(inputHandler: keyboard);
  final keyboard = VirtualKeyboard(defaultInputHandler);

  /// The debugger used to record and parse terminal data
  final debugger = TerminalDebugger();

  /// A temporary terminal to display playback data. null if not in playback
  /// mode.
  Terminal? debuggerTerminal;

  var title = host;

  @override
  void initState() {
    super.initState();
    initTerminal();
  }

  /// Write data to both the main terminal and the debugger
  void write(String data) {
    terminal.write(data);
    debugger.write(data);
  }

  Future<void> initTerminal() async {
    write('Connecting...\r\n');

    final client = SSHClient(
      await SSHSocket.connect(host, port),
      username: username,
      onPasswordRequest: () => password,
    );

    write('Connected\r\n');

    final session = await client.shell(
      pty: SSHPtyConfig(
        width: terminal.viewWidth,
        height: terminal.viewHeight,
      ),
    );

    terminal.buffer.clear();
    terminal.buffer.setCursor(0, 0);

    terminal.onTitleChange = (title) {
      setState(() => this.title = title);
    };

    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      session.resizeTerminal(width, height, pixelWidth, pixelHeight);
    };

    terminal.onOutput = (data) {
      session.write(utf8.encode(data));
    };

    session.stdout.cast<List<int>>().transform(Utf8Decoder()).listen(write);
    session.stderr.cast<List<int>>().transform(Utf8Decoder()).listen(write);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        backgroundColor:
            CupertinoTheme.of(context).barBackgroundColor.withOpacity(0.5),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: TerminalView(debuggerTerminal ?? terminal),
                ),
                SizedBox(
                  width: 600,
                  child: TerminalDebuggerView(
                    debugger,
                    onSeek: (commandIndex) {
                      if (commandIndex == null) {
                        setState(() => this.debuggerTerminal = null);
                        return;
                      }

                      // Get all data rangin from beginning to the command
                      // selected and write it to the temporary terminal
                      final command = debugger.commands[commandIndex];
                      final data = debugger.getRecord(command);

                      final debuggerTerminal = Terminal();
                      debuggerTerminal.write(data);
                      setState(() => this.debuggerTerminal = debuggerTerminal);
                    },
                  ),
                ),
              ],
            ),
          ),
          VirtualKeyboardView(keyboard),
        ],
      ),
    );
  }
}
