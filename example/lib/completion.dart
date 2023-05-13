import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:example/src/platform_menu.dart';
import 'package:example/src/suggestion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

final engine = SuggestionEngine();

Future<Map<String, dynamic>> loadSuggestion() async {
  final data = await rootBundle.load('assets/specs_v1.json.gz');
  return await Stream.value(data.buffer.asUint8List())
      .cast<List<int>>()
      .transform(gzip.decoder)
      .transform(utf8.decoder)
      .transform(json.decoder)
      .first as Map<String, dynamic>;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  engine.load(await loadSuggestion());
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xterm.dart demo',
      debugShowCheckedModeBanner: false,
      home: AppPlatformMenu(child: Home()),
    );
  }
}

class Home extends StatefulWidget {
  Home({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final terminal = Terminal(
    maxLines: 10000,
    onPrivateOSC: _handlePrivateOSC,
  );

  final terminalController = TerminalController();

  final terminalKey = GlobalKey<TerminalViewState>();

  final suggestionOverlay = OverlayPortalController();

  late final Pty pty;

  @override
  void initState() {
    super.initState();
    terminal.addListener(_handleTerminalChanged);

    WidgetsBinding.instance.endOfFrame.then(
      (_) {
        if (mounted) _startPty();
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    terminal.removeListener(_handleTerminalChanged);
  }

  void _startPty() {
    pty = Pty.start(
      shell,
      columns: terminal.viewWidth,
      rows: terminal.viewHeight,
    );

    pty.output
        .cast<List<int>>()
        .transform(Utf8Decoder())
        .listen(terminal.write);

    pty.exitCode.then((code) {
      terminal.write('the process exited with exit code $code');
    });

    terminal.onOutput = (data) {
      pty.write(const Utf8Encoder().convert(data));
    };

    terminal.onResize = (w, h, pw, ph) {
      pty.resize(h, w);
    };
  }

  CellAnchor? _promptStart;
  CellAnchor? _commandStart;
  CellAnchor? _commandEnd;
  CellAnchor? _commandFinished;

  void _handlePrivateOSC(String code, List<String> args) {
    switch (code) {
      case '133':
        _handleFinalTermOSC(args);
    }
  }

  void _handleFinalTermOSC(List<String> args) {
    switch (args) {
      case ['A']:
        _promptStart?.dispose();
        _promptStart = terminal.buffer.createAnchorFromCursor();
        _commandStart?.dispose();
        _commandStart = null;
        _commandEnd?.dispose();
        _commandEnd = null;
        _commandFinished?.dispose();
        _commandFinished = null;
      case ['B']:
        _commandStart?.dispose();
        _commandStart = terminal.buffer.createAnchorFromCursor();
        break;
      case ['C', ..._]:
        _commandEnd?.dispose();
        _commandEnd = terminal.buffer.createAnchorFromCursor();
        // _handleCommandEnd();
        break;
      case ['D', String exitCode]:
        _commandFinished?.dispose();
        _commandFinished = terminal.buffer.createAnchorFromCursor();
        // _handleCommandFinished(int.tryParse(exitCode));
        break;
    }
  }

  // void _handleCommandEnd() {
  //   if (_commandStart == null || _commandEnd == null) return;
  //   final command = terminal.buffer
  //       .getText(BufferRangeLine(_commandStart!.offset, _commandEnd!.offset))
  //       .trim();
  //   print('command: $command');
  // }

  // void _handleCommandFinished(int? exitCode) {
  //   if (_commandEnd == null || _commandFinished == null) return;
  //   final result = terminal.buffer
  //       .getText(BufferRangeLine(_commandEnd!.offset, _commandFinished!.offset))
  //       .trim();
  //   print('result: $result');
  //   print('exit code $exitCode');
  // }

  final suggestions = ValueNotifier<List<FigSuggestion>>([]);

  void _handleTerminalChanged() {
    final commandStart = _commandStart;
    if (commandStart == null || _commandEnd != null) {
      suggestionOverlay.hide();
      return;
    }

    var commandRange = BufferRangeLine(
      commandStart.offset,
      CellOffset(
        terminal.buffer.cursorX,
        terminal.buffer.absoluteCursorY,
      ),
    );
    final command = terminal.buffer.getText(commandRange).trim();

    if (command.isEmpty) {
      suggestionOverlay.hide();
      return;
    }

    print('command: $command');

    suggestions.value = engine.getSuggestions(command).toList();

    print(suggestions.value);

    if (suggestions.value.isNotEmpty) {
      suggestionOverlay.show();
    } else {
      suggestionOverlay.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OverlayPortal(
        controller: suggestionOverlay,
        overlayChildBuilder: (context) {
          return ValueListenableBuilder<List<FigSuggestion>>(
            valueListenable: suggestions,
            builder: (context, suggestions, _) {
              return SuggestionOverlay(
                suggestions,
                cursorRect: terminalKey.currentState!.cursorRect,
              );
            },
          );
        },
        child: TerminalView(
          terminal,
          key: terminalKey,
          controller: terminalController,
          autofocus: true,
          backgroundOpacity: 0.7,
        ),
      ),
    );
  }
}

class SuggestionOverlay extends StatelessWidget {
  const SuggestionOverlay(
    this.suggestions, {
    super.key,
    required this.cursorRect,
  });

  final Rect cursorRect;

  final List<FigSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    print('build suggestions');

    const kScreenPadding = 8.0;
    const kPanelContentDistance = 8.0;
    const kPanelWidth = 300.0;
    const kPanelHeight = 300.0;
    final paddingAbove = MediaQuery.paddingOf(context).top + kScreenPadding;
    final availableHeight =
        cursorRect.top - kPanelContentDistance - paddingAbove;
    final fitsAbove = kPanelHeight <= availableHeight;

    return CustomSingleChildLayout(
      delegate: _SuggestionOverlayDelegate(cursorRect, fitsAbove),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: kPanelWidth,
          maxHeight: kPanelHeight,
        ),
        child: _buildSuggestions(context),
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    final list = ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        final (icon, color, content) = _suggestionContent(suggestion);
        return SuggestionTile(icon: icon, color: color, content: content ?? '');
      },
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
        // border: Border.all(color: Colors.grey[900]!),
      ),
      child: DefaultTextStyle(
        style: TerminalStyle().toTextStyle().copyWith(height: 1.5),
        child: Column(
          children: [
            Expanded(
              child: list,
            ),
          ],
        ),
      ),
    );
  }

  static (IconData, Color, String?) _suggestionContent(
      FigSuggestion suggestion) {
    return switch (suggestion) {
      FigSubCommand(:final names) => (
          Icons.subdirectory_arrow_right,
          Colors.blue,
          names.join(', '),
        ),
      FigOption(:final name) => (
          Icons.settings,
          Colors.green,
          name.join(', '),
        ),
      FigArgument(:final name) => (
          Icons.text_fields,
          Colors.yellow,
          name,
        ),
    };
  }
}

class _SuggestionOverlayDelegate extends SingleChildLayoutDelegate {
  _SuggestionOverlayDelegate(this.cursorRect, this.fitsAbove);

  final Rect cursorRect;

  final bool fitsAbove;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    TextSelectionToolbarLayoutDelegate;

    const kPanelContentDistance = 8.0;
    final dx = min(cursorRect.left, size.width - childSize.width);
    final dy = fitsAbove
        ? cursorRect.top - childSize.height
        : cursorRect.bottom + kPanelContentDistance;
    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(_SuggestionOverlayDelegate oldDelegate) {
    return cursorRect != oldDelegate.cursorRect;
  }
}

class SuggestionTile extends StatelessWidget {
  const SuggestionTile({
    super.key,
    required this.icon,
    required this.content,
    required this.color,
  });

  final IconData icon;
  final Color color;

  final String content;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 4),
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        SizedBox(width: 4),
        Text(content),
      ],
    );
  }
}

String get shell {
  if (Platform.isMacOS || Platform.isLinux) {
    return Platform.environment['SHELL'] ?? 'bash';
  }

  if (Platform.isWindows) {
    return 'cmd.exe';
  }

  return 'sh';
}
