import 'package:test/test.dart';
import 'package:xterm/core.dart';

void main() {
  group('synchronized output (DEC private mode 2026)', () {
    test('repaints are held between begin (?2026h) and end (?2026l)', () {
      final terminal = Terminal();
      terminal.resize(20, 5);

      var notifications = 0;
      terminal.addListener(() => notifications++);

      // Begin a synchronized update.
      terminal.write('\x1b[?2026h');
      final afterBegin = notifications;

      // Content drawn while the update is held must not trigger a repaint.
      terminal.write('hello');
      terminal.write('\x1b[10;5Hworld');
      expect(notifications, afterBegin,
          reason: 'no repaint while a synchronized update is held');

      // Ending the update flushes exactly one repaint of the completed frame.
      terminal.write('\x1b[?2026l');
      expect(notifications, greaterThan(afterBegin),
          reason: 'a repaint is emitted when the update ends');

      // The content written during the hold is present once painting resumes.
      expect(terminal.buffer.lines[0].toString(), startsWith('hello'));
    });

    test('normal writes still repaint when no update is held', () {
      final terminal = Terminal();
      terminal.resize(20, 5);

      var notifications = 0;
      terminal.addListener(() => notifications++);

      terminal.write('hi');
      expect(notifications, greaterThan(0));
    });
  });
}
