/// A product barcode, and whether it can possibly be one.
///
/// Every GTIN — EAN-8, UPC-A, EAN-13, GTIN-14 — carries a check digit computed
/// from the others. The camera path gets this for free: a symbology decoder
/// will not emit a code whose checksum fails. The **typed** path had no such
/// protection and accepted any 8 to 14 digits, so a tester typing `88888888`
/// spent a lookup on a code that cannot exist (the valid EAN-8 ends in 0) and
/// got a Bordeaux back.
///
/// Checking it here costs nothing and is the difference between "no such
/// product" and a confident wrong answer.
abstract final class Barcode {
  /// GTIN lengths. 8, 12, 13 and 14 are the real ones; a code of any other
  /// length is a typo or a different kind of number entirely.
  static const Set<int> lengths = {8, 12, 13, 14};

  /// Whether [digits] is a well-formed GTIN, check digit included.
  static bool isValid(String digits) {
    final code = digits.trim();
    if (!lengths.contains(code.length)) return false;
    if (!RegExp(r'^\d+$').hasMatch(code)) return false;
    if (isRepdigit(code)) return false;
    return checkDigitFor(code.substring(0, code.length - 1)) ==
        int.parse(code[code.length - 1]);
  }

  /// One digit repeated — `88888888888888`, `2222222222222`, `00000000`.
  ///
  /// The check digit cannot reject these and that is not a flaw in it: for any
  /// repeated digit *d*, the twelve EAN-13 weights sum to 24, so the body sums
  /// to 24d and the required check digit works out to d itself about a third of
  /// the time. `8888888888888` and `2222222222222` are both arithmetically
  /// perfect GTINs.
  ///
  /// They are also the first thing anyone types into a barcode box, and Open
  /// Food Facts — being crowd-sourced — has joke records filed under several of
  /// them. `8888888888888` returns a product called "Motorcycle" with 100 kcal
  /// and no macros at all. No manufacturer is allocated a repdigit prefix, so
  /// refusing them costs nothing real and removes the whole class.
  static bool isRepdigit(String code) =>
      code.isNotEmpty && code.split('').every((c) => c == code[0]);

  /// The check digit [body] should end with.
  ///
  /// Weights alternate 3 and 1 **from the right**, which is why this walks the
  /// string backwards rather than keying on absolute position — the weighting
  /// flips between even and odd lengths, and getting it from the left is the
  /// classic way to write a checksum that works for EAN-13 and fails for
  /// EAN-8.
  static int checkDigitFor(String body) {
    var sum = 0;
    for (var i = 0; i < body.length; i++) {
      final digit = int.parse(body[body.length - 1 - i]);
      sum += i.isEven ? digit * 3 : digit;
    }
    return (10 - sum % 10) % 10;
  }
}
