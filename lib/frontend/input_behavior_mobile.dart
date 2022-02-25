import 'package:flutter/services.dart';
import 'package:xterm/frontend/input_behavior_default.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/xterm.dart';

class InputBehaviorMobile extends InputBehaviorDefault {
  InputBehaviorMobile();

  @override
  final acceptKeyStroke = false;

  @override
  final initEditingState = const TextEditingValue(
    text: '  ',
    selection: TextSelection.collapsed(offset: 1),
  );

  @override
  TextEditingValue onTextEdit(
      TextEditingValue value, TerminalUiInteraction terminal) {
    if (value.text.length > initEditingState.text.length) {
      terminal.raiseOnInput(value.text.substring(1, value.text.length - 1));
    } else if (value.text.length < initEditingState.text.length) {
      terminal.keyInput(TerminalKey.backspace);
    } else {
      if (value.selection.baseOffset < 1) {
        terminal.keyInput(TerminalKey.arrowLeft);
      } else if (value.selection.baseOffset > 1) {
        terminal.keyInput(TerminalKey.arrowRight);
      }
    }

    return initEditingState;
  }

  @override
  void onAction(TextInputAction action, TerminalUiInteraction terminal) {
    print('action $action');
    switch (action) {
      case TextInputAction.done:
        terminal.keyInput(TerminalKey.enter);
        break;
      default:
        print('unknown action $action');
    }
  }
}
