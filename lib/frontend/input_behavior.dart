import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/xterm.dart';

abstract class InputBehavior {
  const InputBehavior();

  bool get acceptKeyStroke;

  TextEditingValue get initEditingState;

  void onKeyStroke(RawKeyEvent event, Terminal terminal);

  TextEditingValue onTextEdit(TextEditingValue value, Terminal terminal);

  void onAction(TextInputAction action, Terminal terminal);
}
