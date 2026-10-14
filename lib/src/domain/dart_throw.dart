/// The ring a dart lands in.
enum Multiplier {
  single(1, 'S', 'Single'),
  double(2, 'D', 'Double'),
  treble(3, 'T', 'Triple');

  const Multiplier(this.factor, this.prefix, this.label);

  final int factor;
  final String prefix;
  final String label;
}

/// A single dart landing in a legal segment of a standard dartboard.
///
/// Legal segments: S1-S20, D1-D20, T1-T20, outer bull (25) and bull (50).
/// Bull is modelled as a double on number 25, which is exactly how the
/// rules treat it - that is why it is a legal finishing double.
final class DartThrow {
  const DartThrow._(this.multiplier, this.number);

  /// Throws if the combination does not exist on a dartboard.
  factory DartThrow(Multiplier multiplier, int number) {
    final isBullNumber = number == bullNumber;
    final isBoardNumber = number >= 1 && number <= maxBoardNumber;
    if (!isBoardNumber && !isBullNumber) {
      throw ArgumentError.value(number, 'number', 'Not a dartboard number');
    }
    if (isBullNumber && multiplier == Multiplier.treble) {
      throw ArgumentError('There is no treble 25');
    }
    return DartThrow._(multiplier, number);
  }

  static const int maxBoardNumber = 20;
  static const int bullNumber = 25;

  static const DartThrow outerBull = DartThrow._(Multiplier.single, bullNumber);
  static const DartThrow bull = DartThrow._(Multiplier.double, bullNumber);

  final Multiplier multiplier;
  final int number;

  int get score => multiplier.factor * number;

  bool get isBull => this == bull;
  bool get isOuterBull => this == outerBull;
  bool get isTreble => multiplier == Multiplier.treble;

  /// Only doubles (including bull) may end a leg.
  bool get isFinishingDart => multiplier == Multiplier.double;

  /// "S20", "D16", "T20", "25" (outer bull) and "Bull".
  String get notation {
    if (isBull) return 'Bull';
    if (isOuterBull) return '25';
    return '${multiplier.prefix}$number';
  }

  /// Screen-reader friendly name, e.g. "Treble 20".
  String get spokenName {
    if (isBull) return 'Bull, 50';
    if (isOuterBull) return 'Outer bull, 25';
    return '${multiplier.label} $number';
  }

  /// Every legal segment, ordered singles, doubles, trebles, then bulls.
  static final List<DartThrow> allSegments = List.unmodifiable([
    for (final m in Multiplier.values)
      for (var n = 1; n <= maxBoardNumber; n++) DartThrow._(m, n),
    outerBull,
    bull,
  ]);

  static final Map<String, DartThrow> _byNotation = {
    for (final t in allSegments) t.notation.toUpperCase(): t,
    'S25': outerBull,
    'D25': bull,
    'DB': bull,
    'SB': outerBull,
  };

  /// Parses "T20", "d6", "Bull", "25"; returns null if not a legal segment.
  static DartThrow? tryParse(String text) => _byNotation[text.trim().toUpperCase()];

  /// Like [tryParse] but throws [FormatException] for illegal input.
  static DartThrow parse(String text) =>
      tryParse(text) ?? (throw FormatException('Not a dart segment', text));

  @override
  bool operator ==(Object other) =>
      other is DartThrow && other.multiplier == multiplier && other.number == number;

  @override
  int get hashCode => Object.hash(multiplier, number);

  @override
  String toString() => notation;
}
