import 'package:carbsai/core/models/barcode.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tester typed `88888888` and got a Bordeaux. It is not a barcode: the
/// EAN-8 check digit for `8888888` is 0, so the only valid code of that shape
/// is `88888880`.
void main() {
  test('the code from the bug report is refused', () {
    expect(Barcode.isValid('88888888'), isFalse);
    expect(Barcode.checkDigitFor('8888888'), 0);
    expect(Barcode.isValid('88888880'), isTrue);
  });

  test('real products pass', () {
    for (final code in [
      '5449000000996', // Coca-Cola 330ml, EAN-13
      '4006381333931', // Stabilo pen, the textbook EAN-13
      '3017620422003', // Nutella 400g, EAN-13
      '0012000001086', // UPC-A as 13
      '96385074', // EAN-8
    ]) {
      expect(Barcode.isValid(code), isTrue, reason: code);
    }
  });

  test('a single mistyped digit fails', () {
    // The whole point of a check digit, and the common case here: someone
    // reading a number off a curved tin.
    expect(Barcode.isValid('5449000000997'), isFalse);
    expect(Barcode.isValid('3017620422004'), isFalse);
  });

  test('wrong lengths and non-digits are refused', () {
    for (final bad in ['', '123', '1234567', '123456789', '1'.padRight(15, '1'),
      '12345 78', '1234567a']) {
      expect(Barcode.isValid(bad), isFalse, reason: '"$bad"');
    }
  });

  test('the weighting runs from the right, not the left', () {
    // EAN-8 and EAN-13 have opposite parity, so a checksum written from the
    // left passes one and fails the other.
    expect(Barcode.isValid('96385074'), isTrue, reason: 'EAN-8');
    expect(Barcode.isValid('5449000000996'), isTrue, reason: 'EAN-13');
  });
}
