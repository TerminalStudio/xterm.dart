import 'package:flutter/material.dart';
import 'package:xterm/core/buffer/range.dart';

class TerminalController with ChangeNotifier {
  BufferRange? _selection;

  BufferRange? get selection => _selection;

  bool get hasSelection => _selection != null;

  void setSelection(BufferRange? range) {
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
