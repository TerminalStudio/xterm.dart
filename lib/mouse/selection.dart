import 'package:xterm/mouse/position.dart';

/// SelectionMode determines how the selected area is determined.
enum SelectionMode {
  /// Line selects full lines between start and end position.
  Line,

  /// Block selects the rectangle spanned by start and end.
  Block,
}

class Selection {
  Position? _start;
  Position? _end;
  SelectionMode _mode = SelectionMode.Block;
  var _endFixed = false;

  Position? get start => _start;
  Position? get end => _end;
  SelectionMode get mode => _mode;

  void init(Position position) {
    _start = position;
    _end = position;
    _endFixed = false;
  }

  void update(Position position) {
    final start = _start;
    if (start == null) {
      return;
    }

    // If the start of the selection is fixed and the new position is before it,
    // the start position becomes the end of the selection and fixed.
    if (position.isBefore(start) && !_endFixed) {
      _endFixed = true;
      _end = _start;
    }

    // If the end of the selection is fixed and the new position is after it,
    // the end position becomes the start of the selection and fixed.
    if (_end != null && position.isAfter(_end!) && _endFixed) {
      _endFixed = false;
      _start = _end;
    }

    if (_endFixed) {
      _start = position;
    } else {
      _end = position;
    }

    // print('($_start, $end');
  }

  void clear() {
    _start = null;
    _end = null;
    _endFixed = false;
  }

  bool contains(Position position) {
    if (isEmpty) {
      return false;
    }
    switch (_mode) {
      case SelectionMode.Line:
        // Check if the position is between _start and _end.
        return _start!.isBeforeOrSame(position) &&
            _end!.isAfterOrSame(position);
      case SelectionMode.Block:
        // Check if the position is within the rectangle
        // spanned by _start and _end.
        return _start!.x <= position.x &&
            position.x <= _end!.x &&
            _start!.y <= position.y &&
            position.y <= _end!.y;
    }
  }

  bool get isEmpty {
    return _start == null || _end == null;
  }

  void setMode(SelectionMode mode) {
    _mode = mode;
  }

}
