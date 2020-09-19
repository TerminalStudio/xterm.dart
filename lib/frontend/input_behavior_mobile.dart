import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/frontend/input_behavior_default.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/xterm.dart';

class InputBehaviorMobile extends InputBehaviorDefault {
  const InputBehaviorMobile();

  static const _placeholder = '  ';

  bool get acceptKeyStroke => false;

  TextEditingValue onTextEdit(TextEditingValue value, Terminal terminal) {
    if (value.text.length > _placeholder.length) {
      terminal.onInput(value.text.substring(_placeholder.length));
    } else if (value.text.length < _placeholder.length) {
      terminal.keyInput(TerminalKey.backspace);
    } else {
      if (value.selection.baseOffset < 1) {
        terminal.keyInput(TerminalKey.arrowLeft);
      } else if (value.selection.baseOffset > 1) {
        terminal.keyInput(TerminalKey.arrowRight);
      }
    }

    print(value);
    // return TextEditingValue(text: '  ', composing: TextRange());
    return TextEditingValue(
      text: _placeholder,
      selection: TextSelection.collapsed(offset: 2),
    );
  }

  void onAction(TextInputAction action, Terminal terminal) {
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
