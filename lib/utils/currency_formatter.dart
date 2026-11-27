/// Formatea cantidades monetarias con separadores de miles y 2 decimales (ej. $1,250.00)
class CurrencyFormatter {
  static String format(num amount, {bool withCurrencySymbol = true, bool withMxn = false}) {
    final isNegative = amount < 0;
    final fixed = amount.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final reverseIndex = intPart.length - i;
      buffer.write(intPart[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }

    final prefix = '${isNegative ? '-' : ''}${withCurrencySymbol ? '\$' : ''}';
    final suffix = withMxn ? ' MXN' : '';
    return '$prefix${buffer.toString()}.$decPart$suffix';
  }
}
