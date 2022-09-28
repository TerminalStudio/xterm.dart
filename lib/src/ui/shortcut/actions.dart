import 'package:flutter/widgets.dart';
import 'package:xterm/src/terminal.dart';
import 'package:xterm/src/ui/controller.dart';
import 'package:xterm/src/ui/shortcut/shortcuts.dart';

class TerminalActions extends StatelessWidget {
  const TerminalActions({
    super.key,
    required this.terminal,
    required this.controller,
    required this.shortcuts,
    required this.child,
  });

  final Terminal terminal;

  final TerminalController controller;

  final List<TerminalShortcut> shortcuts;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Convert the list of shortcuts to a callback map.
    final actions = Map.fromEntries(
      shortcuts.map((e) => e.toActionMapEntry(terminal, controller)),
    );
    return Actions(actions: actions, child: child);
  }
}
