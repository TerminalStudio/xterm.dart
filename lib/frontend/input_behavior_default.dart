import 'package:flutter/services.dart';
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
  void onKeyStroke(RawKeyEvent event, TerminalUiInteraction terminal) {
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
        mac: terminal.platform.useMacInputBehavior,
        character: event.character,
      );
    }
  }

  String? _composingString;

  TextEditingValue? _lastEditingState;

  @override
  TextEditingValue? onTextEdit(
      TextEditingValue value, TerminalUiInteraction terminal) {
    var inputText = value.text;
    // we just want to detect if a composing is going on and notify the terminal
    // about it
    if (value.composing.start != value.composing.end) {
      _composingString = inputText;
      terminal.updateComposingString(_composingString!);
      _lastEditingState = value;
      return null;
    }
    //when we reach this point the composing state is over
    if (_composingString != null) {
      _composingString = null;
      terminal.updateComposingString('');
    }

    //this is a hack to bypass some race condition in the input system
    //we just take the last rune if there are more than one as it sometimes
    //happens that the last value is still part of the new value

    if (_lastEditingState?.text.isNotEmpty == true) {
      if (inputText.length > _lastEditingState!.text.length) {
        inputText = inputText.substring(_lastEditingState!.text.length);
      }
    }

    if (inputText.isNotEmpty) {
      terminal.raiseOnInput(inputText);
    }

    _lastEditingState = value;

    if (value == TextEditingValue.empty || inputText == '') {
      return null;
    } else {
      return TextEditingValue.empty;
    }
  }

  @override
  void onAction(TextInputAction action, TerminalUiInteraction terminal) {
    //
  }
}
