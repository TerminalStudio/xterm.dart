import 'package:convert/convert.dart';
import 'package:xterm/terminal/csi.dart';
import 'package:xterm/util/ansi_color.dart';

class DebugHandler {
  final _buffer = StringBuffer();

  var _enabled = false;

  void enable([bool enabled = true]) {
    _enabled = enabled;
  }

  void _checkBuffer() {
    if (!_enabled) return;

    if (_buffer.isNotEmpty) {
      print(AnsiColor.cyan('┤') + _buffer.toString() + AnsiColor.cyan('├'));
      _buffer.clear();
    }
  }

  void onCsi(CSI csi) {
    if (!_enabled) return;
    _checkBuffer();
    print(AnsiColor.green('<CSI $csi>'));
  }

  void onEsc(int charAfterEsc) {
    if (!_enabled) return;
    _checkBuffer();
    print(AnsiColor.green('<ESC ${String.fromCharCode(charAfterEsc)}>'));
  }

  void onOsc(List<String> params) {
    if (!_enabled) return;
    _checkBuffer();
    print(AnsiColor.yellow('<OSC $params>'));
  }

  void onSbc(int codePoint) {
    if (!_enabled) return;
    _checkBuffer();
    print(AnsiColor.magenta('<SBC ${hex.encode([codePoint])}>'));
  }

  void onChar(int codePoint) {
    if (!_enabled) return;
    _buffer.writeCharCode(codePoint);
  }

  void onMetrics(String metrics) {
    if (!_enabled) return;
    print(AnsiColor.blue('<MRC $metrics>'));
  }

  void onError(String error) {
    if (!_enabled) return;
    print(AnsiColor.red('<ERR $error>'));
  }

  void onMsg(Object msg) {
    if (!_enabled) return;
    print(AnsiColor.green('<MSG $msg>'));
  }
}
