import 'package:intl/intl.dart';

/// Money arrives from the API in PAISE (integers) — never floats.
/// These helpers render it as Indian rupees: ₹50, ₹1,250, ₹1,00,000.
String formatPaise(int paise) {
  final hasFraction = paise % 100 != 0;
  final fmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: hasFraction ? 2 : 0,
  );
  return fmt.format(paise / 100);
}

/// "•••• 4821" style masking for bank account numbers.
String maskAccount(String? account) {
  if (account == null || account.isEmpty) return 'Not added';
  final digits = account.replaceAll(RegExp(r'\s'), '');
  if (digits.length <= 4) return '•••• $digits';
  return '•••• ${digits.substring(digits.length - 4)}';
}

/// "+91 98XXX XXXXX" style masking for phone numbers.
String maskPhone(String? phone) {
  if (phone == null || phone.length < 10) return phone ?? '';
  final last10 = phone.substring(phone.length - 10);
  return '+91 ${last10.substring(0, 5)} ${last10.substring(5)}';
}
