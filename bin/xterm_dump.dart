// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';

// import 'package:xterm/core/escape/handler.dart';
// import 'package:xterm/core/escape/parser.dart';

// final handler = DebugTerminalHandler();
// final protocol = EscapeParser(handler);
// final input = BytesBuilder(copy: true);

// void main(List<String> args) async {
//   final inputStream = args.isNotEmpty ? File(args.first).openRead() : stdin;

//   await for (var chunk in inputStream.transform(Utf8Decoder())) {
//     input.add(chunk);
//     protocol.write(chunk);
//   }

//   handler.flush();
// }

// extension StringEscape on String {
//   String escapeInvisible() {
//     return this.replaceAllMapped(RegExp('[\x00-\x1F]'), (match) {
//       return '\\x${match.group(0)!.codeUnitAt(0).toRadixString(16).padLeft(2, '0')}';
//     });
//   }
// }

// class DebugTerminalHandler implements EscapeHandler {
//   final stringBuffer = StringBuffer();

//   void flush() {
//     if (stringBuffer.isEmpty) return;
//     print(Color.green('TXT') + "'$stringBuffer'");
//     stringBuffer.clear();
//   }

//   void recordCommand(String description) {
//     flush();
//     final raw = input.toBytes().sublist(protocol.tokenBegin, protocol.tokenEnd);
//     final token = utf8.decode(raw).replaceAll('\x1b', 'ESC').escapeInvisible();
//     print(Color.magenta('CMD ') + token.padRight(40) + '$description');
//   }

//   @override
//   void writeChar(int char) {
//     stringBuffer.writeCharCode(char);
//   }

//   @override
//   void setCursor(int x, int y) {
//     recordCommand('setCursor $x, $y');
//   }

//   @override
//   void designateCharset(int charset) {
//     recordCommand('designateCharset $charset');
//   }

//   @override
//   void unkownEscape(int char) {
//     recordCommand('unkownEscape ${String.fromCharCode(char)}');
//   }

//   @override
//   void backspaceReturn() {
//     recordCommand('backspaceReturn');
//   }

//   @override
//   void carriageReturn() {
//     recordCommand('carriageReturn');
//   }

//   @override
//   void setCursorX(int x) {
//     recordCommand('setCursorX $x');
//   }

//   @override
//   void setCursorY(int y) {
//     recordCommand('setCursorY $y');
//   }

//   @override
//   void unkownCSI(int finalByte) {
//     recordCommand('unkownCSI ${String.fromCharCode(finalByte)}');
//   }

//   @override
//   void unkownSBC(int char) {
//     recordCommand('unkownSBC ${String.fromCharCode(char)}');
//   }

//   @override
//   noSuchMethod(Invocation invocation) {
//     final name = invocation.memberName;
//     final args = invocation.positionalArguments;
//     recordCommand('noSuchMethod: $name $args');
//   }
// }

// abstract class Color {
//   static String red(String s) => '\u001b[31m$s\u001b[0m';
//   static String green(String s) => '\u001b[32m$s\u001b[0m';
//   static String yellow(String s) => '\u001b[33m$s\u001b[0m';
//   static String blue(String s) => '\u001b[34m$s\u001b[0m';
//   static String magenta(String s) => '\u001b[35m$s\u001b[0m';
//   static String cyan(String s) => '\u001b[36m$s\u001b[0m';
// }

// abstract class Labels {
//   static final txt = Color.green('TXT');
// }
