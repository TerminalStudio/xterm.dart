class CircularList<T> {
  List<T?> _array;
  int _length = 0;
  int _startIndex = 0;

  Function(int num)? onTrimmed;

  CircularList(int maxLength) : _array = List<T?>.filled(maxLength, null);

  // Gets the cyclic index for the specified regular index. The cyclic index can then be used on the
  // backing array to get the element associated with the regular index.
  int _getCyclicIndex(int index) {
    return (_startIndex + index) % _array.length;
  }

  int get maxLength {
    return _array.length;
  }

  set maxLength(int value) {
    if (value <= 0)
      throw ArgumentError.value(
          value, 'value', 'maxLength can\'t be negative!');

    if (value == _array.length) return;

    // Reconstruct array, starting at index 0. Only transfer values from the
    // indexes 0 to length.
    final newArray = List<T?>.generate(
      value,
      (index) => index < _array.length ? _array[_getCyclicIndex(index)] : null,
    );

    _startIndex = 0;
    _array = newArray;
  }

  int get length {
    return _length;
  }

  set length(int value) {
    if (value > _length) {
      for (int i = length; i < value; i++) {
        _array[i] = null;
      }
    }
    _length = value;
  }

  void forEach(
    void Function(T? item, int index) callback, [
    bool includeBuffer = false,
  ]) {
    final len = includeBuffer ? _array.length : _length;
    for (int i = 0; i < len; i++) {
      callback(_array[_getCyclicIndex(i)], i);
    }
  }

  T operator [](int index) {
    if (index > length - 1) {
      throw RangeError.range(index, 0, length - 1);
    }

    return _array[_getCyclicIndex(index)]!;
  }

  operator []=(int index, T value) {
    if (index > length - 1) {
      throw RangeError.range(index, 0, length - 1);
    }

    _array[_getCyclicIndex(index)] = value;
  }

  void clear() {
    _startIndex = 0;
    _length = 0;
  }

  void push(T value) {
    _array[_getCyclicIndex(_length)] = value;
    if (_length == _array.length) {
      _startIndex++;
      if (_startIndex == _array.length) {
        _startIndex = 0;
      }
      onTrimmed?.call(1);
    } else {
      _length++;
    }
  }

  /// Removes and returns the last value on the list
  T pop() {
    return _array[_getCyclicIndex(_length-- - 1)]!;
  }

  /// Deletes and/or inserts items at a particular index (in that order).
  void splice(int start, int deleteCount, List<T> items) {
    // delete items
    if (deleteCount > 0) {
      for (int i = start; i < _length - deleteCount; i++)
        _array[_getCyclicIndex(i)] = _array[_getCyclicIndex(i + deleteCount)];
      length -= deleteCount;
    }
    if (items.length != 0) {
      // add items
      for (int i = _length - 1; i >= start; i--)
        _array[_getCyclicIndex(i + items.length)] = _array[_getCyclicIndex(i)];
      for (int i = 0; i < items.length; i++)
        _array[_getCyclicIndex(start + i)] = items[i];
    }

    // Adjust length as needed
    if (_length + items.length > _array.length) {
      int countToTrim = _length + items.length - _array.length;
      _startIndex += countToTrim;
      length = _array.length;
      onTrimmed?.call(countToTrim);
    } else {
      _length += items.length;
    }
  }

  void trimStart(int count) {
    if (count > _length) count = _length;

    // TODO: perhaps bug in original code, this does not clamp the value of startIndex
    _startIndex += count;
    _length -= count;
    onTrimmed?.call(count);
  }

  void shiftElements(int start, int count, int offset) {
    if (count < 0) return;
    if (start < 0 || start >= _length)
      throw Exception('Start argument is out of range');
    if (start + offset < 0)
      throw Exception('Can not shift elements in list beyond index 0');
    if (offset > 0) {
      for (var i = count - 1; i >= 0; i--) {
        this[start + i + offset] = this[start + i];
      }
      var expandListBy = (start + count + offset) - _length;
      if (expandListBy > 0) {
        _length += expandListBy;
        while (_length > _array.length) {
          length--;
          _startIndex++;
          onTrimmed?.call(1);
        }
      }
    } else {
      for (var i = 0; i < count; i++) {
        this[start + i + offset] = this[start + i];
      }
    }
  }

  bool get isFull => length == maxLength;

  List<T> toList() {
    return List<T>.generate(length, (index) => this[index]!);
  }
}
