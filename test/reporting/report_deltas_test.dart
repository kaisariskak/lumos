import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/reporting/report_deltas.dart';

void main() {
  test('adds deltas to existing totals', () {
    expect(
      applyReportDeltas({'quran': 13, 'book': 4}, {'quran': 5}),
      {'quran': 18, 'book': 4},
    );
  });

  test('adds deltas for metrics without a saved total', () {
    expect(applyReportDeltas({}, {'quran': 3}), {'quran': 3});
  });

  test('negative delta decreases total', () {
    expect(applyReportDeltas({'quran': 13}, {'quran': -3}), {'quran': 10});
  });

  test('total never goes below zero', () {
    expect(applyReportDeltas({'quran': 2}, {'quran': -5}), {'quran': 0});
  });

  test('empty or zero deltas keep totals unchanged', () {
    expect(applyReportDeltas({'quran': 13}, {}), {'quran': 13});
    expect(applyReportDeltas({'quran': 13}, {'quran': 0}), {'quran': 13});
  });

  test('does not mutate the input maps', () {
    final totals = {'quran': 13};
    final deltas = {'quran': 2};
    applyReportDeltas(totals, deltas);
    expect(totals, {'quran': 13});
    expect(deltas, {'quran': 2});
  });
}
