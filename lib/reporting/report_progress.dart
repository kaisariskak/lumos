import '../models/group_metric.dart';
import '../models/ibadat_report.dart';

double metricProgress(int value, int maxValue) {
  if (maxValue <= 0) return 0;
  return (value / maxValue).clamp(0.0, 1.0);
}

double reportProgress(IbadatReport report, Iterable<GroupMetric> metrics) {
  final list = metrics.where((metric) => metric.id != null).toList();
  if (list.isEmpty) return 0;

  final total = list.fold<double>(
    0,
    (sum, metric) => sum + metricProgress(report.valueForMetric(metric.id!), metric.maxValue),
  );
  return total / list.length;
}

double? pointsForMetricValue(int value, GroupMetric metric) {
  final amountPerPoint = metric.pointsPerUnit;
  final pointsValue = metric.pointsValue;
  if (amountPerPoint == null ||
      amountPerPoint <= 0 ||
      pointsValue == null ||
      pointsValue <= 0) {
    return null;
  }
  return value / amountPerPoint * pointsValue;
}

double? maxPointsForMetric(GroupMetric metric) =>
    pointsForMetricValue(metric.maxValue, metric);

String formatMetricPoints(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
        RegExp(r'\.$'),
        '',
      );
}

List<int> quickValuesFor(GroupMetric metric) {
  return [0.25, 0.5, 0.75, 1.0]
      .map((fraction) => (metric.maxValue * fraction).round())
      .toSet()
      .toList()
    ..sort();
}
