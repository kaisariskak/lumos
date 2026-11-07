import 'package:supabase_flutter/supabase_flutter.dart';

import '../groups/group_member_filter.dart';
import '../models/group_metric.dart';
import '../models/ibadat_group.dart';
import '../models/ibadat_period.dart';
import '../models/ibadat_profile.dart';
import '../models/ibadat_report.dart';
import '../repositories/group_metric_repository.dart';
import '../repositories/ibadat_group_repository.dart';
import '../repositories/ibadat_period_repository.dart';
import '../repositories/ibadat_report_repository.dart';
import '../utils/perf_log.dart';
import 'monthly_group_report.dart';

/// Fetches everything needed for [buildMonthlyGroupReport] from Supabase.
Future<MonthlyGroupReport> loadMonthlyGroupReport({
  required IbadatGroup group,
  required int month,
  required int year,
}) {
  return traceAsync(
    'loadMonthlyGroupReport group=${group.id} $month.$year',
    () async {
      final client = Supabase.instance.client;
      final groupRepo = IbadatGroupRepository(client);
      final metricRepo = GroupMetricRepository(client);
      final periodRepo = IbadatPeriodRepository(client);
      final reportRepo = IbadatReportRepository(client);

      final results = await Future.wait([
        groupRepo.getGroupMembers(group.id),
        metricRepo.getForGroup(group.id),
        periodRepo.getPeriodsForGroup(group.id, includePersonal: false),
      ]);
      final members = visibleGroupMembers(
        results[0] as List<IbadatProfile>,
        adminId: group.adminId,
      );
      final metrics = results[1] as List<GroupMetric>;
      final periods = results[2] as List<IbadatPeriod>;

      // Period mode: only the periods attributed to this month are fetched.
      final monthPeriods = periods.where(
        (p) => p.startDate.year == year && p.startDate.month == month,
      );
      final List<IbadatReport> reports;
      if (periods.isNotEmpty) {
        final perPeriod = await Future.wait(
          monthPeriods.map(
            (p) => reportRepo.getGroupReportsByPeriod(
              groupId: group.id,
              periodId: p.id,
            ),
          ),
        );
        reports = perPeriod.expand((r) => r).toList();
      } else {
        reports = await reportRepo.getGroupReports(
          groupId: group.id,
          month: month,
          year: year,
        );
      }

      return buildMonthlyGroupReport(
        group: group,
        month: month,
        year: year,
        members: members,
        metrics: metrics,
        periods: periods,
        reports: reports,
      );
    },
  );
}
