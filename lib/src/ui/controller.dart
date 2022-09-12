import 'package:flutter/material.dart';
import 'package:xterm/src/core/buffer/range.dart';

class TerminalController with ChangeNotifier {
  BufferRange? _selection;

  BufferRange? get selection => _selection;

  void setSelection(BufferRange? range) {
    range = range?.normalized;

    if (_selection != range) {
      _selection = range;
      notifyListeners();
    }
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
