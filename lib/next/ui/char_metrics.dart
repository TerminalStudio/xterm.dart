import 'dart:ui';

import 'package:xterm/next/ui/text_style.dart';

class CharMetrics {
  CharMetrics(this.width, this.height);

  final double width;

  final double height;

  @override
  String toString() {
    return 'CharMetrics(width: $width, height: $height)';
  }
}

CharMetrics calcCharMetrics(TerminalStyle style) {
  const test = 'mmmmmmmmmm';

  final textStyle = style.toTextStyle();
  final builder = ParagraphBuilder(textStyle.getParagraphStyle());
  builder.pushStyle(textStyle.getTextStyle());
  builder.addText(test);

  final paragraph = builder.build();
  paragraph.layout(ParagraphConstraints(width: double.infinity));

  return CharMetrics(
    paragraph.maxIntrinsicWidth / test.length,
    paragraph.height,
  );
}
