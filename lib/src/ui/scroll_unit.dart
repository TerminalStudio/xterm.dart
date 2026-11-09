import 'package:flutter/foundation.dart';

/// How far a mouse wheel scrolls the terminal, in its lines.
///
/// Every `PointerScrollEvent` on a desktop is a wheel: a trackpad arrives as a
/// pan-zoom gesture on macOS, Windows and Linux alike. Each engine scales the
/// wheel's own unit into logical pixels by a fixed factor, Chromium's: 40 per
/// line on macOS, 100/3 per line on Windows (times the system's lines per
/// notch), 53 per notch on Linux. Dividing it back out makes a notch three
/// lines of the terminal everywhere, and on Windows the lines the system is
/// set to; an accelerated or high-resolution wheel scrolls in proportion.
///
/// The factor is the engine's on the machine running this, whatever platform
/// the terminal itself says it is.
abstract final class TerminalScrollUnit {
  /// The pixels of this machine's wheel that make one line of the terminal,
  /// or null where the engine says nothing about its wheel: a phone's scroll
  /// is the finger's own pixels, and a browser hands over pixels of its own.
  static double? get pixelsPerLine {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS => 40 / 3,
      TargetPlatform.windows => 100 / 3,
      TargetPlatform.linux => 53 / 3,
      _ => null,
    };
  }
}

/// Scrolled pixels gathered into whole lines; what falls short of a line
/// waits for the next scroll.
class TerminalScrollLines {
  double _pending = 0;

  /// The whole lines [pixels] completes, signed as it is, at [pixelsPerLine].
  int add(double pixels, double pixelsPerLine) {
    if (pixelsPerLine <= 0) return 0;
    _pending += pixels / pixelsPerLine;
    // 5 * 100 / 3 pixels over 100 / 3 is 4.999…: a whole line short by a
    // rounding error is a whole line.
    final nearest = _pending.roundToDouble();
    final lines = (_pending - nearest).abs() < 1e-6
        ? nearest.toInt()
        : _pending.truncate();
    _pending -= lines;
    return lines;
  }

  void reset() => _pending = 0;
}
