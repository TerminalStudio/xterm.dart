/// Keeps the default style of newly created cells.
class Cursor {
  Cursor({
    required this.fg,
    required this.bg,
    required this.flags,
  });

  int fg;
  int bg;
  int flags;
}
