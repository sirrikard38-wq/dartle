import 'dart:io';

import 'package:dartle/dartle.dart';

/// Every text the app asks the translator for, found in the source: the first
/// argument of `tr(...)` and the two English forms of `trn(...)` (as the key
/// `'one|other'`), plus the texts that are looked up from a list (mode names, the
/// leaderboard buttons, the ring names).
///
/// Used by the translation tests to check that the Croatian catalog has every
/// one of them - and nothing that is no longer used.
Set<String> usedTexts() {
  final keys = <String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll('\\', '/');
    if (path.endsWith('i18n/i18n.dart') || path.endsWith('i18n/croatian.dart')) continue;
    final source = entity.readAsStringSync();
    for (final match in _call.allMatches(source)) {
      final name = match.group(1)!;
      final first = _literals(match.group(2)!);
      if (name == 'tr') {
        keys.add(first);
      } else {
        final second = _literals(match.group(3)!);
        keys.add('$first|$second');
      }
    }
  }
  for (final mode in GameMode.values) {
    keys..add(mode.label)..add(mode.blurb);
  }
  for (final sort in LeaderboardSort.values) {
    keys.add(sort.label);
  }
  for (final multiplier in Multiplier.values) {
    keys.add(multiplier.label);
  }
  return keys;
}

/// One string literal: single or double quoted, with escapes.
const String _lit = r'''(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")''';

/// One or more literals next to each other (Dart joins them).
const String _lits = '$_lit(?:\\s*$_lit)*';

/// `tr(<literals>` or `trn(<count>, <literals>, <literals>`.
final RegExp _call = RegExp(
  '(?<![A-Za-z0-9_.])(tr|trn)\\(\\s*'
  '(?:[^,()\'"]+,\\s*(?=$_lits\\s*,))?' // trn's count
  '($_lits)'
  '(?:\\s*,\\s*($_lits))?',
);

/// The text of adjacent literals, joined, with the escapes undone.
String _literals(String source) {
  final out = StringBuffer();
  for (final m in RegExp(_lit).allMatches(source)) {
    final body = m.group(0)!;
    out.write(_unescape(body.substring(1, body.length - 1)));
  }
  return out.toString();
}

String _unescape(String text) => text.replaceAllMapped(
      RegExp(r'\\(.)'),
      (m) => switch (m.group(1)) {
        'n' => '\n',
        't' => '\t',
        final other => other!,
      },
    );
