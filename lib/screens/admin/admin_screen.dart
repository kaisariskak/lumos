import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../theme/accent_provider.dart';
import '../../models/ibadat_group.dart';
import '../../models/ibadat_period.dart';
import '../../models/ibadat_profile.dart';
import '../../models/group_metric.dart';
import '../../models/invite_code.dart';
import '../../repositories/ibadat_group_repository.dart';
import '../../repositories/group_metric_repository.dart';
import '../../repositories/ibadat_period_repository.dart';
import '../../repositories/ibadat_report_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/invite_code_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../reporting/report_progress.dart';
import '../../services/pin_service.dart';
import '../pin/pin_screen.dart';

class AdminScreen extends StatefulWidget {
  final IbadatProfile profile;
  final IbadatGroup? group;
  final VoidCallback onSwitchGroup;
  final VoidCallback onLogout;
  final VoidCallback? onGroupChanged;

  const AdminScreen({
    super.key,
    required this.profile,
    this.group,
    required this.onSwitchGroup,
    required this.onLogout,
    this.onGroupChanged,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final IbadatGroupRepository _groupRepo;
  late final ProfileRepository _profileRepo;
  late final IbadatPeriodRepository _periodRepo;
  late final IbadatReportRepository _reportRepo;
  late final PaymentRepository _paymentRepo;
  late final InviteCodeRepository _codeRepo;
  late final GroupMetricRepository _metricRepo;
  List<GroupMetric> _groupMetrics = [];

  // Super admin data
  List<IbadatGroup> _allGroups = [];
  Map<String, List<IbadatProfile>> _groupMembers = {};
  Map<String, List<IbadatPeriod>> _groupPeriods = {};
  List<IbadatProfile> _myAdmins = [];
  List<IbadatProfile> _ungroupedUsers = [];

  // Group admin data
  List<IbadatProfile> _members = [];

  List<IbadatGroup> _myGroups = []; // группы этого админа
  IbadatGroup? _localGroup;         // локально после создания
  IbadatGroup? _adminSelectedGroup; // единый выбор группы для всех операций
  InviteCode? _adminSelectedCode;   // активный код выбранной группы

  bool _isLoading = true;
  bool _hasPin = false;
  InviteCode? _activeUserCode;
  InviteCode? _activeAdminCode;
  bool _generatingCode = false;
  bool _metricsExpanded = false;
  int _groupMetricsLoadVersion = 0;
  final _newGroupCtrl = TextEditingController();
  final _periodLabelCtrl = TextEditingController();
  DateTime? _periodStart;
  DateTime? _periodEnd;
  DateTime? _newGroupPeriodStart;
  DateTime? _newGroupPeriodEnd;
  IbadatGroup? _selectedGroup;
  final Set<String> _expandedGroups = {};
  String? _deletingPeriodId; // id периода, который проверяется/удаляется

  // Admin's own personal periods (separate from group periods)
  List<IbadatPeriod> _adminPersonalPeriods = [];
  DateTime? _adminPeriodStart;
  DateTime? _adminPeriodEnd;

  // Admin's own personal metrics (admin_id != null, group_id == null)
  List<GroupMetric> _adminMetrics = [];
  bool _adminMetricsExpanded = false;

  bool get _isSuperAdmin => widget.profile.isSuperAdmin;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _groupRepo = IbadatGroupRepository(client);
    _profileRepo = ProfileRepository(client);
    _periodRepo = IbadatPeriodRepository(client);
    _reportRepo = IbadatReportRepository(client);
    _paymentRepo = PaymentRepository(client);
    _codeRepo = InviteCodeRepository(client);
    _metricRepo = GroupMetricRepository(client);
    _loadData();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    final has = await PinService.hasPin();
    if (mounted) setState(() => _hasPin = has);
  }

  Future<void> _onSetPin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PinScreen(
          isSetup: true,
          onSuccess: () {
            Navigator.of(context).pop();
            _loadPinState();
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _onDisablePin() async {
    await PinService.clearPin();
    _loadPinState();
  }

  @override
  void dispose() {
    _newGroupCtrl.dispose();
    _periodLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (_isSuperAdmin) {
        // Super-admin: only see groups belonging to their own admins
        final admins = await _profileRepo.getAdminsBySuperAdmin(widget.profile.id);
        final adminIds = admins.map((a) => a.id).toList();
        final groups = await _groupRepo.getGroupsByAdminIds(adminIds);
        final ungrouped = await _profileRepo.getUngroupedUsersByAdminIds(adminIds);
        final Map<String, List<IbadatProfile>> membersMap = {};
        final Map<String, List<IbadatPeriod>> periodsMap = {};
        await Future.wait(groups.map((g) async {
          final results = await Future.wait([
            _groupRepo.getGroupMembers(g.id, adminId: g.adminId),
            _periodRepo.getPeriodsForGroup(g.id, includePersonal: false),
          ]);
          membersMap[g.id] = results[0] as List<IbadatProfile>;
          periodsMap[g.id] = results[1] as List<IbadatPeriod>;
        }));
        setState(() {
          _myAdmins = admins;
          _ungroupedUsers = ungrouped;
          _allGroups = groups;
          _groupMembers = membersMap;
          _groupPeriods = periodsMap;
          final prevId = _selectedGroup?.id;
          _selectedGroup = prevId != null
              ? groups.firstWhere((g) => g.id == prevId,
                  orElse: () => groups.isNotEmpty ? groups.first : groups.first)
              : groups.isNotEmpty ? groups.first : null;
          _isLoading = false;
        });
      } else if (widget.profile.isAdmin) {
        // Загружаем все группы этого админа
        final myGroups = await _groupRepo.getGroupsByAdminIds([widget.profile.id]);
        final Map<String, List<IbadatProfile>> membersMap = {};
        final Map<String, List<IbadatPeriod>> periodsMap = {};
        await Future.wait(myGroups.map((g) async {
          final results = await Future.wait([
            _groupRepo.getGroupMembers(g.id),
            _periodRepo.getPeriodsForGroup(g.id, includePersonal: false),
          ]);
          final all = results[0] as List<IbadatProfile>;
          membersMap[g.id] = all.where((m) => m.id != widget.profile.id).toList();
          periodsMap[g.id] = results[1] as List<IbadatPeriod>;
        }));
        // Load admin's personal periods (is_personal = true) and personal metrics.
        final adminResults = await Future.wait([
          _periodRepo.getPersonalPeriodsForAdmin(widget.profile.id),
          _metricRepo.getForAdmin(widget.profile.id),
        ]);
        final personalPeriods = adminResults[0] as List<IbadatPeriod>;
        final personalMetrics = adminResults[1] as List<GroupMetric>;

        setState(() {
          _myGroups = myGroups;
          _allGroups = myGroups;
          _groupMembers = membersMap;
          _groupPeriods = periodsMap;
          _adminPersonalPeriods = personalPeriods;
          _adminMetrics = personalMetrics;
          // Для совместимости оставляем _members для текущей группы
          final currentGroup = widget.group ?? _localGroup;
          _members = currentGroup != null ? (membersMap[currentGroup.id] ?? []) : [];
          _isLoading = false;
          final prevId = _adminSelectedGroup?.id;
          _adminSelectedGroup = prevId != null
              ? myGroups.firstWhere((g) => g.id == prevId,
                  orElse: () => myGroups.isNotEmpty ? myGroups.first : _adminSelectedGroup!)
              : myGroups.isNotEmpty ? myGroups.first : null;
        });
      } else {
        setState(() => _isLoading = false);
      }
      // Load active invite codes (auto-generate if expired)
      if (_isSuperAdmin) {
        _activeAdminCode = await _codeRepo.getOrCreateActiveAdminCode(
            createdBy: widget.profile.id);
      }

      // Load code and metrics for initially selected group (admin)
      if (widget.profile.isAdmin && !_isSuperAdmin && _adminSelectedGroup != null) {
        final selectedGroupId = _adminSelectedGroup!.id;
        final requestVersion = ++_groupMetricsLoadVersion;
        final results = await Future.wait([
          _codeRepo.getActiveUserCode(selectedGroupId),
          _metricRepo.getForGroup(selectedGroupId),
        ]);
        final code = results[0] as InviteCode?;
        final metrics = results[1] as List<GroupMetric>;
        if (mounted &&
            requestVersion == _groupMetricsLoadVersion &&
            _adminSelectedGroup?.id == selectedGroupId) {
          setState(() {
            _adminSelectedCode = code;
            _groupMetrics = metrics;
          });
        }
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateUserCode() async {
    final groupId = (widget.group ?? _localGroup)?.id;
    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).createNewGroup)),
      );
      return;
    }
    setState(() => _generatingCode = true);
    try {
      final code = await _codeRepo.generateUserCode(
        groupId: groupId,
        createdBy: widget.profile.id,
      );
      setState(() {
        _activeUserCode = code;
        _generatingCode = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingCode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.of(context).error}: $e')),
      );
    }
  }

  Future<void> _generateAdminCode() async {
    setState(() => _generatingCode = true);
    try {
      final code = await _codeRepo.generateAdminCode(
        createdBy: widget.profile.id,
      );
      setState(() {
        _activeAdminCode = code;
        _generatingCode = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingCode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.of(context).error}: $e')),
      );
    }
  }

  Future<void> _generateCodeForGroup(IbadatGroup group) async {
    setState(() => _generatingCode = true);
    try {
      await _profileRepo.updateCurrentGroup(widget.profile.id, group.id);
      final code = await _codeRepo.generateUserCode(
        groupId: group.id,
        createdBy: widget.profile.id,
      );
      if (!mounted) return;
      setState(() {
        _adminSelectedCode = code;
        _generatingCode = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingCode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.of(context).error}: $e')),
      );
    }
  }

  Future<void> _onAdminGroupSelected(IbadatGroup g) async {
    final requestVersion = ++_groupMetricsLoadVersion;
    setState(() {
      _adminSelectedGroup = g;
      _adminSelectedCode = null;
      _groupMetrics = [];
      _periodStart = null;
      _periodEnd = null;
    });
    // Загружаем код и настройки для выбранной группы
    try {
      final results = await Future.wait([
        _codeRepo.getActiveUserCode(g.id),
        _metricRepo.getForGroup(g.id),
      ]);
      if (!mounted ||
          requestVersion != _groupMetricsLoadVersion ||
          _adminSelectedGroup?.id != g.id) {
        return;
      }
      final code = results[0] as InviteCode?;
      final metrics = results[1] as List<GroupMetric>;
      setState(() {
        _adminSelectedCode = code;
        _groupMetrics = metrics;
      });
    } catch (e) {
      if (!mounted ||
          requestVersion != _groupMetricsLoadVersion ||
          _adminSelectedGroup?.id != g.id) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
  }

  /// Super-admin reassigns an ungrouped user to a group
  Future<void> _reassignUser(IbadatProfile user, String groupId) async {
    try {
      await _profileRepo.updateCurrentGroup(user.id, groupId);
      if (!mounted) return;
      setState(() {
        _ungroupedUsers.removeWhere((u) => u.id == user.id);
        _groupMembers[groupId] = [
          ...(_groupMembers[groupId] ?? []),
          user.copyWith(currentGroupId: groupId),
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${user.nickname} топқа қосылды ✅'),
        backgroundColor: const Color(0xFF059669),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
  }

  Future<void> _assignGroupAdmin(IbadatProfile member, IbadatGroup group) async {
    final isAdmin = member.role == 'admin';
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isAdmin ? '⬇️' : '👑', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              isAdmin
                  ? '${member.nickname} ${s.removeAdmin}?'
                  : '${member.nickname} "${group.name}" - ${s.makeAdmin}?',
              style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).no, style: const TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).yes,
                style: TextStyle(
                    color: isAdmin
                        ? const Color(0xFF6B7280)
                        : const Color(0xFFF59E0B))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (!isAdmin) {
          // Demote existing group admin first (enforce one admin per group)
          final groupMembers =
              _isSuperAdmin ? (_groupMembers[group.id] ?? []) : _members;
          for (final m in groupMembers) {
            if (m.id != member.id && m.role == 'admin') {
              await _profileRepo.updateRole(m.id, 'user');
            }
          }
        }
        final newRole = isAdmin ? 'user' : 'admin';
        await _profileRepo.updateRole(member.id, newRole);
        // Also update group's admin_id so RLS stays consistent
        if (!isAdmin) {
          await _groupRepo.updateAdminId(group.id, member.id);
        }
        if (!mounted) return;
        setState(() {
          IbadatProfile applyRole(IbadatProfile m) {
            if (m.id == member.id) return m.copyWith(role: newRole);
            if (!isAdmin && m.role == 'admin') return m.copyWith(role: 'user');
            return m;
          }
          for (final key in _groupMembers.keys) {
            _groupMembers[key] = _groupMembers[key]!.map(applyRole).toList();
          }
          _members = _members.map(applyRole).toList();
          if (!isAdmin) {
            _allGroups = _allGroups.map((g) =>
              g.id == group.id ? g.copyWith(adminId: member.id) : g).toList();
            _myGroups = _myGroups.map((g) =>
              g.id == group.id ? g.copyWith(adminId: member.id) : g).toList();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAdmin
                ? '${member.nickname} ${S.of(context).adminRemoved}'
                : '${member.nickname} ${S.of(context).adminAssigned}'),
            backgroundColor: const Color(0xFF374151),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
      }
    }
  }

  Future<void> _removeMember(IbadatProfile member) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              '${member.nickname} ${s.removeMemberConfirm}',
              style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).no, style: const TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).remove,
                style: const TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _profileRepo.updateCurrentGroup(member.id, null);
        if (!mounted) return;
        setState(() {
          for (final key in _groupMembers.keys) {
            _groupMembers[key]?.removeWhere((m) => m.id == member.id);
          }
          _members.removeWhere((m) => m.id == member.id);
        });
        widget.onGroupChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(S.of(context).removedFromGroup),
              backgroundColor: const Color(0xFF374151)),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
      }
    }
  }

  Future<void> _createGroup() async {
    final name = _newGroupCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      final group = await _groupRepo.createGroup(name, widget.profile.id);

      if (_newGroupPeriodStart != null) {
        final end = _newGroupPeriodEnd ?? _newGroupPeriodStart!.add(const Duration(days: 6));
        final s = _newGroupPeriodStart!;
        final label = '${s.day}.${s.month.toString().padLeft(2, '0')} – ${end.day}.${end.month.toString().padLeft(2, '0')}';
        await _periodRepo.createPeriod(
          groupId: group.id,
          label: label,
          startDate: s,
          endDate: end,
          createdBy: widget.profile.id,
        );
      }

      // Автоматически создаём код для новой группы
      InviteCode? inviteCode;
      try {
        inviteCode = await _codeRepo.generateUserCode(
          groupId: group.id,
          createdBy: widget.profile.id,
        );
      } catch (_) {
        // RLS error — продолжаем без кода
      }

      _newGroupCtrl.clear();
      setState(() {
        _newGroupPeriodStart = null;
        _newGroupPeriodEnd = null;
        _localGroup = group;
        _activeUserCode = inviteCode;
      });

      // Перезагружаем профиль чтобы widget.group обновился
      widget.onGroupChanged?.call();

      await _loadData();
      if (!mounted) return;

      if (inviteCode != null) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              S.of(context).groupCreated,
              style: const TextStyle(
                  color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(group.name,
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 13)),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            const Color(0xFF6366F1).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      const Text('🔑', style: TextStyle(fontSize: 20)),
                      const SizedBox(height: 6),
                      Text(
                        inviteCode!.code,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        S.of(context).generateUserCode,
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: inviteCode!.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(S.of(context).codeCopied)),
                  );
                },
                child: Text(S.of(context).codeLabel,
                    style: const TextStyle(color: Color(0xFFA5B4FC))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(S.of(context).groupCreated),
              backgroundColor: const Color(0xFF059669)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
  }

  Future<void> _createPeriod(String groupId) async {
    if (_periodStart == null) return;
    final end = _periodEnd ?? _periodStart!.add(const Duration(days: 6));
    final label = '${_periodStart!.day}.${_periodStart!.month.toString().padLeft(2, '0')} – ${end.day}.${end.month.toString().padLeft(2, '0')}';
    try {
      await _periodRepo.createPeriod(
        groupId: groupId,
        label: label,
        startDate: _periodStart!,
        endDate: end,
        createdBy: widget.profile.id,
      );
      _periodLabelCtrl.clear();
      setState(() {
        _periodStart = null;
        _periodEnd = null;
      });
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).periodCreated),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
  }

  Future<void> _createAdminPersonalPeriod() async {
    if (_adminPeriodStart == null) return;
    final groupId = _adminSelectedGroup?.id ?? widget.profile.currentGroupId;
    final end = _adminPeriodEnd ?? _adminPeriodStart!.add(const Duration(days: 6));
    final s = _adminPeriodStart!;
    final label = '${s.day}.${s.month.toString().padLeft(2, '0')} – ${end.day}.${end.month.toString().padLeft(2, '0')}';
    try {
      await _periodRepo.createPeriod(
        groupId: groupId,
        label: label,
        startDate: s,
        endDate: end,
        createdBy: widget.profile.id,
        isPersonal: true,
      );
      setState(() {
        _adminPeriodStart = null;
        _adminPeriodEnd = null;
      });
      await _loadData();
      widget.onGroupChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.of(context).periodCreated),
        backgroundColor: const Color(0xFF059669),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
  }

  /// Проверяет отчёты и удаляет период, если их нет
  Future<void> _tryDeletePeriod(IbadatPeriod period) async {
    setState(() => _deletingPeriodId = period.id);
    try {
      final hasReports = await _reportRepo.hasReportsForPeriod(
        groupId: period.groupId,
        periodId: period.id,
      );
      if (!mounted) return;
      if (hasReports) {
        setState(() => _deletingPeriodId = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.of(context).periodHasReports),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 5),
        ));
        return;
      }
      await _periodRepo.deletePeriod(period.id);
      if (!mounted) return;
      setState(() {
        if (period.groupId != null) {
          _groupPeriods[period.groupId!]?.removeWhere((p) => p.id == period.id);
        }
        _adminPersonalPeriods.removeWhere((p) => p.id == period.id);
      });
      widget.onGroupChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    } finally {
      if (mounted) setState(() => _deletingPeriodId = null);
    }
  }

  Future<void> _deletePeriod(IbadatPeriod period) async {
    try {
      await _periodRepo.deletePeriod(period.id);
      if (!mounted) return;
      setState(() {
        if (period.groupId != null) {
          _groupPeriods[period.groupId!]?.removeWhere((p) => p.id == period.id);
        }
        _adminPersonalPeriods.removeWhere((p) => p.id == period.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
  }

  // ── PERIODS BOTTOM SHEET ──────────────────────────────────────────────────

  void _showPeriodsSheet(String groupId, List<IbadatPeriod> periods, AppStrings s) {
    DateTime? sheetStart;
    DateTime? sheetEnd;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Row(children: [
                  const Text('📅', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(s.periods,
                      style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ]),
                const SizedBox(height: 16),

                // Existing periods
                if (periods.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(s.selectStartDate,
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 13)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: periods.length,
                      itemBuilder: (_, i) {
                        final p = periods[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF0EA5E9)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.label,
                                          style: const TextStyle(
                                              color: Color(0xFFE2E8F0),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                      Text(
                                          p.dateRangeLabelLocalized(
                                              s.languageCode),
                                          style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                _deletingPeriodId == p.id
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFEF4444)))
                                    : IconButton(
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await _tryDeletePeriod(p);
                                          if (mounted) {
                                            final updated = _groupPeriods[groupId] ?? [];
                                            _showPeriodsSheet(groupId, updated, s);
                                          }
                                        },
                                        icon: const Icon(Icons.delete_outline,
                                            color: Color(0xFFEF4444), size: 20),
                                        tooltip: s.delete,
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0xFFEF4444)
                                              .withValues(alpha: 0.1),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const Divider(color: Color(0xFF334155), height: 24),

                // Add new period
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setSheet(() {
                        sheetStart = picked;
                        sheetEnd = picked.add(const Duration(days: 6));
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Text('📅', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: sheetStart == null
                              ? Text(s.selectStartDate,
                                  style: const TextStyle(
                                      color: Color(0xFF475569), fontSize: 13))
                              : Text(
                                  '${sheetStart!.day}.${sheetStart!.month.toString().padLeft(2, '0')}.${sheetStart!.year}  →  ${sheetEnd!.day}.${sheetEnd!.month.toString().padLeft(2, '0')}.${sheetEnd!.year}  (7 ${s.unitLabel('күн')})',
                                  style: const TextStyle(
                                      color: Color(0xFFE2E8F0), fontSize: 13)),
                        ),
                        if (sheetStart != null)
                          GestureDetector(
                            onTap: () =>
                                setSheet(() { sheetStart = null; sheetEnd = null; }),
                            child: const Icon(Icons.close,
                                size: 16, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: sheetStart == null
                        ? null
                        : () async {
                            setState(() {
                              _periodStart = sheetStart;
                              _periodEnd = sheetEnd;
                            });
                            Navigator.pop(ctx);
                            await _createPeriod(groupId);
                            if (mounted) {
                              final updated = _groupPeriods[groupId] ?? [];
                              _showPeriodsSheet(groupId, updated, s);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(s.createPeriod,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          else if (_isSuperAdmin)
            ..._buildSuperAdminContent()
          else if (widget.profile.isAdmin)
            ..._buildGroupAdminContent()
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_isSuperAdmin ? '🌟' : '👑',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  _isSuperAdmin
                      ? '${widget.profile.nickname} · ${S.of(context).superAdminLabel}'
                      : '${widget.profile.nickname} · ${S.of(context).groupAdminLabel}',
                  style: const TextStyle(
                    color: Color(0xFFFCD34D),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
            ).createShader(b),
            child: Text(
              S.of(context).adminTitle,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── SUPER ADMIN ────────────────────────────────────────────────────────────

  List<Widget> _buildSuperAdminContent() {
    return [
      // ── Invite code for new admins ──
      _buildInviteCodeCard(isAdmin: true),
      const SizedBox(height: 16),

      // ── My admins section ──
      _buildMyAdminsCard(),
      const SizedBox(height: 16),

      // ── Ungrouped (removed) users ──
      if (_ungroupedUsers.isNotEmpty) ...[
        _buildUngroupedUsersCard(),
        const SizedBox(height: 16),
      ],

      // Groups (filtered to this super-admin's scope)
      ..._allGroups.map((group) {
        final members = _groupMembers[group.id] ?? [];
        return _buildGroupCard(group, members);
      }),
      const SizedBox(height: 8),

      // Central period management
      _buildCentralPeriodsCard(),
      const SizedBox(height: 16),

      // Create group
      _buildCreateGroupCard(),
      const SizedBox(height: 16),

      _buildLanguageSwitcher(),
      const SizedBox(height: 16),
      _buildColorPicker(),
      const SizedBox(height: 16),
      _buildPinCard(context),
      const SizedBox(height: 16),

      // Logout
      _buildLogoutButton(),
    ];
  }

  Widget _buildMyAdminsCard() {
    final s = S.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('👑', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                s.myAdminsTitle,
                style: const TextStyle(
                    color: Color(0xFFFCD34D),
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_myAdmins.isEmpty)
            Text(s.noAdmins,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))
          else
            ..._myAdmins.map((admin) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            admin.nickname[0].toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFFFCD34D),
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(admin.nickname,
                                style: const TextStyle(
                                    color: Color(0xFFE2E8F0),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('👑 admin',
                            style: TextStyle(
                                color: Color(0xFFFCD34D), fontSize: 10)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildUngroupedUsersCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                S.of(context).ungroupedUsers,
                style: TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context).ungroupedUsersDesc,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 12),
          ..._ungroupedUsers.map((user) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              user.nickname[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Color(0xFFFCA5A5),
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.nickname,
                                  style: const TextStyle(
                                      color: Color(0xFFE2E8F0),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_allGroups.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _allGroups.map((group) => GestureDetector(
                          onTap: () => _reassignUser(user, group.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFF059669).withValues(alpha: 0.3)),
                            ),
                            child: Text('➕ ${group.name}',
                                style: const TextStyle(
                                    color: Color(0xFF6EE7B7), fontSize: 11)),
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildGroupCard(IbadatGroup group, List<IbadatProfile> members,
      {bool isSuperAdminView = true}) {
    final isExpanded = _expandedGroups.contains(group.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header — tappable
          GestureDetector(
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedGroups.remove(group.id);
              } else {
                _expandedGroups.add(group.id);
              }
            }),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.3),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      ]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                        child: Text('👥', style: TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.name,
                            style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: group.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(S.of(context).codeCopied)),
                            );
                          },
                          child: Text('${S.of(context).codeLabel}: ${group.code}  📋',
                              style: const TextStyle(
                                  color: Color(0xFFA5B4FC), fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${members.length} ${S.of(context).memberCount}',
                        style: const TextStyle(
                            color: Color(0xFFA5B4FC),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            if (members.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(S.of(context).noMembers,
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteGroup(group),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(S.of(context).deleteGroup),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ] else ...[
              ...members.indexed.map((e) => _buildMemberTile(e.$2, group, isSuperAdmin: isSuperAdminView, index: e.$1)),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _deleteGroup(IbadatGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗑️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              '"${group.name}" ${S.of(context).deleteGroupConfirm}',
              style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).no, style: const TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).delete, style: const TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _groupRepo.deleteGroup(group.id);
        // Если удалили текущую группу — сбросить профиль
        final isCurrentGroup = group.id == (widget.group?.id ?? _localGroup?.id);
        if (isCurrentGroup) {
          await _profileRepo.updateCurrentGroup(widget.profile.id, null);
          setState(() => _localGroup = null);
          widget.onGroupChanged?.call();
          return;
        }
        if (!mounted) return;
        setState(() {
          _allGroups.removeWhere((g) => g.id == group.id);
          _myGroups.removeWhere((g) => g.id == group.id);
          _groupMembers.remove(group.id);
          _groupPeriods.remove(group.id);
          if (_adminSelectedGroup?.id == group.id) {
            _adminSelectedGroup = _myGroups.isNotEmpty ? _myGroups.first : null;
          }
          if (_selectedGroup?.id == group.id) {
            _selectedGroup = _allGroups.isNotEmpty ? _allGroups.first : null;
          }
        });
        // Перезагрузить вкладку «Список», чтобы удалённая группа исчезла оттуда тоже
        widget.onGroupChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${group.name}" ${S.of(context).delete}'),
            backgroundColor: const Color(0xFF374151),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
      }
    }
  }

  // ── GROUP ADMIN ────────────────────────────────────────────────────────────

  List<Widget> _buildGroupAdminContent() {
    final hasGroups = _myGroups.isNotEmpty;
    return [
      // Создать новую группу — выше карточки выбора группы
      _buildCreateGroupCard(),
      const SizedBox(height: 16),

      // Все карточки групп
      if (hasGroups)
        ..._myGroups.expand((g) => [
          _buildGroupCard(
            g,
            _groupMembers[g.id] ?? [],
            isSuperAdminView: false,
          ),
          const SizedBox(height: 16),
        ]),

      // ── Одна карточка: выбор группы + период + код + показатели ──
      if (hasGroups) _buildGroupOperationsCard(),
      if (hasGroups) const SizedBox(height: 16),

      // ── Личный период админа ── доступен всегда, даже без групп
      _buildAdminPersonalPeriodCard(context),
      const SizedBox(height: 16),
      _buildLanguageSwitcher(),
      const SizedBox(height: 16),
      _buildColorPicker(),
      const SizedBox(height: 16),
      _buildPinCard(context),
      const SizedBox(height: 16),
      _buildLogoutButton(),
    ];
  }

  // ── INVITE CODE CARD ───────────────────────────────────────────────────────

  Widget _buildInviteCodeCard({required bool isAdmin}) {
    final s = S.of(context);
    final activeCode = isAdmin ? _activeAdminCode : _activeUserCode;
    final expiresAt = activeCode?.expiresAt;
    final expiresLabel = expiresAt != null
        ? '${expiresAt.day.toString().padLeft(2, '0')}.${expiresAt.month.toString().padLeft(2, '0')} ${expiresAt.hour.toString().padLeft(2, '0')}:${expiresAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔑', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                isAdmin ? s.generateAdminCode : s.generateUserCode,
                style: const TextStyle(
                    color: Color(0xFFA5B4FC),
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active code display
          if (activeCode != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    activeCode.code,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.codeExpiresIn}: $expiresLabel',
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: activeCode.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.codeCopied)),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 15),
                    label: Text(s.codeLabel,
                        style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFA5B4FC),
                      side: const BorderSide(
                          color: Color(0xFF6366F1), width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _generatingCode
                        ? null
                        : (isAdmin ? _generateAdminCode : _generateUserCode),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _generatingCode
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('↻',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(s.noActiveCode,
                style: const TextStyle(
                    color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generatingCode
                    ? null
                    : (isAdmin ? _generateAdminCode : _generateUserCode),
                icon: _generatingCode
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add, size: 16),
                label: Text(
                  isAdmin ? s.generateAdminCode : s.generateUserCode,
                  style: const TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── SHARED WIDGETS ─────────────────────────────────────────────────────────

  static const _memberColors = [
    Color(0xFF6366F1), // indigo
    Color(0xFF0EA5E9), // sky
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEC4899), // pink
    Color(0xFF8B5CF6), // violet
    Color(0xFFEF4444), // red
    Color(0xFF14B8A6), // teal
  ];

  Widget _buildMemberTile(IbadatProfile m, IbadatGroup group,
      {required bool isSuperAdmin, int index = 0}) {
    final isSelf = m.id == widget.profile.id;
    final tileColor = _memberColors[index % _memberColors.length];
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: tileColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tileColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tileColor.withValues(alpha: 0.4),
                  tileColor.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                m.nickname[0].toUpperCase(),
                style: TextStyle(
                  color: tileColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(m.nickname,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                    if (m.role == 'admin') ...[
                      const SizedBox(width: 4),
                      const Text('👑', style: TextStyle(fontSize: 11)),
                    ],
                    if (group.financierId == m.id) ...[
                      const SizedBox(width: 4),
                      const Text('💼', style: TextStyle(fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: Color(0xFF94A3B8), size: 20),
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              itemBuilder: (ctx) {
                final s = S.of(ctx);
                return [
                  // Admin toggle: super-admin can only change others; group-admin can change anyone incl. themselves
                  if (!isSuperAdmin || !isSelf)
                    PopupMenuItem(
                      value: 'admin',
                      child: Row(children: [
                        Text(m.role == 'admin' ? '⬇️' : '👑',
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 10),
                        Text(
                          m.role == 'admin' ? s.removeAdmin : s.makeAdmin,
                          style: const TextStyle(
                              color: Color(0xFFFCD34D), fontSize: 13),
                        ),
                      ]),
                    ),
                  // Financier: anyone can be assigned, including self
                  PopupMenuItem(
                    value: 'financier',
                    child: Row(children: [
                      const Text('💼',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 10),
                      Text(
                        group.financierId == m.id
                            ? s.removeFinancier
                            : s.makeFinancier,
                        style: const TextStyle(
                            color: Color(0xFF34D399), fontSize: 13),
                      ),
                    ]),
                  ),
                  if (!isSelf)
                    PopupMenuItem(
                      value: 'change_group',
                      child: Row(children: [
                        const Icon(Icons.swap_horiz,
                            color: Color(0xFF38BDF8), size: 16),
                        const SizedBox(width: 10),
                        Text(s.changeGroup,
                            style: const TextStyle(
                                color: Color(0xFF38BDF8), fontSize: 13)),
                      ]),
                    ),
                  if (!isSelf)
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(children: [
                        const Icon(Icons.person_remove_outlined,
                            color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 10),
                        Text(s.removeMember,
                            style: const TextStyle(
                                color: Color(0xFFEF4444), fontSize: 13)),
                      ]),
                    ),
                ];
              },
              onSelected: (value) {
                switch (value) {
                  case 'admin':
                    _assignGroupAdmin(m, group);
                  case 'financier':
                    _assignFinancier(m, group);
                  case 'change_group':
                    _changeGroup(m);
                  case 'remove':
                    _removeMember(m);
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _changeGroup(IbadatProfile member) async {
    final otherGroups = _allGroups.where((g) => g.id != member.currentGroupId).toList();
    if (otherGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).noOtherGroups)),
      );
      return;
    }

    final selected = await showDialog<IbadatGroup>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          S.of(context).switchGroupTitle,
          style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: otherGroups.map((g) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Text('👥', style: TextStyle(fontSize: 20)),
            title: Text(g.name, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14)),
            subtitle: Text('${S.of(context).codeLabel}: ${g.code}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            onTap: () => Navigator.pop(context, g),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).cancel, style: const TextStyle(color: Color(0xFF6B7280))),
          ),
        ],
      ),
    );

    if (selected == null) return;
    final fromGroupId = member.currentGroupId;
    try {
      await _profileRepo.updateCurrentGroup(member.id, selected.id);
      if (fromGroupId != null) {
        // Move reports only for periods whose dates match in the new group
        final fromPeriods = await _periodRepo.getPeriodsForGroup(fromGroupId, includePersonal: false);
        final toPeriods = await _periodRepo.getPeriodsForGroup(selected.id, includePersonal: false);
        bool sameDay(DateTime a, DateTime b) =>
            a.year == b.year && a.month == b.month && a.day == b.day;

        for (final fp in fromPeriods) {
          final match = toPeriods.where((tp) =>
              sameDay(tp.startDate, fp.startDate) &&
              sameDay(tp.endDate, fp.endDate)).firstOrNull;
          if (match != null) {
            await _reportRepo.moveUserReportsByPeriod(
              userId: member.id,
              fromGroupId: fromGroupId,
              fromPeriodId: fp.id,
              toGroupId: selected.id,
              toPeriodId: match.id,
            );
          }
        }
        // Always move payments
        await _paymentRepo.moveUserPayments(
          userId: member.id,
          fromGroupId: fromGroupId,
          toGroupId: selected.id,
        );
      }
      await _loadData();
      widget.onGroupChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).memberMovedToGroup(member.nickname, selected.name)),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
  }

  Future<void> _assignFinancier(IbadatProfile member, IbadatGroup group) async {
    final isFinancier = group.financierId == member.id;
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💼', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              isFinancier
                  ? '${member.nickname} ${s.removeFinancier}?'
                  : '${member.nickname} "${group.name}" - ${s.makeFinancier}?',
              style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).no, style: const TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).yes,
                style: TextStyle(
                    color: isFinancier
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF10B981))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _groupRepo.updateFinancier(
            group.id, isFinancier ? null : member.id);
        if (!mounted) return;
        final newFinancierId = isFinancier ? null : member.id;
        setState(() {
          _allGroups = _allGroups.map((g) => g.id == group.id
              ? g.copyWith(
                  financierId: newFinancierId,
                  clearFinancierId: newFinancierId == null)
              : g).toList();
          _myGroups = _myGroups.map((g) => g.id == group.id
              ? g.copyWith(
                  financierId: newFinancierId,
                  clearFinancierId: newFinancierId == null)
              : g).toList();
        });
        widget.onGroupChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFinancier
                ? '${member.nickname} ${S.of(context).financierRemoved}'
                : '${member.nickname} ${S.of(context).financierAssigned}'),
            backgroundColor: const Color(0xFF374151),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
      }
    }
  }


  Widget _buildCentralPeriodsCard() {
    // Exclude admin's personal periods — they are managed separately
    final periods = _selectedGroup != null
        ? (_groupPeriods[_selectedGroup!.id] ?? [])
            .where((p) => !p.isPersonal)
            .toList()
        : <IbadatPeriod>[];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📅 ${S.of(context).periods}',
              style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 12),

          // Group selector
          if (_allGroups.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<IbadatGroup>(
                  value: _selectedGroup,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                  items: _allGroups
                      .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                      .toList(),
                  onChanged: (g) => setState(() {
                    _selectedGroup = g;
                    _periodStart = null;
                    _periodEnd = null;
                  }),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Existing periods for selected group
          if (_selectedGroup == null)
            Text(S.of(context).selectGroup,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))
          else if (periods.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(S.of(context).noPeriods,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            )
          else
            ...periods.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      const Text('📅', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.label,
                                style: const TextStyle(
                                    color: Color(0xFFE2E8F0),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(p.dateRangeLabelLocalized(S.of(context).languageCode),
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _deletePeriod(p),
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFFEF4444), size: 17),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFEF4444).withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                )),

          if (_selectedGroup != null) ...[
            const Divider(color: Color(0xFF1E293B)),
            const SizedBox(height: 8),

            // Date picker
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() {
                    _periodStart = picked;
                    _periodEnd = picked.add(const Duration(days: 6));
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Text('📅', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _periodStart == null
                          ? Text(S.of(context).selectStartDate,
                              style: const TextStyle(
                                  color: Color(0xFF475569), fontSize: 13))
                          : Text(
                              '${_periodStart!.day}.${_periodStart!.month.toString().padLeft(2, '0')}.${_periodStart!.year}  →  ${_periodEnd!.day}.${_periodEnd!.month.toString().padLeft(2, '0')}.${_periodEnd!.year}  (7 күн)',
                              style: const TextStyle(
                                  color: Color(0xFFE2E8F0), fontSize: 13),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedGroup == null
                    ? null
                    : () => _createPeriod(_selectedGroup!.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(S.of(context).createPeriod,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupOperationsCard() {
    final s = S.of(context);
    if (_adminSelectedGroup == null) return const SizedBox.shrink();
    // Exclude admin's personal periods — they are managed separately
    final periods = (_groupPeriods[_adminSelectedGroup!.id] ?? [])
        .where((p) => !p.isPersonal)
        .toList();
    final hasPeriod = periods.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Выбор группы (только если групп больше одной) ─────────
          if (_myGroups.length > 1) ...[
            Row(children: [
              const Text('🏷️', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Text(s.selectGroup,
                  style: const TextStyle(
                      color: Color(0xFFA5B4FC),
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _adminSelectedGroup!.id,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: _myGroups.map((g) => DropdownMenuItem(
                value: g.id,
                child: Text(g.name),
              )).toList(),
              onChanged: (id) {
                if (id == null) return;
                _onAdminGroupSelected(_myGroups.firstWhere((g) => g.id == id));
              },
            ),
            const SizedBox(height: 18),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 18),
          ],

          // ══ 1. ПЕРИОД ══════════════════════════════════════════════
          GestureDetector(
            onTap: () => _showPeriodsSheet(_adminSelectedGroup!.id, periods, s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.periods,
                            style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        Text(
                          hasPeriod
                              ? periods.last.dateRangeLabelLocalized(s.languageCode)
                              : s.selectStartDate,
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      color: Color(0xFF0EA5E9), size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 18),

          // ══ 2. КОД ПРИГЛАШЕНИЯ ════════════════════════════════════
          Row(children: [
            const Text('🔑', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Text(s.generateUserCode,
                style: const TextStyle(
                    color: Color(0xFFA5B4FC),
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 12),

          if (_adminSelectedCode != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
              ),
              child: Column(children: [
                Text(_adminSelectedCode!.code,
                    style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4)),
                const SizedBox(height: 4),
                Builder(builder: (_) {
                  final exp = _adminSelectedCode!.expiresAt;
                  return Text(
                    '${s.codeExpiresIn}: ${exp.day.toString().padLeft(2, '0')}.${exp.month.toString().padLeft(2, '0')} ${exp.hour.toString().padLeft(2, '0')}:${exp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 11),
                  );
                }),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: _adminSelectedCode!.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.codeCopied)));
                  },
                  icon: const Icon(Icons.copy, size: 15),
                  label: Text(s.codeLabel,
                      style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFA5B4FC),
                    side: const BorderSide(
                        color: Color(0xFF6366F1), width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _generatingCode
                      ? null
                      : () =>
                          _generateCodeForGroup(_adminSelectedGroup!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _generatingCode
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('↻',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ] else ...[
            Text(s.noActiveCode,
                style: const TextStyle(
                    color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generatingCode
                    ? null
                    : () => _generateCodeForGroup(_adminSelectedGroup!),
                icon: _generatingCode
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add, size: 16),
                label: Text(s.generateUserCode,
                    style: const TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],

          // ══ 3. ПОКАЗАТЕЛИ ГРУППЫ ══════════════════════════════════
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 18),
          ..._buildGroupMetricsSection(s),
        ],
      ),
    );
  }

  List<Widget> _buildGroupMetricsSection(AppStrings s) {
    final metrics = _groupMetrics;
    final accent = AccentProvider.instance.current.accent;
    final accentLight = AccentProvider.instance.current.accentLight;
    return [
      GestureDetector(
        onTap: () => setState(() => _metricsExpanded = !_metricsExpanded),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            const Text('📊', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.customCatsTitle,
                style: TextStyle(
                  color: accentLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${metrics.length}',
                style: TextStyle(
                  color: accentLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: _metricsExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down,
                  color: accentLight, size: 20),
            ),
          ],
        ),
      ),
      if (_metricsExpanded) ...[
        const SizedBox(height: 12),
        if (metrics.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Text(
              S.of(context).customCatEmptyHint,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          )
        else
          ...metrics.map((metric) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: metric.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: metric.color.withValues(alpha: 0.25)),
                      ),
                      child: Center(
                        child: Text(metric.icon,
                            style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.localizedName(s.languageCode),
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${metric.maxValue} ${s.unitLabel(metric.unit)}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editGroupMetric(metric),
                      icon: const Icon(Icons.edit_outlined,
                          color: Color(0xFF6366F1), size: 20),
                      tooltip: 'Изменить',
                    ),
                    IconButton(
                      onPressed: () => _deleteGroupMetric(metric),
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFEF4444), size: 20),
                      tooltip: 'Удалить',
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showAddGroupMetricDialog,
            icon: const Icon(Icons.add, size: 18),
            label: Text(s.customCatAdd),
            style: OutlinedButton.styleFrom(
              foregroundColor: accentLight,
              side: BorderSide(color: accent.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    ];
  }

  Widget _buildCreateGroupCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context).createNewGroup,
              style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: _newGroupCtrl,
            style: const TextStyle(color: Color(0xFFE2E8F0)),
            decoration: InputDecoration(
              hintText: S.of(context).groupNameHint,
              hintStyle: const TextStyle(color: Color(0xFF475569)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF6366F1)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _createGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(S.of(context).create,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminPersonalPeriodCard(BuildContext context) {
    final s = S.of(context);
    final accent = AccentProvider.instance.current.accent;
    final hasPersonalPeriod = _adminPersonalPeriods.isNotEmpty;

    return GestureDetector(
      onTap: () => _showAdminPersonalPeriodsSheet(s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Text('📋', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.myPeriodTitle,
                      style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(
                    hasPersonalPeriod
                        ? _adminPersonalPeriods.last.dateRangeLabelLocalized(s.languageCode)
                        : s.noPeriods,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: accent, size: 16),
          ],
        ),
      ),
    );
  }

  void _showAdminPersonalPeriodsSheet(AppStrings s) {
    DateTime? sheetStart;
    DateTime? sheetEnd;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final accent = AccentProvider.instance.current.accent;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Row(children: [
                  const Text('📋', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(s.myPeriodTitle,
                      style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ]),
                const SizedBox(height: 16),

                if (_adminPersonalPeriods.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(s.noPeriods,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _adminPersonalPeriods.length,
                      itemBuilder: (_, i) {
                        final p = _adminPersonalPeriods[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accent.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.label,
                                          style: const TextStyle(
                                              color: Color(0xFFE2E8F0),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                      Text(p.dateRangeLabelLocalized(s.languageCode),
                                          style: const TextStyle(
                                              color: Color(0xFF64748B), fontSize: 12)),
                                    ],
                                  ),
                                ),
                                _deletingPeriodId == p.id
                                    ? const SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Color(0xFFEF4444)))
                                    : IconButton(
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await _tryDeletePeriod(p);
                                          if (mounted) _showAdminPersonalPeriodsSheet(s);
                                        },
                                        icon: const Icon(Icons.delete_outline,
                                            color: Color(0xFFEF4444), size: 20),
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const Divider(color: Color(0xFF334155), height: 24),

                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setSheet(
                      () => _adminMetricsExpanded = !_adminMetricsExpanded),
                  child: Row(children: [
                    const Text('📊', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.customCatsTitle,
                          style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_adminMetrics.length}',
                        style: TextStyle(
                          color: AccentProvider.instance.current.accentLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _adminMetricsExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down,
                          color: Color(0xFF64748B), size: 20),
                    ),
                  ]),
                ),

                if (_adminMetricsExpanded) ...[
                  const SizedBox(height: 10),

                  if (_adminMetrics.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      s.adminPersonalMetricsHint,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _adminMetrics.length,
                      itemBuilder: (_, i) {
                        final m = _adminMetrics[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: m.color.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: m.color.withValues(alpha: 0.25)),
                                  ),
                                  child: Center(
                                    child: Text(m.icon,
                                        style: const TextStyle(fontSize: 16)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.localizedName(s.languageCode),
                                        style: const TextStyle(
                                          color: Color(0xFFE2E8F0),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${m.maxValue} ${s.unitLabel(m.unit)}',
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    await _editAdminMetric(m);
                                    setSheet(() {});
                                  },
                                  icon: const Icon(Icons.edit_outlined,
                                      color: Color(0xFF6366F1), size: 20),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    await _deleteAdminMetric(m);
                                    setSheet(() {});
                                  },
                                  icon: const Icon(Icons.delete_outline,
                                      color: Color(0xFFEF4444), size: 20),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _showAddAdminMetricDialog();
                        setSheet(() {});
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(s.customCatAdd),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AccentProvider.instance.current.accentLight,
                        side: BorderSide(color: accent.withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],

                const Divider(color: Color(0xFF334155), height: 24),

                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setSheet(() {
                        sheetStart = picked;
                        sheetEnd = picked.add(const Duration(days: 6));
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Text('📅', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: sheetStart == null
                              ? Text(s.selectStartDate,
                                  style: const TextStyle(color: Color(0xFF475569), fontSize: 13))
                              : Text(
                                  '${sheetStart!.day}.${sheetStart!.month.toString().padLeft(2, '0')}.${sheetStart!.year}  →  ${sheetEnd!.day}.${sheetEnd!.month.toString().padLeft(2, '0')}.${sheetEnd!.year}  (7 ${s.unitLabel('күн')})',
                                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13)),
                        ),
                        if (sheetStart != null)
                          GestureDetector(
                            onTap: () => setSheet(() { sheetStart = null; sheetEnd = null; }),
                            child: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: sheetStart == null
                        ? null
                        : () async {
                            setState(() {
                              _adminPeriodStart = sheetStart;
                              _adminPeriodEnd = sheetEnd;
                            });
                            Navigator.pop(ctx);
                            await _createAdminPersonalPeriod();
                            if (mounted) _showAdminPersonalPeriodsSheet(s);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(s.createPeriod,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildLanguageSwitcher() {
    final s = S.of(context);
    final currentLang = LocaleProvider.instance.value.languageCode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                s.language,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AdminLangBtn(
                  label: s.kazakh,
                  flag: '🇰🇿',
                  selected: currentLang == 'kk',
                  onTap: () => LocaleProvider.instance.setLocale(const Locale('kk')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdminLangBtn(
                  label: s.russian,
                  flag: '🇷🇺',
                  selected: currentLang == 'ru',
                  onTap: () => LocaleProvider.instance.setLocale(const Locale('ru')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _refreshGroupMetrics({String? groupId}) async {
    final targetGroupId = groupId ?? _adminSelectedGroup?.id;
    if (targetGroupId == null) return;
    final requestVersion = ++_groupMetricsLoadVersion;
    try {
      final metrics = await _metricRepo.getForGroup(targetGroupId);
      if (!mounted ||
          requestVersion != _groupMetricsLoadVersion ||
          _adminSelectedGroup?.id != targetGroupId) {
        return;
      }
      setState(() => _groupMetrics = metrics);
    } catch (e) {
      if (!mounted ||
          requestVersion != _groupMetricsLoadVersion ||
          _adminSelectedGroup?.id != targetGroupId) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
  }

  Future<void> _showAddGroupMetricDialog() async {
    final group = _adminSelectedGroup;
    if (group == null) return;
    final result = await showDialog<_GroupMetricDialogResult>(
      context: context,
      builder: (_) => const _AddGroupMetricDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await _metricRepo.create(
        groupId: group.id,
        nameRu: result.nameRu,
        nameKk: result.nameKk,
        icon: result.icon,
        colorValue: _nextMetricColorValue(),
        unit: result.unit,
        maxValue: result.maxValue,
        pointsPerUnit: result.pointsPerUnit,
        pointsValue: result.pointsValue,
        orderIndex: _nextMetricOrderIndex(),
      );
      await _refreshGroupMetrics(groupId: group.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Параметр добавлен'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
  }

  Future<void> _deleteGroupMetric(GroupMetric metric) async {
    if (metric.id == null) return;
    final hasRecordedValues = await _metricRepo.hasRecordedValues(metric.id!);
    if (!mounted || _adminSelectedGroup?.id != metric.groupId) return;
    if (hasRecordedValues) {
      final s = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.metricCannotDeleteMsg),
          backgroundColor: const Color(0xFFB45309),
        ),
      );
      return;
    }
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          s.metricDeleteTitle,
          style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700),
        ),
        content: Text(
          s.metricDeleteConfirm(metric.localizedName(s.languageCode), fromGroup: true),
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel, style: const TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete, style: const TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _adminSelectedGroup?.id != metric.groupId) {
      return;
    }
    try {
      await _metricRepo.delete(metric.id!);
      await _refreshGroupMetrics(groupId: metric.groupId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Параметр удалён'),
          backgroundColor: Color(0xFF374151),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
  }

  Future<void> _editGroupMetric(GroupMetric metric) async {
    if (metric.id == null) return;
    final s = S.of(context);
    final result = await _showEditMetricDialog(metric);
    if (result == null || !mounted) return;
    if (_adminSelectedGroup?.id != metric.groupId) return;
    try {
      await _metricRepo.updateMaxValue(metric.id!, result.maxValue);
      await _metricRepo.updatePointsRule(
        metric.id!,
        pointsPerUnit: result.pointsPerUnit,
        pointsValue: result.pointsValue,
      );
      await _refreshGroupMetrics(groupId: metric.groupId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s.error}: $e')));
    }
  }

  Future<_MetricEditResult?> _showEditMetricDialog(
    GroupMetric metric, {
    bool useRootNavigator = false,
  }) {
    return showDialog<_MetricEditResult>(
      context: context,
      useRootNavigator: useRootNavigator,
      builder: (_) => _EditMetricDialog(metric: metric),
    );
  }
  int _nextMetricOrderIndex() {
    if (_groupMetrics.isEmpty) return 0;
    final maxOrderIndex = _groupMetrics
        .map((metric) => metric.orderIndex)
        .reduce((current, next) => current > next ? current : next);
    return maxOrderIndex + 1;
  }

  Future<void> _showAdminNoticeDialog({
    required String title,
    required String message,
    Color accentColor = const Color(0xFFEF4444),
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
              color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAdminMetrics() async {
    try {
      final metrics = await _metricRepo.getForAdmin(widget.profile.id);
      if (!mounted) return;
      setState(() => _adminMetrics = metrics);
    } catch (e) {
      if (!mounted) return;
      await _showAdminNoticeDialog(
        title: S.of(context).error,
        message: '$e',
      );
    }
  }

  Future<void> _showAddAdminMetricDialog() async {
    final result = await showDialog<_GroupMetricDialogResult>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const _AddGroupMetricDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await _metricRepo.create(
        adminId: widget.profile.id,
        nameRu: result.nameRu,
        nameKk: result.nameKk,
        icon: result.icon,
        colorValue: _nextAdminMetricColorValue(),
        unit: result.unit,
        maxValue: result.maxValue,
        pointsPerUnit: result.pointsPerUnit,
        pointsValue: result.pointsValue,
        orderIndex: _nextAdminMetricOrderIndex(),
      );
      await _refreshAdminMetrics();
    } catch (e) {
      if (!mounted) return;
      await _showAdminNoticeDialog(
        title: S.of(context).error,
        message: '$e',
      );
    }
  }

  Future<void> _deleteAdminMetric(GroupMetric metric) async {
    if (metric.id == null) return;
    final hasRecordedValues = await _metricRepo.hasRecordedValues(metric.id!);
    if (!mounted) return;
    if (hasRecordedValues) {
      final s = S.of(context);
      await _showAdminNoticeDialog(
        title: s.metricCannotDeleteTitle,
        message: s.metricCannotDeleteMsg,
        accentColor: const Color(0xFFB45309),
      );
      return;
    }
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          s.metricDeleteTitle,
          style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700),
        ),
        content: Text(
          s.metricDeleteConfirm(metric.localizedName(s.languageCode)),
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel, style: const TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete, style: const TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final backup = List<GroupMetric>.from(_adminMetrics);
    setState(() => _adminMetrics = _adminMetrics.where((m) => m.id != metric.id).toList());
    try {
      await _metricRepo.delete(metric.id!);
    } catch (e) {
      if (mounted) setState(() => _adminMetrics = backup);
      if (!mounted) return;
      await _showAdminNoticeDialog(
        title: S.of(context).error,
        message: '$e',
      );
    }
  }

  Future<void> _editAdminMetric(GroupMetric metric) async {
    if (metric.id == null) return;
    final s = S.of(context);
    final result = await _showEditMetricDialog(metric, useRootNavigator: true);
    if (result == null || !mounted) return;
    try {
      await _metricRepo.updateMaxValue(metric.id!, result.maxValue);
      await _metricRepo.updatePointsRule(
        metric.id!,
        pointsPerUnit: result.pointsPerUnit,
        pointsValue: result.pointsValue,
      );
      await _refreshAdminMetrics();
    } catch (e) {
      if (!mounted) return;
      await _showAdminNoticeDialog(title: s.error, message: '$e');
    }
  }
  int _nextAdminMetricOrderIndex() {
    if (_adminMetrics.isEmpty) return 0;
    final maxOrderIndex = _adminMetrics
        .map((metric) => metric.orderIndex)
        .reduce((current, next) => current > next ? current : next);
    return maxOrderIndex + 1;
  }

  int _nextAdminMetricColorValue() {
    final used = _adminMetrics.map((metric) => metric.colorValue).toSet();
    for (final color in _metricColorPalette) {
      if (!used.contains(color)) return color;
    }
    return _metricColorPalette[_adminMetrics.length % _metricColorPalette.length];
  }

  static const List<int> _metricColorPalette = [
    0xFF0D9488,
    0xFF7C3AED,
    0xFFDB2777,
    0xFFF59E0B,
    0xFF2563EB,
    0xFF059669,
    0xFFE11D48,
    0xFF8B5CF6,
    0xFF0EA5E9,
    0xFF10B981,
    0xFFF97316,
    0xFFEC4899,
  ];

  int _nextMetricColorValue() {
    final used = _groupMetrics.map((metric) => metric.colorValue).toSet();
    for (final color in _metricColorPalette) {
      if (!used.contains(color)) return color;
    }
    return _metricColorPalette[_groupMetrics.length % _metricColorPalette.length];
  }

  Widget _buildColorPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                S.of(context).colorTheme,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: AccentProvider.instance,
            builder: (_, selected, _) => Row(
              children: List.generate(appAccents.length, (i) {
                final theme = appAccents[i];
                final isSelected = selected == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => AccentProvider.instance.setAccent(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: i < appAccents.length - 1 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: isSelected ? 0.2 : 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.accent.withValues(alpha: isSelected ? 0.7 : 0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: theme.accent,
                              shape: BoxShape.circle,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 14)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            theme.name,
                            style: TextStyle(
                              color: isSelected ? theme.accentLight : const Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinCard(BuildContext context) {
    final s = S.of(context);
    final accent = AccentProvider.instance.current.accent;
    final accentLight = AccentProvider.instance.current.accentLight;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                s.pinCode,
                style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _hasPin ? accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _hasPin ? s.pinEnabled : s.pinDisabled,
                  style: TextStyle(
                    color: _hasPin ? accentLight : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _onSetPin,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        _hasPin ? s.pinChange : s.pinSetup,
                        style: TextStyle(color: accentLight, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
              if (_hasPin) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _onDisablePin,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Center(
                        child: Text(
                          s.pinDisable,
                          style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: widget.onLogout,
        icon: const Icon(Icons.logout, size: 18),
        label: Text(S.of(context).logout),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEF4444),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _GroupMetricDialogResult {
  final String nameRu;
  final String nameKk;
  final String icon;
  final String unit;
  final int maxValue;
  final int? pointsPerUnit;
  final int? pointsValue;

  const _GroupMetricDialogResult({
    required this.nameRu,
    required this.nameKk,
    required this.icon,
    required this.unit,
    required this.maxValue,
    this.pointsPerUnit,
    this.pointsValue,
  });
}

class _MetricEditResult {
  final int maxValue;
  final int? pointsPerUnit;
  final int? pointsValue;

  const _MetricEditResult({
    required this.maxValue,
    this.pointsPerUnit,
    this.pointsValue,
  });
}

class _EditMetricDialog extends StatefulWidget {
  final GroupMetric metric;

  const _EditMetricDialog({required this.metric});

  @override
  State<_EditMetricDialog> createState() => _EditMetricDialogState();
}

class _EditMetricDialogState extends State<_EditMetricDialog> {
  late final TextEditingController _maxCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _pointsCtrl;
  String? _maxError;
  String? _amountError;
  String? _pointsError;

  @override
  void initState() {
    super.initState();
    final metric = widget.metric;
    _maxCtrl = TextEditingController(text: '${metric.maxValue}');
    _amountCtrl =
        TextEditingController(text: metric.pointsPerUnit?.toString() ?? '');
    _pointsCtrl =
        TextEditingController(text: metric.pointsValue?.toString() ?? '');
  }

  @override
  void dispose() {
    _maxCtrl.dispose();
    _amountCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, String? error) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      errorText: error,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF6366F1)),
      ),
    );
  }

  void _submit() {
    final s = S.of(context);
    final maxValue = int.tryParse(_maxCtrl.text.trim());
    final amountRaw = _amountCtrl.text.trim();
    final pointsRaw = _pointsCtrl.text.trim();
    final amountValue = amountRaw.isEmpty ? null : int.tryParse(amountRaw);
    final pointsValue = pointsRaw.isEmpty ? null : int.tryParse(pointsRaw);
    final hasScoring = amountRaw.isNotEmpty || pointsRaw.isNotEmpty;
    final invalidMsg =
        s.languageCode == 'kk' ? 'Қате мән' : 'Некорректное значение';

    if (maxValue == null ||
        maxValue <= 0 ||
        (hasScoring && (amountValue == null || amountValue <= 0)) ||
        (hasScoring && (pointsValue == null || pointsValue <= 0))) {
      setState(() {
        _maxError =
            (maxValue == null || maxValue <= 0) ? s.customCatMaxLabel : null;
        _amountError =
            hasScoring && (amountValue == null || amountValue <= 0)
                ? invalidMsg
                : null;
        _pointsError =
            hasScoring && (pointsValue == null || pointsValue <= 0)
                ? invalidMsg
                : null;
      });
      return;
    }

    Navigator.of(context).pop(
      _MetricEditResult(
        maxValue: maxValue,
        pointsPerUnit: hasScoring ? amountValue : null,
        pointsValue: hasScoring ? pointsValue : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final metric = widget.metric;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Text(metric.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              metric.localizedName(s.languageCode),
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _maxCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 16),
              onChanged: (_) {
                if (_maxError != null) setState(() => _maxError = null);
              },
              decoration:
                  _decoration('Цель (${s.unitLabel(metric.unit)})', _maxError),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 16),
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              decoration: _decoration(
                s.customCatScoringAmountLabel,
                _amountError,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pointsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 16),
              onChanged: (_) {
                if (_pointsError != null) setState(() => _pointsError = null);
              },
              decoration: _decoration(
                s.customCatPointsValueLabel,
                _pointsError,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            s.cancel,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            s.save,
            style: const TextStyle(color: Color(0xFF6366F1)),
          ),
        ),
      ],
    );
  }
}

class _AddGroupMetricDialog extends StatefulWidget {
  const _AddGroupMetricDialog();

  @override
  State<_AddGroupMetricDialog> createState() => _AddGroupMetricDialogState();
}

class _AddGroupMetricDialogState extends State<_AddGroupMetricDialog> {
  final _nameRuCtrl = TextEditingController();
  final _nameKkCtrl = TextEditingController();
  final _maxCtrl = TextEditingController(text: '10');
  final _ballCtrl = TextEditingController();
  final _pointsValueCtrl = TextEditingController();
  String _selectedIcon = '📖';
  String _selectedUnit = 'рет';
  String? _errorRu;
  String? _errorKk;
  String? _errorMax;
  String? _errorBall;
  String? _errorPointsValue;

  int? get _parsedMax {
    final v = int.tryParse(_maxCtrl.text.trim());
    return (v != null && v > 0) ? v : null;
  }

  int? get _parsedBall {
    final raw = _ballCtrl.text.trim();
    if (raw.isEmpty) return null;
    final v = int.tryParse(raw);
    return (v != null && v > 0) ? v : null;
  }

  int? get _parsedPointsValue {
    final raw = _pointsValueCtrl.text.trim();
    if (raw.isEmpty) return null;
    final v = int.tryParse(raw);
    return (v != null && v > 0) ? v : null;
  }

  bool get _ballEnabled => _parsedMax != null;

  static const _icons = [
    '📖',
    '📚',
    '📜',
    '⭐',
    '🟩',
    '🎧',
    '🌹',
    '🤲',
    '🌙',
    '📿',
    '🕌',
    '☪️',
    '🕋',
    '✨',
    '💧',
    '🔥',
    '❤️',
  ];

  static const _units = ['рет', 'бет', 'мін', 'күн'];

  @override
  void dispose() {
    _nameRuCtrl.dispose();
    _nameKkCtrl.dispose();
    _maxCtrl.dispose();
    _ballCtrl.dispose();
    _pointsValueCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final s = S.of(context);
    final nameRu = _nameRuCtrl.text.trim();
    final nameKk = _nameKkCtrl.text.trim();
    final maxValue = _parsedMax;
    final requiredMsg = s.languageCode == 'kk' ? 'Міндетті өріс' : 'Обязательное поле';
    final ballRaw = _ballCtrl.text.trim();
    final ballParsed = _parsedBall;
    final pointsValueRaw = _pointsValueCtrl.text.trim();
    final pointsValueParsed = _parsedPointsValue;
    final hasScoring = ballRaw.isNotEmpty || pointsValueRaw.isNotEmpty;

    final errRu = nameRu.isEmpty ? requiredMsg : null;
    final errKk = nameKk.isEmpty ? requiredMsg : null;
    final errMax = (maxValue == null) ? s.customCatMaxLabel : null;
    // Ball is optional. Empty → null. Non-empty must parse to >= 0.
    final errBall = (hasScoring && ballParsed == null)
        ? (s.languageCode == 'kk' ? 'Қате мән' : 'Некорректное значение')
        : null;
    final errPointsValue = (hasScoring && pointsValueParsed == null)
        ? (s.languageCode == 'kk' ? 'Қате мән' : 'Некорректное значение')
        : null;

    if (errRu != null ||
        errKk != null ||
        errMax != null ||
        errBall != null ||
        errPointsValue != null) {
      setState(() {
        _errorRu = errRu;
        _errorKk = errKk;
        _errorMax = errMax;
        _errorBall = errBall;
        _errorPointsValue = errPointsValue;
      });
      return;
    }

    Navigator.of(context).pop(
      _GroupMetricDialogResult(
        nameRu: nameRu,
        nameKk: nameKk,
        icon: _selectedIcon,
        unit: _selectedUnit,
        maxValue: maxValue!,
        pointsPerUnit: ballParsed,
        pointsValue: pointsValueParsed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final accent = AccentProvider.instance.current.accent;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        s.customCatNewTitle,
        style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.customCatNameLabel} (RU)',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameRuCtrl,
              style: const TextStyle(color: Color(0xFFE2E8F0)),
              onChanged: (_) {
                if (_errorRu != null) setState(() => _errorRu = null);
              },
              decoration: InputDecoration(
                hintText: s.customCatNameHint,
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent),
                ),
                isDense: true,
                errorText: _errorRu,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${s.customCatNameLabel} (KK)',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameKkCtrl,
              style: const TextStyle(color: Color(0xFFE2E8F0)),
              onChanged: (_) {
                if (_errorKk != null) setState(() => _errorKk = null);
              },
              decoration: InputDecoration(
                hintText: s.customCatNameHint,
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent),
                ),
                isDense: true,
                errorText: _errorKk,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              s.customCatIconLabel,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((icon) {
                final selected = _selectedIcon == icon;
                return ChoiceChip(
                  label: Text(icon, style: const TextStyle(fontSize: 18)),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedIcon = icon),
                  selectedColor: accent.withValues(alpha: 0.2),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  side: BorderSide(
                    color: selected ? accent : Colors.white.withValues(alpha: 0.06),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              s.customCatUnitLabel,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _units.map((unit) {
                final selected = _selectedUnit == unit;
                return ChoiceChip(
                  label: Text(s.unitLabel(unit)),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedUnit = unit),
                  selectedColor: accent.withValues(alpha: 0.2),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  labelStyle: TextStyle(
                    color: selected ? accent : const Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected ? accent : Colors.white.withValues(alpha: 0.06),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              s.customCatMaxLabel,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _maxCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFFE2E8F0)),
              onChanged: (_) {
                setState(() {
                  if (_errorMax != null) _errorMax = null;
                  // Re-render to enable/disable ball field + recompute total.
                });
              },
              decoration: InputDecoration(
                hintText: '10',
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent),
                ),
                isDense: true,
                errorText: _errorMax,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              s.customCatScoringAmountOptionalLabel,
              style: TextStyle(
                color: _ballEnabled ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _ballCtrl,
              keyboardType: TextInputType.number,
              enabled: _ballEnabled,
              style: TextStyle(
                color: _ballEnabled ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
              ),
              onChanged: (_) {
                setState(() {
                  if (_errorBall != null) _errorBall = null;
                });
              },
              decoration: InputDecoration(
                hintText: _ballEnabled
                    ? (s.languageCode == 'kk' ? 'Мысалы: 50' : 'Например: 50')
                    : (s.languageCode == 'kk' ? 'Алдымен максимум енгізіңіз' : 'Сначала введите максимум'),
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent),
                ),
                isDense: true,
                errorText: _errorBall,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              s.customCatPointsValueLabel,
              style: TextStyle(
                color:
                    _ballEnabled ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _pointsValueCtrl,
              keyboardType: TextInputType.number,
              enabled: _ballEnabled,
              style: TextStyle(
                color:
                    _ballEnabled ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
              ),
              onChanged: (_) {
                setState(() {
                  if (_errorPointsValue != null) _errorPointsValue = null;
                });
              },
              decoration: InputDecoration(
                hintText: _ballEnabled
                    ? (s.languageCode == 'kk' ? 'Мысалы: 1' : 'Например: 1')
                    : (s.languageCode == 'kk'
                        ? 'Алдымен максимум енгізіңіз'
                        : 'Сначала введите максимум'),
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent),
                ),
                isDense: true,
                errorText: _errorPointsValue,
              ),
            ),
            if (_parsedMax != null &&
                _parsedBall != null &&
                _parsedPointsValue != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.languageCode == 'kk' ? 'Жалпы балл: ' : 'Общий балл: ',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    Text(
                      formatMetricPoints(
                        _parsedMax! / _parsedBall! * _parsedPointsValue!,
                      ),
                      style: TextStyle(
                        color: accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel, style: const TextStyle(color: Color(0xFF94A3B8))),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AccentProvider.instance.current.accentDark,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(s.add, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _AdminLangBtn extends StatelessWidget {
  final String label;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  const _AdminLangBtn({
    required this.label,
    required this.flag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6366F1).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFA5B4FC)
                    : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

