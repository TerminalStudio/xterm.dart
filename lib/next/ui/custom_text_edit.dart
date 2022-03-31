import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextEdit extends StatefulWidget {
  CustomTextEdit({
    Key? key,
    required this.child,
    required this.onInsert,
    required this.onDelete,
    required this.onComposing,
    required this.onAction,
    required this.onKey,
    required this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    // this.initEditingState = TextEditingValue.empty,
    this.inputType = TextInputType.text,
    this.inputAction = TextInputAction.done,
    this.keyboardAppearance = Brightness.light,
  }) : super(key: key);

  final Widget child;

  final void Function(String) onInsert;

  final void Function() onDelete;

  final void Function(String?) onComposing;

  final void Function(TextInputAction) onAction;

  final KeyEventResult Function(RawKeyEvent) onKey;

  final FocusNode focusNode;

  final bool autofocus;

  final bool readOnly;

  final TextInputType inputType;

  final TextInputAction inputAction;

  final Brightness keyboardAppearance;

  @override
  CustomTextEditState createState() => CustomTextEditState();
}

class CustomTextEditState extends State<CustomTextEdit>
    implements DeltaTextInputClient {
  TextInputConnection? _connection;

  @override
  void initState() {
    widget.focusNode.addListener(_onFocusChange);
    super.initState();
  }

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
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKey: _onKey,
      child: widget.child,
    );
  }

  bool get hasInputConnection => _connection != null && _connection!.attached;

  void requestKeyboard() {
    if (widget.focusNode.hasFocus) {
      _openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  void setEditingState(TextEditingValue value) {
    _currentEditingValue = value;
    _connection?.setEditingState(value);
  }

  void setEditableRect(Rect rect, Rect caretRect) {
    if (!hasInputConnection) {
      return;
    }

    _connection?.setEditableSizeAndTransform(
      rect.size,
      Matrix4.translationValues(0, 0, 0),
    );

    _connection?.setCaretRect(caretRect);
  }

  void _onFocusChange() {
    _openOrCloseInputConnectionIfNeeded();
  }

  KeyEventResult _onKey(FocusNode focusNode, RawKeyEvent event) {
    if (hasInputConnection && !_currentEditingValue.composing.isCollapsed) {
      return KeyEventResult.skipRemainingHandlers;
    }

    return widget.onKey(event);
  }

  void _openOrCloseInputConnectionIfNeeded() {
    if (widget.focusNode.hasFocus && widget.focusNode.consumeKeyboardToken()) {
      _openInputConnection();
    } else if (!widget.focusNode.hasFocus) {
      _closeInputConnectionIfNeeded();
    }
  }

  bool get _shouldCreateInputConnection => kIsWeb || !widget.readOnly;

  void _openInputConnection() {
    if (!_shouldCreateInputConnection) {
      return;
    }

    if (hasInputConnection) {
      _connection!.show();
    } else {
      final config = TextInputConfiguration(
        inputType: widget.inputType,
        inputAction: widget.inputAction,
        keyboardAppearance: widget.keyboardAppearance,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        enableDeltaModel: true,
      );

      _connection = TextInput.attach(this, config);

      _connection!.show();

      // setEditableRect(Rect.zero, Rect.zero);

      _connection!.setEditingState(_initEditingValue);
    }
  }

  void _closeInputConnectionIfNeeded() {
    if (_connection != null && _connection!.attached) {
      _connection!.close();
      _connection = null;
    }
  }

  final _initEditingValue = TextEditingValue(
    text: '  ',
    selection: TextSelection.collapsed(offset: 2),
  );

  late var _currentEditingValue = _initEditingValue.copyWith();

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

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    final oldEditingValue = _currentEditingValue;

    var haveInsert = false;

    for (var delta in textEditingDeltas) {
      _currentEditingValue = delta.apply(_currentEditingValue);

      if (delta is TextEditingDeltaInsertion) {
        if (_currentEditingValue.composing.isCollapsed) {
          widget.onInsert(delta.textInserted);
          haveInsert = true;
        }
      } else if (delta is TextEditingDeltaDeletion) {
        if (_currentEditingValue.text.length < _initEditingValue.text.length) {
          widget.onDelete();
        }
      } else if (delta is TextEditingDeltaNonTextUpdate) {
        // if (_currentEditingValue.composing.isCollapsed) {
        //   widget.onInsert(delta.textInserted);
        // }
      } else if (delta is TextEditingDeltaReplacement) {
        // print('TextEditingDeltaReplacement');
      } else {
        // print('${delta.runtimeType}');
      }
    }

    if (!haveInsert &&
        !oldEditingValue.composing.isCollapsed &&
        _currentEditingValue.composing.isCollapsed) {
      final composeStart = oldEditingValue.composing.start;
      final composedText = _currentEditingValue.text.substring(composeStart);
      widget.onInsert(composedText);
    }

    if (_currentEditingValue.composing.isCollapsed) {
      widget.onComposing(null);
    } else {
      final text = _currentEditingValue.text;
      widget.onComposing(_currentEditingValue.composing.textInside(text));
    }

    if (_currentEditingValue.composing.isCollapsed &&
        _currentEditingValue != _initEditingValue) {
      _connection!.setEditingState(_initEditingValue);
    }
  }
}
