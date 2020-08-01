import 'dart:async';

import 'package:xterm/utli/observable.dart';

class Oscillator with Observable {
  Oscillator(this.duration);

  Oscillator.ms(int ms) : duration = Duration(milliseconds: ms);

  final Duration duration;

  var _value = true;
  Timer _timer;

  void _onOscillation(_) {
    _value = !_value;
    notifyListeners();
  }

  bool get value {
    return _value;
  }

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(duration, _onOscillation);
  }

  void stop() {
    _timer.cancel();
    _timer = null;
  }
}
