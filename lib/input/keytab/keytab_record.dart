import 'package:xterm/input/keys.dart';

enum KeytabActionType {
  input,
  shortcut,
}

class KeytabAction {
  KeytabAction(this.type, this.value);

  final KeytabActionType type;
  final String value;

  @override
  String toString() {
    switch (type) {
      case KeytabActionType.input:
        return '"$value"';
      case KeytabActionType.shortcut:
        return value;
      default:
        return '(no value)';
    }
  }
}

class KeytabRecord {
  KeytabRecord({
    required this.qtKeyName,
    required this.key,
    required this.action,
    required this.alt,
    required this.ctrl,
    required this.shift,
    required this.anyModifier,
    required this.ansi,
    required this.appScreen,
    required this.keyPad,
    required this.appCursorKeys,
    required this.appKeyPad,
    required this.newLine,
    required this.mac,
  });

  String qtKeyName;
  TerminalKey key;
  KeytabAction action;

  bool? alt;
  bool? ctrl;
  bool? shift;
  bool? anyModifier;
  bool? ansi;
  bool? appScreen;
  bool? keyPad;
  bool? appCursorKeys;
  bool? appKeyPad;
  bool? newLine;
  bool? mac;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('$qtKeyName ');

    if (alt != null) {
      buffer.write(modeStatus(alt!, 'Alt'));
    }

    if (ctrl != null) {
      buffer.write(modeStatus(ctrl!, 'Control'));
    }

    if (shift != null) {
      buffer.write(modeStatus(shift!, 'Shift'));
    }

    if (anyModifier != null) {
      buffer.write(modeStatus(anyModifier!, 'AnyMod'));
    }

    if (ansi != null) {
      buffer.write(modeStatus(ansi!, 'Ansi'));
    }

    if (appScreen != null) {
      buffer.write(modeStatus(appScreen!, 'AppScreen'));
    }

    if (keyPad != null) {
      buffer.write(modeStatus(keyPad!, 'KeyPad'));
    }

    if (appCursorKeys != null) {
      buffer.write(modeStatus(appCursorKeys!, 'AppCuKeys'));
    }

    if (appKeyPad != null) {
      buffer.write(modeStatus(appKeyPad!, 'AppKeyPad'));
    }

    if (newLine != null) {
      buffer.write(modeStatus(newLine!, 'NewLine'));
    }

    if (mac != null) {
      buffer.write(modeStatus(mac!, 'Mac'));
    }

    buffer.write(' : $action');

    return buffer.toString();
  }
}

String modeStatus(bool status, String mode) {
  if (status == true) {
    return '+$mode';
  }

  if (status == false) {
    return '-$mode';
  }

  return '';
}
