import 'package:flutter/foundation.dart';

const bool _perfLogsEnabled = bool.fromEnvironment('PERF_LOGS');

bool get perfLogsEnabled => kDebugMode || _perfLogsEnabled;

Future<T> traceAsync<T>(
  String label,
  Future<T> Function() action, {
  String Function(T result)? describeResult,
}) async {
  if (!perfLogsEnabled) {
    return action();
  }

  final stopwatch = Stopwatch()..start();
  debugPrint('[PERF] START $label');
  try {
    final result = await action();
    stopwatch.stop();
    final details = describeResult == null ? '' : ' ${describeResult(result)}';
    debugPrint('[PERF] END $label ${stopwatch.elapsedMilliseconds}ms$details');
    return result;
  } catch (error) {
    stopwatch.stop();
    debugPrint(
      '[PERF] ERROR $label ${stopwatch.elapsedMilliseconds}ms $error',
    );
    rethrow;
  }
}
