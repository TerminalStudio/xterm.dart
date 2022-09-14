import 'package:flutter/material.dart';
import 'package:xterm/src/core/buffer/range.dart';
import 'package:xterm/src/ui/pointer_input.dart';

class TerminalController with ChangeNotifier {
  BufferRange? _selection;

  BufferRange? get selection => _selection;

  PointerInputs _pointerInputs;
  bool _suspendPointerInputs;

  /// True if sending pointer events to the terminal is suspended.
  bool get suspendedPointerInputs => _suspendPointerInputs;

  /// The set of pointer events which will be used as mouse input for the terminal.
  PointerInputs get pointerInput => _pointerInputs;

  TerminalController({
    PointerInputs pointerInputs = const PointerInputs.none(),
    bool suspendPointerInput = false,
  })  : _pointerInputs = pointerInputs,
        _suspendPointerInputs = suspendPointerInput;

  void setSelection(BufferRange? range) {
    range = range?.normalized;

    if (_selection != range) {
      _selection = range;
      notifyListeners();
    }
  }

  // Select which type of pointer events are send to the terminal.
  void setPointerInputs(PointerInputs pointerInput) {
    _pointerInputs = pointerInput;
    notifyListeners();
  }

  // Toggle sending pointer events to the terminal.
  void setSuspendPointerInput(bool suspend) {
    _suspendPointerInputs = suspend;
    notifyListeners();
  }

  // Returns true if this type of PointerInput should be send to the Terminal.
  bool shouldSendPointerInput(PointerInput pointerInput) {
    // Always return false if pointer input is suspended.
    return _suspendPointerInputs
        ? false
        : _pointerInputs.inputs.contains(pointerInput);
  }

  void clearSelection() {
    _selection = null;
    notifyListeners();
  }

  void addHighlight(BufferRange? range) {
    // TODO: implement addHighlight
  }

  void clearHighlight() {
    // TODO: implement clearHighlight
  }
}
