import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextEdit extends StatefulWidget {
  CustomTextEdit({
    Key? key,
    required this.child,
    required this.onTextInput,
    required this.onAction,
    required this.focusNode,
    this.readOnly = false,
    this.initEditingState = TextEditingValue.empty,
    this.inputType = TextInputType.text,
    this.enableSuggestions = false,
    this.inputAction = TextInputAction.done,
    this.keyboardAppearance = Brightness.light,
    this.autocorrect = false,
  }) : super(key: key);

  final Widget child;

  final void Function(TextEditingValue) onTextInput;

  final void Function(TextInputAction) onAction;

  final FocusNode focusNode;

  final bool readOnly;

  final TextEditingValue initEditingState;

  final TextInputType inputType;

  final bool enableSuggestions;

  final TextInputAction inputAction;

  final Brightness keyboardAppearance;

  final bool autocorrect;

  @override
  CustomTextEditState createState() => CustomTextEditState();
}

class CustomTextEditState extends State<CustomTextEdit>
    implements TextInputClient {
  TextInputConnection? _connection;

  @override
  void initState() {
    widget.focusNode.addListener(_onFocusChange);
    super.initState();
  }

  bool get _shouldCreateInputConnection => kIsWeb || !widget.readOnly;

  bool get _hasInputConnection => _connection != null && _connection!.attached;

  @override
  void didUpdateWidget(CustomTextEdit oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }

    if (!_shouldCreateInputConnection) {
      _closeInputConnectionIfNeeded();
    } else {
      if (oldWidget.readOnly && widget.focusNode.hasFocus) {
        _openInputConnection();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void requestKeyboard() {
    if (widget.focusNode.hasFocus) {
      _openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  void setCaretRect(Rect rect) {
    _connection?.setCaretRect(rect);
  }

  void setEditingState(TextEditingValue value) {
    _currentEditingValue = value;
    _connection?.setEditingState(value);
  }

  void _onFocusChange() {
    _openOrCloseInputConnectionIfNeeded();
  }

  void _openOrCloseInputConnectionIfNeeded() {
    if (widget.focusNode.hasFocus && widget.focusNode.consumeKeyboardToken()) {
      _openInputConnection();
    } else if (!widget.focusNode.hasFocus) {
      _closeInputConnectionIfNeeded();
    }
  }

  void _openInputConnection() {
    if (!_shouldCreateInputConnection) {
      return;
    }

    if (_hasInputConnection) {
      _connection!.show();
    } else {
      final config = TextInputConfiguration(
        inputType: widget.inputType,
        enableSuggestions: widget.enableSuggestions,
        inputAction: widget.inputAction,
        keyboardAppearance: widget.keyboardAppearance,
        autocorrect: widget.autocorrect,
      );

      _connection = TextInput.attach(this, config);

      _connection!.show();

      final dx = 0.0;
      final dy = 0.0;
      _connection!.setEditableSizeAndTransform(
        Size(10, 10),
        Matrix4.translationValues(dx, dy, 0.0),
      );

      _connection!.setEditingState(widget.initEditingState);
    }
  }

  void _closeInputConnectionIfNeeded() {
    if (_connection != null && _connection!.attached) {
      _connection!.close();
      _connection = null;
    }
  }

  TextEditingValue? _currentEditingValue;

  @override
  TextEditingValue? get currentTextEditingValue {
    return _currentEditingValue;
  }

  @override
  AutofillScope? get currentAutofillScope {
    return null;
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    // print('updateEditingValue $value');

    widget.onTextInput(value);

    _currentEditingValue = value;
  }

  @override
  void performAction(TextInputAction action) {
    // print('performAction $action');
    widget.onAction(action);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // print('updateFloatingCursor');
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // print('showAutocorrectionPromptRect');
  }

  @override
  void connectionClosed() {
    // print('connectionClosed');
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // print('performPrivateCommand $action');
  }
}
