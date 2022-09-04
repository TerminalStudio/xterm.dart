import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:xterm/xterm.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktop) {}
  setupAcrylic();

  runApp(MyApp());
}

bool get isDesktop {
  if (kIsWeb) return false;
  return [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
}

Future<void> setupAcrylic() async {
  await Window.initialize();
  await Window.makeTitlebarTransparent();
  await Window.setEffect(effect: WindowEffect.aero);
  await Window.setBlurViewState(MacOSBlurViewState.active);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xterm.dart demo',
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final terminal = Terminal(
    maxLines: 1000,
  );

  late final MockRepl pty;

  @override
  void initState() {
    super.initState();

    pty = MockRepl(terminal.write);

    terminal.onOutput = pty.write;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: TerminalView(
          terminal,
          backgroundOpacity: 0.7,
        ),
      ),
    );
  }
}

class MockRepl {
  MockRepl(this.onOutput) {
    onOutput('Welcome to xterm.dart!\r\n');
    onOutput('Type "help" for more information.\r\n');
    onOutput('\n');
    onOutput('\$ ');
  }

  final void Function(String data) onOutput;

  void write(String input) {
    for (var char in input.codeUnits) {
      switch (char) {
        case 13: // carriage return
          onOutput.call('\r\n');
          onOutput.call('\$ ');
          break;
        case 127: // backspace
          onOutput.call('\b \b');
          break;
        default:
          onOutput.call(String.fromCharCode(char));
      }
    }
  }
}
