import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import '../../models/ibadat_category.dart';
import '../../theme/accent_provider.dart';
import '../../models/ibadat_profile.dart';
import '../../models/ibadat_report.dart';
import '../../widgets/ring_indicator.dart';

class DetailScreen extends StatelessWidget {
  final IbadatProfile profile;
  final IbadatReport? report;
  final String weekLabel;
  final bool isWeekMode;
  final List<IbadatReport> monthReports;

  const DetailScreen({
    super.key,
    required this.profile,
    required this.report,
    required this.weekLabel,
    required this.isWeekMode,
    this.monthReports = const [],
  });

  int _getValue(String key) {
    if (isWeekMode) return report?.getValue(key) ?? 0;
    return monthReports.fold(0, (s, r) => s + r.getValue(key));
  }

  double _calcScore() {
    double sum = 0;
    for (final cat in IbadatCategory.all) {
      final max = isWeekMode ? cat.weekMax : cat.monthMax;
      sum += (_getValue(cat.key) / max).clamp(0.0, 1.0);
    }
    return sum / IbadatCategory.all.length;
  }

  @override
  Widget build(BuildContext context) {
    final score = _calcScore();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF0F172A), AccentProvider.instance.current.gradientMid, const Color(0xFF0F172A)],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chevron_left,
                              color: Color(0xFF94A3B8), size: 20),
                          Text(
                            S.of(context).back,
                            style: const TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    children: [
                      // Profile header
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AccentProvider.instance.current.accentDark, AccentProvider.instance.current.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                              color: AccentProvider.instance.current.accentDark.withValues(alpha: 0.4),
                              blurRadius: 32,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            profile.displayName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.displayName,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.email,
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 12),
                      ),
                      const SizedBox(height: 10),

                      // Period badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: AccentProvider.instance.current.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AccentProvider.instance.current.accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(isWeekMode ? '📅' : '📆',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 6),
                            Text(
                              weekLabel,
                              style: TextStyle(
                                color: AccentProvider.instance.current.accentLight,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Overall ring
                      RingIndicator(value: score, size: 88),
                      const SizedBox(height: 20),

                      // Category grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.3,
                        children: IbadatCategory.all.map((cat) {
                          final val = _getValue(cat.key);
                          final max =
                              isWeekMode ? cat.weekMax : cat.monthMax;
                          final pct = (val / max).clamp(0.0, 1.0);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(cat.icon,
                                        style:
                                            const TextStyle(fontSize: 22)),
                                    CategoryRing(
                                        value: pct, color: cat.color),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  '$val',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: cat.color,
                                  ),
                                ),
                                Text(
                                  '${S.of(context).categoryLabel(cat.key)} · ${S.of(context).unitLabel(cat.unit)}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.06),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: pct,
                                        child: Container(
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: cat.color,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
