import 'better_doubles.dart';
import 'dart_throw.dart';

/// Which setup darts are sensible things to aim at: a single (the outer bull is
/// not one - it is far too hard to hit), a treble from T15 to T20, and one of the
/// [BetterDoubles] (T20 D20 D16 on 132). A low treble like T3, any other double
/// and the Bull as a setup dart are not.
abstract final class NaturalAim {
  /// The lowest treble anyone sensibly aims at as a setup dart.
  static const int lowestTreble = 15;

  static bool isNatural(DartThrow dart) {
    if (dart.isBull || dart.isOuterBull) return false;
    return switch (dart.multiplier) {
      Multiplier.single => true,
      Multiplier.treble => dart.number >= lowestTreble,
      Multiplier.double => BetterDoubles.isBetter(dart),
    };
  }
}
