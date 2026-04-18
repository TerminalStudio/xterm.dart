class EscapeEmitter {
  const EscapeEmitter();

  String primaryDeviceAttributes() {
    return '\x1b[?1;2c';
  }

  String secondaryDeviceAttributes() {
    const model = 0;
    const version = 0;
    return '\x1b[>$model;$version;0c';
  }

  String tertiaryDeviceAttributes() {
    return '\x1bP!|00000000\x1b\\';
  }

  String operatingStatus() {
    return '\x1b[0n';
  }

  /// CPR (Cursor Position Report) reply: `CSI row ; col R`, 1-indexed
  /// per VT100 spec. Callers pass 0-indexed [x] (column) and [y] (row)
  /// from the buffer, so we add 1 here. Without the +1, ncurses apps
  /// (nano, vim) that sync their cursor model via DSR get an off-by-one
  /// position and mis-edit subsequently. (T67 — fixes #58, #94)
  String cursorPosition(int x, int y) {
    return '\x1b[${y + 1};${x + 1}R';
  }

  String bracketedPaste(String text) {
    return '\x1b[200~$text\x1b[201~';
  }

  String size(int rows, int cols) {
    return '\x1b[8;$rows;${cols}t';
  }
}
