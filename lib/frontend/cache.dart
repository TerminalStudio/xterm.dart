import 'package:flutter/painting.dart';
import 'package:quiver/collection.dart';

class TextLayoutCache {
  TextLayoutCache(this.textDirection, int maximumSize)
      : _cache = LruMap<int, TextPainter>(maximumSize: maximumSize);

  final LruMap<int, TextPainter> _cache;
  final TextDirection textDirection;

  TextPainter? getLayoutFromCache(int key) {
    return _cache[key];
  }

  TextPainter performAndCacheLayout(TextSpan text, int key) {
    final textPainter = TextPainter(text: text, textDirection: textDirection);
    textPainter.layout();

    _cache[key] = textPainter;

    return textPainter;
  }

  int get length {
    return _cache.length;
  }
}

final textLayoutCache = TextLayoutCache(TextDirection.ltr, 10240);
