import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/range_line.dart';
import 'package:xterm/src/terminal.dart';
import 'package:xterm/src/ui/controller.dart';

class TerminalActions extends StatelessWidget {
  const TerminalActions({
    super.key,
    required this.terminal,
    required this.controller,
    required this.actions,
    required this.child,
  });

  final Terminal terminal;

  final TerminalController controller;

  final Widget child;

  final Map<Type, Action<Intent>>? actions;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        PasteTextIntent: CallbackAction<PasteTextIntent>(
          onInvoke: (intent) async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text;
            if (text != null) {
              terminal.paste(text);
              controller.clearSelection();
            }
            return null;
          },
        ),
        CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
          onInvoke: (intent) async {
            final selection = controller.selection;

            if (selection == null) {
              return;
            }

            final text = terminal.buffer.getText(selection);

            await Clipboard.setData(ClipboardData(text: text));

            return null;
          },
        ),
        SelectAllTextIntent: CallbackAction<SelectAllTextIntent>(
          onInvoke: (intent) {
            controller.setSelection(
              BufferRangeLine(
                CellOffset(0, terminal.buffer.height - terminal.viewHeight),
                CellOffset(terminal.viewWidth, terminal.buffer.height - 1),
              ),
            );
            return null;
          },
        ),
        ...?actions,
      },
      child: child,
    );
  }
}
