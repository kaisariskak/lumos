import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../models/ibadat_group.dart';
import '../../models/ibadat_profile.dart';
import '../../repositories/ibadat_group_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../theme/accent_provider.dart';

class GroupPickerScreen extends StatefulWidget {
  final IbadatProfile profile;
  final VoidCallback onGroupSelected;
  final VoidCallback? onBack;

  const GroupPickerScreen({
    super.key,
    required this.profile,
    required this.onGroupSelected,
    this.onBack,
  });

  @override
  State<GroupPickerScreen> createState() => _GroupPickerScreenState();
}

class _GroupPickerScreenState extends State<GroupPickerScreen> {
  late final IbadatGroupRepository _groupRepo;
  late final ProfileRepository _profileRepo;

  List<IbadatGroup> _groups = [];
  List<IbadatProfile> _members = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _groupRepo = IbadatGroupRepository(client);
    _profileRepo = ProfileRepository(client);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      List<IbadatGroup> groups;
      List<IbadatProfile> members = [];

      if (widget.profile.isSuperAdmin) {
        groups = await _groupRepo.getAllGroups();
      } else if (widget.profile.isAdmin) {
        final all = await _groupRepo.getAllGroups();
        groups = all.where((g) => g.adminId == widget.profile.id).toList();
      } else if (widget.profile.currentGroupId != null) {
        final group = await _groupRepo.getGroupById(widget.profile.currentGroupId!);
        groups = group != null ? [group] : [];
        if (group != null) {
          members = await _groupRepo.getGroupMembers(group.id);
        }
      } else {
        groups = [];
      }

      setState(() {
        _groups = groups;
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGroup(IbadatGroup group) async {
    setState(() => _isSaving = true);
    try {
      await _profileRepo.updateCurrentGroup(widget.profile.id, group.id);
      widget.onGroupSelected();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Қосылу қатесі: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: AccentProvider.instance.current.accent))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      if (widget.onBack != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: widget.onBack,
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
                                  Text(s.back, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (widget.onBack != null) const SizedBox(height: 16),

                      // Header
                      Center(
                        child: Column(
                          children: [
                            const Text('👥', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              s.selectGroup,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.groupSubtitle,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Groups list
                      if (_groups.isEmpty)
                        Center(
                          child: Text(
                            s.noGroupsHint,
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      else ...[
                        Text(
                          s.availableGroups,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...(_groups.map((g) => _GroupCard(
                              group: g,
                              isCurrent: widget.profile.currentGroupId == g.id,
                              isSaving: _isSaving,
                              canSwitch: widget.profile.isAdmin,
                              onJoin: () => _joinGroup(g),
                            ))),
                        const SizedBox(height: 24),
                      ],

                      // Members list (only for regular users)
                      if (!widget.profile.isAdmin && _members.isNotEmpty) ...[
                        Text(
                          s.membersTitle,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._members.map((m) => _MemberCard(
                              member: m,
                              isMe: m.id == widget.profile.id,
                            )),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final IbadatGroup group;
  final bool isCurrent;
  final bool isSaving;
  final bool canSwitch;
  final VoidCallback onJoin;

  const _GroupCard({
    required this.group,
    required this.isCurrent,
    required this.isSaving,
    required this.canSwitch,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AccentProvider.instance.current;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? accent.accent.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? accent.accent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.accent.withValues(alpha: 0.2),
                accent.accentDark.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(child: Text('👥', style: TextStyle(fontSize: 22))),
        ),
        title: Text(
          group.name,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          '${S.of(context).codeLabel}: ${group.code}',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        trailing: isCurrent
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  S.of(context).currentLabel,
                  style: TextStyle(
                    color: accent.accentLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : canSwitch
                ? IconButton(
                    onPressed: isSaving ? null : onJoin,
                    icon: Icon(Icons.arrow_forward_ios,
                        color: accent.accent, size: 18),
                  )
                : null,
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final IbadatProfile member;
  final bool isMe;

  const _MemberCard({required this.member, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final initials = member.nickname.isNotEmpty
        ? member.nickname[0].toUpperCase()
        : '?';
    final accent = AccentProvider.instance.current;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? accent.accent.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? accent.accent.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isMe
                    ? [accent.accent, accent.accentDark]
                    : [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.06),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.nickname,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  member.role == 'admin' ? S.of(context).tabAdmin : S.of(context).memberRoleLabel,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isMe)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                S.of(context).youLabel,
                style: TextStyle(
                  color: accent.accentLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
