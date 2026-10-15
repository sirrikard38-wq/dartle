import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// How long after the last scroll movement the scrollbar fades away.
const Duration scrollbarHideAfter = Duration(milliseconds: 1500);

/// Scrollbars (the page's and a popup's) are only drawn while something is being
/// scrolled: the element that scrolls gets the class `scrolling`, which the CSS
/// turns into a grey bar, and loses it [scrollbarHideAfter] after the last
/// movement, when the bar fades out smoothly.
void autoHideScrollbars({Duration hideAfter = scrollbarHideAfter}) {
  final timers = <web.Element, Timer>{};
  // Scroll events do not bubble, so listen while they travel down (capture).
  web.document.addEventListener(
    'scroll',
    ((web.Event event) {
      final target = event.target;
      // The page itself scrolls as the document; its bar belongs to <html>.
      final element = target == web.document
          ? web.document.documentElement
          : target as web.Element?;
      if (element == null) return;
      element.classList.add('scrolling');
      timers[element]?.cancel();
      timers[element] = Timer(hideAfter, () {
        element.classList.remove('scrolling');
        timers.remove(element);
      });
    }).toJS,
    true.toJS,
  );
}
