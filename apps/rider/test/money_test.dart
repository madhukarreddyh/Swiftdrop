import 'package:flutter_test/flutter_test.dart';
import 'package:swiftdrop_rider/utils/money.dart';

void main() {
  group('formatPaise', () {
    test('zero paise', () {
      expect(formatPaise(0), '₹0');
    });

    test('whole rupees use Indian grouping', () {
      expect(formatPaise(3000), '₹30');
      expect(formatPaise(5000), '₹50');
      expect(formatPaise(125000), '₹1,250');
      expect(formatPaise(10000000), '₹1,00,000');
    });

    test('fractional rupees show two decimals', () {
      expect(formatPaise(3050), '₹30.50');
      expect(formatPaise(99), '₹0.99');
    });

    test('rider earning example: 95% of ₹70', () {
      // 7000 - round(7000*5/100) = 6650
      expect(formatPaise(6650), '₹66.50');
    });
  });

  group('maskAccount', () {
    test('masks all but last 4 digits', () {
      expect(maskAccount('50100234567891'), '•••• 7891');
    });

    test('empty account', () {
      expect(maskAccount(''), 'Not added');
      expect(maskAccount(null), 'Not added');
    });
  });

  group('maskPhone', () {
    test('masks Indian phone', () {
      expect(maskPhone('919876543210'), '+91 98765 43210');
    });
  });
}
