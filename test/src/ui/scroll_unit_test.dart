import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/src/ui/scroll_unit.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  double perLine(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    return TerminalScrollUnit.pixelsPerLine!;
  }

  test('a notch of the wheel is three lines on every desktop', () {
    // What each engine reports for one notch, in logical pixels.
    const notch = {
      TargetPlatform.macOS: 40.0,
      TargetPlatform.windows: 100.0,
      TargetPlatform.linux: 53.0,
    };
    for (final MapEntry(key: platform, value: pixels) in notch.entries) {
      expect(TerminalScrollLines().add(pixels, perLine(platform)), 3, reason: '$platform');
    }
  });

  test('a phone has no wheel unit', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(TerminalScrollUnit.pixelsPerLine, isNull);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(TerminalScrollUnit.pixelsPerLine, isNull);
  });

  test('Windows scrolls the lines the system is set to', () {
    // Five lines per notch: the engine sends 5 * 100 / 3 pixels.
    expect(TerminalScrollLines().add(5 * 100 / 3, perLine(TargetPlatform.windows)), 5);
  });

  test('an accelerated wheel scrolls in proportion, the rest kept', () {
    final unit = perLine(TargetPlatform.macOS);
    final lines = TerminalScrollLines();
    // Two and a half notches: seven lines and a half.
    expect(lines.add(100, unit), 7);
    expect(lines.add(20, unit), 2, reason: 'the half line kept');
  });

  test('less than a line waits, in either direction', () {
    final lines = TerminalScrollLines();
    expect(lines.add(-5, 10), 0);
    expect(lines.add(-5, 10), -1);
    expect(lines.add(4, 10), 0);
    lines.reset();
    expect(lines.add(6, 10), 0);
  });
}
