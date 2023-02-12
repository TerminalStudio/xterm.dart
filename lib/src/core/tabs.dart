import 'dart:math' show min;

const _kMaxColumns = 1024;

class TabStops {
  final _stops = List<bool>.filled(_kMaxColumns, false);

  TabStops() {
    setUpTabs();
  }

  void setUpTabs() {
    const interval = 8;
    for (var i = 0; i < _kMaxColumns; i += interval) {
      _stops[i] = true;
    }
  }

  int? find(int start, int end) {
    if (start >= end) {
      return null;
    }
    end = min(end, _stops.length);
    for (var i = start + 1; i < end; i++) {
      if (_stops[i]) {
        return i;
      }
    }
    return null;
  }

  void setAt(int index) {
    assert(index >= 0 && index < _kMaxColumns);
    _stops[index] = true;
  }

  void clearAt(int index) {
    assert(index >= 0 && index < _kMaxColumns);
    _stops[index] = false;
  }

  void clearAll() {
    _stops.fillRange(0, _kMaxColumns, false);
  }

  bool isSetAt(int index) {
    return _stops[index];
  }

  void reset() {
    clearAll();
    setUpTabs();
  }
}
