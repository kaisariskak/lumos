String formatPaymentAmount(double value) {
  final raw = value.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(raw[i]);
  }
  return buffer.toString();
}
