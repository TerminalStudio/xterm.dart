import 'package:flutter/material.dart';
import 'package:xterm/frontend/input/input_behavior.dart';
import 'package:xterm/frontend/input/input_listener.dart';
import 'package:xterm/xterm.dart';

class TerminalKeyboardLayer extends StatelessWidget {
  TerminalKeyboardLayer({
    required this.focusNode,
    required this.autofocus,
    required this.inputBehavior,
    required this.terminal,
    required this.child,
  });

  final FocusNode focusNode;
  final bool autofocus;
  final InputBehavior inputBehavior;
  final Terminal terminal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InputListener(
      focusNode: focusNode,
      autofocus: autofocus,
      initEditingState: inputBehavior.initEditingState,
      onKey: (focusNode, keyEvent) {
        if (!inputBehavior.acceptKeyStroke) {
          return KeyEventResult.ignored;
        }

        final handled = inputBehavior.onKeyStroke(keyEvent, terminal);
        if (handled) {
          // TODO: find a way to stop scrolling immediately after key stroke.
          terminal.buffer.setScrollOffsetFromBottom(0);
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      onInput: (value) {
        return inputBehavior.onTextEdit(value, terminal);
      },
      onAction: (action) {
        inputBehavior.onAction(action, terminal);
      },
      onFocusChange: (focused) {
        terminal.refresh();
      },
      child: child,
    );
  }
}
