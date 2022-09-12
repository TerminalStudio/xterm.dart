import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/src/ui/shortcut/intents.dart';
import 'package:xterm/xterm.dart';

class TerminalActions extends StatelessWidget {
  const TerminalActions({
    super.key,
    required this.terminal,
    required this.controller,
    required this.child,
  });

  final Terminal terminal;

  final TerminalController controller;

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
              controller.clearSelection();
            }
            return null;
          },
        ),
        TerminalCopyIntent: CallbackAction(
          onInvoke: (Intent intent) async {
            final selection = controller.selection;

            if (selection == null) {
              return;
            }

            final text = terminal.buffer.getText(selection);

            await Clipboard.setData(ClipboardData(text: text));

            return null;
          },
        ),
        TerminalSelectAllIntent: CallbackAction(onInvoke: (Intent intent) {
          controller.setSelection(
            BufferRange(
              CellOffset(0, terminal.buffer.height - terminal.viewHeight),
              CellOffset(terminal.viewWidth, terminal.buffer.height - 1),
            ),
          );
          return null;
        }),
      },
      child: child,
    );
  }
}
