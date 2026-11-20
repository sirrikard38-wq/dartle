import '../domain/checkout_engine.dart';

/// The Input keypad of Checkout tutorial and Checkout practice: the digits
/// typed, three at the most. [freshAfter] since the last key, or after a
/// number was dealt ([show]), the next digit starts a new number instead of
/// going on the end of the old one (102, away for a while, then 4 is 4).
class NumberInput {
  NumberInput({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// This long after the last key, the next digit starts a new number.
  static const Duration freshAfter = Duration(seconds: 3);

  /// The digits typed (empty for none).
  String digits = '';

  /// The number shown was dealt (Next checkout), not typed.
  bool _dealt = false;

  /// When a key was last pressed.
  DateTime? _typedAt;

  /// The number typed, when the digits make one from 2 to 170.
  int? get number {
    final value = int.tryParse(digits);
    return value != null && value >= CheckoutEngine.minCheckout && value <= CheckoutEngine.maxCheckout
        ? value
        : null;
  }

  /// Types [digit]: no leading zero, three digits at the most. After a dealt
  /// number, or [freshAfter] since the last key, it starts a new number.
  void type(int digit) {
    final now = _now();
    final last = _typedAt;
    if (_dealt || (last != null && now.difference(last) >= freshAfter)) digits = '';
    _dealt = false;
    _typedAt = now;
    if (digits.length >= 3 || (digits.isEmpty && digit == 0)) return;
    digits += '$digit';
  }

  /// Takes the last digit away (UNDO). It counts as a key: what is left can be
  /// typed on.
  void delete() {
    _dealt = false;
    _typedAt = _now();
    if (digits.isEmpty) return;
    digits = digits.substring(0, digits.length - 1);
  }

  /// Shows a dealt [number]; the next digit starts a new one.
  void show(int number) {
    digits = '$number';
    _dealt = true;
  }
}
