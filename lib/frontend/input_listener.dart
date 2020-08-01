import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

typedef KeyStrokeHandler = void Function(RawKeyEvent);
typedef InputHandler = void Function(String);
typedef FocusHandler = void Function(bool);

class InputListener extends StatefulWidget {
  InputListener({
    @required this.child,
    @required this.onKeyStroke,
    @required this.onInput,
    @required this.focusNode,
    this.onFocus,
    this.autofocus = false,
  });

  final Widget child;
  final InputHandler onInput;
  final KeyStrokeHandler onKeyStroke;
  final FocusHandler onFocus;
  final bool autofocus;
  final FocusNode focusNode;

  @override
  InputListenerState createState() => InputListenerState();
}

class InputListenerState extends State<InputListener> {
  var focused = false;
  TextInputConnection conn;

  @override
  void initState() {
    widget.focusNode.addListener(onFocus);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: widget.focusNode,
      onKey: widget.onKeyStroke,
      autofocus: widget.autofocus,
      child: widget.child,
    );
  }

  void onFocus() {
    if (focused == widget.focusNode.hasFocus) {
      return;
    }

    focused = widget.focusNode.hasFocus;

    if (widget.onFocus != null) {
      widget.onFocus(focused);
    }

    openTextInput();
  }

  void openTextInput() {
    final config = TextInputConfiguration();
    conn = TextInput.attach(
      TerminalTextInputClient(onInput),
      config,
    );

    final dx = 0.0;
    final dy = 0.0;
    conn.setEditableSizeAndTransform(
      Size(10, 10),
      Matrix4.translationValues(dx, dy, 0.0),
    );

    conn.show();
  }

  void onInput(String text) {
    widget.onInput(text);
    conn?.setEditingState(TextEditingValue.empty);
  }
}

class TerminalTextInputClient extends TextInputClient {
  TerminalTextInputClient(this.onInput);

  final InputHandler onInput;

  TextEditingValue _savedValue;

  TextEditingValue get currentTextEditingValue {
    return _savedValue;
  }

  AutofillScope get currentAutofillScope {
    return null;
  }

  void updateEditingValue(TextEditingValue value) {
    // print('updateEditingValue $value');

    if (_savedValue == null) {
      onInput(value.text);
    } else if (_savedValue.text.length < value.text.length) {
      final diff = value.text.substring(_savedValue.text.length);
      onInput(diff);
    }

    _savedValue = value;
    // print('updateEditingValue $value');
  }

  void performAction(TextInputAction action) {
    // print('performAction $action');
  }

  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // print('updateFloatingCursor');
  }

  void showAutocorrectionPromptRect(int start, int end) {
    // print('showAutocorrectionPromptRect');
  }

  void connectionClosed() {
    // print('connectionClosed');
  }
}
