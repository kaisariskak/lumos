import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../models/ibadat_group.dart';
import '../../models/ibadat_period.dart';
import '../../models/ibadat_profile.dart';
import '../../models/invite_code.dart';
import '../../repositories/ibadat_group_repository.dart';
import '../../repositories/ibadat_period_repository.dart';
import '../../repositories/invite_code_repository.dart';
import '../../repositories/profile_repository.dart';

class AdminScreen extends StatefulWidget {
  final IbadatProfile profile;
  final IbadatGroup group;
  final VoidCallback onSwitchGroup;
  final VoidCallback onLogout;
  final VoidCallback? onGroupChanged;

  const AdminScreen({
    super.key,
    required this.profile,
    required this.group,
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
  late final InviteCodeRepository _codeRepo;

  // Super admin data
  List<IbadatGroup> _allGroups = [];
  Map<String, List<IbadatProfile>> _groupMembers = {};
  Map<String, List<IbadatPeriod>> _groupPeriods = {};
  List<IbadatProfile> _myAdmins = [];
  List<IbadatProfile> _ungroupedUsers = [];

  // Group admin data
  List<IbadatProfile> _members = [];
  List<IbadatPeriod> _periods = [];

  bool _isLoading = true;
  InviteCode? _activeUserCode;
  InviteCode? _activeAdminCode;
  bool _generatingCode = false;
  final _newGroupCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _periodLabelCtrl = TextEditingController();
  DateTime? _periodStart;
  DateTime? _periodEnd;
  DateTime? _newGroupPeriodStart;
  DateTime? _newGroupPeriodEnd;
  IbadatGroup? _selectedGroup;
  bool _isAdding = false;
  String? _addError;
  final Set<String> _expandedGroups = {};

  bool get _isSuperAdmin => widget.profile.isSuperAdmin;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _groupRepo = IbadatGroupRepository(client);
    _profileRepo = ProfileRepository(client);
    _periodRepo = IbadatPeriodRepository(client);
    _codeRepo = InviteCodeRepository(client);
    _loadData();
  }

  @override
  void dispose() {
    _newGroupCtrl.dispose();
    _emailCtrl.dispose();
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
        for (final g in groups) {
          membersMap[g.id] = await _groupRepo.getGroupMembers(g.id);
          periodsMap[g.id] = await _periodRepo.getPeriodsForGroup(g.id);
        }
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
        final results = await Future.wait([
          _groupRepo.getGroupMembers(widget.group.id),
          _groupRepo.getAllGroups(),
          _periodRepo.getPeriodsForGroup(widget.group.id),
        ]);
        setState(() {
          _members = results[0] as List<IbadatProfile>;
          _allGroups = results[1] as List<IbadatGroup>;
          _periods = results[2] as List<IbadatPeriod>;
          final prevId = _selectedGroup?.id;
          _selectedGroup = prevId != null
              ? _allGroups.firstWhere((g) => g.id == prevId,
                  orElse: () => _allGroups.isNotEmpty ? _allGroups.first : _allGroups.first)
              : _allGroups.isNotEmpty ? _allGroups.first : null;
          _isLoading = false;
        });
      }
      // Load active invite codes
      if (_isSuperAdmin) {
        _activeAdminCode = await _codeRepo.getActiveAdminCode(widget.profile.id);
      } else if (widget.profile.isAdmin) {
        _activeUserCode = await _codeRepo.getActiveUserCode(widget.group.id);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateUserCode() async {
    setState(() => _generatingCode = true);
    try {
      final code = await _codeRepo.generateUserCode(
        groupId: widget.group.id,
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

  /// Super-admin creates an admin user
  Future<void> _addAdmin() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() { _isAdding = true; _addError = null; });
    try {
      final user = await _profileRepo.getUserByEmail(email);
      if (!mounted) return;
      if (user == null) {
        // Not registered yet — add to allowlist with target_role = admin
        await _profileRepo.addToAllowlist(email, widget.profile.id, targetRole: 'admin');
        _emailCtrl.clear();
        setState(() { _addError = null; _isAdding = false; });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$email тіркелді ✅ Жүйеге кіргенде автоматты admin болады.'),
          backgroundColor: const Color(0xFF0EA5E9),
          duration: const Duration(seconds: 5),
        ));
      } else if (user.role == 'admin' && user.superAdminId == widget.profile.id) {
        setState(() { _addError = '${user.displayName} бұл супер-adminдің admin тізімінде бар'; _isAdding = false; });
      } else {
        // Existing user — promote to admin and link to this super-admin
        await _profileRepo.updateRole(user.id, 'admin');
        await _profileRepo.setSuperAdminId(user.id, widget.profile.id);
        _emailCtrl.clear();
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${user.displayName} admin болды 👑'),
          backgroundColor: const Color(0xFF059669),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _addError = '${S.of(context).error}: $e'; _isAdding = false; });
    }
  }

  /// Super-admin reassigns an ungrouped user to a group
  Future<void> _reassignUser(IbadatProfile user, String groupId) async {
    try {
      await _profileRepo.updateCurrentGroup(user.id, groupId);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${user.displayName} топқа қосылды ✅'),
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
                  ? '${member.displayName} ${s.removeAdmin}?'
                  : '${member.displayName} "${group.name}" - ${s.makeAdmin}?',
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
        await _profileRepo.updateRole(member.id, isAdmin ? 'user' : 'admin');
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAdmin
                ? '${member.displayName} ${S.of(context).adminRemoved}'
                : '${member.displayName} ${S.of(context).adminAssigned}'),
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
              '${member.displayName} ${s.removeMemberConfirm}',
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
        await _loadData();
        if (!mounted) return;
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
      // Auto-generate a USER invite code for the new group
      await _codeRepo.generateUserCode(
        groupId: group.id,
        createdBy: widget.profile.id,
      );

      _newGroupCtrl.clear();
      setState(() {
        _newGroupPeriodStart = null;
        _newGroupPeriodEnd = null;
      });
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(S.of(context).groupCreated),
            backgroundColor: const Color(0xFF059669)),
      );
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

  Future<void> _deletePeriod(IbadatPeriod period) async {
    try {
      await _periodRepo.deletePeriod(period.id);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
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
                      ? '${widget.profile.displayName} · ${S.of(context).superAdminLabel}'
                      : '${widget.profile.displayName} · ${S.of(context).groupAdminLabel}',
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
                'Менің Администраторларым',
                style: const TextStyle(
                    color: Color(0xFFFCD34D),
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_myAdmins.isEmpty)
            Text('Администраторлар жоқ',
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
                            admin.displayName[0].toUpperCase(),
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
                            Text(admin.displayName,
                                style: const TextStyle(
                                    color: Color(0xFFE2E8F0),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(admin.email,
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 11)),
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
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 12),
          // Add new admin form
          Text('Жаңа admin қосу',
              style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailCtrl,
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: s.emailHint,
                    hintStyle: const TextStyle(color: Color(0xFF475569)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isAdding ? null : _addAdmin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isAdding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Text('Қосу',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (_addError != null) ...[
            const SizedBox(height: 6),
            Text(_addError!,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
          ],
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
              const Text(
                'Топсыз пайдаланушылар',
                style: TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Топтан шығарылған. Тек супер-admin қосымша топ тағайындай алады.',
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
                              user.displayName[0].toUpperCase(),
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
                              Text(user.displayName,
                                  style: const TextStyle(
                                      color: Color(0xFFE2E8F0),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              Text(user.email,
                                  style: const TextStyle(
                                      color: Color(0xFF64748B), fontSize: 11)),
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
        await _loadData();
        if (!mounted) return;
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
    return [
      // Group card with collapsible members
      _buildGroupCard(widget.group, _members, isSuperAdminView: false),

      _buildPeriodsCard(widget.group.id, _periods),
      const SizedBox(height: 16),
      _buildInviteCodeCard(isAdmin: false),
      const SizedBox(height: 16),
      _buildCreateGroupCard(),
      const SizedBox(height: 16),
      _buildLanguageSwitcher(),
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
                m.displayName[0].toUpperCase(),
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
                      child: Text(m.displayName,
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
                Text(m.email,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 10)),
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
    try {
      await _profileRepo.updateCurrentGroup(member.id, selected.id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.displayName} → "${selected.name}" тобына ауыстырылды ✅'),
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
                  ? '${member.displayName} ${s.removeFinancier}?'
                  : '${member.displayName} "${group.name}" - ${s.makeFinancier}?',
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
        await _loadData();
        if (!mounted) return;
        widget.onGroupChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFinancier
                ? '${member.displayName} ${S.of(context).financierRemoved}'
                : '${member.displayName} ${S.of(context).financierAssigned}'),
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
    final periods = _selectedGroup != null
        ? (_groupPeriods[_selectedGroup!.id] ?? [])
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
          const SizedBox(height: 10),
          Text('📅 ${S.of(context).startDateOptional}',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          const SizedBox(height: 6),
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
                  _newGroupPeriodStart = picked;
                  _newGroupPeriodEnd = picked.add(const Duration(days: 6));
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
                    child: _newGroupPeriodStart == null
                        ? Text(S.of(context).selectStartDate,
                            style: const TextStyle(
                                color: Color(0xFF475569), fontSize: 13))
                        : Text(
                            '${_newGroupPeriodStart!.day}.${_newGroupPeriodStart!.month.toString().padLeft(2, '0')}.${_newGroupPeriodStart!.year}  →  ${_newGroupPeriodEnd!.day}.${_newGroupPeriodEnd!.month.toString().padLeft(2, '0')}.${_newGroupPeriodEnd!.year}  (7 ${S.of(context).unitLabel('күн')})',
                            style: const TextStyle(
                                color: Color(0xFFE2E8F0), fontSize: 13),
                          ),
                  ),
                  if (_newGroupPeriodStart != null)
                    GestureDetector(
                      onTap: () => setState(() {
                        _newGroupPeriodStart = null;
                        _newGroupPeriodEnd = null;
                      }),
                      child: const Icon(Icons.close,
                          size: 16, color: Color(0xFF64748B)),
                    ),
                ],
              ),
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

  Widget _buildPeriodsCard(String groupId, List<IbadatPeriod> periods) {
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

          // Existing periods
          if (periods.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(S.of(context).noPeriods,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            )
          else
            ...periods.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      const Text('📅',
                          style: TextStyle(fontSize: 14)),
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
                                    color: Color(0xFF64748B),
                                    fontSize: 11)),
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

          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 8),

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
                            '${_periodStart!.day}.${_periodStart!.month.toString().padLeft(2, '0')}.${_periodStart!.year}  →  ${_periodEnd!.day}.${_periodEnd!.month.toString().padLeft(2, '0')}.${_periodEnd!.year}  (7 ${S.of(context).unitLabel('күн')})',
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
              onPressed: () => _createPeriod(groupId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(S.of(context).createPeriod,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
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
