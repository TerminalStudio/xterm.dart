import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/frontend/input_behavior.dart';
import 'package:xterm/frontend/input_map.dart';
import 'package:xterm/xterm.dart';

class InputBehaviorDefault extends InputBehavior {
  InputBehaviorDefault();

  @override
  bool get acceptKeyStroke => true;

  @override
  TextEditingValue get initEditingState => TextEditingValue.empty;

  @override
  void onKeyStroke(RawKeyEvent event, Terminal terminal) {
    if (event is! RawKeyDownEvent) {
      return;
    }

    final key = inputMap(event.logicalKey);

    if (key != null) {
      terminal.keyInput(
        key,
        ctrl: event.isControlPressed,
        alt: event.isAltPressed,
        shift: event.isShiftPressed,
      );
    }
  }

  String? _composingString = null;

  @override
  TextEditingValue? onTextEdit(TextEditingValue value, Terminal terminal) {
    // we just want to detect if a composing is going on and notify the terminal
    // about it
    if (value.composing.start != value.composing.end) {
      _composingString = (_composingString ?? '') + value.text;
      terminal.updateComposingString(true, _composingString!);
      return null;
    }
    if (_composingString != null) {
      _composingString = null;
      terminal.updateComposingString(false, '');
    }
    terminal.onInput(value.text);
    if (value == TextEditingValue.empty ||
        value.text == null ||
        value.text == '') {
      return null;
    } else {
      return TextEditingValue.empty;
    }
  }

  @override
  void onAction(TextInputAction action, Terminal terminal) {
    //
  }
}
