import 'package:xterm/next/core/mouse.dart';

abstract class TerminalHandler {
  void writeChar(int char);

  /* SBC */

  void bell();

  void backspaceReturn();

  void tab();

  void newLine();

  void carriageReturn();

  void shiftOut();

  void shiftIn();

  void unkownSBC(int char);

  /* ANSI sequence */

  void sendDeviceAttrs();

  void saveCursor();

  void restoreCursor();

  void index();

  void newline();

  void nextLine();

  void setTapStop();

  void reverseIndex();

  void designateCharset(int charset);

  void unkownEscape(int char);

  /* CSI */

  void unkownCSI(int finalByte);

  void setCursor(int x, int y);

  void setCursorX(int x);

  void setCursorY(int y);

  void sendPrimaryDeviceAttributes();

  void cursorUp(int n);

  void cursorDown(int n);

  void clearTabStopUnderCursor();

  void clearAllTabStops();

  void moveCursorX(int offset);

  void sendSecondaryDeviceAttributes();

  void sendTertiaryDeviceAttributes();

  void sendOperatingStatus();

  void sendCursorPosition();

  void setMargins(int i, [int? bottom]);

  void cursorNextLine(int amount);

  void cursorPrecedingLine(int amount);

  void eraseDisplayBelow();

  void eraseDisplayAbove();

  void eraseDisplay();

  void eraseScrollbackOnly();

  void eraseLineRight();

  void eraseLineLeft();

  void eraseLine();

  void insertLines(int amount);

  void deleteLines(int amount);

  void deleteChars(int amount);

  void scrollUp(int amount);

  void scrollDown(int amount);

  void eraseChars(int amount);

  void insertBlankChars(int amount);

  /* Modes */

  void setInsertMode(bool enabled);

  void setLineFeedMode(bool enabled);

  void setUnknownMode(int mode, bool enabled);

  /* DEC Private modes */

  void setCursorKeysMode(bool enabled);

  void setReverseDisplayMode(bool enabled);

  void setOriginMode(bool enabled);

  void setColumnMode(bool enabled);

  void setAutowrapMode(bool enabled);

  void setMouseMode(MouseMode mode);

  void setCursorBlinkMode(bool enabled);

  void setCursorVisibleMode(bool enabled);

  void useAltBuffer();

  void useMainBuffer();

  void clearAltBuffer();

  void setAppKeypadMode(bool enabled);

  void setReportFocusMode(bool enabled);

  void setMouseReportMode(MouseReportMode mode);

  void setAltBufferMouseScrollMode(bool enabled);

  void setBracketedPasteMode(bool enabled);

  void setUnknownDecMode(int mode, bool enabled);

  /* Select Graphic Rendition (SGR) */

  void resetCursorStyle();

  void setCursorBold();

  void setCursorFaint();

  void setCursorItalic();

  void setCursorUnderline();

  void setCursorBlink();

  void setCursorInverse();

  void setCursorInvisible();

  void setCursorStrikethrough();

  void unsetCursorBold();

  void unsetCursorFaint();

  void unsetCursorItalic();

  void unsetCursorUnderline();

  void unsetCursorBlink();

  void unsetCursorInverse();

  void unsetCursorInvisible();

  void unsetCursorStrikethrough();

  void setForegroundBlack() {}

  void setForegroundRed() {}

  void setForegroundGreen() {}

  void setForegroundYellow() {}

  void setForegroundBlue() {}

  void setForegroundMagenta() {}

  void setForegroundCyan() {}

  void setForegroundWhite() {}

  void resetForeground() {}

  void setForegroundBrightBlack() {}

  void setForegroundBrightRed() {}

  void setForegroundBrightGreen() {}

  void setForegroundBrightYellow() {}

  void setForegroundBrightBlue() {}

  void setForegroundBrightMagenta() {}

  void setForegroundBrightCyan() {}

  void setForegroundBrightWhite() {}

  void setBackgroundBlack() {}

  void setBackgroundRed() {}

  void setBackgroundGreen() {}

  void setBackgroundYellow() {}

  void setBackgroundBlue() {}

  void setBackgroundMagenta() {}

  void setBackgroundCyan() {}

  void setBackgroundWhite() {}

  void resetBackground() {}

  void setBackgroundBrightBlack() {}

  void setBackgroundBrightRed() {}

  void setBackgroundBrightGreen() {}

  void setBackgroundBrightYellow() {}

  void setBackgroundBrightBlue() {}

  void setBackgroundBrightMagenta() {}

  void setBackgroundBrightCyan() {}

  void setBackgroundBrightWhite() {}

  void unsupportedStyle(int param) {}

  void setForegroundIndexed(int param) {}

  void setForegroundRgb(int r, int g, int b) {}

  void setBackgroundRgb(int r, int g, int b) {}

  void setBackgroundIndexed(int index) {}
}
