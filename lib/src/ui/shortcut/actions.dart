import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/src/terminal.dart';
import 'package:xterm/src/ui/controller.dart';
import 'package:xterm/src/ui/selection_mode.dart';

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
    return Actions(
      actions: {
        PasteTextIntent: CallbackAction<PasteTextIntent>(
          onInvoke: (intent) => pasteClipboard(terminal, controller),
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
              terminal.buffer.createAnchor(
                0,
                terminal.buffer.height - terminal.viewHeight,
              ),
              terminal.buffer.createAnchor(
                terminal.viewWidth,
                terminal.buffer.height - 1,
              ),
              mode: SelectionMode.line,
            );
            return null;
          },
        ),
      },
      child: child,
    );
  }
}

/// Pastes the clipboard's text into [terminal], as a paste, so that bracketed
/// paste wraps it. The clipboard can refuse a read, which no one is told of.
Future<void> pasteClipboard(
  Terminal terminal,
  TerminalController controller,
) async {
  final ClipboardData? data;
  try {
    data = await Clipboard.getData(Clipboard.kTextPlain);
  } on PlatformException {
    return;
  }
  final text = data?.text;
  if (text == null) return;
  pasteText(terminal, controller, text);
}

/// Pastes [text] into [terminal], as a paste, so that bracketed paste wraps it.
void pasteText(Terminal terminal, TerminalController controller, String text) {
  if (text.isEmpty) return;
  terminal.paste(text);
  controller.clearSelection();
}
