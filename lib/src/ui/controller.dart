import 'package:flutter/material.dart';
import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/range.dart';
import 'package:xterm/src/core/buffer/range_block.dart';
import 'package:xterm/src/core/buffer/range_line.dart';
import 'package:xterm/src/ui/selection_mode.dart';

class TerminalController with ChangeNotifier {
  BufferRange? _selection;

  BufferRange? get selection => _selection;

  SelectionMode _selectionMode;

  SelectionMode get selectionMode => _selectionMode;

  TerminalController({SelectionMode selectionMode = SelectionMode.line})
      : _selectionMode = selectionMode;

  /// Set selection on the terminal to [range]. For now [range] could be either
  /// a [BufferRangeLine] or a [BufferRangeBlock]. This is not effected by
  /// [selectionMode].
  void setSelection(BufferRange? range) {
    range = range?.normalized;

    if (_selection != range) {
      _selection = range;
      notifyListeners();
    }
  }

  /// Set selection on the terminal to the minimum range that contains both
  /// [begin] and [end]. The type of range is determined by [selectionMode].
  void setSelectionRange(CellOffset begin, CellOffset end) {
    final range = _modeRange(begin, end);
    setSelection(range);
  }

  BufferRange _modeRange(CellOffset begin, CellOffset end) {
    switch (selectionMode) {
      case SelectionMode.line:
        return BufferRangeLine(begin, end);
      case SelectionMode.block:
        return BufferRangeBlock(begin, end);
    }
  }

  /// Controls how the terminal behaves when the user selects a range of text.
  /// The default is [SelectionMode.line]. Setting this to [SelectionMode.block]
  /// enables block selection mode.
  void setSelectionMode(SelectionMode newSelectionMode) {
    // If the new mode is the same as the old mode,
    // nothing has to be changed.
    if (_selectionMode == newSelectionMode) {
      return;
    }
    // Set the new mode.
    _selectionMode = newSelectionMode;
    // Check if an active selection exists.
    final selection = _selection;
    if (selection == null) {
      notifyListeners();
      return;
    }
    // Convert the selection into a selection corresponding to the new mode.
    setSelection(_modeRange(selection.begin, selection.end));
  }

  /// Clears the current selection.
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
