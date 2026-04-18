// T67 regression tests — nano/vim cursor misalignment over raw SSH.
//
// Context: xterm (Dart port) 4.0.0 miscounts cursor position in ncurses
// applications like nano and vim when run without tmux. Diagnostics showed
// PTY size and TERM propagation are correct; web (xterm.js) renders the same
// sequences correctly. So the bug is in this parser/buffer pair.
//
// Each test targets a hypothesis from specs/t67-xterm-fork.md §3.1.
// A failing test localizes the bug; a passing test rules that hypothesis out.
//
// Run from repo root:  dart test test/src/regression/nano_vim_cursor_test.dart

import 'package:test/test.dart';
import 'package:xterm/core.dart';

/// Helper: stringify a row of the main buffer, trimming trailing spaces.
String row(Terminal t, int y) => t.buffer.lines[y].toString().trimRight();

/// Helper: fill each visible row with a unique marker so we can see what moves.
void fillRows(Terminal t, {int rows = 24}) {
  for (var i = 0; i < rows; i++) {
    t.write('L$i');
    if (i < rows - 1) t.write('\r\n');
  }
}

void main() {
  group('T67 — scroll region & cursor regression (nano/vim bug)', () {
    // ---- H1: DECSTBM + RI (Reverse Index) at top margin ----------
    //
    // Issue #94 symptom: "when cursor hits top of screen, vim does not
    // scroll up properly. Only first line content changed, other lines
    // remain unchanged."
    //
    // Classic trigger: RI (ESC M) at top of scroll region should scroll
    // the entire region DOWN by one line — top row becomes blank, all
    // other rows shift down, bottom row drops off.

    test('RI at top of screen (no DECSTBM) scrolls full screen down', () {
      final t = Terminal(maxLines: 100);
      t.resize(80, 24);
      fillRows(t, rows: 24);
      // Cursor is now past L23 on row 23. Move home.
      t.write('\x1b[H'); // CUP 1;1 → (0, 0)
      expect(t.buffer.cursorX, 0);
      expect(t.buffer.cursorY, 0);

      t.write('\x1bM'); // RI — should scroll region (full screen) down 1
      expect(row(t, 0), isEmpty, reason: 'top row must be blank after RI');
      expect(row(t, 1), 'L0', reason: 'L0 must shift from row 0 to row 1');
      expect(row(t, 23), 'L22', reason: 'L22 shifts from row 22 to row 23');
      // L23 falls off the bottom of the region (can reappear in scrollback
      // on main screen — we don't assert on that here).
    });

    test('RI at top of DECSTBM region (rows 2..10) scrolls only the region', () {
      final t = Terminal(maxLines: 100);
      t.resize(80, 24);
      fillRows(t, rows: 24);

      // Set scroll region to rows 2..10 (1-based in the wire protocol → CSI 2;10r).
      t.write('\x1b[2;10r');
      // CUP to top of region (row 2, 1-based = (0, 1) zero-based).
      t.write('\x1b[2;1H');
      expect(t.buffer.cursorY, 1);

      t.write('\x1bM'); // RI at top of region → scrollDown(1)

      // Row 0 is OUTSIDE the region — must not change.
      expect(row(t, 0), 'L0', reason: 'row 0 is above region, untouched');
      // Row 1 (top of region) must now be blank.
      expect(row(t, 1), isEmpty, reason: 'top-of-region blanked by RI scroll');
      // Rows 2..9 shift down: row 2 gets what row 1 had (L1), row 3 gets L2,
      // etc., row 9 gets L8.
      expect(row(t, 2), 'L1');
      expect(row(t, 3), 'L2');
      expect(row(t, 9), 'L8');
      // Row 10 is OUTSIDE the region (bottom was 10, 1-based) — untouched.
      expect(row(t, 10), 'L10', reason: 'row 10 is below region, untouched');
      expect(row(t, 23), 'L23');
    });

    // ---- H1b: IND (Index, ESC D / LF) at bottom margin ----------
    //
    // Mirror image: IND at bottom of region should scroll region UP by 1.
    // Buggy buffers often drop content outside region or fail to scroll.

    test('IND at bottom of DECSTBM region scrolls only the region up', () {
      final t = Terminal(maxLines: 100);
      t.resize(80, 24);
      fillRows(t, rows: 24);

      t.write('\x1b[2;10r'); // region rows 2..10 (1-based)
      t.write('\x1b[10;1H'); // CUP to bottom of region (0-based y=9)
      expect(t.buffer.cursorY, 9);

      t.write('\x1bD'); // IND — scroll region up 1

      expect(row(t, 0), 'L0', reason: 'above region untouched');
      expect(row(t, 1), 'L2', reason: 'L2 shifts from row 2 up to row 1');
      expect(row(t, 8), 'L9', reason: 'L9 shifts from row 9 up to row 8');
      expect(row(t, 9), isEmpty, reason: 'bottom of region blanked');
      expect(row(t, 10), 'L10', reason: 'below region untouched');
    });

    // ---- H2: Save/Restore cursor (DECSC / DECRC) ----------
    //
    // Nano saves the cursor before repainting the status bar, moves,
    // then restores. If DECRC doesn't return to the exact saved spot,
    // subsequent writes land on the wrong row/col.

    test('DECSC + writes + DECRC restores exact cursor position', () {
      final t = Terminal(maxLines: 100);
      t.resize(80, 24);

      // Move to (col=10, row=5) — 0-based: (9, 4).
      t.write('\x1b[5;10H');
      expect(t.buffer.cursorX, 9);
      expect(t.buffer.cursorY, 4);

      t.write('\x1b7'); // DECSC

      // Wander: jump far away and write.
      t.write('\x1b[20;40H');
      t.write('X');

      t.write('\x1b8'); // DECRC — back to (9, 4)
      expect(t.buffer.cursorX, 9);
      expect(t.buffer.cursorY, 4);
    });

    test('DECSC/DECRC survives alternate-screen toggle', () {
      final t = Terminal(maxLines: 100);
      t.resize(80, 24);

      t.write('\x1b[5;10H'); // (9, 4)
      t.write('\x1b7'); // save

      t.write('\x1b[?1049h'); // enter alt screen (nano does this)
      t.write('\x1b[20;40H');
      t.write('junk in alt screen');
      t.write('\x1b[?1049l'); // leave alt screen

      t.write('\x1b8'); // restore
      expect(t.buffer.cursorX, 9);
      expect(t.buffer.cursorY, 4);
    });

    // ---- H3: Alternate screen buffer (1049) ----------
    //
    // nano enters alt screen on start, paints UI there, and leaves on exit.
    // Main screen must be unchanged after leave.

    test('alt-screen 1049h/l preserves main buffer content', () {
      final t = Terminal(maxLines: 100);
      t.resize(80, 24);
      fillRows(t, rows: 24);

      t.write('\x1b[?1049h'); // enter alt
      t.write('\x1b[2J');     // clear
      t.write('\x1b[H');
      t.write('inside alt screen');
      t.write('\x1b[?1049l'); // leave alt

      // Main buffer should still have L0..L23 intact.
      expect(row(t, 0), 'L0');
      expect(row(t, 5), 'L5');
      expect(row(t, 23), 'L23');
    });

    // ---- H4: Autowrap / pending-wrap state (DECAWM) ----------
    //
    // When cursor is at column N (last col) after writing there, the cursor
    // should "hover" — next printable char wraps, but control seqs like CR,
    // BS, cursor movement do NOT trigger the deferred wrap.

    test('writing exactly viewWidth chars leaves cursor in pending-wrap', () {
      final t = Terminal(maxLines: 100);
      t.resize(10, 5);
      t.write('\x1b[H');

      t.write('0123456789'); // exactly 10 chars on a 10-wide terminal
      // After this, cursor is conceptually "past" col 9 but wrap is pending.
      // The 10th char must be on row 0, and the next write should land on row 1.
      expect(row(t, 0), '0123456789');
      expect(t.buffer.cursorY, 0,
          reason: 'cursor must still report row 0 (wrap pending, not applied)');

      t.write('X'); // triggers wrap
      expect(row(t, 1).startsWith('X'), isTrue);
      expect(t.buffer.cursorY, 1);
    });

    test('CR after full-width write does NOT itself wrap', () {
      final t = Terminal(maxLines: 100);
      t.resize(10, 5);
      t.write('\x1b[H');
      t.write('0123456789');
      t.write('\r'); // carriage return only

      // CR should move cursor to col 0 of the SAME row, not advance to row 1.
      expect(t.buffer.cursorX, 0);
      expect(t.buffer.cursorY, 0);
    });

    // ---- H6: DSR (Device Status Report) / CPR (Cursor Position Report) ----
    //
    // THE BUG (discovered 2026-04-13):
    //   emitter.cursorPosition() sends buffer.cursorX/cursorY as-is, but
    //   those are 0-indexed. VT100 CPR response is 1-indexed (CSI row;col R).
    //   Result: every CPR reply is off-by-one in both axes.
    //
    // Nano queries CPR at startup and after certain operations, uses the
    // reply to sync its internal cursor model. Off-by-one CPR → nano's
    // model is permanently shifted → "cursor edits at different position".
    //
    // Tmux doesn't forward CPR to xterm.dart (it answers from its own state),
    // which is why nano-in-tmux works. vt100 terminfo typically doesn't
    // trigger CPR queries, which is why vt100 mode looks fine.

    test('CPR reports 1-indexed position at home (should be 1;1, not 0;0)', () {
      final replies = <String>[];
      final t = Terminal(maxLines: 100, onOutput: replies.add);
      t.resize(80, 24);

      t.write('\x1b[H'); // CUP home → (0,0) internal
      replies.clear();
      t.write('\x1b[6n'); // DSR: request cursor position

      expect(replies, hasLength(1));
      expect(replies.first, '\x1b[1;1R',
          reason: 'CPR at home must be CSI 1;1 R (1-indexed per VT100)');
    });

    test('CPR reports 1-indexed after CUP 5;10', () {
      final replies = <String>[];
      final t = Terminal(maxLines: 100, onOutput: replies.add);
      t.resize(80, 24);

      t.write('\x1b[5;10H'); // CUP row=5, col=10 (1-indexed on wire)
      replies.clear();
      t.write('\x1b[6n');

      expect(replies.first, '\x1b[5;10R',
          reason: 'CPR must mirror the 1-indexed coordinates CUP used');
    });

    test('CPR round-trip: CUP → CPR → CUP returns to same visible row', () {
      final replies = <String>[];
      final t = Terminal(maxLines: 100, onOutput: replies.add);
      t.resize(80, 24);

      t.write('\x1b[12;40H'); // go to middle of screen
      final startY = t.buffer.cursorY;
      final startX = t.buffer.cursorX;
      replies.clear();

      t.write('\x1b[6n'); // query
      // Parse reply: CSI row;col R  (1-indexed)
      final reply = replies.first;
      final match = RegExp(r'\x1b\[(\d+);(\d+)R').firstMatch(reply);
      expect(match, isNotNull);
      final reportedRow = int.parse(match!.group(1)!);
      final reportedCol = int.parse(match.group(2)!);

      // Now feed the reply back as a CUP (as if an app did CPR-then-restore).
      t.write('\x1b[$reportedRow;${reportedCol}H');

      expect(t.buffer.cursorY, startY,
          reason: 'CPR round-trip must land on the same row');
      expect(t.buffer.cursorX, startX,
          reason: 'CPR round-trip must land on the same column');
    });

    // ---- H5: CUP (Cursor Position) with DECSTBM ----------
    //
    // CUP is defined to use absolute screen coordinates unless DECOM (origin
    // mode) is enabled. Nano does NOT enable DECOM but does set DECSTBM.
    // So CUP 1;1 must go to (0, 0) regardless of scroll region.

    test('CUP without DECOM is absolute even under DECSTBM', () {
      final t = Terminal(maxLines: 100);
      t.resize(80, 24);

      t.write('\x1b[5;15r'); // scroll region 5..15 (1-based)
      t.write('\x1b[1;1H'); // CUP home
      expect(t.buffer.cursorX, 0);
      expect(t.buffer.cursorY, 0, reason: 'CUP home is absolute (0,0)');
    });
  });
}
