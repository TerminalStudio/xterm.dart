import 'package:xterm/buffer/cell_flags.dart';
import 'package:xterm/theme/terminal_color.dart';
import 'package:xterm/terminal/csi.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/util/lookup_table.dart';

/// SGR selects one or more character attributes at the same time.
/// Multiple params (up to 32) are applied from in order from left to right.
/// The changed attributes are applied to all new characters received.
/// If you move characters in the viewport by scrolling or any other means,
/// then the attributes move with the characters.
void sgrHandler(CSI csi, Terminal terminal) {
  final params = csi.params.toList();

  if (params.isEmpty) {
    params.add(0);
  }

  for (var i = 0; i < params.length; i++) {
    final param = params[i];
    switch (param) {
      case 0:
        terminal.cursor.fg = terminal.theme.foreground;
        terminal.cursor.bg = TerminalColor.transparent;
        terminal.cursor.flags = 0x00;
        break;
      case 1:
        terminal.cursor.flags |= CellFlags.bold;
        break;
      case 2:
        terminal.cursor.flags |= CellFlags.faint;
        break;
      case 3:
        terminal.cursor.flags |= CellFlags.italic;
        break;
      case 4:
        terminal.cursor.flags |= CellFlags.underline;
        break;
      case 5:
        terminal.cursor.flags |= CellFlags.blink;
        break;
      case 7:
        terminal.cursor.flags |= CellFlags.inverse;
        break;
      case 8:
        terminal.cursor.flags |= CellFlags.invisible;
        break;
      case 21:
        terminal.cursor.flags &= ~CellFlags.bold;
        break;
      case 22:
        terminal.cursor.flags &= ~CellFlags.faint;
        break;
      case 23:
        terminal.cursor.flags &= ~CellFlags.italic;
        break;
      case 24:
        terminal.cursor.flags &= ~CellFlags.underline;
        break;
      case 25:
        terminal.cursor.flags &= ~CellFlags.blink;
        break;
      case 27:
        terminal.cursor.flags &= ~CellFlags.inverse;
        break;
      case 28:
        terminal.cursor.flags &= ~CellFlags.invisible;
        break;
      case 29:
        // not strikethrough
        break;
      case 39:
        terminal.cursor.fg = terminal.theme.foreground;
        break;
      case 30:
        terminal.cursor.fg = terminal.theme.black;
        break;
      case 31:
        terminal.cursor.fg = terminal.theme.red;
        break;
      case 32:
        terminal.cursor.fg = terminal.theme.green;
        break;
      case 33:
        terminal.cursor.fg = terminal.theme.yellow;
        break;
      case 34:
        terminal.cursor.fg = terminal.theme.blue;
        break;
      case 35:
        terminal.cursor.fg = terminal.theme.magenta;
        break;
      case 36:
        terminal.cursor.fg = terminal.theme.cyan;
        break;
      case 37:
        terminal.cursor.fg = terminal.theme.white;
        break;
      case 90:
        terminal.cursor.fg = terminal.theme.brightBlack;
        break;
      case 91:
        terminal.cursor.fg = terminal.theme.brightRed;
        break;
      case 92:
        terminal.cursor.fg = terminal.theme.brightGreen;
        break;
      case 93:
        terminal.cursor.fg = terminal.theme.brightYellow;
        break;
      case 94:
        terminal.cursor.fg = terminal.theme.brightBlue;
        break;
      case 95:
        terminal.cursor.fg = terminal.theme.brightMagenta;
        break;
      case 96:
        terminal.cursor.fg = terminal.theme.brightCyan;
        break;
      case 97:
        terminal.cursor.fg = terminal.theme.brightWhite;
        break;
      case 49:
        terminal.cursor.bg = terminal.theme.background;
        break;
      case 40:
        terminal.cursor.bg = terminal.theme.black;
        break;
      case 41:
        terminal.cursor.bg = terminal.theme.red;
        break;
      case 42:
        terminal.cursor.bg = terminal.theme.green;
        break;
      case 43:
        terminal.cursor.bg = terminal.theme.yellow;
        break;
      case 44:
        terminal.cursor.bg = terminal.theme.blue;
        break;
      case 45:
        terminal.cursor.bg = terminal.theme.magenta;
        break;
      case 46:
        terminal.cursor.bg = terminal.theme.cyan;
        break;
      case 47:
        terminal.cursor.bg = terminal.theme.white;
        break;
      case 100:
        terminal.cursor.bg = terminal.theme.brightBlack;
        break;
      case 101:
        terminal.cursor.bg = terminal.theme.brightRed;
        break;
      case 102:
        terminal.cursor.bg = terminal.theme.brightGreen;
        break;
      case 103:
        terminal.cursor.bg = terminal.theme.brightYellow;
        break;
      case 104:
        terminal.cursor.bg = terminal.theme.brightBlue;
        break;
      case 105:
        terminal.cursor.bg = terminal.theme.brightMagenta;
        break;
      case 106:
        terminal.cursor.bg = terminal.theme.brightCyan;
        break;
      case 107:
        terminal.cursor.bg = terminal.theme.brightWhite;
        break;
      case 38: // set foreground
        final colorResult = parseAnsiColour(params, i, terminal);
        terminal.cursor.fg = colorResult[0];
        i += colorResult[1];
        break;
      case 48: // set background
        final colorResult = parseAnsiColour(params, i, terminal);
        terminal.cursor.bg = colorResult[0];
        i += colorResult[1];
        break;
      default:
        terminal.debug.onError('unknown SGR: $param');
    }
  }
}

/// parse a color from [params] starting from [offset].
/// Returns a list with 2 entries. Index 0 = color, Index 1 = number of params used
List<int> parseAnsiColour(List<int> params, int offset, Terminal terminal) {
  final length = params.length - offset;

  if (length > 2) {
    switch (params[offset + 1]) {
      case 5:
        // 8 bit colour
        final colNum = params[offset + 2];

        if (colNum >= 256 || colNum < 0) {
          return [TerminalColor.empty(), 2];
        }

        return [parse8BitSgrColour(colNum, terminal), 2];

      case 2:
        if (length < 4) {
          return [TerminalColor.empty(), 0];
        }

        // 24 bit colour
        if (length == 5) {
          final r = params[offset + 2];
          final g = params[offset + 3];
          final b = params[offset + 4];
          return [TerminalColor.fromARGB(0xff, r, g, b), 4];
        }

        if (length > 5) {
          // ISO/IEC International Standard 8613-6
          final r = params[offset + 3];
          final g = params[offset + 4];
          final b = params[offset + 5];
          return [TerminalColor.fromARGB(0xff, r, g, b), 5];
        }
    }
  }

  return [TerminalColor.empty(), 0];
}

final grayscaleColors = FastLookupTable({
  232: 0xff080808,
  233: 0xff121212,
  234: 0xff1c1c1c,
  235: 0xff262626,
  236: 0xff303030,
  237: 0xff3a3a3a,
  238: 0xff444444,
  239: 0xff4e4e4e,
  240: 0xff585858,
  241: 0xff626262,
  242: 0xff6c6c6c,
  243: 0xff767676,
  244: 0xff808080,
  245: 0xff8a8a8a,
  246: 0xff949494,
  247: 0xff9e9e9e,
  248: 0xffa8a8a8,
  249: 0xffb2b2b2,
  250: 0xffbcbcbc,
  251: 0xffc6c6c6,
  252: 0xffd0d0d0,
  253: 0xffdadada,
  254: 0xffe4e4e4,
  255: 0xffeeeeee,
});

int parse8BitSgrColour(int colNum, Terminal terminal) {
  // https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit

  switch (colNum) {
    case 0:
      return terminal.theme.black;
    case 1:
      return terminal.theme.red;
    case 2:
      return terminal.theme.green;
    case 3:
      return terminal.theme.yellow;
    case 4:
      return terminal.theme.blue;
    case 5:
      return terminal.theme.magenta;
    case 6:
      return terminal.theme.cyan;
    case 7:
      return terminal.theme.white;
    case 8:
      return terminal.theme.brightBlack;
    case 9:
      return terminal.theme.brightRed;
    case 10:
      return terminal.theme.brightGreen;
    case 11:
      return terminal.theme.brightYellow;
    case 12:
      return terminal.theme.brightBlue;
    case 13:
      return terminal.theme.brightMagenta;
    case 14:
      return terminal.theme.brightCyan;
    case 15:
      return terminal.theme.white;
  }

  if (colNum < 232) {
    var r = 0;
    var g = 0;
    var b = 0;

    final index = colNum - 16;

    for (var i = 0; i < index; i++) {
      if (b == 0) {
        b = 95;
      } else if (b < 255) {
        b += 40;
      } else {
        b = 0;
        if (g == 0) {
          g = 95;
        } else if (g < 255) {
          g += 40;
        } else {
          g = 0;
          if (r == 0) {
            r = 95;
          } else if (r < 255) {
            r += 40;
          } else {
            break;
          }
        }
      }
    }

    return TerminalColor.fromARGB(0xff, r, g, b);
  }

  return grayscaleColors[colNum.clamp(232, 255)]!;
}
