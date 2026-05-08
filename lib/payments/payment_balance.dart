double remainingFixedMonthlyDebt({
  required double fixedMonthlyAmount,
  required double currentMonthPaid,
}) {
  final remaining = fixedMonthlyAmount - currentMonthPaid;
  return remaining > 0 ? remaining : 0;
}
