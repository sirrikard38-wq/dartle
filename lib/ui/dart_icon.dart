import 'package:web/web.dart' as web;

import 'dom.dart';

/// A small stylised dart pointing right. Drawn in the current text colour; its
/// size comes from the CSS of wherever it is used (`.dart-icon`).
web.Element dartIcon() => svg('svg', cls: 'dart-icon', attrs: {
      'viewBox': '0 0 72 28',
      'aria-hidden': 'true',
      'focusable': 'false',
    }, children: [
      // Flight (the two fins), shaft, barrel and tip.
      svg('path', attrs: {'d': 'M2 3 L11 3 L19 14 L11 25 L2 25 L8 14 Z', 'fill': 'currentColor'}),
      svg('rect', attrs: {'x': '18', 'y': '12', 'width': '16', 'height': '4', 'fill': 'currentColor'}),
      svg('rect', attrs: {'x': '32', 'y': '8', 'width': '24', 'height': '12', 'rx': '3', 'fill': 'currentColor'}),
      svg('path', attrs: {'d': 'M56 11 L70 14 L56 17 Z', 'fill': 'currentColor'}),
    ]);
