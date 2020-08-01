import 'package:flutter/widgets.dart';

Size textSize(Text text) {
  var span = text.textSpan ?? TextSpan(text: text.data, style: text.style);

  var tp = TextPainter(
    text: span,
    textAlign: text.textAlign ?? TextAlign.start,
    textDirection: text.textDirection ?? TextDirection.ltr,
    textScaleFactor: text.textScaleFactor ?? 1,
    maxLines: text.maxLines,
    locale: text.locale,
    strutStyle: text.strutStyle,
  );

  tp.layout();

  return Size(tp.width, tp.height);
}

bool isMonospace(List<String> fontFamily) {
  return true; // TBD
}
