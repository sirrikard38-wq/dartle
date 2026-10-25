import '../storage/storage_service.dart';
import 'croatian.dart';

/// The languages of the app. More are added here (and get a catalog below); the
/// little language box at the top cycles through them in this order.
enum Language {
  en('EN', 'English'),
  hr('HR', 'Hrvatski');

  const Language(this.code, this.name);

  /// The two letters shown in the language box.
  final String code;

  /// The language's own name.
  final String name;

  /// The language after this one (the first again after the last).
  Language get next => values[(index + 1) % values.length];

  static Language? fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }
}

/// Every text of the app is written in English in the code, and looked up here
/// when another language is on: `tr('Start')` is "Start" in English and
/// "Kreni" in Croatian. A text with no translation yet is shown in English, so
/// nothing is ever blank. Pieces that change go in braces:
/// `tr('Hi, {name}', {'name': name})`.
abstract final class I18n {
  /// Where the chosen language is saved.
  static const String storageKey = 'dartle.language.v1';

  /// The language the app is in right now.
  static Language current = Language.en;

  /// The translations of every language but English, by the English text.
  static const Map<Language, Map<String, String>> catalogs = {
    Language.hr: croatian,
  };

  /// Reads the saved language (English when there is none).
  static Future<void> load(StorageService storage) async {
    current = Language.fromCode(await storage.read(storageKey)) ?? Language.en;
  }

  /// Changes the language and saves it.
  static Future<void> choose(StorageService storage, Language language) async {
    current = language;
    await storage.write(storageKey, language.code);
  }

  /// [english] in the language that is on, with the `{name}` pieces filled in
  /// from [args].
  static String tr(String english, [Map<String, Object?> args = const {}]) =>
      _fill(catalogs[current]?[english] ?? english, args);

  /// A text that depends on a count: [one] when [count] is 1, [other] otherwise
  /// in English. Croatian has a third form (2 to 4), so its catalog entry for
  /// `'$one|$other'` is three forms joined with `|`: 1 (and 21, 31 ...), 2 to 4,
  /// and the rest. `{n}` is the count.
  static String plural(int count, String one, String other, [Map<String, Object?> args = const {}]) {
    final all = {'n': count, ...args};
    final translated = catalogs[current]?['$one|$other']?.split('|');
    if (translated != null && translated.length == 3) {
      return _fill(translated[_croatianForm(count)], all);
    }
    return _fill(count == 1 ? one : other, all);
  }

  /// 0 for 1, 21, 31 ... (not 11), 1 for 2 to 4, 22 to 24 ... (not 12 to 14),
  /// 2 for everything else.
  static int _croatianForm(int n) {
    final tens = n % 100;
    final ones = n % 10;
    if (ones == 1 && tens != 11) return 0;
    if (ones >= 2 && ones <= 4 && (tens < 12 || tens > 14)) return 1;
    return 2;
  }

  static String _fill(String text, Map<String, Object?> args) {
    if (args.isEmpty) return text;
    return text.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (match) => '${args[match[1]] ?? match[0]}',
    );
  }
}

/// [I18n.tr] - the text in the language that is on.
String tr(String english, [Map<String, Object?> args = const {}]) =>
    I18n.tr(english, args);

/// [I18n.plural].
String trn(int count, String one, String other, [Map<String, Object?> args = const {}]) =>
    I18n.plural(count, one, other, args);
