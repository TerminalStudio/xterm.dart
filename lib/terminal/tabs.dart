class Tabs {
  final _stops = <int>{};

  void setAt(int index) {
    _stops.add(index);
  }

  void clearAt(int index) {
    _stops.remove(index);
  }

  void clearAll() {
    _stops.clear();
  }

  bool isSetAt(int index) {
    return _stops.contains(index);
  }

  void reset() {
    clearAll();
    const maxTabs = 1024;
    const tabLength = 4;
    for (var i = 0; i < maxTabs; i += tabLength) {
      setAt(i);
    }
  }
}
