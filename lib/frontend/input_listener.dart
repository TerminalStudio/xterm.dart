import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

typedef KeyStrokeHandler = void Function(RawKeyEvent);
typedef InputHandler = TextEditingValue? Function(TextEditingValue);
typedef ActionHandler = void Function(TextInputAction);
typedef FocusHandler = void Function(bool);

abstract class InputListenerController {
  void requestKeyboard();
  void setCaretRect(Rect rect);
}

class InputListener extends StatefulWidget {
  InputListener({
    required this.child,
    required this.onKeyStroke,
    required this.onTextInput,
    required this.onAction,
    required this.focusNode,
    this.onFocus,
    this.autofocus = false,
    this.listenKeyStroke = true,
    this.readOnly = false,
    this.initEditingState = TextEditingValue.empty,
    this.inputType = TextInputType.text,
    this.enableSuggestions = false,
    this.inputAction = TextInputAction.done,
    this.keyboardAppearance = Brightness.light,
    this.autocorrect = false,
  });

  final Widget child;
  final InputHandler onTextInput;
  final KeyStrokeHandler onKeyStroke;
  final ActionHandler onAction;
  final FocusHandler? onFocus;
  final bool autofocus;
  final FocusNode focusNode;
  final bool listenKeyStroke;
  final bool readOnly;
  final TextEditingValue initEditingState;
  final TextInputType inputType;
  final bool enableSuggestions;
  final TextInputAction inputAction;
  final Brightness keyboardAppearance;
  final bool autocorrect;

  @override
  InputListenerState createState() => InputListenerState();

  static InputListenerController? of(BuildContext context) {
    return context.findAncestorStateOfType<InputListenerState>();
  }
}

class InputListenerState extends State<InputListener>
    implements InputListenerController {
  TextInputConnection? _conn;
  FocusAttachment? _focusAttachment;
  bool _didAutoFocus = false;

  @override
  void initState() {
    _focusAttachment = widget.focusNode.attach(context);
    widget.focusNode.addListener(onFocusChange);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didAutoFocus && widget.autofocus) {
      _didAutoFocus = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).autofocus(widget.focusNode);
        }
      });
    }
  }

  bool get _shouldCreateInputConnection => kIsWeb || !widget.readOnly;

  bool get _hasInputConnection => _conn != null && _conn!.attached;

  @override
  void didUpdateWidget(InputListener oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(onFocusChange);
      _focusAttachment?.detach();
      _focusAttachment = widget.focusNode.attach(context);
      widget.focusNode.addListener(onFocusChange);
    }

    if (!_shouldCreateInputConnection) {
      closeInputConnectionIfNeeded();
    } else {
      if (oldWidget.readOnly && widget.focusNode.hasFocus) {
        openInputConnection();
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _focusAttachment?.detach();
  }

  @override
  Widget build(BuildContext context) {
    _focusAttachment?.reparent();

    if (widget.listenKeyStroke) {
      return RawKeyboardListener(
        focusNode: widget.focusNode,
        onKey: widget.onKeyStroke,
        autofocus: widget.autofocus,
        child: widget.child,
      );
    }

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      includeSemantics: false,
      child: widget.child,
    );
  }

  @override
  void requestKeyboard() {
    if (widget.focusNode.hasFocus) {
      openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  @override
  void setCaretRect(Rect rect) {
    _conn?.setCaretRect(rect);
  }

  void onFocusChange() {
    if (widget.onFocus != null) {
      widget.onFocus?.call(widget.focusNode.hasFocus);
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
    if (!_shouldCreateInputConnection) {
      return;
    }

    if (_hasInputConnection) {
      _conn!.show();
    } else {
      final config = TextInputConfiguration(
        inputType: widget.inputType,
        enableSuggestions: widget.enableSuggestions,
        inputAction: widget.inputAction,
        keyboardAppearance: widget.keyboardAppearance,
        autocorrect: widget.autocorrect,
      );
      final client = TerminalTextInputClient(onInput, onAction);
      _conn = TextInput.attach(client, config);

      _conn!.show();

      final dx = 0.0;
      final dy = 0.0;
      _conn!.setEditableSizeAndTransform(
        Size(10, 10),
        Matrix4.translationValues(dx, dy, 0.0),
      );

      _conn!.setEditingState(widget.initEditingState);
    }
  }

  void closeInputConnectionIfNeeded() {
    if (_conn != null && _conn!.attached) {
      _conn!.close();
      _conn = null;
    }
  }

  void onInput(TextEditingValue value) {
    final newValue = widget.onTextInput(value);

    if (newValue != null) {
      _conn?.setEditingState(newValue);
    } else {
      _conn?.setEditingState(TextEditingValue.empty);
    }
  }

  void onAction(TextInputAction action) {
    widget.onAction(action);
  }
}

class TerminalTextInputClient extends TextInputClient {
  TerminalTextInputClient(this.onInput, this.onAction);

  final void Function(TextEditingValue) onInput;
  final ActionHandler onAction;

  TextEditingValue? _savedValue;

  TextEditingValue? get currentTextEditingValue {
    return _savedValue;
  }

  AutofillScope? get currentAutofillScope {
    return null;
  }

  void updateEditingValue(TextEditingValue value) {
    // print('updateEditingValue $value');

    if (value.text != '') {
      onInput(value);
    }

    _savedValue = value;
    // print('updateEditingValue $value');
  }

  void performAction(TextInputAction action) {
    // print('performAction $action');
    onAction(action);
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
