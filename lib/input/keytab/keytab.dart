import 'package:xterm/input/keytab/keytab_default.dart';
import 'package:xterm/input/keytab/keytab_parse.dart';
import 'package:xterm/input/keytab/keytab_record.dart';
import 'package:xterm/input/keytab/keytab_token.dart';

class Keytab {
  Keytab({
    required this.name,
    required this.records,
  });

  factory Keytab.parse(String source) {
    final tokens = tokenize(source).toList();
    final parser = KeytabParser()..addTokens(tokens);
    return parser.result;
  }

  factory Keytab.defaultKeytab() {
    return Keytab.parse(kDefaultKeytab);
  }

  final String? name;
  final List<KeytabRecord> records;

  @override
  String toString() {
    final buffer = StringBuffer();

    buffer.writeln('keyboard "$name"');

    for (var record in records) {
      buffer.writeln(record);
    }

    return buffer.toString();
  }
}
