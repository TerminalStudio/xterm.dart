import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/core.dart';
import 'package:xterm/src/ui/shortcut/intents.dart';

class TerminalActions extends StatelessWidget {
  const TerminalActions({
    super.key,
    required this.terminal,
    required this.child,
  });

  final Terminal terminal;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    TextEditingController;

    return Actions(
      actions: {
        TerminalPasteIntent: CallbackAction(
          onInvoke: (Intent intent) async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text;
            if (text != null) {
              terminal.paste(text);
            }
          },
        ),
        // TerminalCopyIntent: CallbackAction(
        //   onInvoke: (Intent intent) => terminal.copy(),
        // ),
        // TerminalSelectAllIntent: CallbackAction(
        //   onInvoke: (Intent intent) => terminal.selectAll(),
        // ),
      },
      child: child,
    );
  }
}

class TerminalPasteAction extends Action<TerminalPasteIntent> {
  TerminalPasteAction(this.terminal);

  final Terminal terminal;

  @override
  void invoke(TerminalPasteIntent intent) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null) {
      terminal.paste(text);
    }
  }
}

class TerminalCopyAction extends Action<TerminalCopyIntent> {
  TerminalCopyAction(this.terminal);

  final Terminal terminal;

  @override
  void invoke(TerminalCopyIntent intent) {
    // terminal
  }
}

class TerminalSelectAllAction extends Action<TerminalSelectAllIntent> {
  TerminalSelectAllAction(this.terminal);

  final Terminal terminal;

  @override
  void invoke(TerminalSelectAllIntent intent) {
    // terminal.selectAll();
  }
}
