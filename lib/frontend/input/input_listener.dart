import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef KeyStrokeHandler = KeyEventResult Function(FocusNode, RawKeyEvent);
typedef InputHandler = TextEditingValue? Function(TextEditingValue);
typedef ActionHandler = void Function(TextInputAction);
typedef FocusChangeHandler = void Function(bool);

abstract class InputController {
  void requestKeyboard();
  void setEditableSizeAndOffset(Size size, Offset offset);
}

class InputListener extends StatefulWidget {
  InputListener({
    required this.child,
    required this.focusNode,
    required this.onKey,
    required this.onInput,
    required this.onAction,
    this.onFocusChange,
    this.autofocus = false,
    this.initEditingState = TextEditingValue.empty,
  });

  final Widget child;
  final FocusNode focusNode;
  final bool autofocus;

  final InputHandler onInput;
  final KeyStrokeHandler onKey;
  final ActionHandler onAction;
  final FocusChangeHandler? onFocusChange;

  final TextEditingValue initEditingState;

  @override
  InputListenerState createState() => InputListenerState();

  static InputController? of(BuildContext context) {
    return context.findAncestorStateOfType<InputListenerState>();
  }
}

class InputListenerState extends State<InputListener>
    implements InputController, TextInputClient {
  @override
  void initState() {
    widget.focusNode.addListener(_onFocusChange);
    super.initState();
  }

  @override
  void didUpdateWidget(InputListener oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }

    if (widget.focusNode.hasFocus) {
      _openInputConnection();
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.focusNode.removeListener(_onFocusChange);
    _closeInputConnectionIfNeeded();
  }

  void _onFocusChange() {
    _openOrCloseInputConnectionIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKey: widget.onKey,
      onFocusChange: widget.onFocusChange,
      includeSemantics: false,
      child: widget.child,
    );
  }

  /* TextInputConnection related */

  TextInputConnection? _inputConnection;

  bool get _hasInputConnection {
    return _inputConnection != null && _inputConnection!.attached;
  }

  void _openOrCloseInputConnectionIfNeeded() {
    if (widget.focusNode.hasFocus && widget.focusNode.consumeKeyboardToken()) {
      _openInputConnection();
    } else if (!widget.focusNode.hasFocus) {
      _closeInputConnectionIfNeeded();
    }
  }

  void _openInputConnection() {
    if (_hasInputConnection) {
      _inputConnection!.show();
    } else {
      final config = TextInputConfiguration();
      _inputConnection = TextInput.attach(this, config);
      _inputConnection!.show();

      setEditableSizeAndOffset(Size.zero, Offset.zero);
      _inputConnection!.setEditingState(widget.initEditingState);
    }
  }

  void _closeInputConnectionIfNeeded() {
    if (_inputConnection != null && _inputConnection!.attached) {
      _inputConnection!.close();
      _inputConnection = null;
    }
  }

  /* InputController implementation */

  @override
  void requestKeyboard() {
    if (widget.focusNode.hasFocus) {
      _openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  @override
  void setEditableSizeAndOffset(Size size, Offset offset) {
    assert(_inputConnection != null);
    _inputConnection!.setEditableSizeAndTransform(
      size,
      Matrix4.translationValues(offset.dx, offset.dy, 0.0),
    );
  }

  /* TextInputClient implementation */

  TextEditingValue? currentTextEditingValue;

  AutofillScope? get currentAutofillScope {
    return null;
  }

  void updateEditingValue(TextEditingValue value) {
    final newValue = widget.onInput(value);
    currentTextEditingValue = newValue ?? value;

    if (newValue != null) {
      _inputConnection?.setEditingState(newValue);
    }

    // print('updateEditingValue $value');
  }

  void performAction(TextInputAction action) {
    // print('performAction $action');
    widget.onAction(action);
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
