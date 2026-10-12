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
