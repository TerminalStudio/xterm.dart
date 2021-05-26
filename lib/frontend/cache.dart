import 'package:flutter/painting.dart';
import 'package:quiver/collection.dart';

class TextLayoutCache {
  TextLayoutCache(this.textDirection, int maximumSize)
      : _cache = LruMap<int, TextPainter>(maximumSize: maximumSize);

  final LruMap<int, TextPainter> _cache;
  final TextDirection textDirection;

  void clear() {
    _cache.clear();
  }

  TextPainter? getLayoutFromCache(int key) {
    return _cache[key];
  }

  // TextPainter getOrPerformLayout(TextSpan text, int key) {
  //   final cachedPainter = _cache[key];
  //   if (cachedPainter != null) {
  //     return cachedPainter;
  //   } else {
  //     return performAndCacheLayout(text, key);
  //   }
  // }

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
double textLayoutCacheFontSize = 0;

// class CodePointCache {
//   CodePointCache(int maximumSize)
//       : _cache = LruMap<int, String>(maximumSize: maximumSize);

//   final LruMap<int, String> _cache;

//   String getOrConstruct(int codePoint) {
//     final cachedString = _cache[codePoint];
//     if (cachedString != null) {
//       return cachedString;
//     } else {
//       return _constructAndCacheString(codePoint);
//     }
//   }

//   String _constructAndCacheString(int codePoint) {
//     final string = String.fromCharCode(codePoint);

//     _cache[codePoint] = string;

//     return string;
//   }
// }

// final codePointCache = CodePointCache(1024);
