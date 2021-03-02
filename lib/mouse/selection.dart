import 'package:xterm/mouse/position.dart';

class Selection {
  Position? _start;
  Position? _end;
  var _endFixed = false;

  Position? get start => _start;
  Position? get end => _end;

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

    if (position.isBefore(start) && !_endFixed) {
      _endFixed = true;
      _end = _start;
    }

    if (position.isAfter(start) && _endFixed) {
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

    return _start!.isBeforeOrSame(position) && _end!.isAfterOrSame(position);
  }

  bool get isEmpty {
    return _start == null || _end == null;
  }
}
