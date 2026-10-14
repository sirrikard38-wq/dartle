import 'dart_throw.dart';

/// Which setup darts are sensible things to aim at. A single (any, outer bull
/// included) is the easiest; trebles T15-T20 are real aims; a low treble like
/// T3, a non-finishing double and the Bull as a setup dart are not.
abstract final class NaturalAim {
  /// The lowest treble anyone sensibly aims at as a setup dart.
  static const int lowestTreble = 15;

  static bool isNatural(DartThrow dart) {
    if (dart.isBull) return false;
    return switch (dart.multiplier) {
      Multiplier.single => true,
      Multiplier.treble => dart.number >= lowestTreble,
      Multiplier.double => false,
    };
  }
}
