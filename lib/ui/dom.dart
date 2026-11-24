import 'dart:async';

import 'package:web/web.dart' as web;

/// Tiny DOM builder so view code reads declaratively.
web.HTMLElement el(
  String tag, {
  String? cls,
  String? text,
  Map<String, String> attrs = const {},
  List<web.Node> children = const [],
}) {
  final node = web.document.createElement(tag) as web.HTMLElement;
  if (cls != null) node.className = cls;
  if (text != null) node.textContent = text;
  for (final entry in attrs.entries) {
    node.setAttribute(entry.key, entry.value);
  }
  for (final child in children) {
    node.appendChild(child);
  }
  return node;
}

const String svgNamespace = 'http://www.w3.org/2000/svg';

/// SVG element builder (SVG needs createElementNS).
web.Element svg(
  String tag, {
  String? cls,
  String? text,
  Map<String, String> attrs = const {},
  List<web.Node> children = const [],
}) {
  final node = web.document.createElementNS(svgNamespace, tag);
  if (cls != null) node.setAttribute('class', cls);
  if (text != null) node.textContent = text;
  for (final entry in attrs.entries) {
    node.setAttribute(entry.key, entry.value);
  }
  for (final child in children) {
    node.appendChild(child);
  }
  return node;
}

web.Text textNode(String text) => web.document.createTextNode(text);

/// A real <button> with an accessible label and optional focus key.
web.HTMLButtonElement button(
  String label, {
  required void Function(bool viaKeyboard) onPressed,
  String? cls,
  String? ariaLabel,
  String? focusKey,
  bool disabled = false,
  Map<String, String> attrs = const {},
}) {
  final b = el('button', cls: cls, text: label, attrs: {
    'type': 'button',
    if (ariaLabel != null) 'aria-label': ariaLabel,
    if (focusKey != null) 'data-focus': focusKey,
    ...attrs,
  }) as web.HTMLButtonElement;
  b.disabled = disabled;
  b.onClick.listen((event) {
    // detail == 0 means keyboard activation (Enter/Space), >0 a pointer click.
    onPressed(event.detail == 0);
  });
  return b;
}

web.CanvasRenderingContext2D? _pen;

double _px(String css) => double.tryParse(css.replaceAll('px', '')) ?? 0;

/// [input] as wide as the letters typed in it - measured, not counted (a W is
/// far wider than an i) - [minCh] characters at the least, with [extraPx] room
/// for the cursor. With [room] (the width it may take), letters that would not
/// fit get smaller (to 11px at the least), so the whole of it is always seen.
void fitToText(web.HTMLInputElement input, {required int minCh, double extraPx = 14, double Function()? room}) {
  input.style.fontSize = '';
  if (!input.isConnected) {
    input.style.width = '${minCh}ch';
    return;
  }
  final s = web.window.getComputedStyle(input);
  final pen = _pen ??=
      (web.document.createElement('canvas') as web.HTMLCanvasElement).getContext('2d')! as web.CanvasRenderingContext2D;
  pen.font = '${s.fontStyle} ${s.fontWeight} ${s.fontSize} ${s.fontFamily}';
  final text = input.value;
  final fontPx = _px(s.fontSize);
  var width = pen.measureText(text).width + _px(s.letterSpacing) * text.length + _px(s.paddingLeft) + _px(s.paddingRight) + extraPx;
  final most = room?.call();
  if (most != null && most > 0 && width > most) {
    final smaller = fontPx * most / width;
    input.style.fontSize = '${smaller < 11 ? 11 : smaller}px';
    width = most;
  }
  input.style.width = 'max(${minCh}ch, ${width}px)';
}

/// A menu button pressed: it goes down a few mm with a very light fill and
/// back up, quickly (140 ms), and only then does [go] run - the press is seen
/// in full before the next screen, and none of it is left for the menu when
/// it comes back. A second press meanwhile does nothing.
void pressThen(web.HTMLElement pressed, void Function() go) {
  if (pressed.classList.contains('pressed')) return;
  if (web.window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    go();
    return;
  }
  pressed.classList.add('pressed');
  Timer(const Duration(milliseconds: 140), () {
    pressed.classList.remove('pressed');
    go();
  });
}

/// A running score with a real minus when negative: "12", "−10", "0".
String formatScore(int points) => points < 0 ? '−${-points}' : '$points';

/// Points with an explicit sign and a real minus: "+7", "−6", "0".
String formatPoints(int points) {
  if (points > 0) return '+$points';
  if (points < 0) return '−${-points}';
  return '0';
}

/// Countdown clock text: "12.34s", then "-8.33s" once time has run out.
String formatCountdown(Duration remaining) {
  final seconds = remaining.inMilliseconds / 1000;
  return '${seconds.toStringAsFixed(2)}s';
}

String formatSeconds(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(2)}s';

String formatMsAsSeconds(int? ms) =>
    ms == null ? '—' : '${(ms / 1000).toStringAsFixed(2)}s';

String formatPercent(double value) => '${value.toStringAsFixed(1)}%';
