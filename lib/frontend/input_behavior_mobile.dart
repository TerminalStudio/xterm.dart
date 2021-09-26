import 'package:flutter/services.dart';
import 'package:xterm/frontend/input_behavior_default.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/xterm.dart';

class InputBehaviorMobile extends InputBehaviorDefault {
  InputBehaviorMobile();

  @override
  final acceptKeyStroke = true;

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
