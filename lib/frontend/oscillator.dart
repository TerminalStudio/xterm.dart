import 'dart:async';

import 'package:xterm/util/observable.dart';

class Oscillator with Observable {
  Oscillator(this.duration);

  Oscillator.ms(int ms) : duration = Duration(milliseconds: ms);

  final Duration duration;

  var _value = true;
  Timer? _timer;
  var _shouldRun = false;

  @override
  void addListener(listener) {
    super.addListener(listener);
    resume();
  }

  @override
  void removeListener(listener) {
    super.removeListener(listener);
    if (listeners.isEmpty) {
      pause();
    }
  }

  void _onOscillation(_) {
    _value = !_value;
    notifyListeners();
  }

  bool get value {
    return _value;
  }

  void restart() {
    stop();
    start();
  }

  void start() {
    _value = true;
    _shouldRun = true;
    // only start right away when anyone is listening.
    // the moment a listener gets registered the Oscillator will start
    if (listeners.isNotEmpty) {
      _startInternal();
    }
  }

  void _startInternal() {
    if (_timer != null) return;
    _timer = Timer.periodic(duration, _onOscillation);
  }

  void pause() {
    _stopInternal();
  }

  void resume() {
    if (_shouldRun) {
      _startInternal();
    }
  }

  void stop() {
    _shouldRun = false;
    _stopInternal();
  }

  void _stopInternal() {
    _timer?.cancel();
    _timer = null;
  }
}
