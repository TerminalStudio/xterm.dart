class CircularList<T> {
  CircularList(int maxLength) : _array = List<T?>.filled(maxLength, null);

  late List<T?> _array;
  var _length = 0;
  var _startIndex = 0;

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

  void forEach(void Function(T item) callback) {
    final length = _length;
    for (int i = 0; i < length; i++) {
      callback(_array[_getCyclicIndex(i)]!);
    }
  }

  T operator [](int index) {
    if (index >= length) {
      throw RangeError.range(index, 0, length - 1);
    }

    return _array[_getCyclicIndex(index)]!;
  }

  operator []=(int index, T value) {
    if (index >= length) {
      throw RangeError.range(index, 0, length - 1);
    }

    _array[_getCyclicIndex(index)] = value;
  }

  void clear() {
    _startIndex = 0;
    _length = 0;
  }

  void pushAll(Iterable<T> items) {
    items.forEach((element) {
      push(element);
    });
  }

  void push(T value) {
    _array[_getCyclicIndex(_length)] = value;
    if (_length == _array.length) {
      _startIndex++;
      if (_startIndex == _array.length) {
        _startIndex = 0;
      }
    } else {
      _length++;
    }
  }

  /// Removes and returns the last value on the list
  T pop() {
    return _array[_getCyclicIndex(_length-- - 1)]!;
  }

  /// Deletes item at [index].
  void remove(int index, [int count = 1]) {
    if (count > 0) {
      if (index + count >= _length) {
        count = _length - index;
      }
      for (var i = index; i < _length - count; i++) {
        _array[_getCyclicIndex(i)] = _array[_getCyclicIndex(i + count)];
      }
      length -= count;
    }
  }

  /// Inserts [item] at [index].
  void insert(int index, T item) {
    if (index == 0 && _length >= _array.length) {
      // when something is inserted at index 0 and the list is full then
      // the new value immediately gets removed => nothing changes
      return;
    }
    for (var i = _length - 1; i >= index; i--) {
      _array[_getCyclicIndex(i + 1)] = _array[_getCyclicIndex(i)];
    }

    _array[_getCyclicIndex(index)] = item;

    if (_length + 1 > _array.length) {
      _startIndex += 1;
    } else {
      _length++;
    }
  }

  /// Inserts [items] at [index] in order.
  void insertAll(int index, List<T> items) {
    for (var i = items.length - 1; i >= 0; i--) {
      insert(index, items[i]);
      // when the list is full then we have to move the index down
      // as newly inserted values remove values with a lower index
      if (_length >= _array.length) {
        index--;
        if (index < 0) {
          return;
        }
      }
    }
  }

  void trimStart(int count) {
    if (count > _length) count = _length;
    _startIndex += count;
    _startIndex %= _array.length;
    _length -= count;
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
        }
      }
    } else {
      for (var i = 0; i < count; i++) {
        this[start + i + offset] = this[start + i];
      }
    }
  }

  void replaceWith(List<T> replacement) {
    var copyStart = 0;
    if (replacement.length > maxLength) {
      copyStart = replacement.length - maxLength;
    }

    final copyLength = replacement.length - copyStart;
    for (var i = 0; i < copyLength; i++) {
      _array[i] = replacement[copyStart + i];
    }

    _startIndex = 0;
    _length = copyLength;
  }

  bool get isFull => length == maxLength;

  List<T> toList() {
    return List<T>.generate(length, (index) => this[index]);
  }
}
