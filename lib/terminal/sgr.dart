import 'package:xterm/theme/terminal_color.dart';
import 'package:xterm/terminal/csi.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/theme/terminal_color_ref.dart';

// reference to color
class Cr implements TerminalColor {
  Cr(this.getter);

  final TerminalColor Function() getter;

  int get value => getter().value;
}

/// SGR selects one or more character attributes at the same time.
/// Multiple params (up to 32) are applied from in order from left to right.
/// The changed attributes are applied to all new characters received.
/// If you move characters in the viewport by scrolling or any other means,
/// then the attributes move with the characters.
void sgrHandler(CSI csi, Terminal terminal) {
  final params = csi.params.toList();

  if (params.isEmpty) {
    params.add('0');
  }

  for (var i = 0; i < params.length; i++) {
    final param = params[i];
    switch (param) {
      case '':
      case '0':
      case '00':
        terminal.cellAttr.reset();
        break;
      case '1':
      case '01':
        terminal.cellAttr.bold = true;
        break;
      case '2':
      case '02':
        terminal.cellAttr.faint = true;
        break;
      case '3':
      case '03':
        terminal.cellAttr.italic = true;
        break;
      case '4':
      case '04':
        terminal.cellAttr.underline = true;
        break;
      case '5':
      case '05':
        terminal.cellAttr.blink = true;
        break;
      case '7':
      case '07':
        terminal.cellAttr.inverse = true;
        break;
      case '8':
      case '08':
        terminal.cellAttr.invisible = true;
        break;
      case '21':
        terminal.cellAttr.bold = false;
        break;
      case '22':
        terminal.cellAttr.faint = false;
        break;
      case '23':
        terminal.cellAttr.italic = false;
        break;
      case '24':
        terminal.cellAttr.underline = false;
        break;
      case '25':
        terminal.cellAttr.blink = false;
        break;
      case '27':
        terminal.cellAttr.inverse = false;
        break;
      case '28':
        terminal.cellAttr.invisible = false;
        break;
      case '29':
        // not strikethrough
        break;
      case '39':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.foreground);
        break;
      case '30':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.black);
        break;
      case '31':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.red);
        break;
      case '32':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.green);
        break;
      case '33':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.yellow);
        break;
      case '34':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.blue);
        break;
      case '35':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.magenta);
        break;
      case '36':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.cyan);
        break;
      case '37':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.white);
        break;
      case '90':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.brightBlack);
        break;
      case '91':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.brightRed);
        break;
      case '92':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.brightGreen);
        break;
      case '93':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.brightYellow);
        break;
      case '94':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.brightBlue);
        break;
      case '95':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.brightMagenta);
        break;
      case '96':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.brightCyan);
        break;
      case '97':
        terminal.cellAttr.fgColor = Cr(() => terminal.theme.white);
        break;
      case '49':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.background);
        break;
      case '40':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.black);
        break;
      case '41':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.red);
        break;
      case '42':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.green);
        break;
      case '43':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.yellow);
        break;
      case '44':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.blue);
        break;
      case '45':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.magenta);
        break;
      case '46':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.cyan);
        break;
      case '47':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.white);
        break;
      case '100':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.brightBlack);
        break;
      case '101':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.brightRed);
        break;
      case '102':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.brightGreen);
        break;
      case '103':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.brightYellow);
        break;
      case '104':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.brightBlue);
        break;
      case '105':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.brightMagenta);
        break;
      case '106':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.brightCyan);
        break;
      case '107':
        terminal.cellAttr.bgColor = Cr(() => terminal.theme.white);
        break;
      case '38': // set foreground
        final color = parseAnsiColour(params.sublist(i), terminal);
        terminal.cellAttr.fgColor = color;
        return;
      case '48': // set background
        final color = parseAnsiColour(params.sublist(i), terminal);
        terminal.cellAttr.bgColor = color;
        return;
      default:
        terminal.debug.onError('unknown SGR: $param');
    }
  }
}

TerminalColor parseAnsiColour(List<String> params, Terminal terminal) {
  if (params.length > 2) {
    switch (params[1]) {
      case "5":
        // 8 bit colour
        final colNum = int.tryParse(params[2]);

        if (colNum == null || colNum >= 256 || colNum < 0) {
          return TerminalColor.empty();
        }

        return parse8BitSgrColour(colNum, terminal);

      case "2":
        if (params.length < 4) {
          return TerminalColor.empty();
        }

        // 24 bit colour
        if (params.length == 5) {
          final r = int.tryParse(params[2]);
          final g = int.tryParse(params[3]);
          final b = int.tryParse(params[4]);

          if (r == null || g == null || b == null) {
            return TerminalColor.empty();
          }

          return TerminalColor.fromARGB(0xff, r, g, b);
        }

        if (params.length > 5) {
          // ISO/IEC International Standard 8613-6
          final r = int.tryParse(params[3]);
          final g = int.tryParse(params[4]);
          final b = int.tryParse(params[5]);

          if (r == null || g == null || b == null) {
            return TerminalColor.empty();
          }

          return TerminalColor.fromARGB(0xff, r, g, b);
        }
    }
  }

  return TerminalColor.empty();
}

const grayscaleColors = {
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
};

TerminalColor parse8BitSgrColour(int colNum, Terminal terminal) {
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

  return TerminalColor(grayscaleColors[colNum.clamp(232, 255)]);
}
