enum TerminalMouseButton {
  left(id: 0),

  middle(id: 1),

  right(id: 2),

  wheelUp(id: 64 + 0, isWheel: true),

  wheelDown(id: 64 + 1, isWheel: true),

  wheelLeft(id: 64 + 2, isWheel: true),

  wheelRight(id: 64 + 3, isWheel: true),
  ;

  /// The id that is used to report a button press or release to the terminal.
  ///
  /// Wheel buttons 4–7 are encoded with bit 6 set (add 64) and the button number
  /// in the low two bits, giving 64 (up), 65 (down), 66 (left), 67 (right). The
  /// button number is transposed into that bit — it is *not* added on top of 64,
  /// or the extra bits read as spurious shift/meta modifiers (e.g. 64+5 = 69 =
  /// wheel-down **+ shift**), which strict applications reject as an invalid wheel
  /// event and ignore — the whole scroll then does nothing.
  final int id;

  /// Whether this button is a mouse wheel button.
  final bool isWheel;

  const TerminalMouseButton({required this.id, this.isWheel = false});
}
