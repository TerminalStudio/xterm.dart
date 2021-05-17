import 'dart:async';

/// EventDebouncer makes sure that events aren't fired at a higher frequency
/// than specified.
/// To ensure that EventDebouncer will ignore events that happen in between
/// and just call the latest event that happened.
class EventDebouncer {
  final Duration _debounceDuration;
  Timer? _debounceTimer;
  Function? _latestCallback;

  EventDebouncer(this._debounceDuration);

  void _consumeLatestCallback() {
    if (!(_debounceTimer?.isActive ?? false)) {
      _debounceTimer = null;
    }

    if (_latestCallback == null) {
      return;
    }

    if (_debounceTimer == null) {
      _latestCallback!();
      _latestCallback = null;
      _debounceTimer = Timer(
        _debounceDuration,
        () {
          _consumeLatestCallback();
        },
      );
    }
  }

  void notifyEvent(Function callback) {
    _latestCallback = callback;
    _consumeLatestCallback();
  }
}
