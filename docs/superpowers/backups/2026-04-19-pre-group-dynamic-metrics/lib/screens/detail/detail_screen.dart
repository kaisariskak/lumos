import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';

import '../../models/custom_category.dart';
import '../../models/ibadat_category.dart';
import '../../models/ibadat_period.dart';
import '../../theme/accent_provider.dart';
import '../../models/ibadat_profile.dart';
import '../../models/ibadat_report.dart';
import '../../repositories/custom_category_repository.dart';
import '../../repositories/ibadat_report_repository.dart';
import '../../widgets/ring_indicator.dart';

class DetailScreen extends StatefulWidget {
  final IbadatProfile profile;
  final String groupId;
  final IbadatReport? report;
  final String weekLabel;
  final bool isWeekMode;
  final List<IbadatReport> monthReports;
  final List<IbadatPeriod> periods;
  final int initialPeriodIdx;

  const DetailScreen({
    super.key,
    required this.profile,
    required this.groupId,
    required this.report,
    required this.weekLabel,
    required this.isWeekMode,
    this.monthReports = const [],
    this.periods = const [],
    this.initialPeriodIdx = 0,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final IbadatReportRepository _repo;
  late final CustomCategoryRepository _customRepo;
  late int _periodIdx;
  IbadatReport? _report;
  List<CustomCategory> _customCategories = [];
  bool _isLoading = false;

  bool get _isPeriodMode => widget.periods.isNotEmpty;

  IbadatPeriod? get _currentPeriod =>
      _isPeriodMode ? widget.periods[_periodIdx.clamp(0, widget.periods.length - 1)] : null;

  @override
  void initState() {
    super.initState();
    _repo = IbadatReportRepository(Supabase.instance.client);
    _customRepo = CustomCategoryRepository(Supabase.instance.client);
    _periodIdx = widget.initialPeriodIdx.clamp(0, widget.periods.isEmpty ? 0 : widget.periods.length - 1);
    _report = widget.report;
    _customRepo.getForGroup(widget.groupId).then((cats) {
      if (mounted) setState(() => _customCategories = cats);
    });
  }

  Future<void> _loadPeriodReport() async {
    final period = _currentPeriod;
    if (period == null) return;
    setState(() => _isLoading = true);
    try {
      final r = await _repo.getReportByPeriod(
        userId: widget.profile.id,
        groupId: widget.groupId,
        periodId: period.id,
      );
      setState(() {
        _report = r;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _goPrev() {
    if (_periodIdx < widget.periods.length - 1) {
      _periodIdx++;
      _loadPeriodReport();
    }
  }

  void _goNext() {
    if (_periodIdx > 0) {
      _periodIdx--;
      _loadPeriodReport();
    }
  }

  int _getValue(String key) {
    if (_isPeriodMode) return _report?.getValue(key) ?? 0;
    if (widget.isWeekMode) return widget.report?.getValue(key) ?? 0;
    return widget.monthReports.fold(0, (s, r) => s + r.getValue(key));
  }

  Widget _buildCatCard({
    required String icon,
    required String label,
    required int val,
    required double pct,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              CategoryRing(value: pct, color: color),
            ],
          ),
          const Spacer(),
          Text('$val', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(2))),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calcScore() {
    double sum = 0;
    for (final cat in IbadatCategory.all) {
      final max = widget.isWeekMode ? cat.weekMax : cat.monthMax;
      sum += (_getValue(cat.key) / max).clamp(0.0, 1.0);
    }
    return sum / IbadatCategory.all.length;
  }

  @override
  Widget build(BuildContext context) {
    final score = _calcScore();
    final accent = AccentProvider.instance.current;
    final period = _currentPeriod;

    String label;
    if (_isPeriodMode && period != null) {
      label = period.dateRangeLabelLocalized(S.of(context).languageCode);
    } else {
      label = widget.weekLabel;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF0F172A), accent.gradientMid, const Color(0xFF0F172A)],
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chevron_left, color: Color(0xFF94A3B8), size: 20),
                          Text(S.of(context).back, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: accent.accent))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                        child: Column(
                          children: [
                            // Avatar
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [accent.accentDark, accent.accent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(36),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.accentDark.withValues(alpha: 0.4),
                                    blurRadius: 32,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  widget.profile.displayName[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.profile.displayName,
                              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.profile.email,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            ),
                            const SizedBox(height: 10),

                            // Period badge / navigator
                            if (_isPeriodMode)
                              _PeriodNav(
                                label: label,
                                canPrev: _periodIdx < widget.periods.length - 1,
                                canNext: _periodIdx > 0,
                                onPrev: _goPrev,
                                onNext: _goNext,
                                accentColor: accent.accent,
                                accentLight: accent.accentLight,
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: accent.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: accent.accent.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(widget.isWeekMode ? '📅' : '📆', style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: TextStyle(color: accent.accentLight, fontSize: 13, fontWeight: FontWeight.w600),
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
                              children: [
                                ...IbadatCategory.all.map((cat) {
                                  final val = _getValue(cat.key);
                                  final max = widget.isWeekMode ? cat.weekMax : cat.monthMax;
                                  final pct = (val / max).clamp(0.0, 1.0);
                                  return _buildCatCard(
                                    icon: cat.icon,
                                    label: '${S.of(context).categoryLabel(cat.key)} · ${S.of(context).unitLabel(cat.unit)}',
                                    val: val,
                                    pct: pct,
                                    color: cat.color,
                                  );
                                }),
                                ..._customCategories.map((cat) {
                                  final val = _report?.getCustomValue(cat.id) ?? 0;
                                  final pct = (val / cat.weekMax).clamp(0.0, 1.0);
                                  return _buildCatCard(
                                    icon: cat.icon,
                                    label: '${cat.name} · ${S.of(context).unitLabel(cat.unit)}',
                                    val: val,
                                    pct: pct,
                                    color: const Color(0xFF6366F1),
                                  );
                                }),
                              ],
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

class _PeriodNav extends StatelessWidget {
  final String label;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Color accentColor;
  final Color accentLight;

  const _PeriodNav({
    required this.label,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.accentColor,
    required this.accentLight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavBtn(icon: Icons.chevron_left, enabled: canPrev, color: accentColor, onTap: onPrev),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📆', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(color: accentLight, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          _NavBtn(icon: Icons.chevron_right, enabled: canNext, color: accentColor, onTap: onNext),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _NavBtn({required this.icon, required this.enabled, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: enabled ? color : const Color(0xFF334155), size: 20),
      ),
    );
  }
}
