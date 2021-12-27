import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

abstract class InputBehavior {
  const InputBehavior();

  bool get acceptKeyStroke;

  TextEditingValue get initEditingState;

  void onKeyStroke(RawKeyEvent event, TerminalUiInteraction terminal);

  TextEditingValue? onTextEdit(
      TextEditingValue value, TerminalUiInteraction terminal);

  void onAction(TextInputAction action, TerminalUiInteraction terminal);
}
