/// Adds per-metric [deltas] to saved [totals] for one report period.
/// Totals are clamped at zero; metrics without a delta are kept as is.
Map<String, int> applyReportDeltas(
  Map<String, int> totals,
  Map<String, int> deltas,
) {
  final result = Map<String, int>.of(totals);
  deltas.forEach((metricId, delta) {
    final next = (result[metricId] ?? 0) + delta;
    result[metricId] = next < 0 ? 0 : next;
  });
  return result;
}
