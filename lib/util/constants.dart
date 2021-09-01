const kReleaseMode = bool.fromEnvironment(
  'dart.vm.product',
  defaultValue: false,
);

const kProfileMode = bool.fromEnvironment(
  'dart.vm.profile',
  defaultValue: false,
);

const kDebugMode = !kReleaseMode && !kProfileMode;

const kIsWeb = identical(0, 0.0);

final kWordSeparators = [
  String.fromCharCode(0),
  ' ',
  '.',
  ':',
  '-',
  '\'',
  '"',
  '*',
  '+',
  '/',
  '\\'
];
