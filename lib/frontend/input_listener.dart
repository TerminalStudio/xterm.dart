import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

typedef KeyStrokeHandler = void Function(RawKeyEvent);
typedef InputHandler = void Function(String);
typedef ActionHandler = void Function(TextInputAction);
typedef FocusHandler = void Function(bool);

abstract class InputListenerController {
  void requestKeyboard();
}

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

  static InputListenerController of(BuildContext context) {
    return context.findAncestorStateOfType<InputListenerState>();
  }
}

class InputListenerState extends State<InputListener>
    implements InputListenerController {
  var focused = false;
  TextInputConnection conn;

  @override
  void initState() {
    focused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(onFocusChange);
    super.initState();
  }

  @override
  void didUpdateWidget(InputListener oldWidget) {
    oldWidget.focusNode.removeListener(onFocusChange);
    widget.focusNode.addListener(onFocusChange);

    onFocusChange();

    super.didUpdateWidget(oldWidget);
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

  void requestKeyboard() {
    if (widget.focusNode.hasFocus) {
      openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  void onFocusChange() {
    if (focused == widget.focusNode.hasFocus) {
      return;
    }

    focused = widget.focusNode.hasFocus;

    if (widget.onFocus != null) {
      widget.onFocus(focused);
    }

    openOrCloseInputConnectionIfNeeded();
  }

  void openOrCloseInputConnectionIfNeeded() {
    if (widget.focusNode.hasFocus && widget.focusNode.consumeKeyboardToken()) {
      openInputConnection();
    } else if (!widget.focusNode.hasFocus) {
      closeInputConnectionIfNeeded();
    }
  }

  void openInputConnection() {
    if (conn != null && conn.attached) {
      conn.show();
    } else {
      final config = TextInputConfiguration();
      final client = TerminalTextInputClient(onInput, onAction);
      conn = TextInput.attach(client, config);

      final dx = 0.0;
      final dy = 0.0;
      conn.setEditableSizeAndTransform(
        Size(10, 10),
        Matrix4.translationValues(dx, dy, 0.0),
      );

      conn.show();
    }
  }

  void closeInputConnectionIfNeeded() {
    if (conn != null && conn.attached) {
      conn.close();
      conn = null;
    }
  }

  void onInput(String text) {
    widget.onInput(text);
    conn?.setEditingState(TextEditingValue.empty);
  }

  void onAction(TextInputAction action) {
    //
  }
}

class TerminalTextInputClient extends TextInputClient {
  TerminalTextInputClient(this.onInput, this.onAction);

  final InputHandler onInput;
  final ActionHandler onAction;

  TextEditingValue _savedValue;

  TextEditingValue get currentTextEditingValue {
    return _savedValue;
  }

  AutofillScope get currentAutofillScope {
    return null;
  }

  void updateEditingValue(TextEditingValue value) {
    print('updateEditingValue $value');

    onInput(value.text);

    // if (_savedValue == null || _savedValue.text == '') {
    //   onInput(value.text);
    // } else if (_savedValue.text.length < value.text.length) {
    //   final diff = value.text.substring(_savedValue.text.length);
    //   onInput(diff);
    // }

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

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // print('performPrivateCommand $action');
  }
}
