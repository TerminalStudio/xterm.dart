import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:quiver/collection.dart';

class TextLayoutCache {
  TextLayoutCache(this.textDirection, int maximumSize)
      : _cache = LruMap<int, Paragraph>(maximumSize: maximumSize);

  final LruMap<int, Paragraph> _cache;
  final TextDirection textDirection;

  Paragraph? getLayoutFromCache(int key) {
    return _cache[key];
  }

  Paragraph performAndCacheLayout(String text, TextStyle style, int key) {
    final builder = ParagraphBuilder(style.getParagraphStyle());
    builder.pushStyle(style.getTextStyle());
    builder.addText(text);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));

    _cache[key] = paragraph;
    return paragraph;
  }

  int get length {
    return _cache.length;
  }
}

final textLayoutCache = TextLayoutCache(TextDirection.ltr, 10240);
